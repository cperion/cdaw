-- impl2/editor/device.t
-- Editor.Device:lower -> Authored.Node

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    local function with_graph_id(graph, graph_id)
        if not graph then return A.Graph(graph_id or 0, L(), L(), L(), L(), L(), A.Serial, A.AudioDomain) end
        return A.Graph(graph_id or graph.id, graph.inputs, graph.outputs, graph.nodes, graph.wires, graph.pre_cords, graph.layout, graph.domain)
    end

    local function child_graph(role, graph, graph_id)
        return A.ChildGraph(role, with_graph_id(graph, graph_id))
    end

    local function lane_graph_id(container_id, local_id, kind_base)
        return container_id * 10000 + kind_base + local_id
    end

    local function lower_native_body(body)
        local params = L()
        for i = 1, #body.params do params[i] = body.params[i]:lower() end
        local mod_slots = L()
        for i = 1, #body.modulators do mod_slots[i] = body.modulators[i]:lower() end
        local cgs = L()
        if body.note_fx then cgs:insert(child_graph(A.NoteFXChild, body.note_fx.chain:lower(), body.id * 10000 + 1)) end
        if body.post_fx then cgs:insert(child_graph(A.PostFXChild, body.post_fx.chain:lower(), body.id * 10000 + 2)) end
        return A.Node(body.id, body.name, body.kind, params, L(), L(), mod_slots, cgs, body.enabled)
    end

    local function lower_container_common(body)
        local params = L()
        for i = 1, #body.params do params[i] = body.params[i]:lower() end
        local mod_slots = L()
        for i = 1, #body.modulators do mod_slots[i] = body.modulators[i]:lower() end
        local cgs = L()
        if body.note_fx then cgs:insert(child_graph(A.NoteFXChild, body.note_fx.chain:lower(), body.id * 10000 + 1)) end
        if body.post_fx then cgs:insert(child_graph(A.PostFXChild, body.post_fx.chain:lower(), body.id * 10000 + 2)) end
        return params, mod_slots, cgs
    end

    local function lower_layer_container(body)
        local params, mod_slots, cgs = lower_container_common(body)
        local branch_nodes, layer_configs = L(), L()
        for i = 1, #body.layers do
            local layer = body.layers[i]
            local chain_graph = with_graph_id(layer.chain:lower(), lane_graph_id(body.id, layer.id, 100))
            branch_nodes:insert(A.Node(layer.id, layer.name, A.SubGraph, L(), L(), L(), L(), L{A.ChildGraph(A.MainChild, chain_graph)}, not layer.muted))
            layer_configs:insert(A.LayerConfig(layer.id, layer.volume:lower(), layer.pan:lower(), layer.muted))
        end
        local main_graph = A.Graph(body.id * 10000 + 3, L(), L(), branch_nodes, L(), L(), A.Parallel(layer_configs), A.AudioDomain)
        cgs:insert(A.ChildGraph(A.MainChild, main_graph))
        return A.Node(body.id, body.name, A.SubGraph, params, L(), L(), mod_slots, cgs, body.enabled)
    end

    local function lower_selector_container(body)
        local params, mod_slots, cgs = lower_container_common(body)
        local branch_nodes, branch_ids = L(), L()
        for i = 1, #body.branches do
            local branch = body.branches[i]
            local chain_graph = with_graph_id(branch.chain:lower(), lane_graph_id(body.id, branch.id, 200))
            branch_nodes:insert(A.Node(branch.id, branch.name, A.SubGraph, L(), L(), L(), L(), L{A.ChildGraph(A.MainChild, chain_graph)}, true))
            branch_ids:insert(branch.id)
        end
        local mode = A.ManualSelect
        if body.mode then
            local mk = body.mode.kind
            if mk == "RoundRobin" then mode = A.RoundRobin
            elseif mk == "FreeRobin" then mode = A.FreeRobin
            elseif mk == "FreeVoice" then mode = A.FreeVoice
            elseif mk == "Keyswitch" then mode = A.Keyswitch(body.mode.lowest_note)
            elseif mk == "CCSwitched" then mode = A.CCSwitched(body.mode.cc)
            elseif mk == "ProgramChange" then mode = A.ProgramChange
            elseif mk == "VelocitySwitch" then mode = A.VelocitySplit(L(body.mode.thresholds or {}))
            end
        end
        local main_graph = A.Graph(body.id * 10000 + 3, L(), L(), branch_nodes, L(), L(), A.Switched(A.SwitchConfig(mode, branch_ids)), A.AudioDomain)
        cgs:insert(A.ChildGraph(A.MainChild, main_graph))
        return A.Node(body.id, body.name, A.SubGraph, params, L(), L(), mod_slots, cgs, body.enabled)
    end

    local function lower_split_container(body)
        local params, mod_slots, cgs = lower_container_common(body)
        local branch_nodes, split_bands = L(), L()
        for i = 1, #body.bands do
            local band = body.bands[i]
            local chain_graph = with_graph_id(band.chain:lower(), lane_graph_id(body.id, band.id, 300))
            branch_nodes:insert(A.Node(band.id, band.name, A.SubGraph, L(), L(), L(), L(), L{A.ChildGraph(A.MainChild, chain_graph)}, true))
            split_bands:insert(A.SplitBand(band.id, band.crossover_value))
        end
        local split_kind = A.FreqSplit
        if body.kind then local sk = body.kind.kind; if sk and A[sk] then split_kind = A[sk] end end
        local main_graph = A.Graph(body.id * 10000 + 3, L(), L(), branch_nodes, L(), L(), A.Split(A.SplitConfig(split_kind, split_bands)), A.AudioDomain)
        cgs:insert(A.ChildGraph(A.MainChild, main_graph))
        return A.Node(body.id, body.name, A.SubGraph, params, L(), L(), mod_slots, cgs, body.enabled)
    end

    local function lower_grid_container(body)
        local params, mod_slots, cgs = lower_container_common(body)
        cgs:insert(child_graph(A.MainChild, body.patch:lower(), body.patch.id))
        return A.Node(body.id, body.name, A.SubGraph, params, L(), L(), mod_slots, cgs, body.enabled)
    end

    return function(self)
        local k = self.kind
        if k == "NativeDevice" then return lower_native_body(self.body)
        elseif k == "LayerDevice" then return lower_layer_container(self.body)
        elseif k == "SelectorDevice" then return lower_selector_container(self.body)
        elseif k == "SplitDevice" then return lower_split_container(self.body)
        elseif k == "GridDevice" then return lower_grid_container(self.body)
        end
        return A.Node(0, "unknown", A.GainNode, L(), L(), L(), L(), L(), false)
    end
end
