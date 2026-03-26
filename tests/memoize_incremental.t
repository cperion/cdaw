-- tests/memoize_incremental.t
-- Verifies memoize/incremental recompilation behavior on the slice/program/unit pipeline.

local DAW = require("daw")
local D = DAW.types
local session = require("app/session")
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local TICKS_PER_BEAT = 960

local pass, fail = 0, 0
local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. m) end
end

local function static_param(id, name, value, mn, mx)
    return D.Editor.ParamValue(
        id, name, value, mn, mx,
        D.Editor.StaticValue(value),
        D.Editor.Replace,
        D.Editor.NoSmoothing
    )
end

local function make_track(track_id, name, osc_id, gain_id, freq, gain, vol, pan)
    return D.Editor.Track(
        track_id, name, nil, nil, 2, D.Editor.AudioTrack, D.Editor.NoInput, D.Editor.MasterOutput,
        static_param(0, "vol", vol, 0, 4),
        static_param(1, "pan", pan, -1, 1),
        D.Editor.DeviceChain(L{
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                osc_id, name .. " Osc", D.Authored.SquareOsc,
                L{static_param(0, "freq", freq, 1, 20000)},
                L(), nil, nil, nil, true, true, nil
            )),
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                gain_id, name .. " Gain", D.Authored.GainNode,
                L{static_param(0, "gain", gain, 0, 4)},
                L(), nil, nil, nil, true, true, nil
            ))
        }),
        L(), L(), L(), L(), nil,
        true, false, false, false, false, false, D.Editor.CrossBoth, L(), nil
    )
end

local function make_project(buffer_size)
    return D.Editor.Project(
        "memoize_incremental", nil, 1,
        D.Editor.Transport(44100, buffer_size or 64, 120, 4, 4, D.Editor.QNone, false, nil, false, nil),
        L{
            make_track(1, "Track 1", 10, 11, 110, 0.5, 0.8, 0.0),
            make_track(2, "Track 2", 20, 21, 220, 0.25, 0.6, 0.0),
        },
        L(),  -- scenes
        L(),  -- cue_markers
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )
end

local function ptr(fn)
    return fn and fn:getpointer() or nil
end

local function snapshot(project)
    local authored = project:lower()
    local resolved = authored:resolve(TICKS_PER_BEAT)
    local classified = resolved:classify()
    local scheduled = classified:schedule()
    local kernel = scheduled:compile()

    local track_units = {}
    local graph_units = {}
    local track_ptrs = {}
    local graph_ptrs = {}
    local node_programs = {}
    local node_units = {}
    local node_ptrs = {}
    local mix_programs = {}
    local mix_units = {}
    local mix_ptrs = {}
    local output_programs = {}
    local output_units = {}
    local output_ptrs = {}

    for i = 1, #scheduled.track_programs do
        local tp = scheduled.track_programs[i]
        track_units[i] = tp:compile()
        graph_units[i] = tp.device_graph:compile()
        track_ptrs[i] = ptr(track_units[i].fn)
        graph_ptrs[i] = ptr(graph_units[i].fn)

        node_programs[i] = {}
        node_units[i] = {}
        node_ptrs[i] = {}
        for j = 1, #tp.device_graph.node_programs do
            node_programs[i][j] = tp.device_graph.node_programs[j]
            node_units[i][j] = tp.device_graph.node_programs[j]:compile()
            node_ptrs[i][j] = ptr(node_units[i][j].fn)
        end

        mix_programs[i] = {}
        mix_units[i] = {}
        mix_ptrs[i] = {}
        for j = 1, #tp.mix_programs do
            mix_programs[i][j] = tp.mix_programs[j]
            mix_units[i][j] = tp.mix_programs[j]:compile()
            mix_ptrs[i][j] = ptr(mix_units[i][j].fn)
        end

        output_programs[i] = {}
        output_units[i] = {}
        output_ptrs[i] = {}
        for j = 1, #tp.output_programs do
            output_programs[i][j] = tp.output_programs[j]
            output_units[i][j] = tp.output_programs[j]:compile()
            output_ptrs[i][j] = ptr(output_units[i][j].fn)
        end
    end

    return {
        project = project,
        authored = authored,
        resolved = resolved,
        classified = classified,
        scheduled = scheduled,
        kernel = kernel,
        render_ptr = ptr(kernel:entry_fn()),
        track_units = track_units,
        graph_units = graph_units,
        track_ptrs = track_ptrs,
        graph_ptrs = graph_ptrs,
        node_programs = node_programs,
        node_units = node_units,
        node_ptrs = node_ptrs,
        mix_programs = mix_programs,
        mix_units = mix_units,
        mix_ptrs = mix_ptrs,
        output_programs = output_programs,
        output_units = output_units,
        output_ptrs = output_ptrs,
    }
