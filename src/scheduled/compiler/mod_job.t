-- src/scheduled/compiler/mod_job.t
-- Compiles a Scheduled.ModProgram into a Terra quote.
--
-- Signature: compile(program: ModProgram, params, state_sym) -> quote
--   program owns all compile-time data. state_sym always nil (ModProgram is stateless).

local compile_binding = require("src/scheduled/compiler/binding")
local C = terralib.includec("math.h")

local NK_LFOMod = 156

local function compile(program, params, _state_sym)
    local job = program.mod

    local literal_values = {}
    for i = 1, #(program.literals or {}) do
        literal_values[i] = program.literals[i].value
    end

    local bufs_sym   = params[1]
    local frames_sym = params[2]
    local init_sym   = params[3]; local block_sym  = params[4]
    local sample_sym = params[5]; local event_sym  = params[6]
    local voice_sym  = params[7]

    local slot = job.output_state_slot

    if job.kind_code == NK_LFOMod then
        local first_param   = job.first_param
        local rate_b        = program.param_bindings and program.param_bindings[first_param + 1]
        local rate_q        = rate_b and compile_binding(rate_b, literal_values,
            init_sym, block_sym, sample_sym, event_sym, voice_sym) or `0.0f
        local block_sample  = program.block_sample or 0.0
        local sample_rate   = (program.transport and program.transport.sample_rate) or 44100.0
        local shape_code    = job.arg0 or 0
        local TAU           = 6.283185307179586

        local cycles_q = `(([float](block_sample / sample_rate)) * [rate_q])
        local frac_q   = `(([cycles_q]) - C.floorf([cycles_q]))
        local out_q

        if shape_code == 1 then
            out_q = `(1.0f - 4.0f * C.fabsf(([frac_q]) - 0.5f))
        elseif shape_code == 2 then
            out_q = `C.copysignf(1.0f, C.sinf(([cycles_q]) * [float](TAU)))
        elseif shape_code == 3 then
            out_q = `(([frac_q]) * 2.0f - 1.0f)
        elseif shape_code == 4 then
            local whole_q = `C.floorf([cycles_q])
            local n_q     = `(C.sinf([whole_q] * 12.9898f) * 43758.5453f)
            local nfrac_q = `([n_q] - C.floorf([n_q]))
            out_q = `([nfrac_q] * 2.0f - 1.0f)
        else
            out_q = `C.sinf(([cycles_q]) * [float](TAU))
        end

        return quote [sample_sym][slot] = [out_q] end
    end

    -- Generic modulator: write binding output to sample slot.
    local out_q = compile_binding(job.output, literal_values,
        init_sym, block_sym, sample_sym, event_sym, voice_sym)
    return quote [sample_sym][slot] = [out_q] end
end

return compile
