-- impl/authored/project.t
-- Authored.Project:resolve
--
-- The resolve phase flattens the Authored tree into flat tables.
-- Individual type:resolve methods produce resolved objects; this root
-- method collects them all into the all_* flat arrays.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.project.resolve", "real")


-- ── ResolveCtx builder ──
-- Provides allocators and collectors that child :resolve() calls use
-- to register their output into the flat tables.

local function make_resolve_ctx(caller_ctx)
    local ctx = caller_ctx or {}
    ctx.diagnostics = ctx.diagnostics or {}
    ctx.ticks_per_beat = ctx.ticks_per_beat or 960
    ctx.sample_rate = ctx.sample_rate or 44100

    -- Flat table collectors
    ctx._all_graphs = {}
    ctx._all_graph_ports = {}
    ctx._all_nodes = {}
    ctx._all_child_graph_refs = {}
    ctx._all_wires = {}
    ctx._all_params = {}
    ctx._all_mod_slots = {}
    ctx._all_mod_routes = {}
    ctx._all_curves = {}

    -- Allocators that assign flat-table indices
    local function push(tbl, item)
        local idx = #tbl
        tbl[idx + 1] = item
        return idx
    end

    -- Graph port allocator: returns base index for a batch of ports
    ctx.alloc_graph_port_base = function(self, count)
        return #ctx._all_graph_ports
    end

    -- Intern a resolved graph into the flat table
    ctx.intern_graph = function(self, graph)
        push(ctx._all_graphs, graph)
    end

    -- Intern graph ports
    ctx.intern_graph_port = function(self, port)
        push(ctx._all_graph_ports, port)
    end

    -- Intern a resolved node
    ctx.intern_node = function(self, node)
        push(ctx._all_nodes, node)
    end

    -- Intern a child graph ref
    ctx.intern_child_graph_ref = function(self, ref)
        return push(ctx._all_child_graph_refs, ref)
    end

    -- Intern a wire
    ctx.intern_wire = function(self, wire)
        push(ctx._all_wires, wire)
    end

    -- Intern a param and return its flat index
    ctx.intern_param = function(self, param)
        return push(ctx._all_params, param)
    end

    -- Intern a mod slot
    ctx.intern_mod_slot = function(self, slot)
        return push(ctx._all_mod_slots, slot)
    end

    -- Mod slot index allocator
    local next_mod_slot_idx = 0
    ctx.alloc_mod_slot_index = function(self)
        local idx = next_mod_slot_idx
        next_mod_slot_idx = next_mod_slot_idx + 1
        return idx
    end

    -- Intern a mod route
    ctx.intern_mod_route = function(self, route)
        push(ctx._all_mod_routes, route)
    end

    -- Curve allocator + intern
    local next_curve_id = 0
    ctx.alloc_curve_id = function(self)
        local id = next_curve_id
        next_curve_id = next_curve_id + 1
        return id
    end
    ctx.intern_curve = function(self, curve)
        push(ctx._all_curves, curve)
    end

    return ctx
end

-- ── Recursive graph flattening ──
-- Walk an authored graph and its children, resolving and interning
-- everything into the flat tables on ctx.

