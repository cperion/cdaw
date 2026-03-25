-- impl/scheduled/output_job.t
-- Scheduled.OutputJob:compile → TerraQuote
--
-- Reads source_buf, applies gain and pan, writes to out_left/out_right.
-- Pan law: equal-power (cos/sin of pan angle).
-- ctx must provide: bufs_sym, frames_sym, BS, literal_values.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.output_job.compile", "real")

local C = terralib.includec("math.h")

local function resolve_binding_value(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end


function D.Scheduled.OutputJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.output_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "OutputJob:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local lits = ctx.literal_values or {}

        local gain = resolve_binding_value(self.gain, lits)
        local pan = resolve_binding_value(self.pan, lits)

        -- Equal-power pan: pan in [-1, 1], angle = (pan + 1) * pi/4
        -- left_gain = cos(angle), right_gain = sin(angle)
        local angle = (pan + 1.0) * math.pi / 4.0
        local lg = gain * math.cos(angle)
        local rg = gain * math.sin(angle)

        local soff = self.source_buf * BS
        local loff = self.out_left * BS
        local roff = self.out_right * BS

        return quote
            var so = [int32](soff)
            var lo = [int32](loff); var ro = [int32](roff)
            for i = 0, frames do
                var s = bufs[so+i]
                bufs[lo+i] = bufs[lo+i] + s * [float](lg)
                bufs[ro+i] = bufs[ro+i] + s * [float](rg)
            end
        end
    end, function()
        return F.noop_quote()
    end)
end

return true
