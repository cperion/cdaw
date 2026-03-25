-- impl/resolved/project.t
-- Resolved.Project:classify
--
-- The classify phase builds the literal table, assigns binding slots to
-- params, counts signals, and propagates flat tables with real indices.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.project.classify", "real")


-- Build a ClassifyCtx that provides literal/slot allocators
local function make_classify_ctx(caller_ctx)
    local ctx = caller_ctx or {}
    ctx.diagnostics = ctx.diagnostics or {}

    -- Literal table: interned constants (dedup by value)
    ctx._literals = {}
    ctx._literal_map = {}  -- value → slot index

    ctx.alloc_literal = function(self, value)
        -- Intern: if we've seen this exact value, reuse its slot
        local existing = ctx._literal_map[value]
        if existing then return existing end
        local slot = #ctx._literals
        ctx._literals[slot + 1] = D.Classified.Literal(value)
        ctx._literal_map[value] = slot
        return slot
    end

    -- Block-rate slot allocator (for automation curves)
    local next_block_slot = 0
    ctx.alloc_block_slot = function(self)
        local s = next_block_slot
        next_block_slot = next_block_slot + 1
        return s
    end

    -- Signal count
    ctx._total_signals = 0
    ctx.alloc_signal = function(self, count)
        local base = ctx._total_signals
        ctx._total_signals = ctx._total_signals + (count or 1)
        return base
    end

    -- State slot allocator
    ctx._total_state_slots = 0
    ctx.alloc_state_slot = function(self, size)
        local base = ctx._total_state_slots
        ctx._total_state_slots = ctx._total_state_slots + (size or 1)
        return base
    end

    return ctx
end


function D.Resolved.Project:classify(caller_ctx)
    return diag.wrap(caller_ctx, "resolved.project.classify", "real", function()
        local ctx = make_classify_ctx(caller_ctx)

        local transport = self.transport:classify(ctx)
        local tempo_map = self.tempo_map:classify(ctx)

        -- Classify params first (builds the literal table)
        local params = L()
        for i = 1, #self.all_params do
            params:insert(self.all_params[i]:classify(ctx))
        end

        -- Make classified params available by flat-table index
        ctx._classified_params = params
        -- Pass through track param indices from resolve phase
        ctx._track_vol_idx = self._track_vol_idx or {}
        ctx._track_pan_idx = self._track_pan_idx or {}

        -- Classify tracks (uses literals for volume/pan bindings)
        local tracks = diag.map(ctx, "resolved.project.classify.tracks",
            self.tracks, function(t) return t:classify(ctx) end)

        -- Classify scenes
        local scenes = L()
        for i = 1, #self.scenes do
            local s = self.scenes[i]
            scenes:insert(D.Classified.Scene(
                s.id, 0, 0, s.quant_code, s.tempo_override
            ))
        end

        -- Classify graphs
        local graphs = diag.map(ctx, "resolved.project.classify.graphs",
            self.all_graphs, function(g) return g:classify(ctx) end)

        -- Classify nodes
        local nodes = diag.map(ctx, "resolved.project.classify.nodes",
            self.all_nodes, function(n) return n:classify(ctx) end)

        -- Classify mod slots and routes
        local mod_slots = diag.map(ctx, "resolved.project.classify.mod_slots",
            self.all_mod_slots, function(ms) return ms:classify(ctx) end)
        local mod_routes = diag.map(ctx, "resolved.project.classify.mod_routes",
            self.all_mod_routes, function(mr) return mr:classify(ctx) end)

        -- Graph ports with signal base
        local graph_ports = L()
        for i = 1, #self.all_graph_ports do
            local gp = self.all_graph_ports[i]
            graph_ports:insert(D.Classified.GraphPort(
                gp.id, gp.hint_code, gp.channels, gp.optional, 0
            ))
        end

        -- Child graph refs
        local child_refs = L()
        for i = 1, #self.all_child_graph_refs do
            local cr = self.all_child_graph_refs[i]
            child_refs:insert(D.Classified.ChildGraphRef(cr.graph_id, cr.role_code))
        end

        -- Wires with weight
        local wires = L()
        for i = 1, #self.all_wires do
            local w = self.all_wires[i]
            wires:insert(D.Classified.Wire(w.from_signal, w.to_signal, 1))
        end

        -- Build literal list
        local literals = L()
        for i = 1, #ctx._literals do
            literals:insert(ctx._literals[i])
        end

        -- Propagate diagnostics
        if caller_ctx then
            caller_ctx.diagnostics = ctx.diagnostics
        end

        return D.Classified.Project(
            transport, tempo_map,
            tracks, scenes,
            graphs, graph_ports, nodes, child_refs,
            wires, L(),           -- feedback_pairs
            params, mod_slots, mod_routes,
            literals,
            L(), L(), L(),        -- init_ops, block_ops, block_pts
            L(), L(), L(),        -- sample_ops, event_ops, voice_ops
            ctx._total_signals,
            ctx._total_state_slots
        )
    end, function()
        return F.classified_project()
    end)
end

return true
