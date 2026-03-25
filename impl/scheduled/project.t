-- impl/scheduled/project.t
-- Scheduled.Project:compile → Kernel.Project
--
-- Compiles the scheduled plan into monomorphic Terra code.
-- Delegates to individual job compile methods, passing a CompileCtx
-- with buffer symbols and literal values.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.project.compile", "real")

local C = terralib.includec("math.h")

local function scan_binding(binding, counts)
    if not binding then return end
    local rc = binding.rate_class
    if rc >= 1 and rc <= 5 then
        local need = binding.slot + 1
        if need > counts[rc] then counts[rc] = need end
    end
end

local function scan_binding_list(bindings, counts)
    for i = 1, #bindings do scan_binding(bindings[i], counts) end
end

local function runtime_slot_counts(self)
    local counts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0 }

    scan_binding_list(self.param_bindings, counts)
    for i = 1, #self.tracks do
        scan_binding(self.tracks[i].volume, counts)
        scan_binding(self.tracks[i].pan, counts)
    end
    for i = 1, #self.send_jobs do scan_binding(self.send_jobs[i].level, counts) end
    for i = 1, #self.mix_jobs do scan_binding(self.mix_jobs[i].gain, counts) end
    for i = 1, #self.output_jobs do
        scan_binding(self.output_jobs[i].gain, counts)
        scan_binding(self.output_jobs[i].pan, counts)
    end
    for i = 1, #self.clip_jobs do scan_binding(self.clip_jobs[i].gain, counts) end
    for i = 1, #self.mod_jobs do scan_binding(self.mod_jobs[i].output, counts) end
    for i = 1, #self.mod_routes do scan_binding(self.mod_routes[i].depth, counts) end

    for i = 1, #self.init_ops do
        scan_binding(self.init_ops[i].i0, counts)
        scan_binding(self.init_ops[i].i1, counts)
        local need = self.init_ops[i].state_slot + 1
        if need > counts[1] then counts[1] = need end
    end
    for i = 1, #self.block_ops do
        scan_binding(self.block_ops[i].i0, counts)
        scan_binding(self.block_ops[i].i1, counts)
        local need = self.block_ops[i].arg0 + 1
        if need > counts[2] then counts[2] = need end
    end
    for i = 1, #self.sample_ops do
        scan_binding(self.sample_ops[i].i0, counts)
        scan_binding(self.sample_ops[i].i1, counts)
        local need = self.sample_ops[i].state_slot + 1
        if need > counts[3] then counts[3] = need end
    end
    for i = 1, #self.event_ops do
        local need = self.event_ops[i].state_slot + 1
        if need > counts[4] then counts[4] = need end
    end
    for i = 1, #self.voice_ops do
        scan_binding(self.voice_ops[i].i0, counts)
        scan_binding(self.voice_ops[i].i1, counts)
        local need = self.voice_ops[i].state_slot + 1
        if need > counts[5] then counts[5] = need end
    end

    return counts
end

