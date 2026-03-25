-- tools/incremental_memoize_probe.t
-- Human-readable probe for memoize/incremental recompilation behavior.

local D = require("daw-unified")
require("impl/init")
local session = require("app/session")
local F = require("impl/_support/fallbacks")
local L = F.L
local TICKS_PER_BEAT = 960

local function static_param(id, name, value, mn, mx)
    return D.Editor.ParamValue(id, name, value, mn, mx, D.Editor.StaticValue(value), D.Editor.Replace, D.Editor.NoSmoothing)
end

local function make_track(track_id, name, osc_id, gain_id, freq, gain, vol)
    return D.Editor.Track(
        track_id, name, 2, D.Editor.AudioTrack, D.Editor.NoInput,
        static_param(0, "vol", vol, 0, 4),
        static_param(1, "pan", 0.0, -1, 1),
        D.Editor.DeviceChain(L{
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(osc_id, name .. " Osc", D.Authored.SquareOsc(), L{static_param(0, "freq", freq, 1, 20000)}, L(), nil, nil, nil, true, nil)),
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(gain_id, name .. " Gain", D.Authored.GainNode(), L{static_param(0, "gain", gain, 0, 4)}, L(), nil, nil, nil, true, nil))
        }),
        L(), L(), L(), nil, nil, false, false, false, false, false, nil
    )
end

local function make_project(buffer_size)
    return D.Editor.Project(
        "memoize_probe", nil, 1,
        D.Editor.Transport(44100, buffer_size or 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            make_track(1, "Track 1", 10, 11, 110, 0.5, 0.8),
            make_track(2, "Track 2", 20, 21, 220, 0.25, 0.6),
        },
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()), D.Authored.AssetBank(L(), L(), L(), L(), L())
    )
end

local function ptr(fn) return fn and fn:getpointer() or nil end

local function snap(project)
    local authored = project:lower()
    local resolved = authored:resolve(TICKS_PER_BEAT)
    local classified = resolved:classify()
    local scheduled = classified:schedule()
    local kernel = scheduled:compile()
    local s = {
        authored = authored,
        resolved = resolved,
        classified = classified,
        scheduled = scheduled,
        kernel = kernel,
        render_ptr = ptr(kernel:entry_fn()),
        track_ptrs = {},
        graph_ptrs = {},
        node_ptrs = {},
        mix_ptrs = {},
        output_ptrs = {},
    }
    for i = 1, #scheduled.track_programs do
        local tp = scheduled.track_programs[i]
        s.track_ptrs[i] = ptr(tp:compile().fn)
        s.graph_ptrs[i] = ptr(tp.device_graph:compile().fn)
        s.node_ptrs[i] = {}
        for j = 1, #tp.device_graph.node_programs do
            s.node_ptrs[i][j] = ptr(tp.device_graph.node_programs[j]:compile().fn)
        end
        s.mix_ptrs[i] = {}
        for j = 1, #tp.mix_programs do
            s.mix_ptrs[i][j] = ptr(tp.mix_programs[j]:compile().fn)
        end
        s.output_ptrs[i] = {}
        for j = 1, #tp.output_programs do
            s.output_ptrs[i][j] = ptr(tp.output_programs[j]:compile().fn)
        end
    end
    return s
end

local function line() print(string.rep("─", 72)) end
local function show_bool(label, v) print(string.format("  %-48s %s", label .. ":", v and "YES" or "NO")) end

print("╔════════════════════════════════════════════════════════════════════╗")
print("║              Incremental memoize / JIT probe                     ║")
print("╚════════════════════════════════════════════════════════════════════╝")
print("")

line()
print("1. Same project twice")
do
    local p = make_project(64)
    local a = snap(p)
    local b = snap(p)
    show_bool("authored project reused", a.authored == b.authored)
    show_bool("resolved project reused", a.resolved == b.resolved)
    show_bool("classified project reused", a.classified == b.classified)
    show_bool("scheduled project reused", a.scheduled == b.scheduled)
    show_bool("kernel render ptr reused", a.render_ptr == b.render_ptr)
    for i = 1, 2 do
        show_bool("track " .. i .. " unit ptr reused", a.track_ptrs[i] == b.track_ptrs[i])
        show_bool("track " .. i .. " graph unit ptr reused", a.graph_ptrs[i] == b.graph_ptrs[i])
        for j = 1, #a.node_ptrs[i] do
            show_bool("track " .. i .. " node " .. j .. " ptr reused", a.node_ptrs[i][j] == b.node_ptrs[i][j])
        end
        for j = 1, #a.mix_ptrs[i] do
            show_bool("track " .. i .. " mix " .. j .. " ptr reused", a.mix_ptrs[i][j] == b.mix_ptrs[i][j])
        end
        for j = 1, #a.output_ptrs[i] do
            show_bool("track " .. i .. " output " .. j .. " ptr reused", a.output_ptrs[i][j] == b.output_ptrs[i][j])
        end
    end
end

