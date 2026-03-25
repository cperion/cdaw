-- impl/scheduled/graph_plan.t
-- Scheduled.GraphPlan:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.graph_plan.compile", "stub")


function D.Scheduled.GraphPlan:compile(ctx)
    return diag.wrap(ctx, "scheduled.graph_plan.compile", "stub", function()
        -- Stub: graph plan compile emits nothing.
        -- Real implementation iterates node jobs in topological order
        -- and splices their compiled quotes.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
