-- src/scheduled/leaf_programs.t
-- Scheduled.NodeProgram:compile, ModProgram:compile, ClipProgram:compile,
-- SendProgram:compile, MixProgram:compile, OutputProgram:compile
--
-- All compile() calls return Unit{fn, state_t} via Unit.leaf().
-- fn signature: terra(bufs, frames, init_slots, block_slots,
--                     sample_slots, event_slots, voice_slots, state: &state_t)
-- No state_raw: &uint8. The state type is declared per node kind and composed
-- by the parent GraphProgram using Unit.compose. Types fall out structurally.

local compile_node_job = require("src/scheduled/compiler/node_job")
local compile_mod_job  = require("src/scheduled/compiler/mod_job")
local compile_clip_job = require("src/scheduled/compiler/clip_job")
local compile_send_job = require("src/scheduled/compiler/send_job")
local compile_mix_job  = require("src/scheduled/compiler/mix_job")
local compile_output_job = require("src/scheduled/compiler/output_job")

-- Per-kind state types for stateful DSP nodes.
-- Each oscillator needs one float phase accumulator in [0, 1).
-- Stateless nodes use tuple() — no field in the composed parent state.
local NK_SineOsc   = 28
local NK_SawOsc    = 29
local NK_SquareOsc = 30

local function make_osc_state_t()
    local S = terralib.types.newstruct("OscState")
    S.entries:insert({ field = "phase", type = float })
    return S
end
-- One canonical type per oscillator kind (they are structurally identical).
local OSC_STATE_T = make_osc_state_t()

local function node_state_t(kind_code)
    if kind_code == NK_SineOsc or kind_code == NK_SawOsc or kind_code == NK_SquareOsc then
        return OSC_STATE_T
    end
    return tuple()
end

return function(types)
    local Unit = types.Unit

    -- Leaf fn param symbols: the runtime inputs every node fn receives.
    -- Indices: [1]=bufs [2]=frames [3]=init_slots [4]=block_slots
    --          [5]=sample_slots [6]=event_slots [7]=voice_slots
    -- Plus optional state param injected by Unit.leaf when state_t != tuple().
    local function make_leaf_params()
        return terralib.newlist({
            symbol(&float, "bufs"),
            symbol(int32,  "frames"),
            symbol(&float, "init_slots"),
            symbol(&float, "block_slots"),
            symbol(&float, "sample_slots"),
            symbol(&float, "event_slots"),
            symbol(&float, "voice_slots"),
        })
    end

    -- Generic leaf compiler.
    -- state_t:      Terra state type for this program (tuple() = stateless).
    -- job_compiler: compile(program, params, state_sym) -> quote.
    --               program = full ASDL program record (owns all compile-time data).
    --               params  = terralib list of leaf fn param symbols.
    --               state_sym = typed &state_t or nil.
    -- No ctx. No bags. All data comes from self or explicit params.
    local function compile_leaf(self, state_t, job_compiler)
        local params = make_leaf_params()
        return Unit.leaf(state_t, params, function(state_sym, params)
            return job_compiler(self, params, state_sym)
        end)
    end

    return {
        node_program = function(self)
            return compile_leaf(self, node_state_t(self.node.kind_code), compile_node_job)
        end,
        mod_program = function(self)
            return compile_leaf(self, tuple(), compile_mod_job)
        end,
        clip_program = function(self)
            return compile_leaf(self, tuple(), compile_clip_job)
        end,
        send_program = function(self)
            return compile_leaf(self, tuple(), compile_send_job)
        end,
        mix_program = function(self)
            return compile_leaf(self, tuple(), compile_mix_job)
        end,
        output_program = function(self)
            return compile_leaf(self, tuple(), compile_output_job)
        end,
    }
end
