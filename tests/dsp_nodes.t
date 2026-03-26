-- tests/dsp_nodes.t
-- Tests multiple node kinds through the full 7-phase pipeline.
-- Each test builds a project with a specific device, compiles it,
-- runs the render, and checks the output against expected values.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local KS = require("tests/kernel_support")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

local FRAMES = 64
local pass_count = 0
local fail_count = 0

local function check(cond, msg)
    if cond then pass_count = pass_count + 1
    else fail_count = fail_count + 1; print("    FAIL: " .. msg) end
end

local function approx(a, b, tol)
    return math.abs(a - b) < (tol or 0.01)
end

-- Build a single-track project with one device, compile, render, return output[0]
local function run_device(name, kind, params, volume, include_source)
    volume = volume or 1.0
    if include_source == nil then include_source = true end
    local editor_params = L()
    for i = 1, #params do
        local p = params[i]
        editor_params:insert(D.Editor.ParamValue(
            p[1], p[2], p[3], p[4], p[5],
            D.Editor.StaticValue(p[3]),  -- default = value
            D.Editor.Replace, D.Editor.NoSmoothing
        ))
    end

    local devices = L()
    if include_source then
        devices:insert(D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
            9, "Src", D.Authored.SquareOsc,
            L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
            L(), nil, nil, nil, true, nil
        )))
    end
    devices:insert(D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
        10, name, kind, editor_params, L(), nil, nil, nil, true, nil
    )))

    local project = D.Editor.Project(
        name, nil, 1,
        D.Editor.Transport(44100, FRAMES, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(volume), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", -1, -1, 1, D.Editor.StaticValue(-1), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(devices),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        )},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local authored = project:lower()
    local resolved = authored:resolve(960)
    local classified = resolved:classify()
    local scheduled = classified:schedule()
    local kernel = scheduled:compile()
    local render = kernel:entry_fn()

    if not render then
        return nil, nil
    end

    local state_raw = KS.alloc_state(kernel)
    local out_l = terralib.new(float[FRAMES])
    local out_r = terralib.new(float[FRAMES])
    render(out_l, out_r, FRAMES, state_raw)
    return out_l[0], out_r[0]
end

-- ══════════════════════════════════════════════════════════
print("═══════════════════════════════════════════")
print("  DSP Node Tests — Full Pipeline")
print("═══════════════════════════════════════════\n")

-- ── GainNode ──
print("GainNode: DC 1.0 × gain=0.5 × vol=1.0")
do
    local vl, vr = run_device("Gain", D.Authored.GainNode,
        {{0, "gain", 0.5, 0, 4}}, 1.0)
    check(vl and approx(vl, 0.5), string.format("L=%.4f expected 0.5", vl or -1))
    check(vr and approx(vr, 0.0), string.format("R=%.4f expected 0.0 (hard-left pan)", vr or -1))
    print(string.format("  → L=%.6f R=%.6f ✓\n", vl or 0, vr or 0))
end

-- ── GainNode with volume ──
print("GainNode: DC 1.0 × gain=0.3 × vol=0.5")
do
    local vl, vr = run_device("Gain2", D.Authored.GainNode,
        {{0, "gain", 0.3, 0, 4}}, 0.5)
    local expected = 0.3 * 0.5
    check(vl and approx(vl, expected), string.format("L=%.4f expected %.4f", vl or -1, expected))
    print(string.format("  → L=%.6f R=%.6f (expected %.4f) ✓\n", vl or 0, vr or 0, expected))
end

-- ── CompressorNode: below threshold → passthrough ──
print("CompressorNode: DC 1.0, threshold=-6dB (0.5), ratio=4")
do
    -- DC 1.0 is above threshold 0.5: compressed = 0.5 + (1.0-0.5)/4 = 0.625
    local vl, vr = run_device("Comp", D.Authored.CompressorNode,
        {{0, "threshold", -6, -60, 0}, {1, "ratio", 4, 1, 20}}, 1.0)
    local thr = math.pow(10, -6/20)  -- ≈ 0.501
    local expected = thr + (1.0 - thr) / 4.0  -- ≈ 0.626
    check(vl and approx(vl, expected, 0.02), string.format("L=%.4f expected ≈%.4f", vl or -1, expected))
    print(string.format("  → L=%.6f (expected ≈%.4f, thr=%.4f) ✓\n", vl or 0, expected, thr))
end

-- ── SaturatorNode: tanh saturation ──
print("SaturatorNode: DC 1.0, drive=2.0")
do
    local expected = math.tanh(1.0 * 2.0)  -- tanh(2) ≈ 0.964
    local vl, vr = run_device("Sat", D.Authored.SaturatorNode(D.Authored.Tanh),
        {{0, "drive", 2.0, 0.1, 10}}, 1.0)
    check(vl and approx(vl, expected, 0.01), string.format("L=%.4f expected ≈%.4f", vl or -1, expected))
    print(string.format("  → L=%.6f (expected tanh(2)=%.4f) ✓\n", vl or 0, expected))
end

-- ── Clipper: hard clip ──
print("Clipper: DC 1.0 (already in range)")
do
    local vl, vr = run_device("Clip", D.Authored.Clipper(D.Authored.HardClipM),
        {}, 1.0)
    check(vl and approx(vl, 1.0), string.format("L=%.4f expected 1.0", vl or -1))
    print(string.format("  → L=%.6f (clipped to [-1,1]) ✓\n", vl or 0))
end

-- ── EQNode: gain boost ──
print("EQNode: DC 1.0, gain=+6dB ≈ 2.0×")
do
    local glin = math.pow(10, 6/20)  -- ≈ 1.995
    local vl, vr = run_device("EQ", D.Authored.EQNode(L{D.Authored.EQBand(D.Authored.Peak)}),
        {{0, "freq", 1000, 20, 20000}, {1, "gain", 6, -24, 24}, {2, "q", 1, 0.1, 10}}, 1.0)
    check(vl and approx(vl, glin, 0.05), string.format("L=%.4f expected ≈%.4f", vl or -1, glin))
    print(string.format("  → L=%.6f (expected ≈%.4f, +6dB) ✓\n", vl or 0, glin))
end

-- ── SineOsc: generates audio ──
print("SineOsc: freq=440 → first sample = sin(0) = 0.0")
do
    local vl, vr = run_device("Sine", D.Authored.SineOsc,
        {{0, "freq", 440, 1, 22050}}, 1.0, false)
    -- First sample: sin(0) = 0.0 (phase starts at 0)
    check(vl ~= nil, "Should produce output")
    check(vl and approx(vl, 0.0, 0.01), string.format("L=%.4f expected ≈0.0 (sin(0))", vl or -1))
    print(string.format("  → L=%.6f (sin(0)=0) ✓\n", vl or 0))
end

-- ── Multi-track mixing ──
print("Multi-track: Track1(gain=0.4, vol=1.0) + Track2(gain=0.2, vol=0.5)")
do
    local project = D.Editor.Project(
        "multi", nil, 1,
        D.Editor.Transport(44100, FRAMES, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(1.0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", -1, -1, 1, D.Editor.StaticValue(-1), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        9, "Src1", D.Authored.SquareOsc,
                        L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                        L(), nil, nil, nil, true, nil
                    )),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        10, "G1", D.Authored.GainNode,
                        L{D.Editor.ParamValue(0, "gain", 0.4, 0, 4, D.Editor.StaticValue(0.4), D.Editor.Replace, D.Editor.NoSmoothing)},
                        L(), nil, nil, nil, true, nil
                    ))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil
            ),
            D.Editor.Track(2, "T2", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", -1, -1, 1, D.Editor.StaticValue(-1), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        19, "Src2", D.Authored.SquareOsc,
                        L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                        L(), nil, nil, nil, true, nil
                    )),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        20, "G2", D.Authored.GainNode,
                        L{D.Editor.ParamValue(0, "gain", 0.2, 0, 4, D.Editor.StaticValue(0.2), D.Editor.Replace, D.Editor.NoSmoothing)},
                        L(), nil, nil, nil, true, nil
                    ))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil
            ),
        },
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local kernel = project:lower():resolve(960):classify():schedule():compile()
    local render = kernel:entry_fn()
    local state_raw = KS.alloc_state(kernel)
    local out_l = terralib.new(float[FRAMES])
    local out_r = terralib.new(float[FRAMES])
    render(out_l, out_r, FRAMES, state_raw)

    -- Expected: T1 = 1.0*0.4*1.0 = 0.4, T2 = 1.0*0.2*0.5 = 0.1, total = 0.5
    local expected = 0.4 * 1.0 + 0.2 * 0.5
    check(approx(out_l[0], expected, 0.01),
        string.format("L=%.4f expected %.4f", out_l[0], expected))
    print(string.format("  → L=%.6f (T1: 0.4×1.0 + T2: 0.2×0.5 = %.4f) ✓\n", out_l[0], expected))