end

local function check_node_reuse(a, b, track_index, label)
    for j = 1, #a.node_programs[track_index] do
        check(a.node_programs[track_index][j] == b.node_programs[track_index][j],
            label .. " node program " .. j .. " reused")
        check(a.node_units[track_index][j] == b.node_units[track_index][j],
            label .. " node unit " .. j .. " reused")
        check(a.node_ptrs[track_index][j] == b.node_ptrs[track_index][j],
            label .. " node fn ptr " .. j .. " reused")
    end
end

local function check_mix_reuse(a, b, track_index, label)
    for j = 1, #a.mix_programs[track_index] do
        check(a.mix_programs[track_index][j] == b.mix_programs[track_index][j],
            label .. " mix program " .. j .. " reused")
        check(a.mix_units[track_index][j] == b.mix_units[track_index][j],
            label .. " mix unit " .. j .. " reused")
        check(a.mix_ptrs[track_index][j] == b.mix_ptrs[track_index][j],
            label .. " mix fn ptr " .. j .. " reused")
    end
end

local function check_output_reuse(a, b, track_index, label)
    for j = 1, #a.output_programs[track_index] do
        check(a.output_programs[track_index][j] == b.output_programs[track_index][j],
            label .. " output program " .. j .. " reused")
        check(a.output_units[track_index][j] == b.output_units[track_index][j],
            label .. " output unit " .. j .. " reused")
        check(a.output_ptrs[track_index][j] == b.output_ptrs[track_index][j],
            label .. " output fn ptr " .. j .. " reused")
    end
end

local function check_output_changed(a, b, track_index, label)
    for j = 1, #a.output_programs[track_index] do
        check(a.output_programs[track_index][j] ~= b.output_programs[track_index][j],
            label .. " output program " .. j .. " changed")
        check(a.output_ptrs[track_index][j] ~= b.output_ptrs[track_index][j],
            label .. " output fn ptr " .. j .. " changed")
    end
end

print("1. Same project twice => full memoize reuse down to leaf program units")
do
    local project = make_project(64)
    local a = snapshot(project)
    local b = snapshot(project)

    check(a.authored == b.authored, "authored project reused")
    check(a.resolved == b.resolved, "resolved project reused")
    check(a.classified == b.classified, "classified project reused")
    check(a.scheduled == b.scheduled, "scheduled project reused")
    check(a.kernel == b.kernel, "kernel project reused")
    check(a.render_ptr == b.render_ptr, "render fn pointer reused")
    for i = 1, 2 do
        check(a.authored.tracks[i] == b.authored.tracks[i], "authored track " .. i .. " reused")
        check(a.resolved.track_slices[i] == b.resolved.track_slices[i], "resolved track slice " .. i .. " reused")
        check(a.classified.track_slices[i] == b.classified.track_slices[i], "classified track slice " .. i .. " reused")
        check(a.scheduled.track_programs[i] == b.scheduled.track_programs[i], "scheduled track program " .. i .. " reused")
        check(a.track_units[i] == b.track_units[i], "track unit " .. i .. " reused")
        check(a.graph_units[i] == b.graph_units[i], "graph unit " .. i .. " reused")
        check(a.track_ptrs[i] == b.track_ptrs[i], "track unit fn ptr " .. i .. " reused")
        check(a.graph_ptrs[i] == b.graph_ptrs[i], "graph unit fn ptr " .. i .. " reused")
        check_node_reuse(a, b, i, "track " .. i)
        check_mix_reuse(a, b, i, "track " .. i)
        check_output_reuse(a, b, i, "track " .. i)
    end
    print("  PASS")
end

