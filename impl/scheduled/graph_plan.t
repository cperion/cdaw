-- impl/scheduled/graph_plan.t
-- Scheduled.GraphPlan:compile → TerraQuote
--
-- Compiles a graph plan by iterating its node jobs in topological order
-- and splicing their compiled quotes. For serial chains, this is just
-- sequential execution of node jobs.
-- ctx must provide: bufs_sym, frames_sym, BS, node_jobs list.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.graph_plan.compile", "real")


function D.Scheduled.GraphPlan:compile(ctx)
    return diag.wrap(ctx, "scheduled.graph_plan.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "GraphPlan:compile requires ctx.bufs_sym")
        assert(ctx and ctx.node_jobs, "GraphPlan:compile requires ctx.node_jobs")

        local quotes = terralib.newlist()

        for j = 0, self.node_job_count - 1 do
            local nj = ctx.node_jobs[self.first_node_job + j + 1]
            if nj then
                quotes:insert(nj:compile(ctx))
            end
        end

        return quote [quotes] end
    end, function()
        return F.noop_quote()
    end)
end

return true
