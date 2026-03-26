-- src/scheduled/compiler/clip_job.t
-- Compiles a Scheduled.ClipProgram into a Terra quote.
--
-- Signature: compile(program: ClipProgram, params, state_sym) -> quote

local compile_binding = require("src/scheduled/compiler/binding")
local C = terralib.includec("math.h")

local function compile(program, params, _state_sym)
    local job = program.clip
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

    if job.content_kind ~= 0 then
        return quote end
    end

    local ooff           = job.out_buf        * BS
    local fade_in_samp   = job.fade_in_tick  or 0
    local fade_out_samp  = job.fade_out_tick or 0

    return quote
        var oo = [int32](ooff)
        var g  : float = [gain_q]
        if g ~= 0.0f then
            for i = 0, frames_sym do
                var fade : float = 1.0f
                escape
                    if fade_in_samp > 0 then
                        emit quote
                            if i < [int32](fade_in_samp) then
                                fade = [float](i) / [float](fade_in_samp)
                            end
                        end
                    end
                    if fade_out_samp > 0 then
                        emit quote
                            var from_end = frames_sym - 1 - i
                            if from_end < [int32](fade_out_samp) then
                                fade = fade * ([float](from_end) / [float](fade_out_samp))
                            end
                        end
                    end
                end
                [bufs_sym][oo+i] = [bufs_sym][oo+i] + g * fade
            end
        end
    end
end

return compile