print("2. Track volume edit => mixer recompiles, graph/node leaves stay cached")
do
    local base = make_project(64)
    local before = snapshot(base)
    local edited = session.update_project_track_volume(base, 1, 0.4)
    local after = snapshot(edited)

    check(edited ~= base, "edited project changed")
    check(edited.tracks[2] == base.tracks[2], "untouched editor track shared")

    check(before.authored.tracks[2] == after.authored.tracks[2], "authored track 2 reused")
    check(before.resolved.track_slices[2] == after.resolved.track_slices[2], "resolved track slice 2 reused")
    check(before.classified.track_slices[2] == after.classified.track_slices[2], "classified track slice 2 reused")
    check(before.scheduled.track_programs[2] == after.scheduled.track_programs[2], "scheduled track program 2 reused")
    check(before.track_ptrs[2] == after.track_ptrs[2], "track 2 fn ptr reused")
    check(before.graph_ptrs[2] == after.graph_ptrs[2], "track 2 graph fn ptr reused")
    check_node_reuse(before, after, 2, "track 2")
    check_mix_reuse(before, after, 2, "track 2")
    check_output_reuse(before, after, 2, "track 2")

    check(before.authored.tracks[1] ~= after.authored.tracks[1], "authored track 1 changed")
    check(before.resolved.track_slices[1] ~= after.resolved.track_slices[1], "resolved track slice 1 changed")
    check(before.classified.track_slices[1] ~= after.classified.track_slices[1], "classified track slice 1 changed")
    check(before.scheduled.track_programs[1] ~= after.scheduled.track_programs[1], "scheduled track program 1 changed")
    check(before.track_ptrs[1] ~= after.track_ptrs[1], "track 1 fn ptr changed")

    check(before.scheduled.track_programs[1].device_graph == after.scheduled.track_programs[1].device_graph,
        "track 1 graph program reused on mixer-only edit")
    check(before.graph_ptrs[1] == after.graph_ptrs[1], "track 1 graph fn ptr reused on mixer-only edit")
    check_node_reuse(before, after, 1, "track 1")
    check_mix_reuse(before, after, 1, "track 1")
    check_output_changed(before, after, 1, "track 1")
    check(before.render_ptr ~= after.render_ptr, "top render fn changed")
    print("  PASS")
end

print("3. Device param edit => affected track/graph recompiles, sibling track leaves stay cached")
do
    local base = make_project(64)
    local before = snapshot(base)
    local edited = session.update_project_param(base, 11, 0, 0.75)
    local after = snapshot(edited)

    check(edited.tracks[2] == base.tracks[2], "untouched editor track shared")
    check(before.track_ptrs[2] == after.track_ptrs[2], "track 2 fn ptr reused")
    check(before.graph_ptrs[2] == after.graph_ptrs[2], "track 2 graph fn ptr reused")
    check_node_reuse(before, after, 2, "track 2")
    check_mix_reuse(before, after, 2, "track 2")
    check_output_reuse(before, after, 2, "track 2")

    check(before.scheduled.track_programs[1] ~= after.scheduled.track_programs[1], "track 1 program changed")
    check(before.track_ptrs[1] ~= after.track_ptrs[1], "track 1 fn ptr changed")
    check(before.scheduled.track_programs[1].device_graph ~= after.scheduled.track_programs[1].device_graph,
        "track 1 graph program changed")
    check(before.graph_ptrs[1] ~= after.graph_ptrs[1], "track 1 graph fn ptr changed")
    check(before.node_programs[1][1] == after.node_programs[1][1], "track 1 node program 1 reused")
    check(before.node_units[1][1] == after.node_units[1][1], "track 1 node unit 1 reused")
    check(before.node_ptrs[1][1] == after.node_ptrs[1][1], "track 1 node fn ptr 1 reused")
    check(before.node_programs[1][2] ~= after.node_programs[1][2], "track 1 node program 2 changed")
    check(before.node_ptrs[1][2] ~= after.node_ptrs[1][2], "track 1 node fn ptr 2 changed")
    check_mix_reuse(before, after, 1, "track 1")
    check_output_reuse(before, after, 1, "track 1")
    check(before.render_ptr ~= after.render_ptr, "top render fn changed")
    print("  PASS")
end