end

-- ── Device chain: two devices in serial ──
print("Serial chain: DC 1.0 → Gain(0.8) → Gain(0.5) → vol=1.0")
do
    local project = D.Editor.Project(
        "serial", nil, 1,
        D.Editor.Transport(44100, FRAMES, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(1.0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", -1, -1, 1, D.Editor.StaticValue(-1), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    9, "Src", D.Authored.SquareOsc,
                    L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil
                )),
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "G1", D.Authored.GainNode,
                    L{D.Editor.ParamValue(0, "g", 0.8, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil
                )),
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    11, "G2", D.Authored.GainNode,
                    L{D.Editor.ParamValue(0, "g", 0.5, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil
                )),
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        )},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local kernel = project:lower():resolve(960):classify():schedule():compile()
    local render = kernel:entry_fn()
    local state_raw = KS.alloc_state(kernel)
    local out_l = terralib.new(float[FRAMES])
    local out_r = terralib.new(float[FRAMES])
    render(out_l, out_r, FRAMES, state_raw)

    -- Expected: 1.0 * 0.8 * 0.5 * 1.0 = 0.4
    local expected = 0.8 * 0.5
    check(approx(out_l[0], expected, 0.01),
        string.format("L=%.4f expected %.4f", out_l[0], expected))
    print(string.format("  → L=%.6f (0.8 × 0.5 = %.4f) ✓\n", out_l[0], expected))
end

-- ══════════════════════════════════════════════════════════
print("")
if fail_count == 0 then
    print("════════════════════════════════════════════")
    print("  ALL DSP TESTS PASSED (" .. pass_count .. " checks)")
    print("  Nodes: Gain, Comp, Saturator, Clipper, EQ, SineOsc")
    print("  Features: multi-track mixing, serial device chains")
    print("════════════════════════════════════════════")
else
    print("════════════════════════════════════════════")
    print("  FAILURES: " .. fail_count .. " / " .. (pass_count + fail_count))
    print("════════════════════════════════════════════")
    os.exit(1)
end
