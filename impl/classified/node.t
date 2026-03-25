-- impl/classified/node.t
-- Classified.Node:schedule → Scheduled.NodeJob
--
-- Creates a NodeJob with buffer assignment from ctx.
-- In serial chains, nodes process in-place (in_buf == out_buf).
-- The ctx maps node IDs to buffer indices.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.node.schedule", "real")


function D.Classified.Node:schedule(ctx)
    return diag.wrap(ctx, "classified.node.schedule", "real", function()
        -- Buffer assignment from ctx (set by project.schedule)
        local in_buf = (ctx and ctx._node_in_buf and ctx._node_in_buf[self.id]) or 0
        local out_buf = (ctx and ctx._node_out_buf and ctx._node_out_buf[self.id]) or 0

        return D.Scheduled.NodeJob(
            self.id,
            self.node_kind_code,
            in_buf, out_buf,
            self.first_param,
            self.param_count,
            self.runtime_state_slot,
            self.state_size,
            self.arg0, self.arg1, self.arg2, self.arg3
        )
    end, function()
        return F.scheduled_node_job(self.id)
    end)
end

return true
