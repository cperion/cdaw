-- src/scheduled/compiler/output_job.t
-- Compiles a Scheduled.OutputProgram into a Terra quote.
--
-- Signature: compile(program: OutputProgram, params, state_sym) -> quote
--   program owns all compile-time data. state_sym always nil (stateless).

local compile_binding = require("src/scheduled/compiler/binding")
local C = terralib.includec("math.h")

local function compile(program, params, _state_sym)
    local job = program.output
    local BS  = program.transport and program.transport.buffer_size or 512

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
    local pan_q  = compile_binding(job.pan,  literal_values,
        init_sym, block_sym, sample_sym, event_sym, voice_sym)

    local soff = job.source_buf * BS
    local loff = job.out_left   * BS
    local roff = job.out_right  * BS

    return quote
        var so   = [int32](soff)
        var lo   = [int32](loff); var ro = [int32](roff)
        var gain : float = [gain_q]
        var pan  : float = [pan_q]
        var angle : float = (pan + 1.0f) * [float](math.pi / 4.0)
        var lg   : float = gain * C.cosf(angle)
        var rg   : float = gain * C.sinf(angle)
        for i = 0, frames_sym do
            var s = [bufs_sym][so+i]
            [bufs_sym][lo+i] = [bufs_sym][lo+i] + s * lg
            [bufs_sym][ro+i] = [bufs_sym][ro+i] + s * rg
        end
    end
end

return compile
