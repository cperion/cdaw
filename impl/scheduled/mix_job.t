-- impl/scheduled/mix_job.t
-- Scheduled.MixJob:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.mix_job.compile", "stub")


function D.Scheduled.MixJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.mix_job.compile", "stub", function()
        -- Stub: mix jobs emit nothing (no mixing).
        -- Real implementation reads source_buf, scales by gain, adds to target_buf.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
