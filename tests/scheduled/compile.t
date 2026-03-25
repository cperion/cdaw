-- tests/scheduled/compile.t
-- Tests for Scheduled -> Kernel public compile surfaces.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

print("1. scheduled.graph_program.compile")
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
    check(unit ~= nil, "kernel unit returned")
    check(unit.fn ~= nil, "unit fn returned")

    local BS = gp.transport.buffer_size
    local total = math.max(gp.total_buffers * BS, 1)
    local bufs = terralib.new(float[total])
    for i = 0, total - 1 do bufs[i] = 0.0 end
    unit.fn(bufs, BS)
    local out0 = bufs[gp.graph.out_buf * BS]
    check(math.abs(out0) > 0.01, "graph output is non-zero")
    print("  PASS")
end

print("2. scheduled.track_program.compile")
do
    local project = D.Editor.Project(
        "track_compile", nil, 1,
        D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(10, "Square", D.Authored.SquareOsc(),
                    L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil)),
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(11, "Gain", D.Authored.GainNode(),
                    L{D.Editor.ParamValue(0, "gain", 0.75, 0, 4, D.Editor.StaticValue(0.75), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local tp = project:lower():resolve():classify():schedule().track_programs[1]
    local unit = tp:compile()
    local outL = terralib.new(float[64])
    local outR = terralib.new(float[64])
    for i = 0, 63 do outL[i] = 0.0; outR[i] = 0.0 end
    unit.fn(outL, outR, 64)
    check(math.abs(outL[0]) > 0.01, "track unit produces sound")
    check(approx(outL[0], outR[0], 0.001), "center pan produces equal L/R")
    print("  PASS")
end

print("3. scheduled.project.compile")
do
    local project = D.Editor.Project(
        "project_compile", nil, 1,
        D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(10, "Square", D.Authored.SquareOsc(), L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(11, "Gain", D.Authored.GainNode(), L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.4), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil),
            D.Editor.Track(2, "T2", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(20, "Square", D.Authored.SquareOsc(), L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(21, "Gain", D.Authored.GainNode(), L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.2), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil)
        },
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local kernel = project:lower():resolve():classify():schedule():compile()
    local entry = kernel:entry_fn()
    local outL = terralib.new(float[64])
    local outR = terralib.new(float[64])
    entry(outL, outR, 64)
    local expected = ((0.4 * 0.5) + (0.2 * 0.5)) * math.cos(math.pi / 4)
    check(approx(outL[0], expected, 0.01), "two tracks mixed to expected equal-power output")
    check(approx(outL[0], outR[0], 0.001), "mix is symmetric L/R")
    print("  PASS")
end

print("")
print(string.format("Scheduled compile: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
