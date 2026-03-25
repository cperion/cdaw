-- impl/authored/project.t
-- Authored.Project:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.project.resolve", "partial")


function D.Authored.Project:resolve(ctx)
    return diag.wrap(ctx, "authored.project.resolve", "partial", function()
        local transport = self.transport:resolve(ctx)
        local tempo_map = self.tempo_map:resolve(ctx)

        local tracks = diag.map(ctx, "authored.project.resolve.tracks",
            self.tracks, function(t) return t:resolve(ctx) end)
        local scenes = diag.map(ctx, "authored.project.resolve.scenes",
            self.scenes, function(s) return s:resolve(ctx) end)

        local assets = self.assets:resolve(ctx)

        -- In a full implementation, we would also flatten all graphs, nodes,
        -- params, mod_slots, mod_routes, and curves into the all_* tables.
        -- For now, return empty flat tables — later phases handle the emptiness.
        return D.Resolved.Project(
            transport,
            tempo_map,
            tracks,
            scenes,
            L(),           -- all_graphs
            L(),           -- all_graph_ports
            L(),           -- all_nodes
            L(),           -- all_child_graph_refs
            L(),           -- all_wires
            L(),           -- all_params
            L(),           -- all_mod_slots
            L(),           -- all_mod_routes
            L(),           -- all_curves
            assets
        )
    end, function()
        return F.resolved_project()
    end)
end

return true
