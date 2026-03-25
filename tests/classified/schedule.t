-- tests/classified/schedule.t
-- Per-method tests for all 7 Classified → Scheduled schedule methods.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

-- ══════════════════════════════════════════
-- 1. classified.transport.schedule
-- ══════════════════════════════════════════
print("1. classified.transport.schedule")
do
    local t = D.Classified.Transport(48000, 1024, 140, 0.1, 3, 8, 4, true, 1920, 7680)
    local ctx = {diagnostics = {}}
    local r = t:schedule(ctx)
    check(r.sample_rate == 48000, "sample_rate")
    check(r.buffer_size == 1024, "buffer_size")
    check(r.bpm == 140, "bpm")
    check(r.looping == true, "looping")
    check(r.loop_start_tick == 1920, "loop_start")
    check(r.loop_end_tick == 7680, "loop_end")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 2. classified.tempo_map.schedule
-- ══════════════════════════════════════════
print("2. classified.tempo_map.schedule")
do
    local tm = D.Classified.TempoMap(L{
        D.Classified.TempoSeg(0, 3840, 120, 0, 22.96875),
        D.Classified.TempoSeg(3840, 1000000000, 60, 88200, 45.9375),
    })
    local ctx = {diagnostics = {}}
    local r = tm:schedule(ctx)
    check(#r.segs == 2, "2 segments")
    check(r.segs[1].start_tick == 0, "seg1 start")
    check(r.segs[2].bpm == 60, "seg2 bpm")
    check(approx(r.segs[2].base_sample, 88200), "seg2 base_sample")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 3. classified.binding.schedule
-- ══════════════════════════════════════════
print("3. classified.binding.schedule")
do
    local b = D.Classified.Binding(0, 7)  -- literal, slot 7
    local ctx = {diagnostics = {}}
    local r = b:schedule(ctx)
    check(r.rate_class == 0, "rate_class=0")
    check(r.slot == 7, "slot=7")

    local b2 = D.Classified.Binding(2, 3)  -- block, slot 3
    local r2 = b2:schedule(ctx)
    check(r2.rate_class == 2, "rate_class=2")
    check(r2.slot == 3, "slot=3")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 4. classified.track.schedule
-- ══════════════════════════════════════════
print("4. classified.track.schedule")
do
    local ct = D.Classified.Track(42, 2, 0, 0, 0,
        D.Classified.Binding(0, 3), D.Classified.Binding(0, 4),
        100, 0, 0, 0, 0, L(), nil, nil, false, false, false, false)
    local ctx = {diagnostics = {},
        _track_work_buf = {[42] = 5},
        _master_left = 0, _master_right = 1}
    local r = ct:schedule(ctx)
    check(r.track_id == 42, "track_id")
    check(r.volume.slot == 3, "vol slot")
    check(r.pan.slot == 4, "pan slot")
    check(r.work_buf == 5, "work_buf=5")
    check(r.out_left == 0, "out_left")
    check(r.out_right == 1, "out_right")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 5. classified.graph.schedule
-- ══════════════════════════════════════════
print("5. classified.graph.schedule")
do
    local cg = D.Classified.Graph(200, 0, 1, 0, 0, 0, 0,
        L{50, 51}, 0, 0, 0, 0, 0, 0)
    local ctx = {diagnostics = {},
        _graph_first_job = {[200] = 10},
        _graph_job_count = {[200] = 2},
        _graph_in_buf = {[200] = 3},
        _graph_out_buf = {[200] = 3}}
    local r = cg:schedule(ctx)
    check(r.graph_id == 200, "graph_id")
    check(r.first_node_job == 10, "first_node_job")
    check(r.node_job_count == 2, "node_job_count")
    check(r.in_buf == 3, "in_buf")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 6. classified.node.schedule
-- ══════════════════════════════════════════
print("6. classified.node.schedule")
do
    local cn = D.Classified.Node(50, 5, 0, 1, 0, 0, 0, 0, 0, 0, 0, true, 0, 0, 0, 0, 0)
    local ctx = {diagnostics = {},
        _node_in_buf = {[50] = 3},
        _node_out_buf = {[50] = 3}}
    local r = cn:schedule(ctx)
    check(r.node_id == 50, "node_id")
    check(r.kind_code == 5, "kind_code=GainNode")
    check(r.in_buf == 3, "in_buf")
    check(r.out_buf == 3, "out_buf")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 7. classified.project.schedule — integration
-- ══════════════════════════════════════════
print("7. classified.project.schedule — integration")
do
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
    local s = c:schedule(ctx)
    check(#s.tracks >= 1, "tracks scheduled")
    check(#s.node_jobs >= 1, "node jobs created")
    check(#s.buffers >= 3, "at least 3 buffers")
    check(s.total_buffers >= 3, "total_buffers >= 3")
    check(s.master_left == 0, "master_left=0")
    check(s.master_right == 1, "master_right=1")
    check(s._literal_values ~= nil, "literals carried")
    print("  PASS")
end

-- Summary
print("")
print(string.format("Classified schedule: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
