-- tests/memoize_incremental.t
-- Verifies memoize/incremental recompilation behavior on the slice/program/unit pipeline.

local D = require("daw-unified")
require("impl/init")
local session = require("app/session")
local F = require("impl/_support/fallbacks")
local L = F.L

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
        track_id, name, 2, D.Editor.AudioTrack, D.Editor.NoInput,
        static_param(0, "vol", vol, 0, 4),
        static_param(1, "pan", pan, -1, 1),
        D.Editor.DeviceChain(L{
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                osc_id, name .. " Osc", D.Authored.SquareOsc(),
                L{static_param(0, "freq", freq, 1, 20000)},
                L(), nil, nil, nil, true, nil
            )),
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                gain_id, name .. " Gain", D.Authored.GainNode(),
                L{static_param(0, "gain", gain, 0, 4)},
                L(), nil, nil, nil, true, nil
            ))
        }),
        L(), L(), L(), nil, nil,
        false, false, false, false, false, nil
    )
end

local function make_project(buffer_size)
    return D.Editor.Project(
        "memoize_incremental", nil, 1,
        D.Editor.Transport(44100, buffer_size or 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            make_track(1, "Track 1", 10, 11, 110, 0.5, 0.8, 0.0),
            make_track(2, "Track 2", 20, 21, 220, 0.25, 0.6, 0.0),
        },
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )
end

local function ptr(fn)
    return fn and fn:getpointer() or nil
end

local function snapshot(project)
    local authored = project:lower()
    local resolved = authored:resolve()
    local classified = resolved:classify()
    local scheduled = classified:schedule()
    local kernel = scheduled:compile()

    local track_units = {}
    local graph_units = {}
    local track_ptrs = {}
    local graph_ptrs = {}
    for i = 1, #scheduled.track_programs do
        track_units[i] = scheduled.track_programs[i]:compile()
        graph_units[i] = scheduled.track_programs[i].device_graph:compile()
        track_ptrs[i] = ptr(track_units[i].fn)
        graph_ptrs[i] = ptr(graph_units[i].fn)
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
    }
end

print("1. Same project twice => full memoize reuse")
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
    end
    print("  PASS")
end

print("2. Track volume edit => only affected track program recompiles")
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

    check(before.authored.tracks[1] ~= after.authored.tracks[1], "authored track 1 changed")
    check(before.resolved.track_slices[1] ~= after.resolved.track_slices[1], "resolved track slice 1 changed")
    check(before.classified.track_slices[1] ~= after.classified.track_slices[1], "classified track slice 1 changed")
    check(before.scheduled.track_programs[1] ~= after.scheduled.track_programs[1], "scheduled track program 1 changed")
    check(before.track_ptrs[1] ~= after.track_ptrs[1], "track 1 fn ptr changed")

    check(before.scheduled.track_programs[1].device_graph == after.scheduled.track_programs[1].device_graph,
        "track 1 graph program reused on mixer-only edit")
    check(before.graph_ptrs[1] == after.graph_ptrs[1], "track 1 graph fn ptr reused on mixer-only edit")
    check(before.render_ptr ~= after.render_ptr, "top render fn changed")
    print("  PASS")
end

print("3. Device param edit => affected graph program recompiles, sibling stays cached")
do
    local base = make_project(64)
    local before = snapshot(base)
    local edited = session.update_project_param(base, 11, 0, 0.75)
    local after = snapshot(edited)

    check(edited.tracks[2] == base.tracks[2], "untouched editor track shared")
    check(before.track_ptrs[2] == after.track_ptrs[2], "track 2 fn ptr reused")
    check(before.graph_ptrs[2] == after.graph_ptrs[2], "track 2 graph fn ptr reused")

    check(before.scheduled.track_programs[1] ~= after.scheduled.track_programs[1], "track 1 program changed")
    check(before.track_ptrs[1] ~= after.track_ptrs[1], "track 1 fn ptr changed")
    check(before.scheduled.track_programs[1].device_graph ~= after.scheduled.track_programs[1].device_graph,
        "track 1 graph program changed")
    check(before.graph_ptrs[1] ~= after.graph_ptrs[1], "track 1 graph fn ptr changed")
    check(before.render_ptr ~= after.render_ptr, "top render fn changed")
    print("  PASS")
end

print("4. Transport change => semantic transport args invalidate schedule/compile, not resolve/classify slices")
do
    local base = make_project(64)
    local before = snapshot(base)
    local edited = D.Editor.Project(
        base.name, base.author, base.format_version,
        D.Editor.Transport(44100, 128, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        base.tracks, base.scenes, base.tempo_map, base.assets
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

print("")
print(string.format("Memoize incremental: %d pass, %d fail (%d total)", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
