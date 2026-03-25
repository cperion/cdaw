-- impl/editor/device.t
-- Editor.Device:lower (parent method for all device variants)
--
-- This sets the fallback on the Device sum type parent.
-- ASDL's __newindex propagation ensures all variants (NativeDevice,
-- LayerDevice, SelectorDevice, SplitDevice, GridDevice) inherit this.
-- Real implementations override specific variants later.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.device.lower", "partial")


-- ── Helper: lower a NativeDeviceBody's fields into an Authored.Node ──

local function lower_native_body(body, ctx)
    local params = diag.map(ctx, "editor.device.lower.params",
        body.params, function(p) return p:lower(ctx) end)

    local mod_slots = diag.map(ctx, "editor.device.lower.modulators",
        body.modulators, function(m) return m:lower(ctx) end)

    local child_graphs = L()

    -- NoteFX lane → child graph with NoteFXChild role
    if body.note_fx then
        local nfx_graph = body.note_fx.chain:lower(ctx)
        child_graphs:insert(D.Authored.ChildGraph(D.Authored.NoteFXChild, nfx_graph))
    end

    -- PostFX lane → child graph with PostFXChild role
    if body.post_fx then
        local pfx_graph = body.post_fx.chain:lower(ctx)
        child_graphs:insert(D.Authored.ChildGraph(D.Authored.PostFXChild, pfx_graph))
    end

    return D.Authored.Node(
        body.id,
        body.name,
        body.kind,       -- NodeKind passes through
        params,
        L(), L(),        -- inputs, outputs (filled by resolve)
        mod_slots,
        child_graphs,
        body.enabled
    )
end

-- ── Helper: lower a container body's common fields ──

local function lower_container_common(body, ctx)
    local params = diag.map(ctx, "editor.device.lower.container.params",
        body.params, function(p) return p:lower(ctx) end)
    local mod_slots = diag.map(ctx, "editor.device.lower.container.modulators",
        body.modulators, function(m) return m:lower(ctx) end)
    local child_graphs = L()

    if body.note_fx then
        local nfx_graph = body.note_fx.chain:lower(ctx)
        child_graphs:insert(D.Authored.ChildGraph(D.Authored.NoteFXChild, nfx_graph))
    end
    if body.post_fx then
        local pfx_graph = body.post_fx.chain:lower(ctx)
        child_graphs:insert(D.Authored.ChildGraph(D.Authored.PostFXChild, pfx_graph))
    end

    return params, mod_slots, child_graphs
end

-- ── Helper: lower a LayerContainer ──

