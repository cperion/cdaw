-- impl/resolved/project.t
-- Resolved.Project:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.project.classify", "partial")


function D.Resolved.Project:classify(ctx)
    return diag.wrap(ctx, "resolved.project.classify", "partial", function()
        local transport = self.transport:classify(ctx)
        local tempo_map = self.tempo_map:classify(ctx)

        local tracks = diag.map(ctx, "resolved.project.classify.tracks",
            self.tracks, function(t) return t:classify(ctx) end)

        -- Classify scenes: pass through as-is (Classified.Scene ≈ Resolved.Scene)
        local scenes = L()
        for i = 1, #self.scenes do
            local s = self.scenes[i]
            scenes[i] = D.Classified.Scene(
                s.id,
                0, 0,          -- first_slot, slot_count (from flat table)
                s.quant_code,
                s.tempo_override
            )
        end

        -- Classify flat tables
        local graphs = diag.map(ctx, "resolved.project.classify.graphs",
            self.all_graphs, function(g) return g:classify(ctx) end)
        local nodes = diag.map(ctx, "resolved.project.classify.nodes",
            self.all_nodes, function(n) return n:classify(ctx) end)
        local params = diag.map(ctx, "resolved.project.classify.params",
            self.all_params, function(p) return p:classify(ctx) end)
        local mod_slots = diag.map(ctx, "resolved.project.classify.mod_slots",
            self.all_mod_slots, function(ms) return ms:classify(ctx) end)
        local mod_routes = diag.map(ctx, "resolved.project.classify.mod_routes",
            self.all_mod_routes, function(mr) return mr:classify(ctx) end)

        -- Graph ports: pass through with signal base
        local graph_ports = L()
        for i = 1, #self.all_graph_ports do
            local gp = self.all_graph_ports[i]
            graph_ports[i] = D.Classified.GraphPort(
                gp.id, gp.hint_code, gp.channels, gp.optional, 0
            )
        end

        -- Child graph refs: pass through
        local child_refs = L()
        for i = 1, #self.all_child_graph_refs do
            local cr = self.all_child_graph_refs[i]
            child_refs[i] = D.Classified.ChildGraphRef(cr.graph_id, cr.role_code)
        end

        -- Wires: pass through with weight
        local wires = L()
        for i = 1, #self.all_wires do
            local w = self.all_wires[i]
            wires[i] = D.Classified.Wire(w.from_signal, w.to_signal, 1)
        end

        return D.Classified.Project(
            transport,
            tempo_map,
            tracks,
            scenes,
            graphs,
            graph_ports,
            nodes,
            child_refs,
            wires,
            L(),            -- feedback_pairs
            params,
            mod_slots,
            mod_routes,
            L(),            -- literals
            L(),            -- init_ops
            L(),            -- block_ops
            L(),            -- block_pts
            L(),            -- sample_ops
            L(),            -- event_ops
            L(),            -- voice_ops
            0,             -- total_signals
            0              -- total_state_slots
        )
    end, function()
        return F.classified_project()
    end)
end

return true
