-- impl/scheduled/mix_job.t
-- Scheduled.MixJob:compile → TerraQuote
--
-- Reads source_buf, scales by gain, adds to target_buf.
-- ctx must provide: bufs_sym, frames_sym, BS, literal_values.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.mix_job.compile", "real")


local function resolve_binding_value(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end


function D.Scheduled.MixJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.mix_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "MixJob:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local gain = resolve_binding_value(self.gain, ctx.literal_values or {})

        local soff = self.source_buf * BS
        local toff = self.target_buf * BS

        return quote
            var so = [int32](soff); var to = [int32](toff)
            var g : float = [float](gain)
            for i = 0, frames do
                bufs[to+i] = bufs[to+i] + bufs[so+i] * g
            end
        end
    end, function()
        return F.noop_quote()
    end)
end

return true
