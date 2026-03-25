-- impl/scheduled/compiler/mix_job.t
-- Private scheduled mix-job quote compiler.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_binding_value = require("impl/scheduled/compiler/binding")
local L = F.L
diag.status("scheduled.mix_job.compile", "real")

local function compile_with(self, ctx)
    return diag.wrap(ctx, "scheduled.mix_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "MixJob:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local gain_q = compile_binding_value(self.gain, ctx)
        local soff = self.source_buf * BS
        local toff = self.target_buf * BS

        return quote
            var so = [int32](soff); var to = [int32](toff)
            var g : float = [gain_q]
            for i = 0, frames do
                bufs[to+i] = bufs[to+i] + bufs[so+i] * g
            end
        end
    end, function()
        return F.noop_quote()
    end)
end

return compile_with
