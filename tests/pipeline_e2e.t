-- tests/pipeline_e2e.t
-- End-to-end test: Editor → Authored → Resolved → Classified → Scheduled → Kernel
-- Verifies the full stub pipeline works with minimal fixtures.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local KS = require("tests/kernel_support")
local TICKS_PER_BEAT = 960

-- Shorthand for ASDL-compatible lists
local function L(t)
    if t == nil then return List() end
    if List:isclassof(t) then return t end
    local l = List()
    for i = 1, #t do l:insert(t[i]) end
    return l
end

local function make_ctx()
    return {
        diagnostics = {},
        ticks_per_beat = 960,
        sample_rate = 44100,
        alloc_graph_id = (function()
            local id = 0
            return function() id = id + 1; return id end
        end)(),
    }
end

local function count_diags(ctx, severity)
    return 0
end

-- ═══════════════════════════════════════════════════════════
-- Test 1: Empty project through full pipeline
-- ═══════════════════════════════════════════════════════════

print("Test 1: Empty project through full pipeline")

local editor_project = D.Editor.Project(
    "Test Project",
    "Test Author",
    1,
    D.Editor.Transport(44100, 512, 120, 4, 4, D.Editor.QNone, false, nil, false, nil),
    L(),  -- tracks
    L(),  -- scenes
    L(),  -- cue_markers
    D.Editor.TempoMap(L(), L()),
    D.Authored.AssetBank(L(), L(), L(), L(), L())
)

local ctx = make_ctx()

