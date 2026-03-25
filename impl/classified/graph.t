-- impl/classified/graph.t
-- Classified.Graph:schedule → Scheduled.GraphPlan
--
-- Creates a GraphPlan with node job range and buffer assignment.
-- The ctx provides the current node job base and buffer indices.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.graph.schedule", "real")


function D.Classified.Graph:schedule(ctx)
    return diag.wrap(ctx, "classified.graph.schedule", "real", function()
        -- Node job range: assigned by ctx from project.schedule
        local first_node_job = (ctx and ctx._graph_first_job and ctx._graph_first_job[self.id]) or 0
        local node_job_count = (ctx and ctx._graph_job_count and ctx._graph_job_count[self.id]) or 0

        -- Buffer assignment: graphs get in/out buffer from ctx
        local in_buf = (ctx and ctx._graph_in_buf and ctx._graph_in_buf[self.id]) or 0
        local out_buf = (ctx and ctx._graph_out_buf and ctx._graph_out_buf[self.id]) or 0

        -- Feedback pairs (not yet wired, but count propagated)
        local first_feedback = 0
        local feedback_count = self.first_feedback  -- reuse field if available
        if feedback_count == nil or feedback_count < 0 then feedback_count = 0 end
        -- Actually use the classified graph's feedback_count field
        feedback_count = self.feedback_count or 0

        return D.Scheduled.GraphPlan(
            self.id,
            first_node_job, node_job_count,
            in_buf, out_buf,
            first_feedback, feedback_count
        )
    end, function()
        return F.scheduled_graph_plan(self.id)
    end)
end

return true
