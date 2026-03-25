-- impl/resolved/mod_slot.t
-- Resolved.ModSlot:classify, Resolved.ModRoute:classify
--
-- ModSlot classify: allocates an output binding for the modulator's
-- signal output. ModRoute classify: interns the depth value as a literal
-- binding (or block binding for modulated depth).

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.mod_route.classify", "real")
diag.status("resolved.mod_slot.classify", "real")


function D.Resolved.ModSlot:classify(ctx)
    return diag.wrap(ctx, "resolved.mod_slot.classify", "real", function()
        -- Allocate an output binding for this modulator.
        -- The modulator node produces a control signal; its output is
        -- stored at a sample-rate slot so downstream routes can read it.
        local output_binding
        if ctx and ctx.alloc_state_slot then
            local slot = ctx:alloc_state_slot(1)
            -- rate_class 3 = sample-rate (mod output updates per sample)
            output_binding = D.Classified.Binding(3, slot)
        else
            output_binding = F.classified_binding(0, 0)
        end

        return D.Classified.ModSlot(
            self.slot_index,
            self.parent_node_id,
            self.modulator_node_id,
            self.per_voice,
            self.first_route,
            self.route_count,
            output_binding
        )
    end, function()
        return F.classified_mod_slot()
    end)
end

function D.Resolved.ModRoute:classify(ctx)
    return diag.wrap(ctx, "resolved.mod_route.classify", "real", function()
        -- Intern the depth value as a literal binding.
        -- Depth is a static float; intern it into the literal table.
        local depth_binding
        if ctx and ctx.alloc_literal then
            local slot = ctx:alloc_literal(self.depth)
            depth_binding = D.Classified.Binding(0, slot)  -- rate_class 0 = literal
        else
            depth_binding = F.classified_binding(0, 0)
        end

        -- Scale binding: if a scale_param_id is present, it could reference
        -- another parameter's binding. For now, pass through as slot reference.
        local scale_slot = nil
        if self.scale_mod_slot then
            scale_slot = self.scale_mod_slot
        end

        return D.Classified.ModRoute(
            self.mod_slot_index,
            self.target_param_id,
            depth_binding,
            self.bipolar,
            scale_slot
        )
    end, function()
        return F.classified_mod_route()
    end)
end

return true
