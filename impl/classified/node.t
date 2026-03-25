-- impl/classified/node.t
-- Classified.Node:schedule → Scheduled.NodeJob

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.node.schedule", "stub")


function D.Classified.Node:schedule(ctx)
    return diag.wrap(ctx, "classified.node.schedule", "stub", function()
        return D.Scheduled.NodeJob(
            self.id,
            self.node_kind_code,
            0, 0,              -- in_buf, out_buf
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
