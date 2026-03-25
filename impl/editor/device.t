-- impl/editor/device.t
-- Editor.Device:lower (parent method for all device variants)

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.device.lower", "real")
diag.variant_family("editor.device.lower", "Editor", "Device")
diag.variant_status("editor.device.lower", "NativeDevice", "real")
diag.variant_status("editor.device.lower", "LayerDevice", "real")
diag.variant_status("editor.device.lower", "SelectorDevice", "real")
diag.variant_status("editor.device.lower", "SplitDevice", "real")
diag.variant_status("editor.device.lower", "GridDevice", "real")

local function with_graph_id(graph, graph_id)
    if not graph then return F.authored_graph(graph_id or 0) end
    return D.Authored.Graph(
        graph_id or graph.id,
        graph.inputs,
        graph.outputs,
        graph.nodes,
        graph.wires,
        graph.pre_cords,
        graph.layout,
        graph.domain
    )
end

local function child_graph(role, graph, graph_id)
    return D.Authored.ChildGraph(role, with_graph_id(graph, graph_id))
end

local function lane_graph_id(container_id, local_id, kind_base)
    return container_id * 10000 + kind_base + local_id
end

local function lower_native_body(body)
    local params = diag.map(nil, "editor.device.lower.params",
        body.params, function(p) return p:lower() end)

    local mod_slots = diag.map(nil, "editor.device.lower.modulators",
        body.modulators, function(m) return m:lower() end)

    local child_graphs = L()
    if body.note_fx then
        child_graphs:insert(child_graph(D.Authored.NoteFXChild, body.note_fx.chain:lower(), body.id * 10000 + 1))
    end
    if body.post_fx then
        child_graphs:insert(child_graph(D.Authored.PostFXChild, body.post_fx.chain:lower(), body.id * 10000 + 2))
    end

    return D.Authored.Node(
        body.id,
        body.name,
        body.kind,
        params,
        L(), L(),
        mod_slots,
        child_graphs,
        body.enabled
    )
end

local function lower_container_common(body)
    local params = diag.map(nil, "editor.device.lower.container.params",
        body.params, function(p) return p:lower() end)
    local mod_slots = diag.map(nil, "editor.device.lower.container.modulators",
        body.modulators, function(m) return m:lower() end)
    local child_graphs = L()

    if body.note_fx then
        child_graphs:insert(child_graph(D.Authored.NoteFXChild, body.note_fx.chain:lower(), body.id * 10000 + 1))
    end
    if body.post_fx then
        child_graphs:insert(child_graph(D.Authored.PostFXChild, body.post_fx.chain:lower(), body.id * 10000 + 2))
    end

    return params, mod_slots, child_graphs
end

local function lower_layer_container(body)
    local params, mod_slots, child_graphs = lower_container_common(body)

    local branch_nodes = L()
    local layer_configs = L()
    for i = 1, #body.layers do
        local layer = body.layers[i]
        local chain_graph = with_graph_id(layer.chain:lower(), lane_graph_id(body.id, layer.id, 100))
        local branch_node = D.Authored.Node(
            layer.id,
            layer.name,
            D.Authored.SubGraph(),
            L(),
            L(), L(),
            L(),
            L{D.Authored.ChildGraph(D.Authored.MainChild, chain_graph)},
            not layer.muted
        )
        branch_nodes:insert(branch_node)
        layer_configs:insert(D.Authored.LayerConfig(
            layer.id,
            layer.volume:lower(),
            layer.pan:lower(),
            layer.muted
        ))
    end

    local main_graph = D.Authored.Graph(
        body.id * 10000 + 3,
        L(), L(),
        branch_nodes,
        L(), L(),
        D.Authored.Parallel(layer_configs),
        D.Authored.AudioDomain
    )
    child_graphs:insert(D.Authored.ChildGraph(D.Authored.MainChild, main_graph))

    return D.Authored.Node(
        body.id,
        body.name,
        D.Authored.SubGraph(),
        params,
        L(), L(),
        mod_slots,
        child_graphs,
        body.enabled
    )
end

