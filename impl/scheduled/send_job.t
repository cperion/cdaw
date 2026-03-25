-- impl/scheduled/send_job.t
-- Scheduled.SendJob:compile → TerraQuote
--
-- Reads source_buf, scales by level, adds to target_buf.
-- Respects enabled flag (disabled → silence).
-- ctx must provide: bufs_sym, frames_sym, BS, literal_values.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.send_job.compile", "real")


local function resolve_binding_value(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end


function D.Scheduled.SendJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.send_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "SendJob:compile requires ctx.bufs_sym")

        -- Disabled sends produce no audio
        if not self.enabled then
            return quote end
        end

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local level = resolve_binding_value(self.level, ctx.literal_values or {})

        local soff = self.source_buf * BS
        local toff = self.target_buf * BS

        return quote
            var so = [int32](soff); var to = [int32](toff)
            var lv : float = [float](level)
            for i = 0, frames do
                bufs[to+i] = bufs[to+i] + bufs[so+i] * lv
            end
        end
    end, function()
        return F.noop_quote()
    end)
end

return true
