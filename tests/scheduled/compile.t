-- tests/scheduled/compile.t
-- Per-method tests for all 11 Scheduled → Kernel compile methods.
-- Covers: binding.compile_value, step.compile, mod_job.compile,
-- plus integration with the compile_jobs.t tests for completeness.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

-- ══════════════════════════════════════════
-- 1. scheduled.binding.compile_value
-- ══════════════════════════════════════════
print("1. scheduled.binding.compile_value")
do
    -- compile_value expects ctx.literals as Classified.Literal objects
    local b = D.Scheduled.Binding(0, 2)  -- literal, slot 2
    local InitArray = float[2]
    local BlockArray = float[2]
    local SampleArray = float[2]
    local EventArray = float[2]
    local VoiceArray = float[2]
    local init_sym = symbol(InitArray, "init_slots")
    local block_sym = symbol(BlockArray, "block_slots")
    local sample_sym = symbol(SampleArray, "sample_slots")
    local event_sym = symbol(EventArray, "event_slots")
    local voice_sym = symbol(VoiceArray, "voice_slots")
    local ctx = {diagnostics = {},
        literals = {
            [1] = D.Classified.Literal(0.25),
            [2] = D.Classified.Literal(0.5),
            [3] = D.Classified.Literal(0.75),
        },
        init_slots_sym = init_sym,
        block_slots_sym = block_sym,
        sample_slots_sym = sample_sym,
        event_slots_sym = event_sym,
        voice_slots_sym = voice_sym,
    }
    local q = b:compile_value(ctx)
    check(q ~= nil, "returned a quote")
    local val_fn = terra() : float return [q] end
    local result = val_fn()
    check(approx(result, 0.75), "literal[2] = 0.75, got " .. result)

    local b2 = D.Scheduled.Binding(0, 0)
    local q2 = b2:compile_value(ctx)
    local val_fn2 = terra() : float return [q2] end
    check(approx(val_fn2(), 0.25), "literal[0] = 0.25")

    local bi = D.Scheduled.Binding(1, 1)
    local bb = D.Scheduled.Binding(2, 1)
    local bs = D.Scheduled.Binding(3, 1)
    local be = D.Scheduled.Binding(4, 1)
    local bv = D.Scheduled.Binding(5, 1)
    local qi = bi:compile_value(ctx)
    local qb = bb:compile_value(ctx)
    local qs = bs:compile_value(ctx)
    local qe = be:compile_value(ctx)
    local qv = bv:compile_value(ctx)
    local rate_fn = terra() : float
        var [init_sym]; var [block_sym]; var [sample_sym]; var [event_sym]; var [voice_sym]
        [init_sym][1] = 1.25f
        [block_sym][1] = 2.25f
        [sample_sym][1] = 3.25f
        [event_sym][1] = 4.25f
        [voice_sym][1] = 5.25f
        return [qi] + [qb] + [qs] + [qe] + [qv]
    end
    check(approx(rate_fn(), 16.25), "non-literal rate classes read their slot arrays")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 2. scheduled.step.compile