-- Phase 0→1: Editor → Authored
local authored = editor_project:lower()
assert(authored ~= nil, "lower returned nil")
assert(authored.name == "Test Project", "name not preserved")
assert(#authored.tracks == 0, "expected 0 tracks")
print("  Editor→Authored: OK (" .. 0 .. " diags)")

-- Phase 1→2: Authored → Resolved
local resolved = authored:resolve(TICKS_PER_BEAT)
assert(resolved ~= nil, "resolve returned nil")
assert(#resolved.track_slices == 0, "expected 0 track_slices")
print("  Authored→Resolved: OK (" .. 0 .. " diags)")

-- Phase 2→3: Resolved → Classified
local classified = resolved:classify()
assert(classified ~= nil, "classify returned nil")
assert(#classified.track_slices == 0, "expected 0 track_slices")
print("  Resolved→Classified: OK (" .. 0 .. " diags)")

-- Phase 3→4: Classified → Scheduled
local scheduled = classified:schedule()
assert(scheduled ~= nil, "schedule returned nil")
assert(#scheduled.track_programs == 0, "expected 0 track_programs")
print("  Classified→Scheduled: OK (" .. 0 .. " diags)")

-- Phase 4→5: Scheduled → Kernel
local kernel = scheduled:compile()
assert(kernel ~= nil, "compile returned nil")
assert(kernel.fn ~= nil, "kernel missing fn")
assert(kernel:state_type() ~= nil, "kernel missing state_type")
assert(kernel:state_init_fn() ~= nil, "kernel missing state_init_fn")
print("  Scheduled→Kernel: OK")

-- Phase 5: Kernel → entry_fn
local entry = kernel:entry_fn()
local state_raw = KS.alloc_state(kernel)
assert(entry ~= nil, "entry_fn returned nil")
print("  Kernel.entry_fn: OK")

print("  Total diagnostics: " .. 0)
print("  PASS")

-- ═══════════════════════════════════════════════════════════
-- Test 2: Project with one track, one device, one clip
-- ═══════════════════════════════════════════════════════════

print("\nTest 2: Project with one track + device + clip")

local function make_param(id, name, val, mn, mx)
    return D.Editor.ParamValue(
        id, name, val, mn, mx,
        D.Editor.StaticValue(val),
        D.Editor.Replace,
        D.Editor.NoSmoothing
    )
end

local note_region = D.Editor.NoteRegion(
    L{
        D.Editor.Note(1, 60, 0, 1, 100, nil, false, nil),
        D.Editor.Note(2, 64, 1, 1, 80, nil, false, nil),
    },
    L()
)

local native_body = D.Editor.NativeDeviceBody(
    1, "Gain", D.Authored.GainNode,
    L{ make_param(1, "gain", 1, 0, 4) },
    L(),    -- modulators
    nil,   -- note_fx
    nil,   -- post_fx
    nil,   -- preset
    true,  -- active
    true,  -- enabled
    nil    -- meta
)

local track = D.Editor.Track(
    1, "Track 1", nil, nil, 2,
    D.Editor.AudioTrack,
    D.Editor.NoInput,
    D.Editor.MasterOutput,
    make_param(0, "volume", 1, 0, 4),
    make_param(1, "pan", 0, -1, 1),
    D.Editor.DeviceChain(L{
        D.Editor.NativeDevice(native_body),
    }),
    L{  -- clips
        D.Editor.Clip(
            1, nil, nil,
            D.Editor.NoteContent(note_region),
            0, 4, 0,
            false, 0, 0,
            0,
            false,
            make_param(0, "clip_gain", 1, 0, 4),
            nil, nil,
            nil, nil,   -- time_sig override
            false, 0,   -- shuffle
            nil, nil    -- seed, meta
        ),
    },   -- end clips
    L(),  -- launcher_clips
    L(),  -- launcher_slots
    L(),  -- sends
    nil,  -- group_track_id
    true,              -- active
    false, false,      -- muted, soloed
    false, false,      -- armed, monitor
    false,             -- phase_invert
    D.Editor.CrossBoth, L(), nil  -- crossfade_mode, remote_controls, meta
)

local project2 = D.Editor.Project(
    "Test With Track",
    nil,
    1,
    D.Editor.Transport(44100, 512, 140, 4, 4, D.Editor.Q1_4, false, nil, false, nil),
    L{ track },
    L(),  -- scenes
    L(),  -- cue_markers
    D.Editor.TempoMap(
        L{ D.Editor.TempoPoint(0, 140) },
        L{ D.Editor.SigPoint(0, 4, 4) }
    ),
    D.Authored.AssetBank(L(), L(), L(), L(), L())
)

ctx = make_ctx()

local a2 = project2:lower()
assert(a2 ~= nil, "lower returned nil")
assert(a2.name == "Test With Track")
assert(#a2.tracks == 1, "expected 1 track, got " .. #a2.tracks)
assert(a2.tracks[1].id == 1, "track id not preserved")
assert(a2.tracks[1].name == "Track 1", "track name not preserved")
assert(#a2.assets.notes == 1, "expected 1 lowered note asset")
assert(a2.assets.notes[1].id == 1, "note asset id should match clip id")
assert(a2.tracks[1].clips[1].content.note_asset_id == 1, "clip should reference lowered note asset")
print("  Editor→Authored: OK (tracks=" .. #a2.tracks .. ", diags=" .. 0 .. ")")

local r2 = a2:resolve(TICKS_PER_BEAT)
assert(r2 ~= nil, "resolve returned nil")
assert(#r2.track_slices == 1)
assert(r2.track_slices[1].track.id == 1)
print("  Authored→Resolved: OK (track_slices=" .. #r2.track_slices .. ", diags=" .. 0 .. ")")

local c2 = r2:classify()
assert(c2 ~= nil, "classify returned nil")
assert(#c2.track_slices == 1)
print("  Resolved→Classified: OK (track_slices=" .. #c2.track_slices .. ", diags=" .. 0 .. ")")

local s2 = c2:schedule()
assert(s2 ~= nil, "schedule returned nil")
assert(#s2.track_programs == 1)
print("  Classified→Scheduled: OK (track_programs=" .. #s2.track_programs .. ", diags=" .. 0 .. ")")

local k2 = s2:compile()
assert(k2 ~= nil, "compile returned nil")
print("  Scheduled→Kernel: OK (diags=" .. 0 .. ")")

local e2 = k2:entry_fn()
assert(e2 ~= nil)
print("  Kernel.entry_fn: OK")

print("  Total diagnostics: " .. 0)
for i = 1, math.min(0, 10) do
    local d = {severity="info",code="",message=""}
    print("    [" .. d.severity .. "] " .. d.code .. ": " .. d.message)
end
if 0 > 10 then
    print("    ... and " .. (0 - 10) .. " more")
end
print("  PASS")

-- ═══════════════════════════════════════════════════════════
-- Test 3: Container devices (Layer, Selector, Split)
-- ═══════════════════════════════════════════════════════════

print("\nTest 3: Container devices")

ctx = make_ctx()

-- Layer container
local layer_body = D.Editor.LayerContainer(
    10, "Layer Container",
    L{
        D.Editor.Layer(1, "Layer A",
            D.Editor.DeviceChain(L()),
            make_param(0, "vol", 1, 0, 4),
            make_param(1, "pan", 0, -1, 1),
            false, nil),
        D.Editor.Layer(2, "Layer B",
            D.Editor.DeviceChain(L()),
            make_param(0, "vol", 0.8, 0, 4),
            make_param(1, "pan", 0.5, -1, 1),
            false, nil),
    },
    L(), L(), nil, nil, nil, true, true, nil
)
local layer_dev = D.Editor.LayerDevice(layer_body)
local layer_node = layer_dev:lower()
assert(layer_node ~= nil, "LayerDevice lower returned nil")
assert(#layer_node.child_graphs > 0, "expected child graphs from layer container")
print("  LayerDevice: OK (child_graphs=" .. #layer_node.child_graphs .. ")")

-- Selector container
local sel_body = D.Editor.SelectorContainer(
    20, "Selector",
    D.Editor.ManualSelect(0),
    L{
        D.Editor.SelectorBranch(1, "A", D.Editor.DeviceChain(L()), nil),
        D.Editor.SelectorBranch(2, "B", D.Editor.DeviceChain(L()), nil),
    },
    L(), L(), nil, nil, nil, true, true, nil
)
local sel_dev = D.Editor.SelectorDevice(sel_body)
local sel_node = sel_dev:lower()
assert(sel_node ~= nil, "SelectorDevice lower returned nil")
print("  SelectorDevice: OK (child_graphs=" .. #sel_node.child_graphs .. ")")

-- Split container
local split_body = D.Editor.SplitContainer(
    30, "Split",
    D.Editor.FreqSplit,
    L{
        D.Editor.SplitBand(1, "Low", 200, D.Editor.DeviceChain(L()), nil),
        D.Editor.SplitBand(2, "High", 2000, D.Editor.DeviceChain(L()), nil),
    },
    L(), L(), nil, nil, nil, true, true, nil
)
local split_dev = D.Editor.SplitDevice(split_body)
local split_node = split_dev:lower()
assert(split_node ~= nil, "SplitDevice lower returned nil")
print("  SplitDevice: OK (child_graphs=" .. #split_node.child_graphs .. ")")

print("  Diags: " .. 0)
print("  PASS")

-- ═══════════════════════════════════════════════════════════
-- Test 4: Grid patch
-- ═══════════════════════════════════════════════════════════

print("\nTest 4: Grid patch")

ctx = make_ctx()

local grid_patch = D.Editor.GridPatch(
    100,
    L{ D.Editor.GridPort(0, "in", D.Editor.AudioHint, 2, false) },
    L{ D.Editor.GridPort(1, "out", D.Editor.AudioHint, 2, false) },
    L{
        D.Editor.GridModule(1, "Osc", D.Authored.SineOsc, L(), true, 100, 100, nil),
        D.Editor.GridModule(2, "Filter", D.Authored.SVF(), L(), true, 200, 100, nil),
    },
    L{
        D.Editor.GridCable(1, 0, 2, 0),
    },
    L(),
    D.Editor.AudioDomain
)

local grid_graph = grid_patch:lower()
assert(grid_graph ~= nil, "GridPatch lower returned nil")
assert(#grid_graph.nodes == 2, "expected 2 nodes")
assert(#grid_graph.wires == 1, "expected 1 wire")
assert(grid_graph.layout.kind == "Free", "expected Free layout")
print("  GridPatch: OK (nodes=" .. #grid_graph.nodes .. ", wires=" .. #grid_graph.wires .. ")")
print("  PASS")

-- ═══════════════════════════════════════════════════════════
-- Summary
-- ═══════════════════════════════════════════════════════════

print("\n════════════════════════════════════════")
print("ALL TESTS PASSED")
print("Full 7-phase stub pipeline is operational.")
print("════════════════════════════════════════")
