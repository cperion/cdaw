-- impl/authored/mod_slot.t
-- Authored.ModSlot:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.mod_slot.resolve", "real")


function D.Authored.ModSlot:resolve(ctx)
    return diag.wrap(ctx, "authored.mod_slot.resolve", "real", function()
        -- Resolve the modulator node
        local mod_node = self.modulator:resolve(ctx)

        -- Resolve routes
        local routes = L()
        for i = 1, #self.routings do
            local r = self.routings[i]
            routes[i] = D.Resolved.ModRoute(
                0,                 -- mod_slot_index (set by parent flattening)
                r.target_param_id,
                r.depth,
                r.bipolar,
                r.scale_mod_slot,
                r.scale_param_id
            )
        end

        -- Build resolved mod slot
        local slot_index = ctx and ctx.alloc_mod_slot_index
            and ctx:alloc_mod_slot_index() or 0

        -- parent_node_id comes from ctx (set by flatten_node in project.resolve)
        -- or defaults to 0 for standalone use
        local parent_node_id = (ctx and ctx._current_parent_node_id) or 0

        return D.Resolved.ModSlot(
            slot_index,
            parent_node_id,
            mod_node.id,
            self.per_voice,
            0,                    -- first_route (set by flattening pass)
            #routes               -- route_count
        )
    end, function()
        return F.resolved_mod_slot()
    end)
end

return true
