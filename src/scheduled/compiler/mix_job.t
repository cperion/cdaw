-- src/scheduled/compiler/mix_job.t
-- Compiles a Scheduled.MixProgram into a Terra quote.
--
-- Signature: compile(program: MixProgram, params, state_sym) -> quote
--   program owns all compile-time data (mix job, literals, transport).
--   params[1]=bufs, params[2]=frames, [3..7]=rate slots.
--   state_sym: always nil (MixProgram is stateless).

local compile_binding = require("src/scheduled/compiler/binding")

local function compile(program, params, _state_sym)
    local job    = program.mix
    local BS     = program.transport and program.transport.buffer_size or 512

    local literal_values = {}
    for i = 1, #(program.literals or {}) do
        literal_values[i] = program.literals[i].value
    end

    local bufs_sym   = params[1]
    local frames_sym = params[2]
    local init_sym   = params[3]; local block_sym  = params[4]
    local sample_sym = params[5]; local event_sym  = params[6]
    local voice_sym  = params[7]

    local gain_q = compile_binding(job.gain, literal_values,
        init_sym, block_sym, sample_sym, event_sym, voice_sym)
    local soff = job.source_buf * BS
    local toff = job.target_buf * BS

    return quote
        var so = [int32](soff); var to = [int32](toff)
        var g  : float = [gain_q]
        for i = 0, frames_sym do
            [bufs_sym][to+i] = [bufs_sym][to+i] + [bufs_sym][so+i] * g
        end
    end
end

return compile
