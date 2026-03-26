-- impl2/scheduled/leaf_programs.t
-- Scheduled.NodeProgram:compile, ModProgram:compile, ClipProgram:compile,
-- SendProgram:compile, MixProgram:compile, OutputProgram:compile

local compile_node_job = require("src/scheduled/compiler/node_job")
local compile_mod_job = require("src/scheduled/compiler/mod_job")
local compile_clip_job = require("src/scheduled/compiler/clip_job")
local compile_send_job = require("src/scheduled/compiler/send_job")
local compile_mix_job = require("src/scheduled/compiler/mix_job")
local compile_output_job = require("src/scheduled/compiler/output_job")

return function(types)
local K = types.Kernel
    local Unit = types.Unit
    local function build_literal_values(literals)
        local values = {}
        for i = 1, #(literals or {}) do values[i] = literals[i].value end
        return values
    end

    local function make_leaf_ctx(self)
        local bufs_sym = symbol(&float, "bufs")
        local frames_sym = symbol(int32, "frames")
        local init_slots_sym = symbol(&float, "init_slots")
        local block_slots_sym = symbol(&float, "block_slots")
        local sample_slots_sym = symbol(&float, "sample_slots")
        local event_slots_sym = symbol(&float, "event_slots")
        local voice_slots_sym = symbol(&float, "voice_slots")
        local state_raw_sym = symbol(&uint8, "state_raw")
        return {
            diagnostics = {},
            BS = (self.transport and self.transport.buffer_size) or 512,
            sample_rate = (self.transport and self.transport.sample_rate) or 44100,
            literals = self.literals,
            literal_values = build_literal_values(self.literals),
            bufs_sym = bufs_sym,
            frames_sym = frames_sym,
            init_slots_sym = init_slots_sym,
            block_slots_sym = block_slots_sym,
            sample_slots_sym = sample_slots_sym,
            event_slots_sym = event_slots_sym,
            voice_slots_sym = voice_slots_sym,
            state_raw_sym = state_raw_sym,
            state_sym = `([&float]([state_raw_sym])),
        }
    end

    local function compile_leaf(self, job_field, compile_job_fn, extra_ctx)
        local ctx = make_leaf_ctx(self)
        if extra_ctx then for k, v in pairs(extra_ctx(self, ctx)) do ctx[k] = v end end
        local body_q = compile_job_fn(self[job_field], ctx)
        local fn = terra([ctx.bufs_sym], [ctx.frames_sym], [ctx.init_slots_sym], [ctx.block_slots_sym],
                         [ctx.sample_slots_sym], [ctx.event_slots_sym], [ctx.voice_slots_sym], [ctx.state_raw_sym])
            [body_q]
        end
        return Unit(fn, tuple())
    end

    local function node_extra(self, ctx)
        ctx.param_bindings = self.param_bindings
        ctx.param_meta = self.params
        ctx.mod_slots = self.mod_slots
        ctx.mod_routes = self.mod_routes
        ctx.mod_slot_by_index = {}
        for i = 1, #(self.mod_slots or {}) do
            local ms = self.mod_slots[i]
            ctx.mod_slot_by_index[ms.slot_index] = ms
        end
        return {}
    end

    local function mod_extra(self, ctx)
        ctx.block_sample = 0
        ctx.param_bindings = self.param_bindings
        return {}
    end

    return {
        node_program = function(self) return compile_leaf(self, "node", compile_node_job, node_extra) end,
        mod_program = function(self) return compile_leaf(self, "mod", compile_mod_job, mod_extra) end,
        clip_program = function(self) return compile_leaf(self, "clip", compile_clip_job) end,
        send_program = function(self) return compile_leaf(self, "send", compile_send_job) end,
        mix_program = function(self) return compile_leaf(self, "mix", compile_mix_job) end,
        output_program = function(self) return compile_leaf(self, "output", compile_output_job) end,
    }
end
