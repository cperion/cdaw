-- impl/resolved/mod_slot.t
-- Resolved.ModSlot:classify, Resolved.ModRoute:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.mod_route.classify", "stub")
diag.status("resolved.mod_slot.classify", "stub")


function D.Resolved.ModSlot:classify(ctx)
    return diag.wrap(ctx, "resolved.mod_slot.classify", "stub", function()
        return D.Classified.ModSlot(
            self.slot_index,
            self.parent_node_id,
            self.modulator_node_id,
            self.per_voice,
            self.first_route,
            self.route_count,
            F.classified_binding(0, 0)   -- output_binding (stub)
        )
    end, function()
        return F.classified_mod_slot()
    end)
end

function D.Resolved.ModRoute:classify(ctx)
    return diag.wrap(ctx, "resolved.mod_route.classify", "stub", function()
        return D.Classified.ModRoute(
            self.mod_slot_index,
            self.target_param_id,
            F.classified_binding(0, 0),  -- depth binding (stub)
            self.bipolar,
            nil                          -- scale_binding_slot
        )
    end, function()
        return F.classified_mod_route()
    end)
end

return true
