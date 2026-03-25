-- impl/resolved/node.t
-- Resolved.Node:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.node.classify", "stub")


function D.Resolved.Node:classify(ctx)
    return diag.wrap(ctx, "resolved.node.classify", "stub", function()
        return D.Classified.Node(
            self.id,
            self.node_kind_code,
            self.first_param,
            self.param_count,
            0, 0, 0,          -- signal_offset, state_offset, state_size
            self.first_mod_slot,
            self.mod_slot_count,
            self.first_child_graph_ref,
            self.child_graph_ref_count,
            self.enabled,
            0,                 -- runtime_state_slot
            self.arg0, self.arg1, self.arg2, self.arg3
        )
    end, function()
        return F.classified_node(self.id)
    end)
end

return true
