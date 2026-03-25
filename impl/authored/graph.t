-- impl/authored/graph.t
-- Authored.Graph:resolve -> Resolved.GraphSlice

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.graph.resolve", "real")

local layout_codes = { Serial = 0, Free = 1, Parallel = 2, Switched = 3, Split = 4 }
local domain_codes = { NoteDomain = 0, AudioDomain = 1, HybridDomain = 2, ControlDomain = 3 }
local hint_codes = {
    AudioHint = 0, ControlHint = 1, GateHint = 2,
    PitchHint = 3, PhaseHint = 4, TriggerHint = 5,
}
local role_codes = { MainChild = 0, PreFXChild = 1, PostFXChild = 2, NoteFXChild = 3 }
local lfo_shape_codes = { Sine = 0, Triangle = 1, Square = 2, Saw = 3, SampleHoldLFO = 4, CustomLFO = 5 }

local function push(tbl, item)
    local idx = #tbl
    tbl[idx + 1] = item
    return idx
end

local function to_list(tbl)
    local l = L()
    for i = 1, #tbl do l:insert(tbl[i]) end
    return l
end

local function make_state()
    return {
        next_curve_id = 0,
        next_mod_slot_index = 0,
        graphs = {},
        graph_ports = {},
        nodes = {},
        child_graph_refs = {},
        wires = {},
        params = {},
        mod_slots = {},
        mod_routes = {},
        curves = {},
    }
end

local resolve_graph_internal

local interp_codes = { Linear = 0, Smoothstep = 1, Hold = 2 }

local function authored_curve_to_resolved(param, ticks_per_beat)
    if not param.source or param.source.kind ~= "AutomationRef" then return nil end
    local curve = param.source.curve
    local points = L()
    for i = 1, #curve.points do
        local pt = curve.points[i]
        points[i] = D.Resolved.AutoPoint(pt.time_beats * ticks_per_beat, pt.value)
    end
    return D.Resolved.AutoCurve(tonumber(param.id) or 0, points, interp_codes[curve.mode and curve.mode.kind] or 0)
end

local function resolve_param_internal(param, ticks_per_beat, node_id, st)
    local rp = param:resolve(ticks_per_beat)
    local curve = authored_curve_to_resolved(param, ticks_per_beat)
    local curve_id = nil
    if curve then
        curve_id = st.next_curve_id
        st.next_curve_id = curve_id + 1
        local reassigned = D.Resolved.AutoCurve(curve_id, curve.points, curve.interp_code)
        push(st.curves, reassigned)
    end
    return D.Resolved.Param(
        rp.id,
        node_id,
        rp.name,
        rp.default_value,
        rp.min_value,
        rp.max_value,
        D.Resolved.ParamSourceRef(rp.source.source_kind, rp.source.value, curve_id),
        rp.combine_code,
        rp.smoothing_code,
        rp.smoothing_ms
    )
end

local function encode_mod_args(kind)
    if not kind or not kind.kind then return 0, 0, 0, 0 end
    if kind.kind == "LFOMod" then
        local shape = kind.shape
        local shape_name = shape and shape.kind or "Sine"
        return lfo_shape_codes[shape_name] or 0, 0, 0, 0
    end
    return 0, 0, 0, 0
end

local function resolve_mod_slot_internal(ms, ticks_per_beat, parent_node_id, st)
    local slot_index = st.next_mod_slot_index
    st.next_mod_slot_index = slot_index + 1

    local first_param = #st.params
    for i = 1, #ms.modulator.params do
        push(st.params, resolve_param_internal(ms.modulator.params[i], ticks_per_beat, ms.modulator.id, st))
    end

    local first_route = #st.mod_routes
    for i = 1, #ms.routings do
        local r = ms.routings[i]
        push(st.mod_routes, D.Resolved.ModRoute(
            slot_index,
            r.target_param_id,
            r.depth,
            r.bipolar,
            r.scale_mod_slot,
            r.scale_param_id
        ))
    end

    local kind_ref = ms.modulator.kind:resolve()
    local arg0, arg1, arg2, arg3 = encode_mod_args(ms.modulator.kind)
    return D.Resolved.ModSlot(
        slot_index,
        parent_node_id,
        ms.modulator.id,
        kind_ref.kind_code,
        first_param,
        #ms.modulator.params,
        arg0, arg1, arg2, arg3,
        ms.per_voice,
        first_route,
        #ms.routings
    )
