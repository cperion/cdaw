-- impl/scheduled/output_job.t
-- Scheduled.OutputJob:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.output_job.compile", "stub")


function D.Scheduled.OutputJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.output_job.compile", "stub", function()
        -- Stub: output jobs emit nothing (silence on master).
        -- Real implementation reads source_buf, applies gain/pan,
        -- writes to out_left/out_right.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