local function flatten_graph(authored_graph, ctx)
    -- Resolve ports
    local port_base = #ctx._all_graph_ports
    for i = 1, #authored_graph.inputs do
        local p = authored_graph.inputs[i]
        ctx:intern_graph_port(D.Resolved.GraphPort(
            p.id, p.name,
            ({AudioHint=0,ControlHint=1,GateHint=2,PitchHint=3,PhaseHint=4,TriggerHint=5})[p.hint and p.hint.kind] or 0,
            p.channels, p.optional
        ))
    end
    for i = 1, #authored_graph.outputs do
        local p = authored_graph.outputs[i]
        ctx:intern_graph_port(D.Resolved.GraphPort(
            p.id, p.name,
            ({AudioHint=0,ControlHint=1,GateHint=2,PitchHint=3,PhaseHint=4,TriggerHint=5})[p.hint and p.hint.kind] or 0,
            p.channels, p.optional
        ))
    end

    -- Resolve nodes and collect ids
    local node_ids = L()
    for i = 1, #authored_graph.nodes do
        local anode = authored_graph.nodes[i]
        local resolved_node = flatten_node(anode, ctx)
        ctx:intern_node(resolved_node)
        node_ids:insert(resolved_node.id)
    end

    -- Resolve wires
    local wire_ids = L()
    for i = 1, #authored_graph.wires do
        local w = authored_graph.wires[i]
        local wire_idx = #ctx._all_wires
        ctx:intern_wire(D.Resolved.Wire(w.from_node_id, w.to_node_id))
        wire_ids:insert(wire_idx)
    end

    -- PreCords
    local precord_base = 0  -- simplified: precords aren't yet in flat table

    -- Layout → code
    local layout_codes = {Serial=0,Free=1,Parallel=2,Switched=3,Split=4}
    local domain_codes = {NoteDomain=0,AudioDomain=1,HybridDomain=2,ControlDomain=3}
    local layout_code = layout_codes[authored_graph.layout.kind or authored_graph.layout] or 0
    local domain_code = domain_codes[authored_graph.domain.kind or authored_graph.domain] or 1

    local resolved_graph = D.Resolved.Graph(
        authored_graph.id,
        layout_code, domain_code,
        port_base, #authored_graph.inputs,
        port_base + #authored_graph.inputs, #authored_graph.outputs,
        node_ids, wire_ids,
        precord_base, #authored_graph.pre_cords,
        0, 0, 0, 0
    )
    ctx:intern_graph(resolved_graph)
    return resolved_graph
end

-- Forward declaration used above
function flatten_node(authored_node, ctx)
    -- Resolve kind
    local kind_ref = authored_node.kind:resolve(ctx)
    local kind_code = kind_ref.kind_code

    -- Resolve and intern params
    local param_base = #ctx._all_params
    local param_count = #authored_node.params
    for i = 1, param_count do
        local rp = authored_node.params[i]:resolve(ctx)
        -- Set the node_id on the resolved param
        rp = D.Resolved.Param(
            rp.id, authored_node.id, rp.name,
            rp.default_value, rp.min_value, rp.max_value,
            rp.source, rp.combine_code, rp.smoothing_code, rp.smoothing_ms
        )
        ctx:intern_param(rp)
    end

    -- Resolve mod slots
    local mod_slot_base = #ctx._all_mod_slots
    local mod_slot_count = #authored_node.mod_slots
    for i = 1, mod_slot_count do
        local ms = authored_node.mod_slots[i]
        local resolved_ms = ms:resolve(ctx)
        -- Fix parent_node_id
        resolved_ms = D.Resolved.ModSlot(
            resolved_ms.slot_index, authored_node.id,
            resolved_ms.modulator_node_id, resolved_ms.per_voice,
            #ctx._all_mod_routes, #ms.routings
        )
        ctx:intern_mod_slot(resolved_ms)
        -- Intern routes
        for j = 1, #ms.routings do
            local r = ms.routings[j]
            ctx:intern_mod_route(D.Resolved.ModRoute(
                resolved_ms.slot_index, r.target_param_id,
                r.depth, r.bipolar, r.scale_mod_slot, r.scale_param_id
            ))
        end
    end

    -- Resolve child graphs (recursive)
    local cgr_base = #ctx._all_child_graph_refs
    local cgr_count = #authored_node.child_graphs
    local role_codes = {MainChild=0,PreFXChild=1,PostFXChild=2,NoteFXChild=3}
    for i = 1, cgr_count do
        local cg = authored_node.child_graphs[i]
        local child_resolved = flatten_graph(cg.graph, ctx)
        ctx:intern_child_graph_ref(D.Resolved.ChildGraphRef(
            child_resolved.id,
            role_codes[cg.role and cg.role.kind] or 0
        ))
    end

    return D.Resolved.Node(
        authored_node.id,
        kind_code,
        param_base, param_count,
        0, 0,  -- inputs/outputs (port-level, set if needed)
        0, 0,
        mod_slot_base, mod_slot_count,
        cgr_base, cgr_count,
        authored_node.enabled,
        nil,   -- plugin_handle
        0, 0, 0, 0
    )
end