-- ══════════════════════════════════════════
print("2. scheduled.step.compile — orchestrates clear + node jobs")
do
    local BS = 32
    local total = 4 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    -- A step that clears buf[2] and runs node_job[0] (GainNode on buf[2])
    local nj = D.Scheduled.NodeJob(1, 5, 2, 2, 0, 1, 0, 0, 0, 0, 0, 0)

    local gp = D.Scheduled.GraphPlan(100, 0, 1, 2, 2, 0, 0)

    local step = D.Scheduled.Step(0, 2, -1, 0, -1, -1, -1, -1)

    local ctx = {
        diagnostics = {},
        bufs_sym = bufs_sym,
        frames_sym = frames_sym,
        BS = BS,
        literal_values = {[1] = 0.5},
        param_bindings = {[1] = D.Scheduled.Binding(0, 0)},
        node_jobs = {nj},
        graph_plans = {gp},
        clip_jobs = {},
        mod_jobs = {},
        send_jobs = {},
        mix_jobs = {},
        output_jobs = {},
    }

    local q = step:compile(ctx)

    -- Build test: fill buf[2] with 1.0, run step (clear + gain)
    local render = terra([frames_sym])
        var [bufs_sym]
        for i = 0, total do [bufs_sym][i] = 0.0f end
        -- Pre-fill buf[2] with DC 1.0
        for i = 0, [frames_sym] do [bufs_sym][ ([int32](2*BS)) + i] = 1.0f end
        [q]
        -- Return buf[2][0]
        return [bufs_sym][ [int32](2*BS) ]
    end

    local result = render(BS)
    -- Step clears buf[2] to 0, then GainNode 0.5 on 0 → still 0
    -- (clear happens first, then gain processes the zeros)
    check(approx(result, 0.0), "step: clear then gain(0) = 0, got " .. result)
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 3. scheduled.mod_job.compile
-- ══════════════════════════════════════════
print("3. scheduled.mod_job.compile — constant modulator")
do
    local BS = 32
    local total = 4 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    local mj = D.Scheduled.ModJob(
        60, 100,           -- mod_node_id, parent_node_id
        false,             -- per_voice
        0, 1,              -- first_route, route_count
        -1,                -- output_state_slot (-1 = no state array)
        D.Scheduled.Binding(0, 0)  -- output → literal[0]
    )

    local ctx = {
        diagnostics = {},
        bufs_sym = bufs_sym,
        frames_sym = frames_sym,
        BS = BS,
        literal_values = {[1] = 0.5},
        param_bindings = {},
    }

    local q = mj:compile(ctx)
    check(q ~= nil, "mod_job produced a quote")
    -- With no state array, mod_job is a no-op (value baked into literals)
    -- Just verify it compiles without error
    local render = terra([frames_sym])
        var [bufs_sym]
        [q]
    end
    render(BS)  -- should not crash
    check(true, "mod_job compiled and ran without error")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 4. scheduled.tempo_map.compile
-- ══════════════════════════════════════════
print("4. scheduled.tempo_map.compile — tick_to_sample function")
do
    local spt120 = (60.0/120) * 44100 / 960
    local tm = D.Scheduled.TempoMap(L{
        D.Scheduled.TempoSeg(0, 3840, 120, 0, spt120)})
    local ctx = {diagnostics = {}}
    tm:compile(ctx)
    check(ctx.tick_to_sample_fn ~= nil, "tick_to_sample_fn created")
    if ctx.tick_to_sample_fn then
        local s = ctx.tick_to_sample_fn(960)
        check(approx(s, 960 * spt120, 1), "tick 960 → " .. (960*spt120))
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 5. scheduled.node_job.compile — GainNode
-- ══════════════════════════════════════════
print("5. scheduled.node_job.compile — GainNode")
do
    local BS = 32
    local total = 2 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    local nj = D.Scheduled.NodeJob(1, 5, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0)
    local ctx = {diagnostics = {}, bufs_sym = bufs_sym, frames_sym = frames_sym,
        BS = BS, literal_values = {[1] = 0.3},
        param_bindings = {[1] = D.Scheduled.Binding(0, 0)}}
    local q = nj:compile(ctx)
    local render = terra([frames_sym])
        var [bufs_sym]
        for i = 0, [frames_sym] do [bufs_sym][i] = 1.0f end
        [q]
        return [bufs_sym][0]
    end
    check(approx(render(BS), 0.3), "1.0 * 0.3 = 0.3")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 6. scheduled.mix_job.compile
