-- tests/classify_schedule.t
-- Integration checks across Authored -> Resolved -> Classified -> Scheduled.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local KS = require("tests/kernel_support")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local TICKS_PER_BEAT = 960

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

print("Test 1: TempoMap cumulative base_sample")
do
    local tm = D.Authored.TempoMap(
        L{D.Authored.TempoPoint(0, 120), D.Authored.TempoPoint(4, 60)}, L())
    local r = tm:resolve(960, 48000)
    local seg1_spt = (60.0/120) * 48000 / 960
    local seg2_base = 4 * 960 * seg1_spt
    local seg2_spt = (60.0/60) * 48000 / 960
    check(#r.segments == 2, "2 segments")
    check(approx(r.segments[1].samples_per_tick, seg1_spt), "seg1 spt")
    check(approx(r.segments[2].base_sample, seg2_base), "seg2 base_sample")
    check(approx(r.segments[2].samples_per_tick, seg2_spt), "seg2 spt")
    print("  PASS")
end

print("Test 2: GraphSlice classify allocates signal/state/literal data")
do
    local gs = D.Resolved.GraphSlice(
        L{D.Resolved.Graph(1, 0, 1, 0, 1, 1, 1, L{10}, L(), 0, 0, 0, 0, 0, 0)},
        L(),
        L{D.Resolved.Node(10, 10, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, true, nil, 0, 0, 0, 0)},
        L(),
        L(),
        L{D.Resolved.Param(0, 10, "delay", 0.25, 0, 1, D.Resolved.ParamSourceRef(0, 0.25, nil), 0, 0, 0)},
        L{D.Resolved.ModSlot(0, 10, 20, 156, 0, 0, 0, 0, 0, 0, false, 0, 0)},
        L{D.Resolved.ModRoute(0, 0, 0.5, false, nil, nil)},
        L())
    local c = gs:classify()
    check(c.total_signals >= 2, "signals allocated")
    check(c.total_state_slots >= 2, "state slots allocated")
    check(#c.literals >= 1, "literals interned")
    check(#c.mod_slots == 1, "mod slot classified")
    print("  PASS")
end

print("Test 3: TrackSlice classify + schedule builds reusable program")
do
    local ts = D.Resolved.TrackSlice(
        D.Resolved.Track(1, "T", 2, 0, 0, 0, 0, 1, 10, 0, 0, 0, 0, 0, 0, nil, nil, false, false, false, false, false),
        L{
            D.Resolved.Param(0, 0, "vol", 1, 0, 4, D.Resolved.ParamSourceRef(0, 0.8, nil), 0, 0, 0),
            D.Resolved.Param(1, 0, "pan", 0, -1, 1, D.Resolved.ParamSourceRef(0, 0.0, nil), 0, 0, 0)
        },
        L(), L(), L(), L(),
        D.Resolved.GraphSlice(
            L{D.Resolved.Graph(10, 0, 1, 0, 0, 0, 0, L{20}, L(), 0, 0, 0, 0, 0, 0)},
            L(),
            L{D.Resolved.Node(20, 30, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, true, nil, 0, 0, 0, 0)},
            L(), L(),
            L{D.Resolved.Param(0, 20, "freq", 100, 1, 20000, D.Resolved.ParamSourceRef(0, 100, nil), 0, 0, 0)},
            L(), L(), L())
    )
    local scheduled = ts:classify():schedule()
    check(scheduled.track.track_id == 1, "track id preserved")
    check(#scheduled.device_graph.node_programs == 1, "device graph program created")
    check(#scheduled.output_programs >= 1, "output programs created")
    check(scheduled.total_buffers >= 4, "buffers allocated")
    print("  PASS")
end

print("Test 4: Automation becomes block ops across classify/schedule")
do
    local project = D.Editor.Project(
        "auto", nil, 1,
        D.Editor.Transport(44100, 128, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4,
                D.Editor.AutomationRef(D.Editor.AutoCurve(L{D.Editor.AutoPoint(0, 0.2), D.Editor.AutoPoint(1, 0.8)}, D.Editor.Linear)),
                D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{D.Editor.NativeDevice(D.Editor.NativeDeviceBody(9, "Square", D.Authored.SquareOsc, L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))}),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()), D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local classified = project:lower():resolve(TICKS_PER_BEAT):classify()
    local scheduled = classified:schedule()
    check(#classified.track_slices[1].mixer_block_ops >= 1, "classified block ops")
    check(#classified.track_slices[1].mixer_block_pts >= 2, "classified block pts")
    check(#scheduled.track_programs[1].mixer_block_ops >= 1, "scheduled block ops")
    check(#scheduled.track_programs[1].mixer_block_pts >= 2, "scheduled block pts")
    print("  PASS")
end

print("Test 5: End-to-end classify/schedule/compile produces sound")
do
    local project = D.Editor.Project(
        "sound", nil, 1,
        D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(9, "Square", D.Authored.SquareOsc, L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(10, "Gain", D.Authored.GainNode, L{D.Editor.ParamValue(0, "gain", 0.5, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()), D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local kernel = project:lower():resolve(TICKS_PER_BEAT):classify():schedule():compile()
    local outL = terralib.new(float[64])
    local outR = terralib.new(float[64])
    local state_raw = KS.alloc_state(kernel)
    kernel:entry_fn()(outL, outR, 64, state_raw)
    check(math.abs(outL[0]) > 0.01, "non-zero output")
    check(approx(outL[0], outR[0], 0.001), "equal L/R")
    print("  PASS")
end

print("")
if fail == 0 then
    print("════════════════════════════════════════")
    print("ALL CLASSIFY/SCHEDULE TESTS PASSED (" .. pass .. " checks)")
    print("════════════════════════════════════════")
else
    print("════════════════════════════════════════")
    print("FAILURES: " .. fail .. "/" .. (pass + fail))
    print("════════════════════════════════════════")
    os.exit(1)
end