line()
print("2. Mixer-only edit on track 1 (track volume)")
do
    local p = make_project(64)
    local before = snap(p)
    local after = snap(session.update_project_track_volume(p, 1, 0.4))
    show_bool("track 2 track-unit ptr reused", before.track_ptrs[2] == after.track_ptrs[2])
    show_bool("track 2 graph-unit ptr reused", before.graph_ptrs[2] == after.graph_ptrs[2])
    show_bool("track 2 node 1 ptr reused", before.node_ptrs[2][1] == after.node_ptrs[2][1])
    show_bool("track 2 node 2 ptr reused", before.node_ptrs[2][2] == after.node_ptrs[2][2])
    show_bool("track 2 mix ptr reused", before.mix_ptrs[2][1] == after.mix_ptrs[2][1])
    show_bool("track 2 output ptr reused", before.output_ptrs[2][1] == after.output_ptrs[2][1])
    show_bool("track 1 track-unit ptr changed", before.track_ptrs[1] ~= after.track_ptrs[1])
    show_bool("track 1 graph-unit ptr reused", before.graph_ptrs[1] == after.graph_ptrs[1])
    show_bool("track 1 node 1 ptr reused", before.node_ptrs[1][1] == after.node_ptrs[1][1])
    show_bool("track 1 node 2 ptr reused", before.node_ptrs[1][2] == after.node_ptrs[1][2])
    show_bool("track 1 mix ptr reused", before.mix_ptrs[1][1] == after.mix_ptrs[1][1])
    show_bool("track 1 output ptr changed", before.output_ptrs[1][1] ~= after.output_ptrs[1][1])
    show_bool("project render ptr changed", before.render_ptr ~= after.render_ptr)
end

line()
print("3. Device edit on track 1 (gain parameter)")
do
    local p = make_project(64)
    local before = snap(p)
    local after = snap(session.update_project_param(p, 11, 0, 0.75))
    show_bool("track 2 track-unit ptr reused", before.track_ptrs[2] == after.track_ptrs[2])
    show_bool("track 2 graph-unit ptr reused", before.graph_ptrs[2] == after.graph_ptrs[2])
    show_bool("track 2 node 1 ptr reused", before.node_ptrs[2][1] == after.node_ptrs[2][1])
    show_bool("track 2 node 2 ptr reused", before.node_ptrs[2][2] == after.node_ptrs[2][2])
    show_bool("track 2 mix ptr reused", before.mix_ptrs[2][1] == after.mix_ptrs[2][1])
    show_bool("track 2 output ptr reused", before.output_ptrs[2][1] == after.output_ptrs[2][1])
    show_bool("track 1 track-unit ptr changed", before.track_ptrs[1] ~= after.track_ptrs[1])
    show_bool("track 1 graph-unit ptr changed", before.graph_ptrs[1] ~= after.graph_ptrs[1])
    show_bool("track 1 node 1 ptr reused", before.node_ptrs[1][1] == after.node_ptrs[1][1])
    show_bool("track 1 node 2 ptr changed", before.node_ptrs[1][2] ~= after.node_ptrs[1][2])
    show_bool("track 1 mix ptr reused", before.mix_ptrs[1][1] == after.mix_ptrs[1][1])
    show_bool("track 1 output ptr reused", before.output_ptrs[1][1] == after.output_ptrs[1][1])
    show_bool("project render ptr changed", before.render_ptr ~= after.render_ptr)
end

line()
print("4. Transport edit only (buffer size 64 -> 128)")
do
    local p = make_project(64)
    local before = snap(p)
    local p2 = D.Editor.Project(p.name, p.author, p.format_version,
        D.Editor.Transport(44100, 128, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        p.tracks, p.scenes, p.tempo_map, p.assets)
    local after = snap(p2)
    show_bool("resolved track slice 1 reused", before.resolved.track_slices[1] == after.resolved.track_slices[1])
    show_bool("resolved track slice 2 reused", before.resolved.track_slices[2] == after.resolved.track_slices[2])
    show_bool("track 1 track-unit ptr changed", before.track_ptrs[1] ~= after.track_ptrs[1])
    show_bool("track 2 track-unit ptr changed", before.track_ptrs[2] ~= after.track_ptrs[2])
    show_bool("project render ptr changed", before.render_ptr ~= after.render_ptr)
end

line()
print("5. Session undo / redo hot swap")
do
    local p = make_project(64)
    local s = session.new(p):compile()
    local base = snap(s.project)
    local base_render = ptr(s.render_fn)

    s:set_track_volume(1, 0.4)
    local edited = snap(s.project)
    local edited_render = ptr(s.render_fn)

    s:undo()
    local undone = snap(s.project)
    local undone_render = ptr(s.render_fn)

    show_bool("undo restored original project object", s.project == p)
    show_bool("undo restored render ptr", base.render_ptr == undone.render_ptr and base_render == undone_render)
    show_bool("undo restored track 1 node 1 ptr", base.node_ptrs[1][1] == undone.node_ptrs[1][1])
    show_bool("undo restored track 1 mix ptr", base.mix_ptrs[1][1] == undone.mix_ptrs[1][1])
    show_bool("undo restored track 1 output ptr", base.output_ptrs[1][1] == undone.output_ptrs[1][1])
    show_bool("undo diverged from edited ptr", edited.render_ptr ~= undone.render_ptr)

    s:redo()
    local redone = snap(s.project)
    local redone_render = ptr(s.render_fn)
    show_bool("redo restored edited render ptr", redone.render_ptr == edited.render_ptr and redone_render == edited_render)
    show_bool("redo restored edited track 1 node 1 ptr", redone.node_ptrs[1][1] == edited.node_ptrs[1][1])
    show_bool("redo restored edited track 1 mix ptr", redone.mix_ptrs[1][1] == edited.mix_ptrs[1][1])
    show_bool("redo restored edited track 1 output ptr", redone.output_ptrs[1][1] == edited.output_ptrs[1][1])
end

print("")
line()
print("Rule reminder:")
print("  terralib.memoize keys by Lua equality on explicit args only.")
print("  No hidden semantic state. Explicit params or ASDL-owned structure only.")
line()