local function lower_selector_container(body)
    local params, mod_slots, child_graphs = lower_container_common(body)

    local branch_nodes = L()
    local branch_ids = L()
    for i = 1, #body.branches do
        local branch = body.branches[i]
        local chain_graph = with_graph_id(branch.chain:lower(), lane_graph_id(body.id, branch.id, 200))
        local branch_node = D.Authored.Node(
            branch.id,
            branch.name,
            D.Authored.SubGraph(),
            L(), L(), L(),
            L(),
            L{D.Authored.ChildGraph(D.Authored.MainChild, chain_graph)},
            true
        )
        branch_nodes:insert(branch_node)
        branch_ids:insert(branch.id)
    end

    local mode = D.Authored.ManualSelect
    if body.mode then
        local mk = body.mode.kind
        if mk == "RoundRobin" then mode = D.Authored.RoundRobin
        elseif mk == "FreeRobin" then mode = D.Authored.FreeRobin
        elseif mk == "FreeVoice" then mode = D.Authored.FreeVoice
        elseif mk == "Keyswitch" then mode = D.Authored.Keyswitch(body.mode.lowest_note)
        elseif mk == "CCSwitched" then mode = D.Authored.CCSwitched(body.mode.cc)
        elseif mk == "ProgramChange" then mode = D.Authored.ProgramChange
        elseif mk == "VelocitySwitch" then mode = D.Authored.VelocitySplit(L(body.mode.thresholds or {}))
        end
    end

    local main_graph = D.Authored.Graph(
        body.id * 10000 + 3,
        L(), L(),
        branch_nodes,
        L(), L(),
        D.Authored.Switched(D.Authored.SwitchConfig(mode, branch_ids)),
        D.Authored.AudioDomain
    )
    child_graphs:insert(D.Authored.ChildGraph(D.Authored.MainChild, main_graph))

    return D.Authored.Node(
        body.id, body.name, D.Authored.SubGraph(),
        params, L(), L(), mod_slots, child_graphs, body.enabled
    )
end

local function lower_split_container(body)
    local params, mod_slots, child_graphs = lower_container_common(body)

    local branch_nodes = L()
    local split_bands = L()
    for i = 1, #body.bands do
        local band = body.bands[i]
        local chain_graph = with_graph_id(band.chain:lower(), lane_graph_id(body.id, band.id, 300))
        local branch_node = D.Authored.Node(
            band.id, band.name, D.Authored.SubGraph(),
            L(), L(), L(),
            L(),
            L{D.Authored.ChildGraph(D.Authored.MainChild, chain_graph)},
            true
        )
        branch_nodes:insert(branch_node)
        split_bands:insert(D.Authored.SplitBand(band.id, band.crossover_value))
    end

    local split_kind = D.Authored.FreqSplit
    if body.kind then
        local sk = body.kind.kind
        if sk and D.Authored[sk] then split_kind = D.Authored[sk] end
    end

    local main_graph = D.Authored.Graph(
        body.id * 10000 + 3,
        L(), L(),
        branch_nodes,
        L(), L(),
        D.Authored.Split(D.Authored.SplitConfig(split_kind, split_bands)),
        D.Authored.AudioDomain
    )
    child_graphs:insert(D.Authored.ChildGraph(D.Authored.MainChild, main_graph))

    return D.Authored.Node(
        body.id, body.name, D.Authored.SubGraph(),
        params, L(), L(), mod_slots, child_graphs, body.enabled
    )
end

local function lower_grid_container(body)
    local params, mod_slots, child_graphs = lower_container_common(body)
    child_graphs:insert(child_graph(D.Authored.MainChild, body.patch:lower(), body.patch.id))
    return D.Authored.Node(
        body.id, body.name, D.Authored.SubGraph(),
        params, L(), L(), mod_slots, child_graphs, body.enabled
    )
end

local lower_device = terralib.memoize(function(self)
    local k = self.kind
    if k == "NativeDevice" then
        return lower_native_body(self.body)
    elseif k == "LayerDevice" then
        return lower_layer_container(self.body)
    elseif k == "SelectorDevice" then
        return lower_selector_container(self.body)
    elseif k == "SplitDevice" then
        return lower_split_container(self.body)
    elseif k == "GridDevice" then
        return lower_grid_container(self.body)
    end
    return F.authored_node(0, "unknown_device")
end)

function D.Editor.Device:lower()
    return diag.wrap(nil, "editor.device.lower", "real", function()
        return lower_device(self)
    end, function()
        return F.authored_node(0, "device_fallback")
    end)
end

return true