end

local function resolve_node_internal(node, ticks_per_beat, st)
    local kind_ref = node.kind:resolve()

    local first_param = #st.params
    for i = 1, #node.params do
        push(st.params, resolve_param_internal(node.params[i], ticks_per_beat, node.id, st))
    end

    local first_mod_slot = #st.mod_slots
    for i = 1, #node.mod_slots do
        push(st.mod_slots, resolve_mod_slot_internal(node.mod_slots[i], ticks_per_beat, node.id, st))
    end

    local first_child_graph_ref = #st.child_graph_refs
    for i = 1, #node.child_graphs do
        local cg = node.child_graphs[i]
        local child_root = resolve_graph_internal(cg.graph, ticks_per_beat, st)
        push(st.child_graph_refs, D.Resolved.ChildGraphRef(child_root.id, role_codes[cg.role and cg.role.kind] or 0))
    end

    return D.Resolved.Node(
        node.id,
        kind_ref.kind_code,
        first_param,
        #node.params,
        0,
        #node.inputs,
        0,
        #node.outputs,
        first_mod_slot,
        #node.mod_slots,
        first_child_graph_ref,
        #node.child_graphs,
        node.enabled,
        nil,
        node.x_pos or 0,
        node.y_pos or 0,
        0,
        0
    )
end

resolve_graph_internal = function(graph, ticks_per_beat, st)
    local port_base = #st.graph_ports
    for i = 1, #graph.inputs do
        local p = graph.inputs[i]
        push(st.graph_ports, D.Resolved.GraphPort(
            p.id, p.name,
            hint_codes[p.hint and p.hint.kind] or 0,
            p.channels,
            p.optional
        ))
    end
    for i = 1, #graph.outputs do
        local p = graph.outputs[i]
        push(st.graph_ports, D.Resolved.GraphPort(
            p.id, p.name,
            hint_codes[p.hint and p.hint.kind] or 0,
            p.channels,
            p.optional
        ))
    end

    local node_ids = L()
    for i = 1, #graph.nodes do
        local rn = resolve_node_internal(graph.nodes[i], ticks_per_beat, st)
        push(st.nodes, rn)
        node_ids:insert(rn.id)
    end

    local wire_ids = L()
    for i = 1, #graph.wires do
        local w = graph.wires[i]
        local wire_idx = push(st.wires, D.Resolved.Wire(w.from_node_id, w.to_node_id))
        wire_ids:insert(wire_idx)
    end

    local rg = D.Resolved.Graph(
        graph.id,
        layout_codes[graph.layout.kind or graph.layout] or 0,
        domain_codes[graph.domain.kind or graph.domain] or 1,
        port_base,
        #graph.inputs,
        port_base + #graph.inputs,
        #graph.outputs,
        node_ids,
        wire_ids,
        0,
        #graph.pre_cords,
        0, 0, 0, 0
    )
    push(st.graphs, rg)
    return rg
end

local resolve_graph_slice = terralib.memoize(function(self, ticks_per_beat)
    local st = make_state()
    resolve_graph_internal(self, ticks_per_beat, st)
    return D.Resolved.GraphSlice(
        to_list(st.graphs),
        to_list(st.graph_ports),
        to_list(st.nodes),
        to_list(st.child_graph_refs),
        to_list(st.wires),
        to_list(st.params),
        to_list(st.mod_slots),
        to_list(st.mod_routes),
        to_list(st.curves)
    )
end)

function D.Authored.Graph:resolve(ticks_per_beat)
    assert(type(ticks_per_beat) == "number", "Authored.Graph:resolve requires explicit number ticks_per_beat")
    return diag.wrap(nil, "authored.graph.resolve", "real", function()
        return resolve_graph_slice(self, ticks_per_beat)
    end, function()
        return F.resolved_graph_slice(self.id)
    end)
end

return true