local function resolve_literal_binding(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end

local function eval_block_curve(op, block_pts, literal_values, block_tick)
    local pt_count = op.pt_count or 0
    local base = resolve_literal_binding(op.i0, literal_values)
    if pt_count <= 0 then return base end

    local first = block_pts[op.first_pt + 1]
    if not first then return base end
    if block_tick <= first.tick then return first.value end

    local prev = first
    for i = 2, pt_count do
        local cur = block_pts[op.first_pt + i]
        if not cur then break end
        if block_tick <= cur.tick then
            if op.interp == 2 or cur.tick == prev.tick then
                return prev.value
            end
            local t = (block_tick - prev.tick) / (cur.tick - prev.tick)
            if op.interp == 1 then
                t = t * t * (3.0 - 2.0 * t)
            end
            return prev.value + (cur.value - prev.value) * t
        end
        prev = cur
    end
    return prev.value
end

local function emit_runtime_ops(self, ctx)
    local quotes = terralib.newlist()

    for i = 1, #self.init_ops do
        local op = self.init_ops[i]
        if op.kind == 0 and ctx.init_slots_sym then
            local slot = op.state_slot
            local v0 = op.i0:compile_value(ctx)
            quotes:insert(quote [ctx.init_slots_sym][slot] = [v0] end)
        end
    end

    for i = 1, #self.block_ops do
        local op = self.block_ops[i]
        if op.kind == 0 and ctx.block_slots_sym then
            local slot = op.arg0
            local v0 = op.i0:compile_value(ctx)
            quotes:insert(quote [ctx.block_slots_sym][slot] = [v0] end)
        elseif op.kind == 1 and ctx.block_slots_sym then
            local slot = op.arg0
            local v = eval_block_curve(op, self.block_pts, ctx.literal_values or {}, ctx.block_tick or 0)
            quotes:insert(quote [ctx.block_slots_sym][slot] = [float](v) end)
        end
    end

    for i = 1, #self.sample_ops do
        local op = self.sample_ops[i]
        if op.kind == 0 and ctx.sample_slots_sym then
            local slot = op.state_slot
            local v0 = op.i0:compile_value(ctx)
            quotes:insert(quote [ctx.sample_slots_sym][slot] = [v0] end)
        end
    end

    for i = 1, #self.event_ops do
        local op = self.event_ops[i]
        if op.kind == 0 and ctx.event_slots_sym then
            local slot = op.state_slot
            local v = op.min_v
            quotes:insert(quote [ctx.event_slots_sym][slot] = [float](v) end)
        end
    end

    for i = 1, #self.voice_ops do
        local op = self.voice_ops[i]
        if op.kind == 0 and ctx.voice_slots_sym then
            local slot = op.state_slot
            local v0 = op.i0:compile_value(ctx)
            quotes:insert(quote [ctx.voice_slots_sym][slot] = [v0] end)
        end
    end

    return quotes
end


function D.Scheduled.Project:compile(caller_ctx)
    return diag.wrap(caller_ctx, "scheduled.project.compile", "real", function()
        local ctx = caller_ctx or {}
        ctx.diagnostics = ctx.diagnostics or {}

        local buffer_size = self.transport.buffer_size
        local n_bufs = math.max(self.total_buffers, 1)
        local ml = self.master_left
        local mr = self.master_right
        local literal_values = {}
        for i = 1, #self.literals do literal_values[i] = self.literals[i].value end

        -- Snapshot scheduled data into plain Lua tables
        local literals = {}
        for i = 1, #self.literals do literals[i] = self.literals[i] end
        local params = {}
        for i = 1, #self.params do params[i] = self.params[i] end
        local mod_slots = {}
        for i = 1, #self.mod_slots do mod_slots[i] = self.mod_slots[i] end
        local mod_routes = {}
        for i = 1, #self.mod_routes do mod_routes[i] = self.mod_routes[i] end
        local node_jobs = {}
        for i = 1, #self.node_jobs do node_jobs[i] = self.node_jobs[i] end
        local track_plans = {}
        for i = 1, #self.tracks do track_plans[i] = self.tracks[i] end
        local param_bindings = {}
        for i = 1, #self.param_bindings do param_bindings[i] = self.param_bindings[i] end
        local graph_plans = {}
        for i = 1, #self.graph_plans do graph_plans[i] = self.graph_plans[i] end
        local steps = {}
        for i = 1, #self.steps do steps[i] = self.steps[i] end
        local send_jobs = {}
        for i = 1, #self.send_jobs do send_jobs[i] = self.send_jobs[i] end
        local mix_jobs = {}
        for i = 1, #self.mix_jobs do mix_jobs[i] = self.mix_jobs[i] end
        local output_jobs = {}
        for i = 1, #self.output_jobs do output_jobs[i] = self.output_jobs[i] end
        local clip_jobs = {}
        for i = 1, #self.clip_jobs do clip_jobs[i] = self.clip_jobs[i] end
        local mod_jobs = {}
        for i = 1, #self.mod_jobs do mod_jobs[i] = self.mod_jobs[i] end

        local BS = buffer_size
        local total_floats = n_bufs * BS
        local BufArray = float[total_floats]
        local TF = total_floats
        local rate_counts = runtime_slot_counts(self)
        local init_count = math.max(rate_counts[1], 1)
        local block_count = math.max(rate_counts[2], 1)
        local sample_count = math.max(rate_counts[3], 1)
        local event_count = math.max(rate_counts[4], 1)
        local voice_count = math.max(rate_counts[5], 1)
        local state_count = math.max(self.total_state_slots, 1)
        local InitArray = float[init_count]
        local BlockArray = float[block_count]
        local SampleArray = float[sample_count]
        local EventArray = float[event_count]
        local VoiceArray = float[voice_count]
        local StateArray = float[state_count]

        -- ── Build compile context for individual job methods ──
        -- Terra symbols are created inside the terra block and shared
        -- with all job compile methods via the compile_ctx.
        local compile_ctx = {
            diagnostics = ctx.diagnostics,
            BS = BS,
            sample_rate = self.transport.sample_rate,
            literals = literals,
            literal_values = literal_values,
            block_tick = ctx.block_tick or 0,
            param_bindings = param_bindings,
            param_meta = params,
            mod_slots = mod_slots,
            mod_routes = mod_routes,
            node_jobs = node_jobs,
            graph_plans = graph_plans,
            steps = steps,
            send_jobs = send_jobs,
            mix_jobs = mix_jobs,
            output_jobs = output_jobs,
            clip_jobs = clip_jobs,
            mod_jobs = mod_jobs,
        }

        compile_ctx.mod_slot_by_index = {}
        for i = 1, #compile_ctx.mod_slots do
            local ms = compile_ctx.mod_slots[i]
            compile_ctx.mod_slot_by_index[ms.slot_index] = ms
        end

        -- ── Build render function ──
        local render_fn
        if #track_plans > 0 then
            -- Pre-create Terra symbols that all quotes will share
            local bufs_sym = symbol(BufArray, "bufs")
            local init_slots_sym = symbol(InitArray, "init_slots")
            local block_slots_sym = symbol(BlockArray, "block_slots")
            local sample_slots_sym = symbol(SampleArray, "sample_slots")
            local event_slots_sym = symbol(EventArray, "event_slots")
            local voice_slots_sym = symbol(VoiceArray, "voice_slots")
            local state_sym = symbol(StateArray, "state")
            local frames_sym = symbol(int32, "frames")
            local ol_sym = symbol(&float, "output_left")
            local or_sym = symbol(&float, "output_right")
            compile_ctx.bufs_sym = bufs_sym
            compile_ctx.init_slots_sym = init_slots_sym
            compile_ctx.block_slots_sym = block_slots_sym
            compile_ctx.sample_slots_sym = sample_slots_sym
            compile_ctx.event_slots_sym = event_slots_sym
            compile_ctx.voice_slots_sym = voice_slots_sym
            compile_ctx.state_sym = state_sym
            compile_ctx.frames_sym = frames_sym

            -- Compile tempo map (emits tick_to_sample helper if needed)
            local tempo_quote = self.tempo_map:compile(compile_ctx)

            -- ── Collect all quotes for the render function body ──
            local body_quotes = terralib.newlist()

            -- Zero all buffers and runtime control/state slots.
            body_quotes:insert(quote
                for i = 0, TF do [bufs_sym][i] = 0.0f end
                for i = 0, init_count do [init_slots_sym][i] = 0.0f end
                for i = 0, block_count do [block_slots_sym][i] = 0.0f end
                for i = 0, sample_count do [sample_slots_sym][i] = 0.0f end
                for i = 0, event_count do [event_slots_sym][i] = 0.0f end
                for i = 0, voice_count do [voice_slots_sym][i] = 0.0f end
                for i = 0, state_count do [state_sym][i] = 0.0f end
            end)

            -- Tempo map helper (if any)
            body_quotes:insert(tempo_quote)

            -- Populate runtime control slots from scheduled ops.
            body_quotes:insert(quote [emit_runtime_ops(self, compile_ctx)] end)

            -- Execute the scheduled step list. Steps in turn delegate to clip,
            -- node, mod, send, mix, and output job compilers.
            for si = 1, #steps do
                body_quotes:insert(steps[si]:compile(compile_ctx))
            end

            -- Copy master to output
            local mlo = ml * BS; local mro = mr * BS
            body_quotes:insert(quote
                var mL = [int32](mlo); var mR = [int32](mro)
                for i = 0, [frames_sym] do
                    [ol_sym][i] = [bufs_sym][mL+i]
                    [or_sym][i] = [bufs_sym][mR+i]
                end
            end)

            render_fn = terra([ol_sym], [or_sym], [frames_sym])
                var [bufs_sym]
                var [init_slots_sym]
                var [block_slots_sym]
                var [sample_slots_sym]
                var [event_slots_sym]
                var [voice_slots_sym]
                var [state_sym]
                [body_quotes]
            end
        else
            render_fn = terra(output_left : &float, output_right : &float, frames : int32)
                for i = 0, frames do output_left[i] = 0.0f; output_right[i] = 0.0f end
            end
        end

        local stub_type = tuple()
        local noop_q = quote end
        local buffers = D.Kernel.Buffers(stub_type, stub_type, stub_type, stub_type, stub_type)
        local state = D.Kernel.State(stub_type, stub_type, stub_type, stub_type, stub_type, stub_type)
        local api = D.Kernel.API(
            noop_q, noop_q, quote render_fn end,
            noop_q, noop_q, noop_q, noop_q, noop_q, noop_q,
            noop_q, noop_q, noop_q, noop_q, noop_q, noop_q, noop_q, noop_q
        )
        return D.Kernel.Project(buffers, state, api, render_fn)
    end, function()
        return F.kernel_project()
    end)
end

return true
