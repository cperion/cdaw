-- tests/first_sound.t
-- MILESTONE E: First sound test.
-- Verifies that the compiled kernel produces actual non-zero audio output.
-- Signal path: SquareOsc(very low freq) → GainNode(gain=0.75)
-- → track volume(0.8) → center-pan OutputJob(equal-power) → master L/R

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L
local TICKS_PER_BEAT = 960
local C = terralib.includec("stdio.h")

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
    tol = tol or 0.001
    return math.abs(a - b) < tol
end

-- ══════════════════════════════════════════════════════════
-- Build a minimal project: 1 track, SquareOsc(very low freq) → GainNode(gain=0.75),
-- track volume=0.8.
-- With a low enough frequency, the whole test block stays at +1.0 before gain.
-- Expected output per channel sample at center pan:
-- 1.0 * 0.75 * 0.8 * cos(pi/4) ≈ 0.424264
-- ══════════════════════════════════════════════════════════

print("═══════════════════════════════════════════")
print("  FIRST SOUND TEST — Milestone E")
print("═══════════════════════════════════════════")
print("")

local FRAMES = 64
local GAIN = 0.75
local VOLUME = 0.8
local EXPECTED = 1.0 * GAIN * VOLUME * math.cos(math.pi / 4)

print("Signal path: SquareOsc(100 Hz) → GainNode(gain=" .. GAIN .. ") → volume(" .. VOLUME .. ") → center-pan output → master")
print("Expected output per channel sample: " .. EXPECTED)
print("")

local project = D.Editor.Project(
    "first_sound", nil, 1,
    D.Editor.Transport(44100, FRAMES, 120, 0, 4, 4, D.Editor.QNone, false, nil),
    L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
        D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(VOLUME), D.Editor.Replace, D.Editor.NoSmoothing),
        D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
        D.Editor.DeviceChain(L{
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                9, "Square", D.Authored.SquareOsc(),
                L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                L(), nil, nil, nil, true, nil
            )),
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                10, "Gain", D.Authored.GainNode(),
                L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(GAIN), D.Editor.Replace, D.Editor.NoSmoothing)},
                L(), nil, nil, nil, true, nil
            ))
        }),
        L(), L(), L(), nil, nil, false, false, false, false, false, nil
    )},
    L(),
    D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
    D.Authored.AssetBank(L(), L(), L(), L(), L())
)

-- ── Run the full 7-phase pipeline ──
print("Phase 0: Editor")
local ctx = {diagnostics = {}}

print("Phase 1: Editor → Authored")
local authored = project:lower()
check(#authored.tracks == 1, "Should have 1 track")

print("Phase 2: Authored → Resolved")
local resolved = authored:resolve(TICKS_PER_BEAT)
local rt = resolved.track_slices[1]
check(rt ~= nil, "Should have a resolved track slice")
check(rt and #rt.device_graph.nodes >= 1, "Should have ≥1 resolved node")
check(rt and #rt.mixer_params >= 2, "Should have track mixer params")

print("Phase 3: Resolved → Classified")
local classified = resolved:classify()
local ct = classified.track_slices[1]
local classified_literal_count = (ct and #ct.mixer_literals or 0) + (ct and ct.device_graph and #ct.device_graph.literals or 0)
check(classified_literal_count >= 1, "Should have ≥1 classified literal")

print("Phase 4: Classified → Scheduled")
local scheduled = classified:schedule()
local tp = scheduled.track_programs[1]
check(tp ~= nil, "Should have a scheduled track program")
check(tp and tp.device_graph and #tp.device_graph.node_programs >= 1, "Should have ≥1 scheduled node program")
check(tp and tp.total_buffers >= 3, "Should have ≥3 buffers (master L + R + work)")

print("  Literals:")
if tp then
    for i = 1, #tp.mixer_literals do
        print("    mixer[" .. (i-1) .. "] = " .. tp.mixer_literals[i].value)
    end
    for i = 1, #tp.device_graph.literals do
        print("    graph[" .. (i-1) .. "] = " .. tp.device_graph.literals[i].value)
    end
end

print("Phase 5: Scheduled → Kernel")
local kernel = scheduled:compile()
check(kernel ~= nil, "Kernel should not be nil")
local render = kernel:entry_fn()
check(render ~= nil, "Should have a compiled render function")

print("Phase 6: Kernel entry")
check(render ~= nil, "render should not be nil")

print("")
print("── Calling compiled render function ──")

-- Allocate output buffers
local output_left = terralib.new(float[FRAMES])
local output_right = terralib.new(float[FRAMES])

-- Zero them
for i = 0, FRAMES - 1 do
    output_left[i] = 0.0
    output_right[i] = 0.0
end

-- Call the compiled render!
render(output_left, output_right, FRAMES)

-- ── Check output ──
print("")
print("── Output verification ──")

-- Check first few samples
local all_zero = true
local all_correct = true
for i = 0, FRAMES - 1 do
    local vl = output_left[i]
    local vr = output_right[i]
    if vl ~= 0.0 or vr ~= 0.0 then all_zero = false end
    if not approx(vl, EXPECTED) or not approx(vr, EXPECTED) then
        all_correct = false
        if i < 4 then
            print(string.format("  sample[%d]: L=%.6f R=%.6f (expected %.6f)", i, vl, vr, EXPECTED))
        end
    end
end

-- Print first few samples
for i = 0, math.min(7, FRAMES - 1) do
    print(string.format("  output[%d]: L=%.6f  R=%.6f", i, output_left[i], output_right[i]))
end

print("")
check(not all_zero, "Output should NOT be all zeros — we want SOUND!")
check(all_correct, "All samples should be ≈" .. EXPECTED .. " (1.0 × " .. GAIN .. " × " .. VOLUME .. " × cos(pi/4))")

-- Count diagnostics
check(#ctx.diagnostics == 0,
    "Should have 0 diagnostics, got " .. #ctx.diagnostics)
if #ctx.diagnostics > 0 then
    for i = 1, #ctx.diagnostics do
        local d = ctx.diagnostics[i]
        print("  diag: [" .. (d.severity or "?") .. "] " .. (d.code or "?") .. ": " .. (d.message or "?"))
    end
end

-- ── Summary ──
print("")
if fail_count == 0 then
    print("════════════════════════════════════════════")
    print("  🔊 FIRST SOUND: PASS (" .. pass_count .. " checks)")
    print("  Signal: SquareOsc(100) → Gain(" .. GAIN .. ") → Vol(" .. VOLUME .. ") → center-pan → " .. EXPECTED)
    print("  Compiled Terra function produced real audio output!")
    print("════════════════════════════════════════════")
else
    print("════════════════════════════════════════════")
    print("  FAILURES: " .. fail_count .. " / " .. (pass_count + fail_count))
    print("════════════════════════════════════════════")
    os.exit(1)
end
