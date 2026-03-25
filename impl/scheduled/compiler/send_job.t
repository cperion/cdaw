-- impl/scheduled/compiler/send_job.t
-- Private scheduled send-job quote compiler.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_binding_value = require("impl/scheduled/compiler/binding")
local L = F.L
diag.status("scheduled.send_job.compile", "real")

local function compile_with(self, ctx)
    return diag.wrap(ctx, "scheduled.send_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "SendJob:compile requires ctx.bufs_sym")
        if not self.enabled then return quote end end

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local level_q = compile_binding_value(self.level, ctx)
        local soff = self.source_buf * BS
        local toff = self.target_buf * BS

        return quote
            var so = [int32](soff); var to = [int32](toff)
            var lv : float = [level_q]
            for i = 0, frames do
                bufs[to+i] = bufs[to+i] + bufs[so+i] * lv
            end
        end
    end, function()
        return F.noop_quote()
    end)
end

return compile_with
