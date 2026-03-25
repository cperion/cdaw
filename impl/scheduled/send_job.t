-- impl/scheduled/send_job.t
-- Scheduled.SendJob:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.send_job.compile", "stub")


function D.Scheduled.SendJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.send_job.compile", "stub", function()
        -- Stub: send jobs emit nothing (no audio routed).
        -- Real implementation reads source_buf, scales by level, writes to target_buf.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