print("4. Transport change => semantic transport args invalidate schedule/compile, not resolve/classify slices")
do
    local base = make_project(64)
    local before = snapshot(base)
    local edited = D.Editor.Project(
        base.name, base.author, base.format_version,
        D.Editor.Transport(44100, 128, 120, 4, 4, D.Editor.QNone, false, nil, false, nil),
        base.tracks, base.scenes, base.cue_markers, base.tempo_map, base.assets
    )
    local after = snapshot(edited)

    check(edited.tracks == base.tracks, "tracks structurally reused at editor level")
    check(before.authored.tracks[1] == after.authored.tracks[1], "authored track 1 reused")
    check(before.authored.tracks[2] == after.authored.tracks[2], "authored track 2 reused")
    check(before.resolved.track_slices[1] == after.resolved.track_slices[1], "resolved track slice 1 reused")
    check(before.resolved.track_slices[2] == after.resolved.track_slices[2], "resolved track slice 2 reused")
    check(before.classified.track_slices[1] == after.classified.track_slices[1], "classified track slice 1 reused")
    check(before.classified.track_slices[2] == after.classified.track_slices[2], "classified track slice 2 reused")

    check(before.scheduled.track_programs[1] ~= after.scheduled.track_programs[1], "scheduled track program 1 changed")
    check(before.scheduled.track_programs[2] ~= after.scheduled.track_programs[2], "scheduled track program 2 changed")
    check(before.track_ptrs[1] ~= after.track_ptrs[1], "track 1 fn ptr changed")
    check(before.track_ptrs[2] ~= after.track_ptrs[2], "track 2 fn ptr changed")
    check(before.render_ptr ~= after.render_ptr, "top render fn changed")
    print("  PASS")
end

print("5. Session undo restores original hot path and leaf units")
do
    local project = make_project(64)
    local s = session.new(project)
    local before = snapshot(s.project)
    local before_render = ptr(s:render_fn())

    s:set_track_volume(1, 0.4)
    local edited = snapshot(s.project)

    s:undo()
    local undone = snapshot(s.project)
    local undone_render = ptr(s:render_fn())

    check(s.project == project, "undo restored original project object")
    check(before.render_ptr == undone.render_ptr, "undo restored project render ptr")
    check(before_render == undone_render, "undo restored live session render ptr")
    check(before.track_ptrs[1] == undone.track_ptrs[1], "undo restored track 1 fn ptr")
    check(before.track_ptrs[2] == undone.track_ptrs[2], "undo restored track 2 fn ptr")
    check(before.graph_ptrs[1] == undone.graph_ptrs[1], "undo restored track 1 graph fn ptr")
    check(before.graph_ptrs[2] == undone.graph_ptrs[2], "undo restored track 2 graph fn ptr")
    check_node_reuse(before, undone, 1, "undo track 1")
    check_node_reuse(before, undone, 2, "undo track 2")
    check_mix_reuse(before, undone, 1, "undo track 1")
    check_mix_reuse(before, undone, 2, "undo track 2")
    check_output_reuse(before, undone, 1, "undo track 1")
    check_output_reuse(before, undone, 2, "undo track 2")
    check(edited.render_ptr ~= undone.render_ptr, "undo diverged from edited render ptr")
    print("  PASS")
end

print("6. Session redo restores edited hot path and leaf units")
do
    local project = make_project(64)
    local s = session.new(project)
    s:set_track_volume(1, 0.4)
    local edited = snapshot(s.project)
    local edited_render = ptr(s:render_fn())

    s:undo()
    s:redo()
    local redone = snapshot(s.project)
    local redone_render = ptr(s:render_fn())

    check(redone.render_ptr == edited.render_ptr, "redo restored project render ptr")
    check(redone_render == edited_render, "redo restored live session render ptr")
    check(redone.track_ptrs[1] == edited.track_ptrs[1], "redo restored track 1 fn ptr")
    check(redone.track_ptrs[2] == edited.track_ptrs[2], "redo restored track 2 fn ptr")
    check(redone.graph_ptrs[1] == edited.graph_ptrs[1], "redo restored track 1 graph fn ptr")
    check(redone.graph_ptrs[2] == edited.graph_ptrs[2], "redo restored track 2 graph fn ptr")
    check_node_reuse(edited, redone, 1, "redo track 1")
    check_node_reuse(edited, redone, 2, "redo track 2")
    check_mix_reuse(edited, redone, 1, "redo track 1")
    check_mix_reuse(edited, redone, 2, "redo track 2")
    check_output_reuse(edited, redone, 1, "redo track 1")
    check_output_reuse(edited, redone, 2, "redo track 2")
    print("  PASS")
end

print("7. Same-value session edit is a no-op")
do
    local project = make_project(64)
    local s = session.new(project)
    local before_project = s.project
    local before_render = ptr(s:render_fn())

    s:set_track_volume(1, 0.8)

    check(s.project == before_project, "same-value edit preserved project identity")
    check(ptr(s:render_fn()) == before_render, "same-value edit preserved render fn ptr")
    print("  PASS")
end

print("")
print(string.format("Memoize incremental: %d pass, %d fail (%d total)", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
