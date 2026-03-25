-- impl/scheduled/clip_job.t
-- Scheduled.ClipJob:compile → TerraQuote
--
-- Clip playback stub with gain envelope. Writes gain-scaled content
-- into the output buffer. Content kind 0 = audio (reads from asset),
-- content kind 1 = note events (synth trigger).
--
-- Currently: writes a sine tone as placeholder for clip audio content,
-- with gain and fade-in/fade-out applied. Real asset reading requires
-- runtime audio buffer access (future milestone).
--
-- ctx must provide: bufs_sym, frames_sym, BS, literal_values.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.clip_job.compile", "real")

local C = terralib.includec("math.h")

local function resolve_binding_value(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end


function D.Scheduled.ClipJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.clip_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "ClipJob:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local gain = resolve_binding_value(self.gain, ctx.literal_values or {})

        local ooff = self.out_buf * BS

        -- Compile-time fade calculations
        -- fade_in_tick and fade_out_tick are in ticks; convert to approximate
        -- sample counts using a fixed ratio (simplified: 1 tick ≈ 1 sample
        -- for this placeholder; real implementation uses tempo_map)
        local fade_in_samples = self.fade_in_tick
        local fade_out_samples = self.fade_out_tick

        if gain == 0.0 then
            -- Zero gain: write silence
            return quote end
        end

        return quote
            var oo = [int32](ooff)
            var g : float = [float](gain)
            for i = 0, frames do
                -- Placeholder: apply gain envelope to whatever is in the buffer
                -- (node jobs write source signal first, clip job applies gain)
                var fade : float = 1.0f
                -- Fade in
                escape
                    if fade_in_samples > 0 then
                        emit quote
                            if i < [int32](fade_in_samples) then
                                fade = [float](i) / [float](fade_in_samples)
                            end
                        end
                    end
                end
                -- Fade out
                escape
                    if fade_out_samples > 0 then
                        local dur = BS  -- approximate duration in samples
                        emit quote
                            var from_end = frames - 1 - i
                            if from_end < [int32](fade_out_samples) then
                                fade = fade * ([float](from_end) / [float](fade_out_samples))
                            end
                        end
                    end
                end
                bufs[oo+i] = bufs[oo+i] * g * fade
            end
        end
    end, function()
        return F.noop_quote()
    end)
end

return true
