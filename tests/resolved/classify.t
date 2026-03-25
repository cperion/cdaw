-- tests/resolved/classify.t
-- Per-method tests for all 9 Resolved → Classified classify methods.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

-- ══════════════════════════════════════════
-- 1. resolved.transport.classify
-- ══════════════════════════════════════════
print("1. resolved.transport.classify")
do
    local t = D.Resolved.Transport(48000, 512, 140, 0.1, 3, 8, 4, true, 1920, 7680)
    local ctx = {diagnostics = {}}
    local r = t:classify(ctx)
    check(r.sample_rate == 48000, "sample_rate")
    check(r.buffer_size == 512, "buffer_size")
    check(r.bpm == 140, "bpm")
    check(approx(r.swing, 0.1), "swing")
    check(r.looping == true, "looping")
    check(r.loop_start_tick == 1920, "loop_start")
    check(r.loop_end_tick == 7680, "loop_end")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 2. resolved.tempo_map.classify
-- ══════════════════════════════════════════
print("2. resolved.tempo_map.classify")
do
    local tm = D.Resolved.TempoMap(L{
        D.Resolved.TempoSeg(0, 120, 0, 22.96875),
        D.Resolved.TempoSeg(3840, 60, 88200, 45.9375),
    })
    local ctx = {diagnostics = {}}
    local r = tm:classify(ctx)
    check(#r.segments == 2, "2 segments")
    -- Classified adds end_tick
    check(r.segments[1].start_tick == 0, "seg1 start=0")
    check(r.segments[1].end_tick == 3840, "seg1 end_tick=3840, got " .. r.segments[1].end_tick)
    check(r.segments[2].start_tick == 3840, "seg2 start=3840")
    check(r.segments[2].bpm == 60, "seg2 bpm=60")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 3. resolved.track.classify
-- ══════════════════════════════════════════
print("3. resolved.track.classify")
do
    local t = D.Resolved.Track(5, "Bass", 2, 1, 1, 0, 0, 1, 10,
        0, 2, 0, 1, L{8}, nil, nil, true, false, false, false, true)
    -- Build classify ctx with classified params and track indices
    local vol_binding = D.Classified.Binding(0, 3)
    local pan_binding = D.Classified.Binding(0, 4)
    local ctx = {
        diagnostics = {},
        _classified_params = {
            [1] = D.Classified.Param(0, 0, 1, 0, 4, vol_binding, 0, 0, 0, 0, 0, 0),
            [2] = D.Classified.Param(1, 0, 0, -1, 1, pan_binding, 0, 0, 0, 0, 0, 0),
        },
        _track_vol_idx = {[5] = 0},
        _track_pan_idx = {[5] = 1},
    }
    local r = t:classify(ctx)
    check(r.id == 5, "track id")
    check(r.channels == 2, "channels")
    check(r.volume.rate_class == 0, "vol rate_class=0")
    check(r.volume.slot == 3, "vol slot=3")
    check(r.pan.slot == 4, "pan slot=4")
    check(r.muted_structural == true, "muted")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 4. resolved.graph.classify
-- ══════════════════════════════════════════
print("4. resolved.graph.classify")
do
    local g = D.Resolved.Graph(10, 0, 1, 0, 2, 2, 1,
        L{20, 21}, L{0, 1}, 0, 0, 0, 0, 0, 0)
    local next_sig = 0
    local ctx = {diagnostics = {},
        alloc_signal = function(self, c) local b = next_sig; next_sig = next_sig + c; return b end}
    local r = g:classify(ctx)
    check(r.id == 10, "graph id")
    check(r.wire_count == 2, "wire_count=2")
    check(r.signal_count == 3, "signal_count=3 (2in+1out)")
    check(r.first_signal == 0, "first_signal=0")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 5. resolved.node.classify
-- ══════════════════════════════════════════
print("5. resolved.node.classify")
do
    -- LFOMod (kind_code=156) needs state
    local n = D.Resolved.Node(42, 156, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, true, nil, 0, 0, 0, 0)
    local next_state = 10
    local ctx = {diagnostics = {},
        alloc_signal = function(self, c) return 0 end,
        alloc_state_slot = function(self, sz) local b = next_state; next_state = next_state + sz; return b end}
    local r = n:classify(ctx)
    check(r.node_kind_code == 156, "kind=LFOMod")
    check(r.state_size == 1, "LFOMod state_size=1")
    check(r.runtime_state_slot == 10, "state_slot=10")

    -- GainNode (5) needs no state
    local n2 = D.Resolved.Node(43, 5, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, true, nil, 0, 0, 0, 0)
    local r2 = n2:classify(ctx)
    check(r2.state_size == 0, "GainNode no state")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 6. resolved.param.classify
-- ══════════════════════════════════════════
print("6. resolved.param.classify")
do
    -- Static param
    local p = D.Resolved.Param(0, 42, "cutoff", 1000, 20, 20000,
        D.Resolved.ParamSourceRef(0, 5000, nil), 0, 0, 0)
    local literals = {}
    local ctx = {diagnostics = {},
        alloc_literal = function(self, v) local s = #literals; literals[s+1] = v; return s end,
        alloc_block_slot = function(self) return 99 end}
    local r = p:classify(ctx)
    check(r.base_value.rate_class == 0, "static → literal (rc=0)")
    check(r.base_value.slot == 0, "literal slot=0")
    check(#literals == 1, "1 literal interned")
    check(approx(literals[1], 5000), "literal=5000")

    -- Automation param
    local p2 = D.Resolved.Param(1, 42, "vol", 1, 0, 1,
        D.Resolved.ParamSourceRef(1, 0, 0), 0, 0, 0)
    local r2 = p2:classify(ctx)
    check(r2.base_value.rate_class == 2, "automation → block (rc=2)")
    check(r2.base_value.slot == 99, "block slot=99")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 7. resolved.mod_slot.classify
-- ══════════════════════════════════════════
print("7. resolved.mod_slot.classify")
do
    local ms = D.Resolved.ModSlot(3, 100, 200, true, 0, 2)
    local next_state = 0
    local ctx = {diagnostics = {},
        alloc_state_slot = function(self, sz) local b = next_state; next_state = next_state + sz; return b end}
    local r = ms:classify(ctx)
    check(r.slot_index == 3, "slot_index")
    check(r.parent_node_id == 100, "parent_node_id")
    check(r.per_voice == true, "per_voice")
    check(r.output_binding.rate_class == 3, "output rc=3 (sample)")
    check(r.output_binding.slot == 0, "output slot=0")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 8. resolved.mod_route.classify
-- ══════════════════════════════════════════
print("8. resolved.mod_route.classify")
do
    local mr = D.Resolved.ModRoute(3, 42, 0.75, true, nil, nil)
    local lits = {}
    local ctx = {diagnostics = {},
        alloc_literal = function(self, v) local s = #lits; lits[s+1] = v; return s end}
    local r = mr:classify(ctx)
    check(r.target_param_id == 42, "target")
    check(r.bipolar == true, "bipolar")
    check(r.depth.rate_class == 0, "depth rc=0 (literal)")
    check(approx(lits[1], 0.75), "depth literal=0.75")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 9. resolved.project.classify (integration)
-- ══════════════════════════════════════════
print("9. resolved.project.classify — integration")
do
    -- Build via full pipeline
    local project = D.Editor.Project(
        "Test", nil, 1,
        D.Editor.Transport(44100, 256, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "v", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "p", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "G", D.Authored.GainNode(),
                    L{D.Editor.ParamValue(0, "g", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local ctx = {diagnostics = {}}
    local a = project:lower(ctx)
    local r = a:resolve(ctx)
    local c = r:classify(ctx)
    check(#c.graphs >= 1, "classified graphs")
    check(#c.nodes >= 1, "classified nodes")
    check(#c.params >= 1, "classified params")
    check(#c.literals >= 1, "literals populated")
    check(c.total_signals >= 0, "total_signals tracked")
    print("  PASS")
end

-- Summary
print("")
print(string.format("Resolved classify: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