local function lower_layer_container(body, ctx)
    local params, mod_slots, child_graphs = lower_container_common(body, ctx)

    local branch_nodes = L()
    local layer_configs = L()
    for i = 1, #body.layers do
        local layer = body.layers[i]

        -- Each layer becomes a branch-entry node containing the chain
        local chain_graph = layer.chain:lower(ctx)
        local branch_node = D.Authored.Node(
            layer.id,
            layer.name,
            D.Authored.SubGraph(),
            L(),               -- params on the branch node itself
            L(), L(),          -- inputs, outputs
            L(),               -- mod_slots
            L{D.Authored.ChildGraph(D.Authored.MainChild, chain_graph)},
            not layer.muted
        )
        branch_nodes:insert(branch_node)

        -- Authored.LayerConfig references the branch-entry node
        local vol = layer.volume:lower(ctx)
        local pan = layer.pan:lower(ctx)
        layer_configs:insert(D.Authored.LayerConfig(layer.id, vol, pan, layer.muted))
    end

    local main_graph_id = ctx and ctx.alloc_graph_id
        and ctx:alloc_graph_id() or 0
    local main_graph = D.Authored.Graph(
        main_graph_id,
        L(), L(),              -- inputs, outputs
        branch_nodes,
        L(), L(),              -- wires, pre_cords
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

-- ── Helper: lower a SelectorContainer ──

local function lower_selector_container(body, ctx)
    local params, mod_slots, child_graphs = lower_container_common(body, ctx)

    local branch_nodes = L()
    local branch_ids = L()
    for i = 1, #body.branches do
        local branch = body.branches[i]
        local chain_graph = branch.chain:lower(ctx)
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

    -- Map Editor.SelectorMode → Authored.SelectorMode
    local mode = D.Authored.ManualSelect
    if body.mode then
        local mk = body.mode.kind
        if mk == "RoundRobin" then mode = D.Authored.RoundRobin
        elseif mk == "FreeRobin" then mode = D.Authored.FreeRobin
        elseif mk == "FreeVoice" then mode = D.Authored.FreeVoice
        elseif mk == "Keyswitch" then mode = D.Authored.Keyswitch(body.mode.lowest_note)
        elseif mk == "CCSwitched" then mode = D.Authored.CCSwitched(body.mode.cc)
        elseif mk == "ProgramChange" then mode = D.Authored.ProgramChange
        elseif mk == "VelocitySwitch" then
            mode = D.Authored.VelocitySplit(L(body.mode.thresholds or {}))
        else
            mode = D.Authored.ManualSelect
        end
    end

    local switch_config = D.Authored.SwitchConfig(mode, branch_ids)

    local main_graph_id = ctx and ctx.alloc_graph_id
        and ctx:alloc_graph_id() or 0
    local main_graph = D.Authored.Graph(
        main_graph_id, L(), L(),
        branch_nodes, L(), L(),
        D.Authored.Switched(switch_config),
        D.Authored.AudioDomain
    )

    child_graphs:insert(D.Authored.ChildGraph(D.Authored.MainChild, main_graph))

    return D.Authored.Node(
        body.id, body.name, D.Authored.SubGraph(),
        params, L(), L(), mod_slots, child_graphs, body.enabled
    )
end

-- ── Helper: lower a SplitContainer ──

local function lower_split_container(body, ctx)
    local params, mod_slots, child_graphs = lower_container_common(body, ctx)

    local branch_nodes = L()
    local split_bands = L()
    for i = 1, #body.bands do
        local band = body.bands[i]
        local chain_graph = band.chain:lower(ctx)
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

    -- Map Editor.SplitKind → Authored.SplitKind
    local split_kind = D.Authored.FreqSplit
    if body.kind then
        local sk = body.kind.kind
        if sk and D.Authored[sk] then split_kind = D.Authored[sk] end
    end

    local split_config = D.Authored.SplitConfig(split_kind, split_bands)

    local main_graph_id = ctx and ctx.alloc_graph_id
        and ctx:alloc_graph_id() or 0
    local main_graph = D.Authored.Graph(
        main_graph_id, L(), L(),
        branch_nodes, L(), L(),
        D.Authored.Split(split_config),
        D.Authored.AudioDomain
    )

    child_graphs:insert(D.Authored.ChildGraph(D.Authored.MainChild, main_graph))

    return D.Authored.Node(
        body.id, body.name, D.Authored.SubGraph(),
        params, L(), L(), mod_slots, child_graphs, body.enabled
    )
end

-- ── Helper: lower a GridContainer ──

local function lower_grid_container(body, ctx)
    local params, mod_slots, child_graphs = lower_container_common(body, ctx)

    local main_graph = body.patch:lower(ctx)
    child_graphs:insert(D.Authored.ChildGraph(D.Authored.MainChild, main_graph))

    return D.Authored.Node(
        body.id, body.name, D.Authored.SubGraph(),
        params, L(), L(), mod_slots, child_graphs, body.enabled
    )
end

-- ═══════════════════════════════════════════════════════════
-- Parent method on Device sum type.
-- __newindex propagation copies this to all variants.
-- ═══════════════════════════════════════════════════════════

function D.Editor.Device:lower(ctx)
    return diag.wrap(ctx, "editor.device.lower", "partial", function()
        local k = self.kind

        if k == "NativeDevice" then
            return lower_native_body(self.body, ctx)
        elseif k == "LayerDevice" then
            return lower_layer_container(self.body, ctx)
        elseif k == "SelectorDevice" then
            return lower_selector_container(self.body, ctx)
        elseif k == "SplitDevice" then
            return lower_split_container(self.body, ctx)
        elseif k == "GridDevice" then
            return lower_grid_container(self.body, ctx)
        end

        diag.record(ctx, "warning", "editor.device.lower.unknown_kind",
            "unknown device kind: " .. tostring(k))
        return F.authored_node(0, "unknown_device")
    end, function()
        return F.authored_node(0, "device_fallback")
    end)
end

return true
