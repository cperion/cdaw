-- tools/incremental_memoize_probe.t
-- Human-readable probe for memoize/incremental recompilation behavior.

local D = require("daw-unified")
require("impl/init")
local session = require("app/session")
local F = require("impl/_support/fallbacks")
local L = F.L

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
    local resolved = authored:resolve()
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
    }
    s.track_ptrs = {}
    s.graph_ptrs = {}
    for i = 1, #scheduled.track_programs do
        s.track_ptrs[i] = ptr(scheduled.track_programs[i]:compile().fn)
        s.graph_ptrs[i] = ptr(scheduled.track_programs[i].device_graph:compile().fn)
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
    show_bool("track 1 track-unit ptr changed", before.track_ptrs[1] ~= after.track_ptrs[1])
    show_bool("track 1 graph-unit ptr reused", before.graph_ptrs[1] == after.graph_ptrs[1])
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
    show_bool("track 1 track-unit ptr changed", before.track_ptrs[1] ~= after.track_ptrs[1])
    show_bool("track 1 graph-unit ptr changed", before.graph_ptrs[1] ~= after.graph_ptrs[1])
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

print("")
line()
print("Rule reminder:")
print("  terralib.memoize keys by Lua equality on explicit args only.")
print("  No hidden semantic state. Explicit params or ASDL-owned structure only.")
line()
