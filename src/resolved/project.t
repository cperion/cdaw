-- impl2/resolved/project.t
-- Resolved.GraphSlice:classify, Resolved.TrackSlice:classify, Resolved.Project:classify

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local C = types.Classified
    local node_state_sizes = { [10] = 1, [11] = 4, [12] = 2, [156] = 1, [157] = 2 }
    local mod_state_sizes = { [156] = 1, [157] = 2 }

    local function to_list(tbl) local l = L(); for i = 1, #tbl do l:insert(tbl[i]) end; return l end

    local function make_state()
        return { literals = {}, literal_map = {}, next_block_slot = 0, next_signal = 0, next_state_slot = 0 }
    end

    local function alloc_literal(st, value)
        local existing = st.literal_map[value]
        if existing ~= nil then return existing end
        local slot = #st.literals
        st.literals[slot + 1] = C.Literal(value)
        st.literal_map[value] = slot
        return slot
    end

    local function alloc_block_slot(st)
        local s = st.next_block_slot; st.next_block_slot = s + 1; return s
    end

    local function alloc_signal(st, count)
        local base = st.next_signal; st.next_signal = st.next_signal + (count or 1); return base
    end

    local function alloc_state_slot(st, size)
        local base = st.next_state_slot; st.next_state_slot = st.next_state_slot + (size or 1); return base
    end

    local function build_param_binding_by_id(params)
        local by_id = {}; for i = 1, #params do by_id[params[i].id] = params[i].base_value end; return by_id
    end

    local function build_param_binding_by_index(params)
        local by_index = {}; for i = 1, #params do by_index[i - 1] = params[i].base_value end; return by_index
    end

    local function build_curve_map(curves)
        local by_id = {}; for i = 1, #curves do by_id[curves[i].id] = curves[i] end; return by_id
    end

    local function classify_param_internal(param, st)
        local rate_class, slot = 0, 0
        if param.source.source_kind == 0 then
            slot = alloc_literal(st, param.source.value)
        elseif param.source.source_kind == 1 then
            rate_class = 2; slot = alloc_block_slot(st)
        end
        return C.Param(param.id, param.node_id, param.default_value, param.min_value, param.max_value,
            C.Binding(rate_class, slot), param.combine_code, param.smoothing_code, param.smoothing_ms, 0, 0, 0)
    end

    local function classify_graph_internal(graph, st)
        local first_wire, wire_count = 0, #graph.wire_ids
        if wire_count > 0 then first_wire = graph.wire_ids[1] end
        local signal_count = graph.input_count + graph.output_count
        local first_signal = signal_count > 0 and alloc_signal(st, signal_count) or 0
        return C.Graph(graph.id, graph.layout_code, graph.domain_code,
            graph.first_input, graph.input_count, graph.first_output, graph.output_count,
            graph.node_ids, first_wire, wire_count, 0, 0, first_signal, signal_count)
    end

    local function classify_node_internal(node, st)
        local io_count = node.input_count + node.output_count
        local signal_offset = io_count > 0 and alloc_signal(st, io_count) or 0
        local state_size = node_state_sizes[node.node_kind_code] or 0
        local state_offset = state_size > 0 and alloc_state_slot(st, state_size) or 0
        return C.Node(node.id, node.node_kind_code, node.first_param, node.param_count,
            signal_offset, state_offset, state_size,
            node.first_mod_slot, node.mod_slot_count, node.first_child_graph_ref, node.child_graph_ref_count,
            node.enabled, state_offset, node.arg0, node.arg1, node.arg2, node.arg3)
    end

    local function classify_mod_slot_internal(ms, st)
        local output_slot = alloc_state_slot(st, 1)
        local state_size = mod_state_sizes[ms.modulator_kind_code] or 0
        local runtime_state_slot = state_size > 0 and alloc_state_slot(st, state_size) or 0
        return C.ModSlot(ms.slot_index, ms.parent_node_id, ms.modulator_node_id, ms.modulator_kind_code,
            ms.first_param, ms.param_count, ms.arg0, ms.arg1, ms.arg2, ms.arg3,
            ms.per_voice, ms.first_route, ms.route_count, state_size, runtime_state_slot,
            C.Binding(3, output_slot))
    end

    local function classify_mod_route_internal(mr, st)
        return C.ModRoute(mr.mod_slot_index, mr.target_param_id,
            C.Binding(0, alloc_literal(st, mr.depth)), mr.bipolar, mr.scale_mod_slot)
    end

    local function patch_param_modulations(params, mod_routes)
        local route_counts, route_first = {}, {}
        for i = 1, #mod_routes do
            local r = mod_routes[i]
            if route_counts[r.target_param_id] == nil then
                route_counts[r.target_param_id] = 0; route_first[r.target_param_id] = i - 1
            end
            route_counts[r.target_param_id] = route_counts[r.target_param_id] + 1
        end
        local patched = L()
        for i = 1, #params do
            local p = params[i]
            patched:insert(C.Param(p.id, p.node_id, p.default_value, p.min_value, p.max_value,
                p.base_value, p.combine_code, p.smoothing_code, p.smoothing_ms,
                route_first[p.id] or 0, route_counts[p.id] or 0, p.runtime_state_slot))
        end
        return patched
    end

    local function build_block_tables(resolved_params, classified_params, curve_by_id, st)
        local block_ops, block_pts = L(), L()
        for i = 1, #resolved_params do
            local rp = resolved_params[i]
            local cp = classified_params[i]
            if rp.source and rp.source.source_kind == 1 and rp.source.curve_id ~= nil and cp and cp.base_value.rate_class == 2 then
                local curve = curve_by_id[rp.source.curve_id]
                if curve and #curve.points > 0 then
                    local first_pt = #block_pts
                    for j = 1, #curve.points do
                        block_pts:insert(C.BlockPt(curve.points[j].tick, curve.points[j].value))
                    end
                    local default_slot = alloc_literal(st, rp.source.value or rp.default_value or 0.0)
                    block_ops:insert(C.BlockOp(1, first_pt, #curve.points, curve.interp_code or 0,
                        cp.base_value.slot, C.Binding(0, default_slot), nil))
                end
            end
        end
        return block_ops, block_pts
    end

    local function classify_slot(slot)
        return C.Slot(slot.slot_index, slot.slot_kind, slot.clip_id,
            slot.launch_mode_code, slot.quant_code, slot.legato, slot.retrigger,
            slot.follow_kind_code, slot.follow_weight_a, slot.follow_weight_b,
            slot.follow_target_scene_id, slot.enabled)
    end

    local function classify_clip(clip, param_binding_by_id)
        return C.Clip(clip.id, clip.content_kind, clip.asset_id,
            clip.start_tick, clip.start_tick + clip.duration_tick, clip.source_offset_tick,
            clip.lane, clip.muted,
            param_binding_by_id[clip.gain_param_id] or C.Binding(0, 0),
            clip.fade_in_tick, clip.fade_in_curve_code, clip.fade_out_tick, clip.fade_out_curve_code)
    end

    local function classify_send(send, param_binding_by_id)
        return C.Send(send.id, send.target_track_id,
            param_binding_by_id[send.level_param_id] or C.Binding(0, 0),
            send.pre_fader, send.enabled)
    end

    local function classify_graph_slice(self)
        local st = make_state()
        local params = L()
        for i = 1, #self.params do params[i] = classify_param_internal(self.params[i], st) end
        local curve_by_id = build_curve_map(self.curves)
        local graphs = L()
        for i = 1, #self.graphs do graphs[i] = classify_graph_internal(self.graphs[i], st) end
        local nodes = L()
        for i = 1, #self.nodes do nodes[i] = classify_node_internal(self.nodes[i], st) end
        local mod_slots = L()
        for i = 1, #self.mod_slots do mod_slots[i] = classify_mod_slot_internal(self.mod_slots[i], st) end
        local mod_routes = L()
        for i = 1, #self.mod_routes do mod_routes[i] = classify_mod_route_internal(self.mod_routes[i], st) end
        params = patch_param_modulations(params, mod_routes)
        local block_ops, block_pts = build_block_tables(self.params, params, curve_by_id, st)
        local graph_ports = L()
        for i = 1, #self.graph_ports do
            local gp = self.graph_ports[i]
            graph_ports[i] = C.GraphPort(gp.id, gp.hint_code, gp.channels, gp.optional, 0)
        end
        local child_refs = L()
        for i = 1, #self.child_graph_refs do
            local cr = self.child_graph_refs[i]
            child_refs[i] = C.ChildGraphRef(cr.graph_id, cr.role_code)
        end
        local wires = L()
        for i = 1, #self.wires do
            local w = self.wires[i]
            wires[i] = C.Wire(w.from_signal, w.to_signal, 1)
        end
        return C.GraphSlice(graphs, graph_ports, nodes, child_refs, wires, L(), params,
            mod_slots, mod_routes, to_list(st.literals), L(), block_ops, block_pts, L(), L(), L(),
            st.next_signal, st.next_state_slot)
    end

    local function classify_track_slice(self)
        local st = make_state()
        local mixer_params = L()
        for i = 1, #self.mixer_params do mixer_params[i] = classify_param_internal(self.mixer_params[i], st) end
        local curve_by_id = build_curve_map(self.mixer_curves)
        mixer_params = patch_param_modulations(mixer_params, L())
        local param_binding_by_id = build_param_binding_by_id(mixer_params)
        local param_binding_by_index = build_param_binding_by_index(mixer_params)
        local block_ops, block_pts = build_block_tables(self.mixer_params, mixer_params, curve_by_id, st)
        local clips = L()
        for i = 1, #self.clips do clips[i] = classify_clip(self.clips[i], param_binding_by_id) end
        local slots = L()
        for i = 1, #self.slots do slots[i] = classify_slot(self.slots[i]) end
        local sends = L()
        for i = 1, #self.sends do sends[i] = classify_send(self.sends[i], param_binding_by_id) end
        local t = self.track
        return C.TrackSlice(
            C.Track(t.id, t.channels, t.input_kind_code, t.input_arg0, t.input_arg1,
                param_binding_by_index[t.volume_param_index] or C.Binding(0, 0),
                param_binding_by_index[t.pan_param_index] or C.Binding(0, 0),
                t.device_graph_id,
                t.output_track_id, t.group_track_id,
                t.muted, t.soloed, t.armed, t.monitor_input),
            mixer_params, clips, slots, sends,
            to_list(st.literals), L(), block_ops, block_pts, L(), L(), L(),
            self.device_graph:classify())
    end

    local function classify_project(self)
        local transport = self.transport:classify()
        local tempo_map = self.tempo_map:classify()
        local track_slices = L()
        for i = 1, #self.track_slices do track_slices[i] = self.track_slices[i]:classify() end
        local scenes = L()
        for i = 1, #self.scenes do
            local s = self.scenes[i]
            scenes[i] = C.Scene(s.id, 0, 0, s.quant_code, s.tempo_override)
        end
        return C.Project(transport, tempo_map, track_slices, scenes)
    end

    return {
        graph_slice = classify_graph_slice,
        track_slice = classify_track_slice,
        project = classify_project,
    }
end