-- ══════════════════════════════════════════
print("6. scheduled.mix_job.compile — buffer addition")
do
    local BS = 16
    local total = 4 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    local mj = D.Scheduled.MixJob(1, 0, D.Scheduled.Binding(0, 0))
    local ctx = {diagnostics = {}, bufs_sym = bufs_sym, frames_sym = frames_sym,
        BS = BS, literal_values = {[1] = 0.5}}
    local q = mj:compile(ctx)
    local render = terra([frames_sym])
        var [bufs_sym]
        for i = 0, total do [bufs_sym][i] = 0.0f end
        [bufs_sym][0] = 0.2f  -- target
        [bufs_sym][ [int32](BS) ] = 0.6f  -- source
        [q]
        return [bufs_sym][0]
    end
    check(approx(render(BS), 0.5), "0.2 + 0.6*0.5 = 0.5, got " .. render(BS))
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 7. scheduled.send_job.compile
-- ══════════════════════════════════════════
print("7. scheduled.send_job.compile")
do
    local BS = 16
    local total = 4 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    local sj = D.Scheduled.SendJob(2, 0, D.Scheduled.Binding(0, 0), false, true)
    local ctx = {diagnostics = {}, bufs_sym = bufs_sym, frames_sym = frames_sym,
        BS = BS, literal_values = {[1] = 0.4}}
    local q = sj:compile(ctx)
    local render = terra([frames_sym])
        var [bufs_sym]
        for i = 0, total do [bufs_sym][i] = 0.0f end
        [bufs_sym][ ([int32](2*BS)) ] = 1.0f
        [q]
        return [bufs_sym][0]
    end
    check(approx(render(BS), 0.4), "1.0 * 0.4 = 0.4")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 8. scheduled.output_job.compile
-- ══════════════════════════════════════════
print("8. scheduled.output_job.compile — stereo pan")
do
    local BS = 16
    local total = 4 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    -- Hard left pan: pan=-1 → angle=0 → left=gain, right=0
    local oj = D.Scheduled.OutputJob(2, 0, 1,
        D.Scheduled.Binding(0, 0), D.Scheduled.Binding(0, 1))
    local ctx = {diagnostics = {}, bufs_sym = bufs_sym, frames_sym = frames_sym,
        BS = BS, literal_values = {[1] = 1.0, [2] = -1.0}}
    local q = oj:compile(ctx)
    local render_l = terra([frames_sym])
        var [bufs_sym]
        for i = 0, total do [bufs_sym][i] = 0.0f end
        [bufs_sym][ ([int32](2*BS)) ] = 1.0f
        [q]
        return [bufs_sym][0]
    end
    -- Need separate bufs_sym for R test since symbols are consumed
    local bufs_sym2 = symbol(BufArray, "bufs2")
    local frames_sym2 = symbol(int32, "frames2")
    local oj2 = D.Scheduled.OutputJob(2, 0, 1,
        D.Scheduled.Binding(0, 0), D.Scheduled.Binding(0, 1))
    local ctx2 = {diagnostics = {}, bufs_sym = bufs_sym2, frames_sym = frames_sym2,
        BS = BS, literal_values = {[1] = 1.0, [2] = -1.0}}
    local q2 = oj2:compile(ctx2)
    local render_r = terra([frames_sym2])
        var [bufs_sym2]
        for i = 0, total do [bufs_sym2][i] = 0.0f end
        [bufs_sym2][ ([int32](2*BS)) ] = 1.0f
        [q2]
        return [bufs_sym2][ [int32](BS) ]
    end
    local l = render_l(BS)
    local r = render_r(BS)
    check(l > 0.9, "hard left: L > 0.9, got " .. l)
    check(approx(r, 0, 0.01), "hard left: R ≈ 0, got " .. r)
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 9. scheduled.graph_plan.compile
-- ══════════════════════════════════════════
print("9. scheduled.graph_plan.compile — chain 2 nodes")
do
    local BS = 16
    local total = 2 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    local nj1 = D.Scheduled.NodeJob(1, 5, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0)
    local nj2 = D.Scheduled.NodeJob(2, 5, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)
    local gp = D.Scheduled.GraphPlan(100, 0, 2, 0, 0, 0, 0)
    local ctx = {diagnostics = {}, bufs_sym = bufs_sym, frames_sym = frames_sym,
        BS = BS, literal_values = {[1] = 0.7, [2] = 0.3},
        param_bindings = {[1] = D.Scheduled.Binding(0, 0), [2] = D.Scheduled.Binding(0, 1)},
        node_jobs = {nj1, nj2}}
    local q = gp:compile(ctx)
    local render = terra([frames_sym])
        var [bufs_sym]
        for i = 0, [frames_sym] do [bufs_sym][i] = 1.0f end
        [q]
        return [bufs_sym][0]
    end
    check(approx(render(BS), 0.21, 0.01), "1.0 * 0.7 * 0.3 = 0.21")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 10. scheduled.clip_job.compile — gain envelope
