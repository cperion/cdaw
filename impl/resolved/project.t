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

local function build_param_binding_maps(params)
    local by_id = {}
    for i = 1, #params do
        local p = params[i]
        by_id[p.id] = p.base_value
    end
    return by_id
end

local function build_curve_map(curves)
    local by_id = {}
    for i = 1, #curves do
        by_id[curves[i].id] = curves[i]
    end
    return by_id
end

local function classify_send(send, param_binding_by_id)
    return D.Classified.Send(
        send.id,
        send.target_track_id,
        param_binding_by_id[send.level_param_id] or F.classified_binding(0, 0),
        send.pre_fader,
        send.enabled
    )
end

local function classify_clip(clip, param_binding_by_id)
    return D.Classified.Clip(
        clip.id,
        clip.content_kind,
        clip.asset_id,
        clip.start_tick,
        clip.start_tick + clip.duration_tick,
        clip.source_offset_tick,
        clip.lane,
        clip.muted,
        param_binding_by_id[clip.gain_param_id] or F.classified_binding(0, 0),
        clip.fade_in_tick,
        clip.fade_in_curve_code,
        clip.fade_out_tick,
        clip.fade_out_curve_code
    )
end

local function classify_slot(slot)
    return D.Classified.Slot(
        slot.slot_index,
        slot.slot_kind,
        slot.clip_id,
        slot.launch_mode_code,
        slot.quant_code,
        slot.legato,
        slot.retrigger,
        slot.follow_kind_code,
        slot.follow_weight_a,
        slot.follow_weight_b,
        slot.follow_target_scene_id,
        slot.enabled
    )
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
        local param_binding_by_id = build_param_binding_maps(params)
        local curve_by_id = build_curve_map(self.all_curves)

        -- Classify tracks (uses param flat-table indices carried on each track)
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

        -- Patch params with route ranges so later phases can locate all
        -- modulations targeting a given parameter.
        do
            local route_counts = {}
            local route_first = {}
            for i = 1, #mod_routes do
                local r = mod_routes[i]
                if route_counts[r.target_param_id] == nil then
                    route_counts[r.target_param_id] = 0
                    route_first[r.target_param_id] = i - 1
                end
                route_counts[r.target_param_id] = route_counts[r.target_param_id] + 1
            end
            local patched = L()
            for i = 1, #params do
                local p = params[i]
                patched:insert(D.Classified.Param(
                    p.id, p.node_id,
                    p.default_value, p.min_value, p.max_value,
                    p.base_value,
                    p.combine_code,
                    p.smoothing_code, p.smoothing_ms,
                    route_first[p.id] or 0,
                    route_counts[p.id] or 0,
                    p.runtime_state_slot
                ))
            end
            params = patched
            ctx._classified_params = params
            param_binding_by_id = build_param_binding_maps(params)
        end

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

        local block_ops = L()
        local block_pts = L()
        for i = 1, #self.all_params do
            local rp = self.all_params[i]
            local cp = params[i]
            if rp.source and rp.source.source_kind == 1 and rp.source.curve_id ~= nil and cp and cp.base_value.rate_class == 2 then
                local curve = curve_by_id[rp.source.curve_id]
                if curve and #curve.points > 0 then
                    local first_pt = #block_pts
                    for j = 1, #curve.points do
                        block_pts:insert(D.Classified.BlockPt(curve.points[j].tick, curve.points[j].value))
                    end
                    local default_slot = ctx:alloc_literal(rp.source.value or rp.default_value or 0.0)
                    block_ops:insert(D.Classified.BlockOp(
                        1,
                        first_pt,
                        #curve.points,
                        curve.interp_code or 0,
                        cp.base_value.slot,
                        D.Classified.Binding(0, default_slot),
                        nil
                    ))
                end
            end
        end

        -- Build literal list
        local literals = L()
        for i = 1, #ctx._literals do
            literals:insert(ctx._literals[i])
        end

        local clips = L()
        for i = 1, #self.all_clips do
            clips:insert(classify_clip(self.all_clips[i], param_binding_by_id))
        end

        local slots = L()
        for i = 1, #self.all_slots do
            slots:insert(classify_slot(self.all_slots[i]))
        end

        local sends = L()
        for i = 1, #self.all_sends do
            sends:insert(classify_send(self.all_sends[i], param_binding_by_id))
        end

        -- Propagate diagnostics
        if caller_ctx then
            caller_ctx.diagnostics = ctx.diagnostics
        end

        return D.Classified.Project(
            transport, tempo_map,
            tracks, scenes,
            clips, slots, sends,
            graphs, graph_ports, nodes, child_refs,
            wires, L(),           -- feedback_pairs
            params, mod_slots, mod_routes,
            literals,
            L(), block_ops, block_pts,
            L(), L(), L(),        -- sample_ops, event_ops, voice_ops
            ctx._total_signals,
            ctx._total_state_slots
        )
    end, function()
        return F.classified_project()
    end)
end

return true
