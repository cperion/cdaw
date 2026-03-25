-- impl/classified/graph.t
-- Classified.Graph:schedule → Scheduled.GraphPlan

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.graph.schedule", "stub")


function D.Classified.Graph:schedule(ctx)
    return diag.wrap(ctx, "classified.graph.schedule", "stub", function()
        return D.Scheduled.GraphPlan(
            self.id,
            0, 0,              -- first_node_job, node_job_count
            0, 0,              -- in_buf, out_buf
            0, 0               -- first_feedback, feedback_count
        )
    end, function()
        return F.scheduled_graph_plan(self.id)
    end)
end

return true
