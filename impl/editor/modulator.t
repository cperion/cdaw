-- impl/editor/modulator.t
-- Editor.Modulator:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.modulator.lower", "real")


function D.Editor.Modulator:lower(ctx)
    return diag.wrap(ctx, "editor.modulator.lower", "real", function()
        -- Build the modulator node
        local params = diag.map(ctx, "editor.modulator.lower.params",
            self.params, function(p) return p:lower(ctx) end)

        local mod_node = D.Authored.Node(
            self.id,
            self.name,
            self.kind,       -- NodeKind passes through (same type)
            params,
            L(), L(),          -- inputs, outputs (filled by resolve)
            L(), L(),          -- mod_slots, child_graphs
            self.enabled
        )

        -- Build modulation routes from mappings
        local routes = L()
        for i = 1, #self.mappings do
            local m = self.mappings[i]
            routes[i] = D.Authored.ModRoute(
                m.target_param_id,
                m.depth,
                m.bipolar,
                m.scale_modulator_id,
                m.scale_param_id
            )
        end

        return D.Authored.ModSlot(mod_node, routes, self.per_voice)
    end, function()
        return F.authored_mod_slot()
    end)
end

return true
