-- tests/compile_jobs.t
-- Tests for individual Scheduled.*:compile methods.
-- Verifies: node_job, mix_job, send_job, output_job, step, graph_plan,
-- tempo_map, clip_job compile produce correct Terra code.

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

-- Helper: create a compile context with Terra symbols
local function make_compile_ctx(n_bufs, buffer_size, literal_values, param_bindings)
    local BS = buffer_size or 256
    local total = (n_bufs or 4) * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")
    return {
        bufs_sym = bufs_sym,
        frames_sym = frames_sym,
        BS = BS,
        literal_values = literal_values or {},
        param_bindings = param_bindings or {},
        diagnostics = {},
    }
end

-- Helper: build and run a Terra function from a compile context + quote
local function run_render(ctx, setup_quote, job_quote, n_bufs, buffer_size)
    local BS = buffer_size or 256
    local total = (n_bufs or 4) * BS
    local BufArray = float[total]
    local bufs = ctx.bufs_sym
    local frames = ctx.frames_sym

    local render = terra(output: &float, [frames])
        var [bufs]
        for i = 0, total do [bufs][i] = 0.0f end
        [setup_quote]
        [job_quote]
        -- Copy buf[0] to output
        for i = 0, frames do output[i] = [bufs][i] end
    end

    local out = terralib.new(float[BS])
    render(out, BS)
    return out
end

-- ══════════════════════════════════════════════════════════
-- Test 1: NodeJob GainNode compile
-- ══════════════════════════════════════════════════════════
print("Test 1: NodeJob GainNode compile")
do
    local BS = 64
    local ctx = make_compile_ctx(4, BS,
        {[1] = 0.5},       -- literal[0] = 0.5 (gain)
        {[1] = D.Scheduled.Binding(0, 0)}  -- param[0] → literal[0]
    )

    local nj = D.Scheduled.NodeJob(
        1, 5,          -- id=1, kind=GainNode
        0, 0,          -- in_buf=0, out_buf=0 (in-place)
        0, 1,          -- first_param=0, param_count=1
        0, 0,          -- state
        0, 0, 0, 0
    )

    local q = nj:compile(ctx)
    local bufs = ctx.bufs_sym
    local frames = ctx.frames_sym

    -- Fill buf[0] with 1.0, run gain
    local setup = quote
        for i = 0, frames do [bufs][i] = 1.0f end
    end

    local out = run_render(ctx, setup, q, 4, BS)
    check(approx(out[0], 0.5), "GainNode: 1.0 * 0.5 = 0.5, got " .. out[0])
    check(approx(out[32], 0.5), "GainNode mid: 0.5, got " .. out[32])
    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 2: NodeJob SineOsc compile
-- ══════════════════════════════════════════════════════════
print("Test 2: NodeJob SineOsc compile")
do
    local BS = 64
    local ctx = make_compile_ctx(4, BS,
        {[1] = 440.0},
        {[1] = D.Scheduled.Binding(0, 0)}
    )

    local nj = D.Scheduled.NodeJob(
        2, 28,         -- id=2, kind=SineOsc
        0, 0,          -- out_buf=0
        0, 1,
        0, 0,
        0, 0, 0, 0
    )

    local q = nj:compile(ctx)
    local out = run_render(ctx, quote end, q, 4, BS)

    -- SineOsc at 440Hz: sample[0] = sin(0) = 0
    check(approx(out[0], 0.0, 0.01), "SineOsc[0] ≈ 0, got " .. out[0])
    -- Sample should be non-zero somewhere
    local found_nonzero = false
    for i = 1, BS - 1 do
        if math.abs(out[i]) > 0.01 then found_nonzero = true; break end
    end
    check(found_nonzero, "SineOsc produces non-zero samples")
    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 3: MixJob compile — source→target mixing
