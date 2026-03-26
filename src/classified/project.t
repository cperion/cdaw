-- impl2/classified/project.t
-- Classified.GraphSlice:schedule, Classified.TrackSlice:schedule, Classified.Project:schedule

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local S = types.Scheduled
    local function to_list(tbl) local l = L(); for i = 1, #tbl do l:insert(tbl[i]) end; return l end

    local function make_state(literals_owner)
        local st = { next_buf = 0, buffers = {}, literals = {}, literal_map = {} }
        local literals = literals_owner and literals_owner.literals or nil
        if literals then
            for i = 1, #literals do
                st.literals[i] = literals[i]
                st.literal_map[literals[i].value] = i - 1
            end
        end
        return st
    end

    local function alloc_buffer(st, channels, persistent)
        local idx = st.next_buf; st.next_buf = idx + 1
        st.buffers[idx + 1] = S.Buffer(idx, channels or 1, false, persistent or false)
        return idx
    end

    local function ensure_literal(st, value)
        local existing = st.literal_map[value]
        if existing ~= nil then return existing end
        local slot = #st.literals
        -- Use Classified.Literal via the parent's literal type
        st.literals[slot + 1] = { value = value }
        st.literal_map[value] = slot
        return slot
    end

    local function schedule_literal_list(literals)
        local out = L()
        for i = 1, #literals do out[i] = S.Literal(literals[i].value) end
        return out
    end

    local function schedule_param_list(params)
        local out = L()
        for i = 1, #params do
            local p = params[i]
            out[i] = S.Param(p.id, p.node_id, p.default_value, p.min_value, p.max_value,
                p.base_value:schedule(), p.combine_code, p.smoothing_code, p.smoothing_ms,
                p.first_modulation, p.modulation_count, p.runtime_state_slot)
        end
        return out
    end

    local function schedule_param_bindings(params)
        local out = L()
        for i = 1, #params do out[i] = params[i].base_value:schedule() end
        return out
    end

    local function schedule_local_binding(binding, literal_slot_map)
        if not binding then return nil end
        local scheduled = binding:schedule()
        if scheduled.rate_class ~= 0 then return scheduled end
        local local_slot = literal_slot_map[scheduled.slot]
        assert(local_slot ~= nil, "missing local literal slot for binding slot " .. tostring(scheduled.slot))
        return S.Binding(0, local_slot)
    end

    local function collect_binding_literals(binding, graph_literals, slot_seen, literal_pairs)
        if not binding or binding.rate_class ~= 0 then return end
        local slot = binding.slot
        if slot_seen[slot] then return end
        local lit = graph_literals[slot + 1]
        assert(lit ~= nil, "missing classified literal for slot " .. tostring(slot))
        slot_seen[slot] = true
        literal_pairs[#literal_pairs + 1] = slot
        literal_pairs[#literal_pairs + 1] = lit
    end

    local function collect_node_schedule_inputs(node, params, mod_slots, mod_routes, graph_literals)
        local node_params, node_mod_slots, node_mod_routes = {}, {}, {}
        local literal_pairs, slot_seen = {}, {}
        for i = 0, (node.param_count or 0) - 1 do
            local p = params[node.first_param + i + 1]
            if p then
                node_params[#node_params + 1] = p
                collect_binding_literals(p.base_value, graph_literals, slot_seen, literal_pairs)
            end
        end
        for i = 0, (node.mod_slot_count or 0) - 1 do
            local ms = mod_slots[node.first_mod_slot + i + 1]
            if ms then
                node_mod_slots[#node_mod_slots + 1] = ms
                for ri = 0, (ms.route_count or 0) - 1 do
                    local mr = mod_routes[ms.first_route + ri + 1]
                    if mr then
                        node_mod_routes[#node_mod_routes + 1] = mr
                        collect_binding_literals(mr.depth, graph_literals, slot_seen, literal_pairs)
                    end
                end
            end
        end
        return node_params, node_mod_slots, node_mod_routes, literal_pairs
    end

    local function collect_mod_schedule_inputs(mod_slot, params, graph_literals)
        local mod_params, literal_pairs, slot_seen = {}, {}, {}
        for i = 0, (mod_slot.param_count or 0) - 1 do
            local p = params[mod_slot.first_param + i + 1]
            if p then
                mod_params[#mod_params + 1] = p
                collect_binding_literals(p.base_value, graph_literals, slot_seen, literal_pairs)
            end
        end
        return mod_params, literal_pairs
    end

    local function collect_literal_pairs_from_bindings(literals, ...)
        local slot_seen, literal_pairs = {}, {}
        local bindings = {...}
        for i = 1, #bindings do
            collect_binding_literals(bindings[i], literals, slot_seen, literal_pairs)
        end
        return literal_pairs
    end

    -- Primitive-keyed memoized builders for leaf programs
    local build_node_program_impl = terralib.memoize(function(
            node_id, node_kind_code, in_buf, out_buf, node_runtime_state_slot, node_state_size,
            node_arg0, node_arg1, node_arg2, node_arg3,
            transport, tempo_map,
            param_count, mod_slot_count, route_count, literal_pair_count, ...)
        local args = {...}
        local idx = 1
        local literal_slot_map, local_literals = {}, L()
        for i = 1, literal_pair_count do
            local old_slot = args[idx]; idx = idx + 1
            local lit_value = args[idx]; idx = idx + 1
            literal_slot_map[old_slot] = i - 1
            local_literals[i] = S.Literal(lit_value)
        end
        local function binding_from_parts(rate_class, slot)
            if rate_class ~= 0 then return S.Binding(rate_class, slot) end
            local local_slot = literal_slot_map[slot]
            assert(local_slot ~= nil, "missing local literal slot for binding slot " .. tostring(slot))
            return S.Binding(0, local_slot)
        end
        local route_first_by_slot, route_count_by_slot = {}, {}
        local route_first_by_param, route_count_by_param = {}, {}
        local route_specs = {}
        for i = 1, route_count do
            local spec = {
                mod_slot_index = args[idx], target_param_id = args[idx+1],
                depth_rate_class = args[idx+2], depth_slot = args[idx+3],
                bipolar = args[idx+4], scale_binding_slot = args[idx+5],
            }; idx = idx + 6
            route_specs[i] = spec
            if route_first_by_slot[spec.mod_slot_index] == nil then route_first_by_slot[spec.mod_slot_index] = i - 1 end
            route_count_by_slot[spec.mod_slot_index] = (route_count_by_slot[spec.mod_slot_index] or 0) + 1
            if route_first_by_param[spec.target_param_id] == nil then route_first_by_param[spec.target_param_id] = i - 1 end
            route_count_by_param[spec.target_param_id] = (route_count_by_param[spec.target_param_id] or 0) + 1
        end
        local mod_slot_specs = {}
        for i = 1, mod_slot_count do
            mod_slot_specs[i] = {
                slot_index = args[idx], parent_node_id = args[idx+1],
                modulator_node_id = args[idx+2], modulator_kind_code = args[idx+3],
                arg0 = args[idx+4], arg1 = args[idx+5], arg2 = args[idx+6], arg3 = args[idx+7],
                per_voice = args[idx+8], state_size = args[idx+9], runtime_state_slot = args[idx+10],
                output_rate_class = args[idx+11], output_slot = args[idx+12],
            }; idx = idx + 13
        end
        local param_specs = {}
        for i = 1, param_count do
            param_specs[i] = {
                id = args[idx], node_id = args[idx+1],
                default_value = args[idx+2], min_value = args[idx+3], max_value = args[idx+4],
                base_rate_class = args[idx+5], base_slot = args[idx+6],
                combine_code = args[idx+7], smoothing_code = args[idx+8], smoothing_ms = args[idx+9],
                runtime_state_slot = args[idx+10],
            }; idx = idx + 11
        end
        local local_mod_routes = L()
        for i = 1, route_count do
            local spec = route_specs[i]
            local_mod_routes[i] = S.ModRoute(spec.mod_slot_index, spec.target_param_id,
                binding_from_parts(spec.depth_rate_class, spec.depth_slot), spec.bipolar, spec.scale_binding_slot)
        end
        local local_mod_slots = L()
        for i = 1, mod_slot_count do
            local spec = mod_slot_specs[i]
            local_mod_slots[i] = S.ModSlot(spec.slot_index, spec.parent_node_id, spec.modulator_node_id, spec.modulator_kind_code,
                0, 0, spec.arg0, spec.arg1, spec.arg2, spec.arg3, spec.per_voice,
                route_first_by_slot[spec.slot_index] or 0, route_count_by_slot[spec.slot_index] or 0,
                spec.state_size, spec.runtime_state_slot, S.Binding(spec.output_rate_class, spec.output_slot))
        end
        local local_params, local_param_bindings = L(), L()
        for i = 1, param_count do
            local spec = param_specs[i]
            local base_value = binding_from_parts(spec.base_rate_class, spec.base_slot)
            local_params[i] = S.Param(spec.id, spec.node_id, spec.default_value, spec.min_value, spec.max_value,
                base_value, spec.combine_code, spec.smoothing_code, spec.smoothing_ms,
                route_first_by_param[spec.id] or 0, route_count_by_param[spec.id] or 0, spec.runtime_state_slot)
            local_param_bindings[i] = base_value
        end
        return S.NodeProgram(
            S.NodeJob(node_id, node_kind_code, in_buf, out_buf, 0, param_count, node_runtime_state_slot, node_state_size,
                node_arg0, node_arg1, node_arg2, node_arg3),
            local_param_bindings, local_params, local_mod_slots, local_mod_routes, local_literals,
            transport, tempo_map)
    end)

    local function build_node_program(node, in_buf, out_buf, transport, tempo_map, params, mod_slots, mod_routes, literal_pairs)
        local args = {
            node.id, node.node_kind_code, in_buf, out_buf, node.runtime_state_slot, node.state_size,
            node.arg0, node.arg1, node.arg2, node.arg3,
            transport, tempo_map,
            #params, #mod_slots, #mod_routes, #literal_pairs / 2,
        }
        for i = 1, #literal_pairs, 2 do
            args[#args+1] = literal_pairs[i]; args[#args+1] = literal_pairs[i+1].value
        end
        for i = 1, #mod_routes do
            local mr = mod_routes[i]
            args[#args+1] = mr.mod_slot_index; args[#args+1] = mr.target_param_id
            args[#args+1] = mr.depth.rate_class; args[#args+1] = mr.depth.slot
            args[#args+1] = mr.bipolar; args[#args+1] = mr.scale_binding_slot
        end
        for i = 1, #mod_slots do
            local ms = mod_slots[i]
            args[#args+1] = ms.slot_index; args[#args+1] = ms.parent_node_id
            args[#args+1] = ms.modulator_node_id; args[#args+1] = ms.modulator_kind_code
            args[#args+1] = ms.arg0; args[#args+1] = ms.arg1; args[#args+1] = ms.arg2; args[#args+1] = ms.arg3
            args[#args+1] = ms.per_voice; args[#args+1] = ms.state_size; args[#args+1] = ms.runtime_state_slot
            args[#args+1] = ms.output_binding.rate_class; args[#args+1] = ms.output_binding.slot
        end
        for i = 1, #params do
            local p = params[i]
            args[#args+1] = p.id; args[#args+1] = p.node_id
            args[#args+1] = p.default_value; args[#args+1] = p.min_value; args[#args+1] = p.max_value
            args[#args+1] = p.base_value.rate_class; args[#args+1] = p.base_value.slot
            args[#args+1] = p.combine_code; args[#args+1] = p.smoothing_code; args[#args+1] = p.smoothing_ms
            args[#args+1] = p.runtime_state_slot
        end
        return build_node_program_impl(unpack(args))
    end

    local build_mod_program_impl = terralib.memoize(function(mod_slot, transport, tempo_map, param_count, literal_pair_count, ...)
        local args = {...}; local idx = 1
        local params = {}
        for i = 1, param_count do params[i] = args[idx]; idx = idx + 1 end
        local literal_slot_map, local_literals = {}, L()
        for i = 1, literal_pair_count do
            local old_slot = args[idx]; idx = idx + 1; local lit = args[idx]; idx = idx + 1
            literal_slot_map[old_slot] = i - 1; local_literals[i] = S.Literal(lit.value)
        end
        local local_param_bindings = L()
        for i = 1, param_count do local_param_bindings[i] = schedule_local_binding(params[i].base_value, literal_slot_map) end
        return S.ModProgram(
            S.ModJob(mod_slot.modulator_node_id, mod_slot.parent_node_id, mod_slot.modulator_kind_code,
                0, param_count, mod_slot.arg0, mod_slot.arg1, mod_slot.arg2, mod_slot.arg3,
                mod_slot.per_voice, 0, mod_slot.route_count,
                mod_slot.runtime_state_slot, mod_slot.state_size,
                mod_slot.output_binding.slot, mod_slot.output_binding:schedule()),
            local_param_bindings, local_literals, transport, tempo_map)
    end)

    local function build_mod_program(mod_slot, transport, tempo_map, params, literal_pairs)
        local args = { mod_slot, transport, tempo_map, #params, #literal_pairs / 2 }
        for i = 1, #params do args[#args+1] = params[i] end
        for i = 1, #literal_pairs do args[#args+1] = literal_pairs[i] end
        return build_mod_program_impl(unpack(args))
    end

    local build_clip_program_impl = terralib.memoize(function(
            clip_id, content_kind, asset_id, out_buf, start_tick, end_tick, source_offset_tick,
            gain_rate_class, gain_slot, reversed, fade_in_tick, fade_in_curve_code, fade_out_tick, fade_out_curve_code,
            transport, tempo_map, literal_pair_count, ...)
        local args = {...}; local idx = 1
        local literal_slot_map, local_literals = {}, L()
        for i = 1, literal_pair_count do
            local old_slot = args[idx]; idx = idx + 1; local lit_value = args[idx]; idx = idx + 1
            literal_slot_map[old_slot] = i - 1; local_literals[i] = S.Literal(lit_value)
        end
        local local_gain_slot = gain_rate_class == 0 and literal_slot_map[gain_slot] or gain_slot
        assert(gain_rate_class ~= 0 or local_gain_slot ~= nil, "missing local clip gain literal slot")
        return S.ClipProgram(
            S.ClipJob(clip_id, content_kind, asset_id, out_buf, start_tick, end_tick, source_offset_tick,
                S.Binding(gain_rate_class, local_gain_slot), reversed,
                fade_in_tick, fade_in_curve_code, fade_out_tick, fade_out_curve_code),
            local_literals, transport, tempo_map)
    end)

    local function build_clip_program(clip, out_buf, transport, tempo_map, literal_pairs)
        local gain = clip.gain:schedule()
        local args = { clip.id, clip.content_kind, clip.asset_id, out_buf, clip.start_tick, clip.end_tick, clip.source_offset_tick,
            gain.rate_class, gain.slot, false, clip.fade_in_tick, clip.fade_in_curve_code, clip.fade_out_tick, clip.fade_out_curve_code,
            transport, tempo_map, #literal_pairs / 2 }
        for i = 1, #literal_pairs, 2 do args[#args+1] = literal_pairs[i]; args[#args+1] = literal_pairs[i+1].value end
        return build_clip_program_impl(unpack(args))
    end

    local build_send_program_impl = terralib.memoize(function(
            source_buf, target_buf, level_rate_class, level_slot, pre_fader, enabled,
            transport, tempo_map, literal_pair_count, ...)
        local args = {...}; local idx = 1
        local literal_slot_map, local_literals = {}, L()
        for i = 1, literal_pair_count do
            local old_slot = args[idx]; idx = idx + 1; local lit_value = args[idx]; idx = idx + 1
            literal_slot_map[old_slot] = i - 1; local_literals[i] = S.Literal(lit_value)
        end
        local local_level_slot = level_rate_class == 0 and literal_slot_map[level_slot] or level_slot
        assert(level_rate_class ~= 0 or local_level_slot ~= nil, "missing local send level literal slot")
        return S.SendProgram(
            S.SendJob(source_buf, target_buf, S.Binding(level_rate_class, local_level_slot), pre_fader, enabled),
            local_literals, transport, tempo_map)
    end)

    local function build_send_program(send, source_buf, target_buf, transport, tempo_map, literal_pairs)
        local level = send.level:schedule()
        local args = { source_buf, target_buf, level.rate_class, level.slot, send.pre_fader, send.enabled,
            transport, tempo_map, #literal_pairs / 2 }
        for i = 1, #literal_pairs, 2 do args[#args+1] = literal_pairs[i]; args[#args+1] = literal_pairs[i+1].value end
        return build_send_program_impl(unpack(args))
    end

    local build_mix_program_impl = terralib.memoize(function(
            source_buf, target_buf, gain_rate_class, gain_slot,
            transport, tempo_map, literal_pair_count, ...)
        local args = {...}; local idx = 1
        local literal_slot_map, local_literals = {}, L()
        for i = 1, literal_pair_count do
            local old_slot = args[idx]; idx = idx + 1; local lit_value = args[idx]; idx = idx + 1
            literal_slot_map[old_slot] = i - 1; local_literals[i] = S.Literal(lit_value)
        end
        local local_gain_slot = gain_rate_class == 0 and literal_slot_map[gain_slot] or gain_slot
        assert(gain_rate_class ~= 0 or local_gain_slot ~= nil, "missing local mix gain literal slot")
        return S.MixProgram(
            S.MixJob(source_buf, target_buf, S.Binding(gain_rate_class, local_gain_slot)),
            local_literals, transport, tempo_map)
    end)

    local function build_mix_program(source_buf, target_buf, gain_binding, transport, tempo_map, literal_pairs)
        local args = { source_buf, target_buf, gain_binding.rate_class, gain_binding.slot,
            transport, tempo_map, #literal_pairs / 2 }
        for i = 1, #literal_pairs, 2 do args[#args+1] = literal_pairs[i]; args[#args+1] = literal_pairs[i+1].value end
        return build_mix_program_impl(unpack(args))
    end

    local build_output_program_impl = terralib.memoize(function(
            source_buf, out_left, out_right, gain_rate_class, gain_slot, pan_rate_class, pan_slot,
            transport, tempo_map, literal_pair_count, ...)
        local args = {...}; local idx = 1
        local literal_slot_map, local_literals = {}, L()
        for i = 1, literal_pair_count do
            local old_slot = args[idx]; idx = idx + 1; local lit_value = args[idx]; idx = idx + 1
            literal_slot_map[old_slot] = i - 1; local_literals[i] = S.Literal(lit_value)
        end
        local local_gain_slot = gain_rate_class == 0 and literal_slot_map[gain_slot] or gain_slot
        local local_pan_slot = pan_rate_class == 0 and literal_slot_map[pan_slot] or pan_slot
        assert(gain_rate_class ~= 0 or local_gain_slot ~= nil, "missing local output gain literal slot")
        assert(pan_rate_class ~= 0 or local_pan_slot ~= nil, "missing local output pan literal slot")
        return S.OutputProgram(
            S.OutputJob(source_buf, out_left, out_right,
                S.Binding(gain_rate_class, local_gain_slot), S.Binding(pan_rate_class, local_pan_slot)),
            local_literals, transport, tempo_map)
    end)

    local function build_output_program(source_buf, out_left, out_right, gain_binding, pan_binding, transport, tempo_map, literal_pairs)
        local args = { source_buf, out_left, out_right, gain_binding.rate_class, gain_binding.slot,
            pan_binding.rate_class, pan_binding.slot, transport, tempo_map, #literal_pairs / 2 }
        for i = 1, #literal_pairs, 2 do args[#args+1] = literal_pairs[i]; args[#args+1] = literal_pairs[i+1].value end
        return build_output_program_impl(unpack(args))
    end

    local function schedule_init_ops(ops)
        local out = L(); for i = 1, #ops do local op = ops[i]
            out[i] = S.InitOp(op.kind, op.arg0, op.arg1, op.i0:schedule(), op.i1 and op.i1:schedule() or nil, op.state_slot)
        end; return out
    end
    local function schedule_block_ops(ops)
        local out = L(); for i = 1, #ops do local op = ops[i]
            out[i] = S.BlockOp(op.kind, op.first_pt, op.pt_count, op.interp, op.arg0, op.i0:schedule(), op.i1 and op.i1:schedule() or nil)
        end; return out
    end
    local function schedule_block_pts(pts)
        local out = L(); for i = 1, #pts do out[i] = S.BlockPt(pts[i].tick, pts[i].value) end; return out
    end
    local function schedule_sample_ops(ops)
        local out = L(); for i = 1, #ops do local op = ops[i]
            out[i] = S.SampleOp(op.kind, op.i0:schedule(), op.i1 and op.i1:schedule() or nil, op.arg0, op.arg1, op.arg2, op.state_slot)
        end; return out
    end
    local function schedule_event_ops(ops)
        local out = L(); for i = 1, #ops do local op = ops[i]
            out[i] = S.EventOp(op.kind, op.event_code, op.min_v, op.max_v, op.state_slot)
        end; return out
    end
    local function schedule_voice_ops(ops)
        local out = L(); for i = 1, #ops do local op = ops[i]
            out[i] = S.VoiceOp(op.kind, op.i0:schedule(), op.i1 and op.i1:schedule() or nil, op.arg0, op.arg1, op.arg2, op.state_slot)
        end; return out
    end

    local function schedule_graph_slice(self, transport, tempo_map)
        local st = make_state(self)
        local scheduled_transport = transport and transport:schedule() or S.Transport(44100, 512, 120, 0, 4, 4, 0, false, 0, 0)
        local scheduled_tempo_map = tempo_map and tempo_map:schedule() or S.TempoMap(L())
        local graph = self.graphs[1]
        local in_buf = alloc_buffer(st, 1, false)
        local out_buf = alloc_buffer(st, 1, false)
        local scheduled_literals = schedule_literal_list(st.literals)

        local mod_programs = L()
        for i = 1, #self.mod_slots do
            local mod_slot = self.mod_slots[i]
            local mod_params, mod_literal_pairs = collect_mod_schedule_inputs(mod_slot, self.params, self.literals)
            mod_programs[i] = build_mod_program(mod_slot, scheduled_transport, scheduled_tempo_map, mod_params, mod_literal_pairs)
        end

        local node_programs = L()
        local prev_out = in_buf
        for i = 1, #self.nodes do
            local node = self.nodes[i]
            local node_in = prev_out
            local node_out = (i == #self.nodes) and out_buf or alloc_buffer(st, 1, false)
            local node_params, node_mod_slots, node_mod_routes, node_literal_pairs =
                collect_node_schedule_inputs(node, self.params, self.mod_slots, self.mod_routes, self.literals)
            node_programs[i] = build_node_program(node, node_in, node_out,
                scheduled_transport, scheduled_tempo_map,
                node_params, node_mod_slots, node_mod_routes, node_literal_pairs)
            prev_out = node_out
        end

        return S.GraphProgram(
            scheduled_transport, scheduled_tempo_map, to_list(st.buffers),
            S.GraphPlan(graph.id, in_buf, out_buf, graph.first_feedback or 0, graph.feedback_count or 0),
            node_programs, mod_programs, scheduled_literals,
            schedule_init_ops(self.init_ops), schedule_block_ops(self.block_ops), schedule_block_pts(self.block_pts),
            schedule_sample_ops(self.sample_ops), schedule_event_ops(self.event_ops), schedule_voice_ops(self.voice_ops),
            st.next_buf, self.total_state_slots)
    end

    local function schedule_track_slice(self, transport, tempo_map)
        local st = make_state(self)
        local scheduled_transport = transport and transport:schedule() or S.Transport(44100, 512, 120, 0, 4, 4, 0, false, 0, 0)
        local scheduled_tempo_map = tempo_map and tempo_map:schedule() or S.TempoMap(L())
        local device_graph = self.device_graph:schedule(transport, tempo_map)

        local unity_slot = ensure_literal(st, 1.0)
        local unity_binding = S.Binding(0, unity_slot)
        local work_buf = alloc_buffer(st, 1, false)
        local mix_in_buf = alloc_buffer(st, 1, false)
        local master_left = alloc_buffer(st, 1, true)
        local master_right = alloc_buffer(st, 1, true)
        local scheduled_literals = schedule_literal_list(st.literals)

        local clip_programs = L()
        for i = 1, #self.clips do
            local clip = self.clips[i]
            if not clip.muted then
                local clip_literal_pairs = collect_literal_pairs_from_bindings(self.mixer_literals, clip.gain)
                clip_programs:insert(build_clip_program(clip, work_buf, scheduled_transport, scheduled_tempo_map, clip_literal_pairs))
            end
        end

        local send_programs = L()
        for i = 1, #self.sends do
            local send = self.sends[i]
            local send_literal_pairs = collect_literal_pairs_from_bindings(self.mixer_literals, send.level)
            send_programs:insert(build_send_program(send, work_buf, mix_in_buf, scheduled_transport, scheduled_tempo_map, send_literal_pairs))
        end

        local mix_literal_pairs = collect_literal_pairs_from_bindings(st.literals, unity_binding)
        local mix_programs = L{build_mix_program(mix_in_buf, work_buf, unity_binding, scheduled_transport, scheduled_tempo_map, mix_literal_pairs)}

        local output_literal_pairs = collect_literal_pairs_from_bindings(self.mixer_literals, self.track.volume, self.track.pan)
        local output_programs = L{build_output_program(work_buf, master_left, master_right,
            self.track.volume:schedule(), self.track.pan:schedule(),
            scheduled_transport, scheduled_tempo_map, output_literal_pairs)}

        local launch_entries = L()
        for i = 1, #self.slots do
            local slot = self.slots[i]
            launch_entries[i] = S.LaunchEntry(self.track.id, slot.slot_index, slot.slot_kind, slot.clip_id,
                slot.launch_mode_code, slot.quant_code, slot.legato, slot.retrigger,
                slot.follow_kind_code, slot.follow_weight_a, slot.follow_weight_b, slot.follow_target_scene_id, slot.enabled)
        end

        return S.TrackProgram(
            scheduled_transport, scheduled_tempo_map, to_list(st.buffers),
            S.TrackPlan(self.track.id,
                self.track.volume:schedule(), self.track.pan:schedule(),
                self.track.input_kind_code, self.track.input_arg0, self.track.input_arg1,
                work_buf, -1, mix_in_buf, master_left, master_right, false),
            device_graph, clip_programs, send_programs, mix_programs, output_programs, launch_entries,
            schedule_param_list(self.mixer_params), schedule_param_bindings(self.mixer_params), scheduled_literals,
            schedule_init_ops(self.mixer_init_ops), schedule_block_ops(self.mixer_block_ops), schedule_block_pts(self.mixer_block_pts),
            schedule_sample_ops(self.mixer_sample_ops), schedule_event_ops(self.mixer_event_ops), schedule_voice_ops(self.mixer_voice_ops),
            st.next_buf, self.device_graph.total_state_slots, master_left, master_right)
    end

    local function schedule_project(self)
        local transport = self.transport:schedule()
        local tempo_map = self.tempo_map:schedule()
        local track_programs = L()
        for i = 1, #self.track_slices do
            track_programs[i] = self.track_slices[i]:schedule(self.transport, self.tempo_map)
        end
        local scene_entries = L()
        for i = 1, #self.scenes do
            local s = self.scenes[i]
            scene_entries[i] = S.SceneEntry(s.id, s.first_slot, s.slot_count, s.quant_code, s.tempo_override)
        end
        return S.Project(transport, tempo_map, track_programs, scene_entries)
    end

    return {
        graph_slice = schedule_graph_slice,
        track_slice = schedule_track_slice,
        project = schedule_project,
    }
end
