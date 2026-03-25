-- tests/classified/schedule.t
-- Per-method tests for Classified -> Scheduled schedule methods.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

print("1. classified.transport.schedule")
do
    local t = D.Classified.Transport(48000, 1024, 140, 0.1, 3, 8, 4, true, 1920, 7680)
    local r = t:schedule()
    check(r.sample_rate == 48000, "sample_rate")
    check(r.buffer_size == 1024, "buffer_size")
    check(r.bpm == 140, "bpm")
    check(r.looping == true, "looping")
    print("  PASS")
end

print("2. classified.tempo_map.schedule")
do
    local tm = D.Classified.TempoMap(L{
        D.Classified.TempoSeg(0, 3840, 120, 0, 22.96875),
        D.Classified.TempoSeg(3840, 1000000000, 60, 88200, 45.9375),
    })
    local r = tm:schedule()
    check(#r.segs == 2, "2 segments")
    check(r.segs[1].start_tick == 0, "seg1 start")
    check(r.segs[2].bpm == 60, "seg2 bpm")
    check(approx(r.segs[2].base_sample, 88200), "seg2 base_sample")
    print("  PASS")
end

print("3. classified.binding.schedule")
do
    local b = D.Classified.Binding(0, 7)
    local r = b:schedule()
    check(r.rate_class == 0, "literal rc")
    check(r.slot == 7, "slot=7")

    local b2 = D.Classified.Binding(2, 3)
    local r2 = b2:schedule()
    check(r2.rate_class == 2, "block rc")
    check(r2.slot == 3, "slot=3")
    print("  PASS")
end

print("4. classified.graph_slice.schedule")
do
    local gs = D.Classified.GraphSlice(
        L{D.Classified.Graph(200, 0, 1, 0, 0, 0, 0, L{50, 51}, 0, 0, 0, 0, 0, 0)},
        L(),
        L{
            D.Classified.Node(50, 28, 0, 1, 0, 0, 0, 0, 0, 0, 0, true, 0, 0, 0, 0, 0),
            D.Classified.Node(51, 5, 1, 1, 0, 0, 0, 0, 0, 0, 0, true, 0, 0, 0, 0, 0),
        },
        L(), L(), L(),
        L{
            D.Classified.Param(0, 50, 100, 1, 20000, D.Classified.Binding(0, 0), 0, 0, 0, 0, 0, 0),
            D.Classified.Param(1, 51, 0.5, 0, 4, D.Classified.Binding(0, 1), 0, 0, 0, 0, 0, 0),
        },
        L(), L(),
        L{D.Classified.Literal(100), D.Classified.Literal(0.5)},
        L(), L(), L(), L(), L(), L(),
        1, 0
    )
    local r = gs:schedule(F.classified_transport(), F.classified_tempo_map())
    check(r.graph.graph_id == 200, "graph_id")
    check(#r.node_jobs == 2, "2 node jobs")
    check(r.graph.node_job_count == 2, "job count")
    check(r.graph.in_buf == 0, "in_buf=0")
    check(r.graph.out_buf >= 1, "out_buf allocated")
    print("  PASS")
end

print("5. classified.track_slice.schedule")
do
    local ts = D.Classified.TrackSlice(
        D.Classified.Track(42, 2, 0, 0, 0,
            D.Classified.Binding(0, 0), D.Classified.Binding(0, 1),
            100, 0, 0, 0, 0, 0, 0, nil, nil, false, false, false, false),
        L{
            D.Classified.Param(0, 0, 1, 0, 4, D.Classified.Binding(0, 0), 0, 0, 0, 0, 0, 0),
            D.Classified.Param(1, 0, 0, -1, 1, D.Classified.Binding(0, 1), 0, 0, 0, 0, 0, 0),
        },
        L(), L(), L(),
        L{D.Classified.Literal(0.8), D.Classified.Literal(0.0)},
        L(), L(), L(), L(), L(), L(),
        F.classified_graph_slice(100)
    )
    local r = ts:schedule(F.classified_transport(), F.classified_tempo_map())
    check(r.track.track_id == 42, "track_id")
    check(r.track.work_buf == 0, "work_buf=0")
    check(r.track.mix_in_buf == 1, "mix_in_buf=1")
    check(r.master_left == 2, "master_left=2")
    check(r.master_right == 3, "master_right=3")
    check(#r.output_jobs >= 1, "output jobs")
    print("  PASS")
end

print("6. classified.project.schedule")
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
    local s = project:lower():resolve():classify():schedule()
    check(#s.track_programs >= 1, "track programs scheduled")
    check(#s.track_programs[1].device_graph.node_jobs >= 1, "node jobs created")
    check(#s.track_programs[1].output_jobs >= 1, "output jobs created")
    check(s.track_programs[1].total_buffers >= 4, "buffers allocated")
    print("  PASS")
end

print("")
print(string.format("Classified schedule: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