-- ══════════════════════════════════════════════════════════
print("Test 3: MixJob compile — buffer mixing")
do
    local BS = 32
    local ctx = make_compile_ctx(4, BS,
        {[1] = 0.75},
        {}
    )

    local mj = D.Scheduled.MixJob(
        1,         -- source_buf=1
        0,         -- target_buf=0
        D.Scheduled.Binding(0, 0)  -- gain → literal[0] = 0.75
    )

    local q = mj:compile(ctx)
    local bufs = ctx.bufs_sym
    local frames = ctx.frames_sym

    -- Fill source buf[1] with 0.8, target buf[0] with 0.1
    local setup = quote
        for i = 0, frames do
            [bufs][i] = 0.1f              -- target buf[0]
            [bufs][([int32](BS)) + i] = 0.8f  -- source buf[1]
        end
    end

    local out = run_render(ctx, setup, q, 4, BS)
    -- Expected: 0.1 + 0.8 * 0.75 = 0.1 + 0.6 = 0.7
    check(approx(out[0], 0.7), "MixJob: 0.1 + 0.8*0.75 = 0.7, got " .. out[0])
    check(approx(out[16], 0.7), "MixJob mid: 0.7, got " .. out[16])
    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 4: SendJob compile — send routing
-- ══════════════════════════════════════════════════════════
print("Test 4: SendJob compile — send routing")
do
    local BS = 32
    local ctx = make_compile_ctx(4, BS,
        {[1] = 0.5},
        {}
    )

    -- Enabled send
    local sj = D.Scheduled.SendJob(
        2,         -- source_buf=2
        0,         -- target_buf=0
        D.Scheduled.Binding(0, 0),  -- level → 0.5
        false,     -- pre_fader
        true       -- enabled
    )

    local q = sj:compile(ctx)
    local bufs = ctx.bufs_sym
    local frames = ctx.frames_sym

    local setup = quote
        for i = 0, frames do
            [bufs][i] = 0.0f
            [bufs][([int32](BS*2)) + i] = 1.0f  -- source
        end
    end

    local out = run_render(ctx, setup, q, 4, BS)
    check(approx(out[0], 0.5), "SendJob: 1.0 * 0.5 = 0.5, got " .. out[0])

    -- Disabled send should produce nothing
    local sj2 = D.Scheduled.SendJob(2, 0, D.Scheduled.Binding(0, 0), false, false)
    local q2 = sj2:compile(ctx)
    local out2 = run_render(ctx, setup, q2, 4, BS)
    check(approx(out2[0], 0.0), "Disabled send: 0.0, got " .. out2[0])

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 5: OutputJob compile — gain + pan to stereo
-- ══════════════════════════════════════════════════════════
print("Test 5: OutputJob compile — stereo output with pan")
do
    local BS = 32
    local ctx = make_compile_ctx(4, BS,
        {[1] = 0.8, [2] = 0.0},  -- gain=0.8, pan=0.0 (center)
        {}
    )

    local oj = D.Scheduled.OutputJob(
        2,         -- source_buf=2
        0, 1,      -- out_left=0, out_right=1
        D.Scheduled.Binding(0, 0),  -- gain → 0.8
        D.Scheduled.Binding(0, 1)   -- pan → 0.0 (center)
    )

    local q = oj:compile(ctx)
    local bufs = ctx.bufs_sym
    local frames = ctx.frames_sym

    local setup = quote
        for i = 0, frames do
            [bufs][([int32](BS*2)) + i] = 1.0f  -- source
        end
    end

    -- Build a function that reads both L and R outputs
    local render = terra(out_l: &float, out_r: &float, [ctx.frames_sym])
        var [ctx.bufs_sym]
        for i = 0, BS*4 do [ctx.bufs_sym][i] = 0.0f end
        [setup]
        [q]
        for i = 0, [ctx.frames_sym] do
            out_l[i] = [ctx.bufs_sym][i]
            out_r[i] = [ctx.bufs_sym][([int32](BS)) + i]
        end
    end

    local out_l = terralib.new(float[BS])
    local out_r = terralib.new(float[BS])
    render(out_l, out_r, BS)

    -- Center pan: both channels should get equal-power cos/sin at pi/4
    -- pan=0 → angle = (0+1)*pi/4 = pi/4
    -- left = 0.8 * cos(pi/4) ≈ 0.8 * 0.707 ≈ 0.566
    -- right = 0.8 * sin(pi/4) ≈ 0.8 * 0.707 ≈ 0.566
    local expected = 0.8 * math.cos(math.pi / 4)
    check(approx(out_l[0], expected, 0.01),
        "OutputJob L: " .. expected .. ", got " .. out_l[0])
    check(approx(out_r[0], expected, 0.01),
        "OutputJob R: " .. expected .. ", got " .. out_r[0])
    check(approx(out_l[0], out_r[0], 0.001),
        "Center pan: L ≈ R")

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 6: GraphPlan compile — sequences node jobs
-- ══════════════════════════════════════════════════════════
print("Test 6: GraphPlan compile — sequences node jobs")
do
    local BS = 32
    local ctx = make_compile_ctx(4, BS,
        {[1] = 0.8, [2] = 0.5},
        {[1] = D.Scheduled.Binding(0, 0),  -- param[0] → gain=0.8
         [2] = D.Scheduled.Binding(0, 1)}  -- param[1] → gain=0.5
    )

    -- Two gain nodes in series: 1.0 → *0.8 → *0.5 = 0.4
    local nj1 = D.Scheduled.NodeJob(1, 5, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0)
    local nj2 = D.Scheduled.NodeJob(2, 5, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)
    ctx.node_jobs = {nj1, nj2}

    local gp = D.Scheduled.GraphPlan(100, 0, 2, 0, 0, 0, 0)
    local q = gp:compile(ctx)

    local setup = quote
        for i = 0, [ctx.frames_sym] do [ctx.bufs_sym][i] = 1.0f end
    end
    local out = run_render(ctx, setup, q, 4, BS)
    check(approx(out[0], 0.4), "GraphPlan: 1.0 * 0.8 * 0.5 = 0.4, got " .. out[0])

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 7: TempoMap compile — tick_to_sample function
-- ══════════════════════════════════════════════════════════
print("Test 7: TempoMap compile — tick_to_sample function")
do
    -- 120 BPM at tick 0, 60 BPM at tick 3840 (beat 4)
    -- At 44100 Hz, 960 ticks/beat:
    --   spt@120 = (60/120) * 44100 / 960 = 22.96875
    --   base_sample@3840 = 3840 * 22.96875 = 88200
    --   spt@60 = (60/60) * 44100 / 960 = 45.9375
    local spt120 = (60.0/120) * 44100 / 960
    local base2 = 3840 * spt120
    local spt60 = (60.0/60) * 44100 / 960

    local tm = D.Scheduled.TempoMap(L{
        D.Scheduled.TempoSeg(0, 3840, 120, 0, spt120),
        D.Scheduled.TempoSeg(3840, 1e9, 60, base2, spt60),
    })

    local ctx = {diagnostics = {}}
    local q = tm:compile(ctx)

    check(ctx.tick_to_sample_fn ~= nil, "tick_to_sample_fn created")

    if ctx.tick_to_sample_fn then
        local fn = ctx.tick_to_sample_fn
        -- tick 0 → sample 0
        local s0 = fn(0)
        check(approx(s0, 0, 0.1), "tick 0 → sample 0, got " .. s0)

        -- tick 960 (beat 1) → 960 * spt120 = 22050
        local s1 = fn(960)
        check(approx(s1, 960 * spt120, 1), "tick 960 → " .. (960*spt120) .. ", got " .. s1)

        -- tick 3840 (beat 4) → base2 = 88200
        local s4 = fn(3840)
        check(approx(s4, base2, 1), "tick 3840 → " .. base2 .. ", got " .. s4)

        -- tick 4800 (beat 5, in 60 BPM region) → base2 + (4800-3840)*spt60
        local expected5 = base2 + 960 * spt60
        local s5 = fn(4800)
        check(approx(s5, expected5, 1), "tick 4800 → " .. expected5 .. ", got " .. s5)
    end

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 8: ClipJob compile — gain envelope
-- ══════════════════════════════════════════════════════════
print("Test 8: ClipJob compile — gain envelope applied")
do
    local BS = 32
    local ctx = make_compile_ctx(4, BS,
        {[1] = 0.6},
        {}
    )

    local cj = D.Scheduled.ClipJob(
        1, 0, 0,       -- clip_id, content_kind=audio, asset_id
        0,             -- out_buf=0
        0, 1000,       -- start_tick, end_tick
        0,             -- source_offset
        D.Scheduled.Binding(0, 0),  -- gain → 0.6
        false,         -- reversed
        0, 0,          -- fade_in: none
        0, 0           -- fade_out: none
    )

    local q = cj:compile(ctx)
    local bufs = ctx.bufs_sym
    local frames = ctx.frames_sym

    -- Fill buffer with 1.0 (simulating source), then apply clip gain
    local setup = quote
        for i = 0, frames do [bufs][i] = 1.0f end
    end

    local out = run_render(ctx, setup, q, 4, BS)
    check(approx(out[0], 0.6), "ClipJob: 1.0 * gain(0.6) = 0.6, got " .. out[0])
    check(approx(out[16], 0.6), "ClipJob mid: 0.6, got " .. out[16])

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 9: Full pipeline still works with refactored compile
-- ══════════════════════════════════════════════════════════
print("Test 9: Full pipeline with refactored compile")
do
    local project = D.Editor.Project(
        "refactor_test", nil, 1,
        D.Editor.Transport(44100, 128, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(1.0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0.0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        10, "Saturator", D.Authored.SaturatorNode(D.Authored.Tanh),
                        L{D.Editor.ParamValue(0, "drive", 1, 0.1, 10, D.Editor.StaticValue(2.0), D.Editor.Replace, D.Editor.NoSmoothing)},
                        L(), nil, nil, nil, true, nil
                    )),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        11, "Gain", D.Authored.GainNode(),
                        L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.3), D.Editor.Replace, D.Editor.NoSmoothing)},
                        L(), nil, nil, nil, true, nil
                    ))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil
            ),
            D.Editor.Track(2, "T2", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0.0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        20, "Clipper", D.Authored.Clipper(D.Authored.HardClipM),
                        L{},
                        L(), nil, nil, nil, true, nil
                    ))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil
            )
        },
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local ctx = {diagnostics = {}}
    local a = project:lower(ctx)
    local r = a:resolve(ctx)
    local c = r:classify(ctx)
    local s = c:schedule(ctx)
    local k = s:compile(ctx)

    check(k ~= nil, "kernel compiled")
    check(k._render_fn ~= nil, "render function exists")

    if k._render_fn then
        local BS = 128
        local out_l = terralib.new(float[BS])
        local out_r = terralib.new(float[BS])
        k._render_fn(out_l, out_r, BS)

        -- T1: DC 1.0 → tanh(1.0 * 2.0) → *0.3 → *1.0 (vol)
        -- tanh(2.0) ≈ 0.964
        -- T1 contribution: 0.964 * 0.3 * 1.0 ≈ 0.289
        --
        -- T2: DC 1.0 → clip(1.0) = 1.0 → *0.5 (vol)
        -- T2 contribution: 1.0 * 0.5 = 0.5
        --
        -- Total: ≈ 0.789
        local total = math.tanh(2.0) * 0.3 * 1.0 + 1.0 * 0.5
        check(approx(out_l[0], total, 0.01),
            "2-track mix: " .. total .. ", got " .. out_l[0])
        check(out_l[0] == out_r[0], "L == R (both center pan)")
    end

    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Summary
-- ══════════════════════════════════════════════════════════
print("")
print("════════════════════════════════════════")
if fail_count == 0 then
    print(string.format("ALL COMPILE JOB TESTS PASSED (%d checks)", pass_count))
    print("  NodeJob, MixJob, SendJob, OutputJob, GraphPlan, TempoMap, ClipJob")
else
    print(string.format("FAILED: %d/%d checks failed", fail_count, pass_count + fail_count))
end
print("════════════════════════════════════════")
os.exit(fail_count > 0 and 1 or 0)
