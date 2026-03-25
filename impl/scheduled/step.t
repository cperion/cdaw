-- impl/scheduled/step.t
-- Scheduled.Step:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.step.compile", "stub")


function D.Scheduled.Step:compile(ctx)
    return diag.wrap(ctx, "scheduled.step.compile", "stub", function()
        -- Stub: a step compile emits nothing.
        -- Real implementation orchestrates clear, clip, node, mod, send,
        -- mix, and output jobs in the correct order.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