function D.Authored.Project:resolve(caller_ctx)
    return diag.wrap(caller_ctx, "authored.project.resolve", "real", function()
        local ctx = make_resolve_ctx(caller_ctx)

        -- Use sample_rate from transport for tempo calculations
        ctx.sample_rate = self.transport.sample_rate or ctx.sample_rate

        local transport = self.transport:resolve(ctx)
        local tempo_map = self.tempo_map:resolve(ctx)

        -- Resolve tracks (which recursively flatten their device graphs)
        local tracks = L()
        for i = 1, #self.tracks do
            local atrack = self.tracks[i]

            -- Flatten the track's device graph
            local device_graph = flatten_graph(atrack.device_graph, ctx)

            -- Resolve track-level params (volume, pan)
            -- Record flat-table indices for classify-time lookup
            local vol = atrack.volume:resolve(ctx)
            local vol_flat_idx = #ctx._all_params
            ctx:intern_param(D.Resolved.Param(
                vol.id, 0, vol.name,
                vol.default_value, vol.min_value, vol.max_value,
                vol.source, vol.combine_code, vol.smoothing_code, vol.smoothing_ms
            ))
            local pan = atrack.pan:resolve(ctx)
            local pan_flat_idx = #ctx._all_params
            ctx:intern_param(D.Resolved.Param(
                pan.id, 0, pan.name,
                pan.default_value, pan.min_value, pan.max_value,
                pan.source, pan.combine_code, pan.smoothing_code, pan.smoothing_ms
            ))

            -- Store flat indices keyed by track id for classify
            ctx._track_vol_idx = ctx._track_vol_idx or {}
            ctx._track_pan_idx = ctx._track_pan_idx or {}
            ctx._track_vol_idx[atrack.id] = vol_flat_idx
            ctx._track_pan_idx[atrack.id] = pan_flat_idx

            -- Resolve clips
            local clip_base = 0
            local clips_resolved = diag.map(ctx, "authored.project.resolve.clips",
                atrack.clips, function(c) return c:resolve(ctx) end)

            -- Resolve slots
            local slots_resolved = diag.map(ctx, "authored.project.resolve.slots",
                atrack.launcher_slots, function(s) return s:resolve(ctx) end)

            -- Resolve sends
            local sends_resolved = diag.map(ctx, "authored.project.resolve.sends",
                atrack.sends, function(s) return s:resolve(ctx) end)
            local send_ids = L()
            for j = 1, #sends_resolved do send_ids:insert(sends_resolved[j].id) end

            -- Encode input
            local ik, ia0, ia1 = 0, 0, 0
            if atrack.input then
                local inp = atrack.input
                if inp.kind == "AudioInput" then ik, ia0, ia1 = 1, inp.device_id, inp.channel
                elseif inp.kind == "MIDIInput" then ik, ia0, ia1 = 2, inp.device_id, inp.channel
                elseif inp.kind == "TrackInputTap" then ik, ia0, ia1 = 3, inp.track_id, inp.post_fader and 1 or 0
                end
            end

            tracks:insert(D.Resolved.Track(
                atrack.id, atrack.name, atrack.channels,
                ik, ia0, ia1,
                vol.id, pan.id,
                device_graph.id,
                clip_base, #clips_resolved,
                0, #slots_resolved,
                send_ids,
                atrack.output_track_id, atrack.group_track_id,
                atrack.muted, atrack.soloed,
                atrack.armed, atrack.monitor_input,
                atrack.phase_invert
            ))
        end

        local scenes = diag.map(ctx, "authored.project.resolve.scenes",
            self.scenes, function(s) return s:resolve(ctx) end)

        local assets = self.assets:resolve(ctx)

        -- Convert collected tables to Lists
        local function to_list(tbl)
            local l = L()
            for i = 1, #tbl do l:insert(tbl[i]) end
            return l
        end

        -- Propagate diagnostics
        if caller_ctx then
            caller_ctx.diagnostics = ctx.diagnostics
        end

        local result = D.Resolved.Project(
            transport,
            tempo_map,
            tracks,
            scenes,
            to_list(ctx._all_graphs),
            to_list(ctx._all_graph_ports),
            to_list(ctx._all_nodes),
            to_list(ctx._all_child_graph_refs),
            to_list(ctx._all_wires),
            to_list(ctx._all_params),
            to_list(ctx._all_mod_slots),
            to_list(ctx._all_mod_routes),
            to_list(ctx._all_curves),
            assets
        )
        -- Attach track param flat-indices for classify phase
        result._track_vol_idx = ctx._track_vol_idx or {}
        result._track_pan_idx = ctx._track_pan_idx or {}
        return result
    end, function()
        return F.resolved_project()
    end)
end

return true
