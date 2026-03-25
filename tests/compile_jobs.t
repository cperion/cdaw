-- tests/compile_jobs.t
-- New compile-unit tests on the slice/program surface.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L
local TICKS_PER_BEAT = 960

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

local function graph_output(unit, gp)
    local BS = gp.transport.buffer_size
    local total = math.max(gp.total_buffers * BS, 1)
    local bufs = terralib.new(float[total])
    for i = 0, total - 1 do bufs[i] = 0.0 end
    unit.fn(bufs, BS)
    return bufs[gp.graph.out_buf * BS]
end

print("Test 1: GraphProgram compile — SquareOsc -> Gain")
do
    local gs = D.Classified.GraphSlice(
        L{D.Classified.Graph(1, 0, 1, 0, 0, 0, 0, L{10, 11}, 0, 0, 0, 0, 0, 0)},
        L(),
        L{
            D.Classified.Node(10, 30, 0, 1, 0, 0, 0, 0, 0, 0, 0, true, 0, 0, 0, 0, 0),
            D.Classified.Node(11, 5, 1, 1, 0, 0, 0, 0, 0, 0, 0, true, 0, 0, 0, 0, 0),
        },
        L(), L(), L(),
        L{
            D.Classified.Param(0, 10, 100, 1, 20000, D.Classified.Binding(0, 0), 0, 0, 0, 0, 0, 0),
            D.Classified.Param(1, 11, 0.5, 0, 4, D.Classified.Binding(0, 1), 0, 0, 0, 0, 0, 0),
        },
        L(), L(),
        L{D.Classified.Literal(100), D.Classified.Literal(0.5)},
        L(), L(), L(), L(), L(), L(),
        1, 0)
    local gp = gs:schedule(F.classified_transport(), F.classified_tempo_map())
    local unit = gp:compile()
    local out0 = graph_output(unit, gp)
    check(approx(out0, 0.5, 0.01), "square(+1) * gain(0.5) = 0.5")
    print("  PASS")
end

print("Test 2: TrackProgram compile — volume/pan applied")
do
    local project = D.Editor.Project(
        "track_unit", nil, 1,
        D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(-1), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(10, "Square", D.Authored.SquareOsc(),
                    L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local tp = project:lower():resolve(TICKS_PER_BEAT):classify():schedule().track_programs[1]
    local unit = tp:compile()
    local outL = terralib.new(float[64])
    local outR = terralib.new(float[64])
    for i = 0, 63 do outL[i] = 0.0; outR[i] = 0.0 end
    unit.fn(outL, outR, 64)
    check(outL[0] > 0.49 and outL[0] < 0.51, "hard-left volume 0.5 on +1 square = 0.5 left")
    check(approx(outR[0], 0.0, 0.01), "hard-left right channel ~= 0")
    print("  PASS")
end

print("Test 3: Project compile — multi-track mix")
do
    local project = D.Editor.Project(
        "mix_unit", nil, 1,
        D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{D.Editor.NativeDevice(D.Editor.NativeDeviceBody(10, "Square", D.Authored.SquareOsc(), L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))}),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil),
            D.Editor.Track(2, "T2", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.25), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{D.Editor.NativeDevice(D.Editor.NativeDeviceBody(20, "Square", D.Authored.SquareOsc(), L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))}),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil)
        },
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local kernel = project:lower():resolve(TICKS_PER_BEAT):classify():schedule():compile()
    local outL = terralib.new(float[64])
    local outR = terralib.new(float[64])
    kernel:entry_fn()(outL, outR, 64)
    local expected = (0.5 + 0.25) * math.cos(math.pi / 4)
    check(approx(outL[0], expected, 0.01), "mixed left output")
    check(approx(outR[0], expected, 0.01), "mixed right output")
    print("  PASS")
end

print("Test 4: Automation compiles through TrackProgram")
do
    local project = D.Editor.Project(
        "auto_unit", nil, 1,
        D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4,
                D.Editor.AutomationRef(D.Editor.AutoCurve(L{D.Editor.AutoPoint(0, 0.2), D.Editor.AutoPoint(1, 0.8)}, D.Editor.Linear)),
                D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{D.Editor.NativeDevice(D.Editor.NativeDeviceBody(10, "Square", D.Authored.SquareOsc(), L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))}),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local tp = project:lower():resolve(TICKS_PER_BEAT):classify():schedule().track_programs[1]
    check(#tp.mixer_block_ops >= 1, "mixer block ops present")
    check(#tp.mixer_block_pts >= 2, "mixer block points present")
    check(tp:compile() ~= nil, "track program compiles")
    print("  PASS")
end

print("")
if fail == 0 then
    print("════════════════════════════════════════")
    print("ALL COMPILE-UNIT TESTS PASSED (" .. pass .. " checks)")
    print("════════════════════════════════════════")
else
    print("════════════════════════════════════════")
    print("FAILED: " .. fail .. "/" .. (pass + fail) .. " checks failed")
    print("════════════════════════════════════════")
    os.exit(1)
end
