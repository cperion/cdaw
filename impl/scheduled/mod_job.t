-- impl/scheduled/mod_job.t
-- Scheduled.ModJob:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.mod_job.compile", "stub")


function D.Scheduled.ModJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.mod_job.compile", "stub", function()
        -- Stub: modulation jobs emit nothing (zero control output).
        -- Real implementation evaluates the modulator and applies routes.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
