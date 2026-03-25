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

local function resolve_binding_value(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end


function D.Scheduled.Project:compile(caller_ctx)
    return diag.wrap(caller_ctx, "scheduled.project.compile", "real", function()
        local ctx = caller_ctx or {}
        ctx.diagnostics = ctx.diagnostics or {}

        local buffer_size = self.transport.buffer_size
        local n_bufs = math.max(self.total_buffers, 1)
        local ml = self.master_left
        local mr = self.master_right
        local literal_values = self._literal_values or {}

        -- Snapshot scheduled data into plain Lua tables
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

        -- ── Build compile context for individual job methods ──
        -- Terra symbols are created inside the terra block and shared
        -- with all job compile methods via the compile_ctx.
        local compile_ctx = {
            diagnostics = ctx.diagnostics,
            BS = BS,
            literal_values = literal_values,
            param_bindings = param_bindings,
            node_jobs = node_jobs,
            graph_plans = graph_plans,
            send_jobs = send_jobs,
            mix_jobs = mix_jobs,
            output_jobs = output_jobs,
            clip_jobs = clip_jobs,
            mod_jobs = mod_jobs,
        }

        -- ── Build render function ──
        local render_fn
        if #track_plans > 0 then
            -- Pre-create Terra symbols that all quotes will share
            local bufs_sym = symbol(BufArray, "bufs")
            local frames_sym = symbol(int32, "frames")
            local ol_sym = symbol(&float, "output_left")
            local or_sym = symbol(&float, "output_right")
            compile_ctx.bufs_sym = bufs_sym
            compile_ctx.frames_sym = frames_sym

            -- Compile tempo map (emits tick_to_sample helper if needed)
            local tempo_quote = self.tempo_map:compile(compile_ctx)

            -- ── Collect all quotes for the render function body ──
            local body_quotes = terralib.newlist()

            -- Zero all buffers
            body_quotes:insert(quote
                for i = 0, TF do [bufs_sym][i] = 0.0f end
            end)

            -- Tempo map helper (if any)
            body_quotes:insert(tempo_quote)

            -- Fill work buffers with DC 1.0 (test input)
            for ti = 1, #track_plans do
                local woff = track_plans[ti].work_buf * BS
                body_quotes:insert(quote
                    var wo = [int32](woff)
                    for i = 0, [frames_sym] do [bufs_sym][wo+i] = 1.0f end
                end)
            end

            -- Process node jobs via delegation
            for ni = 1, #node_jobs do
                body_quotes:insert(node_jobs[ni]:compile(compile_ctx))
            end

            -- Mix tracks to master with volume
            for ti = 1, #track_plans do
                local tp = track_plans[ti]
                local woff = tp.work_buf * BS
                local mlo = ml * BS
                local mro = mr * BS
                local vv = resolve_binding_value(tp.volume, literal_values)
                body_quotes:insert(quote
                    var wo = [int32](woff)
                    var mL = [int32](mlo); var mR = [int32](mro)
                    var v : float = vv
                    for i = 0, [frames_sym] do
                        var s = [bufs_sym][wo+i] * v
                        [bufs_sym][mL+i] = [bufs_sym][mL+i] + s
                        [bufs_sym][mR+i] = [bufs_sym][mR+i] + s
                    end
                end)
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
        local result = D.Kernel.Project(buffers, state, api)
        result._render_fn = render_fn
        return result
    end, function()
        return F.kernel_project()
    end)
end

return true
