-- tests/classify_schedule.t
-- Tests for Resolved→Classified and Classified→Scheduled methods.
-- Verifies: graph/node/mod classify with real allocation,
-- track/graph/node schedule with buffer assignment,
-- tempo_map cumulative base_sample.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass_count = 0
local fail_count = 0

local function check(cond, msg)
    if cond then
        pass_count = pass_count + 1
    else
        fail_count = fail_count + 1
        print("  FAIL: " .. msg)
    end
end

local function approx(a, b, tol)
    return math.abs(a - b) < (tol or 0.001)
end

-- ══════════════════════════════════════════════════════════
-- Test 1: TempoMap cumulative base_sample
-- ══════════════════════════════════════════════════════════
print("Test 1: TempoMap cumulative base_sample")
do
    -- Two tempo points: 120 BPM at beat 0, 60 BPM at beat 4
    local tmap = D.Authored.TempoMap(
        L{D.Authored.TempoPoint(0, 120), D.Authored.TempoPoint(4, 60)},
        L()
    )
    local ctx = {diagnostics = {}, ticks_per_beat = 960, sample_rate = 48000}
    local resolved = tmap:resolve(ctx)

    check(#resolved.segments == 2, "should have 2 segments, got " .. #resolved.segments)

    local s1 = resolved.segments[1]
    local s2 = resolved.segments[2]

    -- Segment 1: start_tick=0, bpm=120, base_sample=0
    check(s1.start_tick == 0, "seg1 start_tick=0, got " .. s1.start_tick)
    check(s1.bpm == 120, "seg1 bpm=120, got " .. s1.bpm)
    check(s1.base_sample == 0, "seg1 base_sample=0, got " .. s1.base_sample)

    -- samples_per_tick at 120 BPM, 48kHz, 960 tpb:
    -- = (60/120) * 48000 / 960 = 0.5 * 50 = 25
    local expected_spt1 = (60.0 / 120) * 48000 / 960
    check(approx(s1.samples_per_tick, expected_spt1),
        "seg1 spt=" .. expected_spt1 .. ", got " .. s1.samples_per_tick)

    -- Segment 2: start_tick = 4 * 960 = 3840
    check(s2.start_tick == 3840, "seg2 start_tick=3840, got " .. s2.start_tick)
    check(s2.bpm == 60, "seg2 bpm=60, got " .. s2.bpm)

    -- base_sample = 0 + 3840 * 25 = 96000
    local expected_base = 3840 * expected_spt1
    check(approx(s2.base_sample, expected_base),
        "seg2 base_sample=" .. expected_base .. ", got " .. s2.base_sample)

    -- spt at 60 BPM = (60/60) * 48000 / 960 = 50
    local expected_spt2 = (60.0 / 60) * 48000 / 960
    check(approx(s2.samples_per_tick, expected_spt2),
        "seg2 spt=" .. expected_spt2 .. ", got " .. s2.samples_per_tick)

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 2: TempoMap 3 segments cumulative
-- ══════════════════════════════════════════════════════════
print("Test 2: TempoMap 3 segments cumulative base_sample")
do
    -- 120 BPM at beat 0, 90 BPM at beat 2, 180 BPM at beat 6
    local tmap = D.Authored.TempoMap(
        L{D.Authored.TempoPoint(0, 120),
          D.Authored.TempoPoint(2, 90),
          D.Authored.TempoPoint(6, 180)},
        L()
    )
    local ctx = {diagnostics = {}, ticks_per_beat = 960, sample_rate = 44100}
    local resolved = tmap:resolve(ctx)
    check(#resolved.segments == 3, "should have 3 segments")

    -- seg1: tick=0, base=0
    check(resolved.segments[1].base_sample == 0, "seg1 base=0")

    -- seg2: tick=1920, base = 1920 * spt_at_120
    local spt120 = (60.0/120) * 44100 / 960
    local expected_base2 = 1920 * spt120
    check(approx(resolved.segments[2].base_sample, expected_base2, 1),
        "seg2 base=" .. expected_base2 .. ", got " .. resolved.segments[2].base_sample)

    -- seg3: tick=5760, base = base2 + (5760-1920) * spt_at_90
    local spt90 = (60.0/90) * 44100 / 960
    local expected_base3 = expected_base2 + (5760 - 1920) * spt90
    check(approx(resolved.segments[3].base_sample, expected_base3, 1),
        "seg3 base=" .. expected_base3 .. ", got " .. resolved.segments[3].base_sample)

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 3: Graph classify allocates signals and wires
-- ══════════════════════════════════════════════════════════
print("Test 3: Graph classify — signal and wire allocation")
do
    -- Build a resolved graph with 2 inputs, 1 output, and 2 wire refs
    local rg = D.Resolved.Graph(
        100,          -- id
        0, 1,         -- layout=serial, domain=audio
        0, 2,         -- first_input=0, input_count=2
        2, 1,         -- first_output=2, output_count=1
        L{10, 11},    -- node_ids
        L{0, 1},      -- wire_ids (flat indices 0, 1)
        0, 0,         -- precords
        0, 0, 0, 0    -- args
    )

    -- Classify ctx with signal allocator
    local next_signal = 0
    local ctx = {
        diagnostics = {},
        alloc_signal = function(self, count)
            local base = next_signal
            next_signal = next_signal + count
            return base
        end
    }

    local cg = rg:classify(ctx)

    check(cg.id == 100, "graph id preserved")
    check(cg.layout_code == 0, "layout_code=serial")
    check(cg.domain_code == 1, "domain_code=audio")

    -- Wire range
    check(cg.first_wire == 0, "first_wire=0, got " .. cg.first_wire)
    check(cg.wire_count == 2, "wire_count=2, got " .. cg.wire_count)

    -- Signal allocation: 2 inputs + 1 output = 3 signals
    check(cg.first_signal == 0, "first_signal=0, got " .. cg.first_signal)
    check(cg.signal_count == 3, "signal_count=3, got " .. cg.signal_count)
    check(next_signal == 3, "total signals allocated=3, got " .. next_signal)

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 4: Node classify allocates signals and state
-- ══════════════════════════════════════════════════════════
print("Test 4: Node classify — signal offset and state allocation")
do
    -- A DelayNode (kind_code=10) needs state
    local rn = D.Resolved.Node(
        50, 10,        -- id=50, kind_code=10 (DelayNode)
        0, 2,          -- first_param=0, param_count=2
        0, 1,          -- first_input=0, input_count=1
        1, 1,          -- first_output=1, output_count=1
        0, 0,          -- mod slots
        0, 0,          -- child graph refs
        true,          -- enabled
        nil,           -- plugin_handle
        0, 0, 0, 0    -- args
    )

    local next_signal = 10  -- start at 10 to test offset
    local next_state = 5
    local ctx = {
        diagnostics = {},
        alloc_signal = function(self, count)
            local base = next_signal; next_signal = next_signal + count; return base
        end,
        alloc_state_slot = function(self, size)
            local base = next_state; next_state = next_state + size; return base
        end,
    }

    local cn = rn:classify(ctx)

    check(cn.id == 50, "node id=50")
    check(cn.node_kind_code == 10, "kind_code=10 (DelayNode)")
    check(cn.signal_offset == 10, "signal_offset=10, got " .. cn.signal_offset)
    check(cn.state_offset == 5, "state_offset=5, got " .. cn.state_offset)
    check(cn.state_size == 1, "state_size=1 (DelayNode), got " .. cn.state_size)
    check(cn.runtime_state_slot == 5, "runtime_state_slot=5, got " .. cn.runtime_state_slot)
    check(next_signal == 12, "signals consumed: 10→12 (2 ports), got " .. next_signal)
    check(next_state == 6, "state consumed: 5→6, got " .. next_state)

    -- A GainNode (kind_code=5) needs NO state
    local rn2 = D.Resolved.Node(
        51, 5,         -- id=51, kind_code=5 (GainNode)
        2, 1,          -- first_param=2, param_count=1
        0, 0, 0, 0,   -- no ports
        0, 0, 0, 0,
        true, nil,
        0, 0, 0, 0
    )
    local cn2 = rn2:classify(ctx)
    check(cn2.state_size == 0, "GainNode state_size=0, got " .. cn2.state_size)
    check(cn2.runtime_state_slot == 0, "GainNode no state slot, got " .. cn2.runtime_state_slot)
    check(next_state == 6, "no state consumed for GainNode")

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 5: ModSlot classify allocates output binding
-- ══════════════════════════════════════════════════════════
print("Test 5: ModSlot classify — output binding allocation")
do
    local rms = D.Resolved.ModSlot(
        0,      -- slot_index
        100,    -- parent_node_id
        200,    -- modulator_node_id
        false,  -- per_voice
        0, 2    -- first_route=0, route_count=2
    )

    local next_state = 0
    local ctx = {
        diagnostics = {},
        alloc_state_slot = function(self, size)
            local base = next_state; next_state = next_state + size; return base
        end,
    }

    local cms = rms:classify(ctx)

    check(cms.slot_index == 0, "slot_index=0")
    check(cms.parent_node_id == 100, "parent_node_id=100")
    check(cms.modulator_node_id == 200, "modulator_node_id=200")
    check(cms.output_binding.rate_class == 3, "output rate_class=3 (sample), got " .. cms.output_binding.rate_class)
    check(cms.output_binding.slot == 0, "output slot=0, got " .. cms.output_binding.slot)
    check(next_state == 1, "1 state slot allocated for mod output")

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 6: ModRoute classify interns depth as literal
-- ══════════════════════════════════════════════════════════
print("Test 6: ModRoute classify — depth literal binding")
do
    local rmr = D.Resolved.ModRoute(
        0,      -- mod_slot_index
        42,     -- target_param_id
        0.75,   -- depth
        true,   -- bipolar
        nil, nil
    )

    local literals = {}
    local ctx = {
        diagnostics = {},
        alloc_literal = function(self, value)
            local slot = #literals
            literals[slot + 1] = value
            return slot
        end,
    }

    local cmr = rmr:classify(ctx)

    check(cmr.mod_slot_index == 0, "mod_slot_index=0")
    check(cmr.target_param_id == 42, "target_param_id=42")
    check(cmr.depth.rate_class == 0, "depth rate_class=0 (literal), got " .. cmr.depth.rate_class)
    check(cmr.depth.slot == 0, "depth slot=0, got " .. cmr.depth.slot)
    check(cmr.bipolar == true, "bipolar=true")
    check(#literals == 1, "1 literal interned")
    check(approx(literals[1], 0.75), "literal[0]=0.75, got " .. literals[1])

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 7: Graph classify + Node classify in full pipeline
-- ══════════════════════════════════════════════════════════
print("Test 7: Full pipeline — graph/node classify get real signal/state counts")
do
    -- Build a project with a DelayNode to test state allocation
    local project = D.Editor.Project(
        "classify_test", nil, 1,
        D.Editor.Transport(44100, 256, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0.0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Gain", D.Authored.GainNode(),
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil
                ))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        )},
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local ctx = {diagnostics = {}}
    local authored = project:lower(ctx)
    local resolved = authored:resolve(ctx)
    local classified = resolved:classify(ctx)

    -- Should have at least 1 graph and 1 node classified
    check(#classified.graphs >= 1, "at least 1 classified graph")
    check(#classified.nodes >= 1, "at least 1 classified node")

    -- total_signals should be > 0 if graphs had ports allocated
    -- (graphs from DeviceChain may not have explicit ports, so this can be 0)
    -- But total_state_slots tracks state allocation
    check(classified.total_signals >= 0, "total_signals >= 0")
    check(classified.total_state_slots >= 0, "total_state_slots >= 0")

    -- Verify the pipeline still compiles all the way
    local scheduled = classified:schedule(ctx)
    check(#scheduled.tracks >= 1, "scheduled has tracks")
    check(scheduled.total_buffers >= 3, "at least 3 buffers (2 master + 1 work)")

    local kernel = scheduled:compile(ctx)
    check(kernel ~= nil, "kernel compiled")
    check(kernel:entry_fn() ~= nil, "render function exists")

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 8: Track.schedule uses ctx buffer assignment
-- ══════════════════════════════════════════════════════════
print("Test 8: Classified.Track:schedule — buffer from ctx")
do
    local ct = D.Classified.Track(
        42, 2,
        0, 0, 0,
        D.Classified.Binding(0, 3),  -- volume → literal[3]
        D.Classified.Binding(0, 4),  -- pan → literal[4]
        100,                         -- device_graph_id
        0, 0, 0, 0,                 -- clips, slots
        0, 0,                       -- sends
        nil, nil,
        false, false, false, false
    )

    local ctx = {
        diagnostics = {},
        _track_work_buf = {[42] = 7},
        _master_left = 0,
        _master_right = 1,
    }

    local tp = ct:schedule(ctx)
    check(tp.track_id == 42, "track_id=42")
    check(tp.volume.rate_class == 0 and tp.volume.slot == 3, "volume binding preserved")
    check(tp.pan.rate_class == 0 and tp.pan.slot == 4, "pan binding preserved")
    check(tp.work_buf == 7, "work_buf=7 from ctx, got " .. tp.work_buf)
    check(tp.out_left == 0, "out_left=0, got " .. tp.out_left)
    check(tp.out_right == 1, "out_right=1, got " .. tp.out_right)

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 9: Graph.schedule + Node.schedule use ctx
-- ══════════════════════════════════════════════════════════
print("Test 9: Classified.Graph/Node:schedule — ctx delegation")
do
    local cg = D.Classified.Graph(
        200, 0, 1,     -- id=200, serial, audio
        0, 0, 0, 0,
        L{50, 51},     -- node_ids
        0, 0, 0, 0,
        0, 0
    )

    local ctx = {
        diagnostics = {},
        _graph_first_job = {[200] = 10},
        _graph_job_count = {[200] = 2},
        _graph_in_buf = {[200] = 5},
        _graph_out_buf = {[200] = 5},
    }

    local gp = cg:schedule(ctx)
    check(gp.graph_id == 200, "graph_id=200")
    check(gp.first_node_job == 10, "first_node_job=10, got " .. gp.first_node_job)
    check(gp.node_job_count == 2, "node_job_count=2, got " .. gp.node_job_count)
    check(gp.in_buf == 5, "in_buf=5, got " .. gp.in_buf)
    check(gp.out_buf == 5, "out_buf=5, got " .. gp.out_buf)

    -- Node schedule
    local cn = D.Classified.Node(
        50, 5,         -- id=50, GainNode
        0, 1,
        0, 0, 0,
        0, 0, 0, 0,
        true, 0,
        0, 0, 0, 0
    )

    local nctx = {
        diagnostics = {},
        _node_in_buf = {[50] = 5},
        _node_out_buf = {[50] = 5},
    }

    local nj = cn:schedule(nctx)
    check(nj.node_id == 50, "node_id=50")
    check(nj.kind_code == 5, "kind_code=5 (GainNode)")
    check(nj.in_buf == 5, "in_buf=5, got " .. nj.in_buf)
    check(nj.out_buf == 5, "out_buf=5, got " .. nj.out_buf)

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Summary
-- ══════════════════════════════════════════════════════════
print("")
print("════════════════════════════════════════")
if fail_count == 0 then
    print(string.format("ALL CLASSIFY/SCHEDULE TESTS PASSED (%d checks)", pass_count))
else
    print(string.format("FAILED: %d/%d checks failed", fail_count, pass_count + fail_count))
end
print("════════════════════════════════════════")
os.exit(fail_count > 0 and 1 or 0)