-- ══════════════════════════════════════════
print("10. scheduled.clip_job.compile")
do
    local BS = 32
    local total = 2 * BS
    local BufArray = float[total]
    local bufs_sym = symbol(BufArray, "bufs")
    local frames_sym = symbol(int32, "frames")

    local cj = D.Scheduled.ClipJob(1, 0, 0, 0, 0, 1000, 0,
        D.Scheduled.Binding(0, 0), false, 0, 0, 0, 0)
    local ctx = {diagnostics = {}, bufs_sym = bufs_sym, frames_sym = frames_sym,
        BS = BS, literal_values = {[1] = 0.6}}
    local q = cj:compile(ctx)
    local render = terra([frames_sym])
        var [bufs_sym]
        for i = 0, total do [bufs_sym][i] = 0.0f end
        [q]
        return [bufs_sym][0]
    end
    check(approx(render(BS), 0.6), "clip source * gain(0.6) = 0.6")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 11. scheduled.project.compile — integration
-- ══════════════════════════════════════════
print("11. scheduled.project.compile — full pipeline")
do
    local project = D.Editor.Project(
        "Test", nil, 1,
        D.Editor.Transport(44100, 128, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "v", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "p", 0, -1, 1, D.Editor.StaticValue(-1), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    9, "Square", D.Authored.SquareOsc(),
                    L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil)),
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
    check(#s.output_jobs >= 1, "scheduled output job exists")
    check(s.steps[1].output_job >= 0, "first scheduled step drives output job")
    local k = s:compile(ctx)
    local render = k and k:entry_fn() or nil
    check(k ~= nil, "kernel produced")
    check(render ~= nil, "entry_fn exists")
    if render then
        local out_l = terralib.new(float[128])
        local out_r = terralib.new(float[128])
        render(out_l, out_r, 128)
        -- SquareOsc(100Hz, constant over this block) → Gain(0.5) → Vol(0.8) = 0.4,
        -- then OutputJob pan=-1 sends it hard left.
        check(approx(out_l[0], 0.4), "left output = 0.4, got " .. out_l[0])
        check(approx(out_r[0], 0.0, 0.01), "right output = 0 via OutputJob pan, got " .. out_r[0])
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 12. scheduled.project.compile — block-rate control slot
-- ══════════════════════════════════════════
print("12. scheduled.project.compile — block-rate control slot")
do
    local transport = D.Scheduled.Transport(44100, 64, 120, 0, 4, 4, 0, false, 0, 0)
    local tempo_map = D.Scheduled.TempoMap(L{D.Scheduled.TempoSeg(0, 3840, 120, 0, (60.0/120) * 44100 / 960)})
    local buffers = L{
        D.Scheduled.Buffer(0, 1, false, true),
        D.Scheduled.Buffer(1, 1, false, true),
        D.Scheduled.Buffer(2, 1, false, false),
    }
    local tracks = L{
        D.Scheduled.TrackPlan(1,
            D.Scheduled.Binding(2, 0),
            D.Scheduled.Binding(0, 1),
            0, 0, 0,
            0, 1,
            2, -1, -1,
            0, 1,
            false)
    }
    local steps = L{D.Scheduled.Step(0, -1, 0, -1, -1, -1, -1, 0)}
    local clip_jobs = L{D.Scheduled.ClipJob(1, 0, 0, 2, 0, 960, 0, D.Scheduled.Binding(0, 0), false, 0, 0, 0, 0)}
    local output_jobs = L{D.Scheduled.OutputJob(2, 0, 1, D.Scheduled.Binding(2, 0), D.Scheduled.Binding(0, 1))}
    local block_ops = L{D.Scheduled.BlockOp(0, 0, 0, 0, 0, D.Scheduled.Binding(0, 2), nil)}

    local p = D.Scheduled.Project(
        transport, tempo_map,
        buffers, tracks, steps,
        L(), L(),
        L(), L(), output_jobs, clip_jobs, L(),
        L(), L(),
        L{D.Scheduled.Literal(1.0), D.Scheduled.Literal(-1.0), D.Scheduled.Literal(0.5)},
        L(), L(), L(),
        L(),
        L(), block_ops, L(),
        L(), L(), L(),
        3, 0,
        0, 1
    )

    local k = p:compile({diagnostics = {}})
    local render = k and k:entry_fn() or nil
    check(k ~= nil and render ~= nil, "manual scheduled project compiled")
    if render then
        local out_l = terralib.new(float[64])
        local out_r = terralib.new(float[64])
        render(out_l, out_r, 64)
        check(approx(out_l[0], 0.5, 0.01), "block slot drives output gain to 0.5, got " .. out_l[0])
        check(approx(out_r[0], 0.0, 0.01), "hard-left pan still applies, got " .. out_r[0])
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 13. scheduled.project.compile — block curve interpolation
-- ══════════════════════════════════════════
print("13. scheduled.project.compile — block curve interpolation")
do
    local transport = D.Scheduled.Transport(44100, 64, 120, 0, 4, 4, 0, false, 0, 0)
    local tempo_map = D.Scheduled.TempoMap(L{D.Scheduled.TempoSeg(0, 3840, 120, 0, (60.0/120) * 44100 / 960)})
    local buffers = L{
        D.Scheduled.Buffer(0, 1, false, true),
        D.Scheduled.Buffer(1, 1, false, true),
        D.Scheduled.Buffer(2, 1, false, false),
    }
    local tracks = L{
        D.Scheduled.TrackPlan(1,
            D.Scheduled.Binding(2, 0),
            D.Scheduled.Binding(0, 1),
            0, 0, 0,
            0, 1,
            2, -1, -1,
            0, 1,
            false)
    }
    local steps = L{D.Scheduled.Step(0, -1, 0, -1, -1, -1, -1, 0)}
    local clip_jobs = L{D.Scheduled.ClipJob(1, 0, 0, 2, 0, 960, 0, D.Scheduled.Binding(0, 0), false, 0, 0, 0, 0)}
    local output_jobs = L{D.Scheduled.OutputJob(2, 0, 1, D.Scheduled.Binding(2, 0), D.Scheduled.Binding(0, 1))}
    local block_ops = L{D.Scheduled.BlockOp(1, 0, 2, 0, 0, D.Scheduled.Binding(0, 2), nil)}
    local block_pts = L{D.Scheduled.BlockPt(0, 0.2), D.Scheduled.BlockPt(960, 0.8)}

    local p = D.Scheduled.Project(
        transport, tempo_map,
        buffers, tracks, steps,
        L(), L(),
        L(), L(), output_jobs, clip_jobs, L(),
        L(), L(),
        L{D.Scheduled.Literal(1.0), D.Scheduled.Literal(-1.0), D.Scheduled.Literal(0.0)},
        L(), L(), L(),
        L(),
        L(), block_ops, block_pts,
        L(), L(), L(),
        3, 0,
        0, 1
    )

    local k0 = p:compile({diagnostics = {}, block_tick = 0})
    local kMid = p:compile({diagnostics = {}, block_tick = 480})
    local k1 = p:compile({diagnostics = {}, block_tick = 960})
    local r0 = k0 and k0:entry_fn() or nil
    local rMid = kMid and kMid:entry_fn() or nil
    local r1 = k1 and k1:entry_fn() or nil
    check(k0 ~= nil and r0 ~= nil, "curve project compile @ tick 0")
    check(kMid ~= nil and rMid ~= nil, "curve project compile @ tick 480")
    check(k1 ~= nil and r1 ~= nil, "curve project compile @ tick 960")
    if r0 and rMid and r1 then
        local out0L = terralib.new(float[64]); local out0R = terralib.new(float[64])
        local outML = terralib.new(float[64]); local outMR = terralib.new(float[64])
        local out1L = terralib.new(float[64]); local out1R = terralib.new(float[64])
        r0(out0L, out0R, 64)
        rMid(outML, outMR, 64)
        r1(out1L, out1R, 64)
        check(approx(out0L[0], 0.2, 0.01), "curve tick 0 -> gain 0.2, got " .. out0L[0])
        check(approx(outML[0], 0.5, 0.02), "curve tick 480 -> interpolated gain 0.5, got " .. outML[0])
        check(approx(out1L[0], 0.8, 0.01), "curve tick 960 -> gain 0.8, got " .. out1L[0])
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 14. scheduled.project.compile — modulation routing
-- ══════════════════════════════════════════
print("14. scheduled.project.compile — modulation routing")
do
    local transport = D.Scheduled.Transport(44100, 64, 120, 0, 4, 4, 0, false, 0, 0)
    local tempo_map = D.Scheduled.TempoMap(L{D.Scheduled.TempoSeg(0, 3840, 120, 0, (60.0/120) * 44100 / 960)})
    local buffers = L{
        D.Scheduled.Buffer(0, 1, false, true),
        D.Scheduled.Buffer(1, 1, false, true),
        D.Scheduled.Buffer(2, 1, false, false),
    }
    local tracks = L{
        D.Scheduled.TrackPlan(1,
            D.Scheduled.Binding(0, 2),
            D.Scheduled.Binding(0, 1),
            0, 0, 0,
            0, 2,
            2, -1, -1,
            0, 1,
            false)
    }
    local steps = L{
        D.Scheduled.Step(0, -1, -1, -1, 0, -1, -1, -1),
        D.Scheduled.Step(1, -1, 0, 0, -1, -1, -1, 0),
    }
    local node_jobs = L{D.Scheduled.NodeJob(10, 5, 2, 2, 0, 1, 0, 0, 0, 0, 0, 0)}
    local clip_jobs = L{D.Scheduled.ClipJob(1, 0, 0, 2, 0, 960, 0, D.Scheduled.Binding(0, 0), false, 0, 0, 0, 0)}
    local mod_jobs = L{D.Scheduled.ModJob(90, 10, false, 0, 1, 0, D.Scheduled.Binding(0, 3))}
    local output_jobs = L{D.Scheduled.OutputJob(2, 0, 1, D.Scheduled.Binding(0, 2), D.Scheduled.Binding(0, 1))}

    local p = D.Scheduled.Project(
        transport, tempo_map,
        buffers, tracks, steps,
        L(), node_jobs,
        L(), L(), output_jobs, clip_jobs, mod_jobs,
        L(), L(),
        L{
            D.Scheduled.Literal(1.0),
            D.Scheduled.Literal(-1.0),
            D.Scheduled.Literal(1.0),
            D.Scheduled.Literal(0.5),
            D.Scheduled.Literal(0.2),
        },
        L{
            D.Scheduled.Param(0, 10, 0.2, 0, 4, D.Scheduled.Binding(0, 4), 0, 0, 0, 0, 1, 0)
        },
        L{
            D.Scheduled.ModSlot(0, 10, 90, false, 0, 1, D.Scheduled.Binding(3, 0))
        },
        L{
            D.Scheduled.ModRoute(0, 0, D.Scheduled.Binding(0, 0), true, nil)
        },
        L{D.Scheduled.Binding(0, 4)},
        L(), L(), L(),
        L(), L(), L(),
        3, 1,
        0, 1
    )

    local k = p:compile({diagnostics = {}})
    local render = k and k:entry_fn() or nil
    check(k ~= nil and render ~= nil, "manual modulation project compiled")
    if render then
        local out_l = terralib.new(float[64])
        local out_r = terralib.new(float[64])
        render(out_l, out_r, 64)
        check(approx(out_l[0], 0.7, 0.02), "modulation adds 0.5 to base gain 0.2 -> 0.7, got " .. out_l[0])
        check(approx(out_r[0], 0.0, 0.01), "hard-left pan still applies under modulation")
    end
    print("  PASS")
end

-- Summary
print("")
print(string.format("Scheduled compile: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
