-- impl/view/device_view.t
-- View.DeviceView:to_decl()
-- Focused device panel: native params, container lanes, modulators.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.device_view.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local B = require("impl/view/components/button")
local P = require("impl/view/components/placeholder_panel")
local LR = require("impl/view/components/list_row")
local PF = require("impl/view/components/panel_frame")

-- ── Helper: lower a single param view ──

local function lower_param(param, ctx, scope)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local pscope = C.make_scope(ctx, param.identity, C.identity_key(param.identity))
    local cmd = C.find_command(param.commands, V.DSCCSetParamValue)
    local name = "Param " .. tostring(param.param_ref and param.param_ref.param_id or "?")
    if ctx.param_names and param.param_ref then
        name = ctx.param_names[C.encode_semantic_ref(param.param_ref)] or name
    end
    local row = LR.action_value(ctx, pscope:child("base"), name, cmd and cmd.action_id or nil, {
        button_text = "...",
        button_width = ui.fixed(32),
    })
    return P.wrap_node(ctx, pscope, param.param_ref or param.identity, row, {
        width = ui.grow(),
        height = ui.fixed(22),
    })
end

-- ── Helper: lower a modulation route view ──

local function lower_mod_route(route, ctx)
    local ui = ctx.ui
    local rscope = C.make_scope(ctx, route.identity, C.identity_key(route.identity))
    local row = LR.value_row(ctx, rscope:child("base"), "→ param " .. tostring(route.target_param_ref and route.target_param_ref.param_id or "?"),
        T.quiet_label(ctx, string.format("%.0f%%", (route.route_index or 0) * 100), {
            key = rscope:child("depth"),
            width = ui.fit(),
            font_size = 10,
        })
    )
    return P.wrap_node(ctx, rscope, route.identity, row, {
        width = ui.grow(),
        height = ui.fixed(22),
    })
end

-- ── Helper: lower a modulator view ──

local function lower_modulator(mod, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local mscope = C.make_scope(ctx, mod.identity, C.identity_key(mod.identity))
    local children = {}
    C.push(children, T.body_label(ctx, "Modulator " .. tostring(mod.modulator_ref and mod.modulator_ref.modulator_id or "?"), {
        key = mscope:child("title"),
        width = ui.grow(),
        font_size = 11,
    }))
    for i = 1, #mod.routes do
        C.push(children, lower_mod_route(mod.routes[i], ctx))
    end
    P.overlay_children(ctx, mscope, mod.identity, children)
    return ui.column {
        key = mscope,
        width = ui.grow(),
        height = ui.fit(),
        gap = 1,
        padding = { left = 4, top = 4, right = 4, bottom = 4 },
        background = p.surface_inset,
        border = C.border(ctx, p.border_subtle, 1),
    } (children)
end

-- ── Helper: lower a device section view ──

local function lower_section(section, ctx, scope)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local sscope = C.make_scope(ctx, section.identity, C.identity_key(section.identity))
    local children = {}

    -- Params
    for i = 1, #section.params do
        C.push(children, lower_param(section.params[i], ctx, sscope))
    end

    -- Modulators
    for i = 1, #section.modulators do
        C.push(children, lower_modulator(section.modulators[i], ctx))
    end

    if #children == 0 then
        C.push(children, T.quiet_label(ctx, "(empty)", {
            key = sscope:child("empty"),
            width = ui.grow(),
            font_size = 10,
        }))
    end

    local title = section.section_key or "Section"
    local kind = section.kind
    if kind then
        local kn = kind.kind
        if kn == "DeviceHeaderSection" then title = "Header"
        elseif kn == "DeviceParamsSection" then title = "Parameters"
        elseif kn == "DeviceModulatorsSection" then title = "Modulators"
        elseif kn == "DeviceNoteFXSection" then title = "Note FX"
        elseif kn == "DevicePostFXSection" then title = "Post FX"
        elseif kn == "DeviceChildrenSection" then title = "Children"
        end
    end

    local section_node = PF.section(ctx, sscope:child("frame"), title, {}, children)
    local wrapped = { section_node }
    P.overlay_children(ctx, sscope, section.identity, wrapped)
    return ctx.ui.column {
        key = sscope,
        width = ctx.ui.grow(),
        height = ctx.ui.fit(),
        gap = 0,
    } (wrapped)
end

-- ── Helper: lower container lane (layer/selector/split) ──

local function lower_lane(lane_type, lane, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local lscope = C.make_scope(ctx, lane.identity, C.identity_key(lane.identity))

    -- Determine lane label from ref type
    local ref = lane.layer_ref or lane.branch_ref or lane.band_ref
    local label = "Lane"
    if ref then
        if ref.kind == "LayerRef" then label = "Layer " .. tostring(ref.layer_id)
        elseif ref.kind == "SelectorBranchRef" then label = "Branch " .. tostring(ref.branch_id)
        elseif ref.kind == "SplitBandRef" then label = "Band " .. tostring(ref.band_id)
        end
    end

    -- The lane contains a nested DeviceChainView
    local chain_decl = lane.chain:to_decl(ctx)

    local children = {
        T.body_label(ctx, label, {
            key = lscope:child("title"),
            width = ui.grow(),
            font_size = 11,
        }),
        chain_decl,
    }
    P.overlay_children(ctx, lscope, lane.identity, children)

    return ui.column {
        key = lscope,
        width = ui.grow(),
        height = ui.fit(),
        gap = 2,
        padding = { left = 4, top = 4, right = 4, bottom = 4 },
        background = p.surface_inset,
        border = C.border(ctx, p.border_subtle, 1),
    } (children)
end

-- ── Helper: lower a list of sections ──

local function lower_sections(sections, ctx, scope)
    local children = {}
    for i = 1, #sections do
        C.push(children, lower_section(sections[i], ctx, scope))
    end
    return children
end

-- ═══════════════════════════════════════════════════════════════════════
-- DeviceView:to_decl — sum type dispatch
-- ═══════════════════════════════════════════════════════════════════════

function V.DeviceView:to_decl(ctx)
    return diag.wrap(ctx, "view.device_view.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, C.identity_key(self.identity))
        local k = self.kind

        -- Determine device name and header title
        local device_name = C.device_name(ctx, self.device_ref)
        local variant_label = "Device"
        if k == "NativeDeviceView" then variant_label = "Native Device"
        elseif k == "LayerContainerView" then variant_label = "Layer Container"
        elseif k == "SelectorContainerView" then variant_label = "Selector Container"
        elseif k == "SplitContainerView" then variant_label = "Split Container"
        elseif k == "GridContainerView" then variant_label = "Grid Container"
        end

        -- Header always renders so the local surface identity stays stable.
        local header_children = {
            T.strong_label(ctx, device_name, {
                key = scope:child("name"),
                width = ui.grow(),
                font_size = 12,
            }),
            T.quiet_label(ctx, variant_label, {
                key = scope:child("variant"),
                width = ui.fit(),
                font_size = 10,
            }),
        }

        -- Build the full surface content first; compilation state overlays it.
        local all_children = {}
        C.push(all_children, ui.row {
            key = scope:child("header"),
            width = ui.grow(),
            height = ui.fixed(28),
            align_y = ui.align_y.center,
            gap = 6,
            padding = { left = 8, top = 0, right = 8, bottom = 0 },
        } (header_children))

        local section_children = lower_sections(self.sections, ctx, scope)
        local lane_children = {}
        if k == "LayerContainerView" then
            for i = 1, #self.layers do
                C.push(lane_children, lower_lane("layer", self.layers[i], ctx))
            end
        elseif k == "SelectorContainerView" then
            for i = 1, #self.branches do
                C.push(lane_children, lower_lane("selector", self.branches[i], ctx))
            end
        elseif k == "SplitContainerView" then
            for i = 1, #self.bands do
                C.push(lane_children, lower_lane("split", self.bands[i], ctx))
            end
        end

        for i = 1, #section_children do
            C.push(all_children, section_children[i])
        end

        if #lane_children > 0 then
            C.push(all_children, T.section_title(ctx, "LANES", scope:child("lanes_title")))
            for i = 1, #lane_children do
                C.push(all_children, lane_children[i])
            end
        end

        local surface_children = {
            ui.scroll_region {
                key = scope:child("scroll"),
                width = ui.grow(),
                height = ui.grow(),
                vertical = true,
            } {
                ui.column {
                    key = scope:child("content"),
                    width = ui.grow(),
                    height = ui.fit(),
                    gap = 6,
                } (all_children),
            },
        }
        P.overlay_children(ctx, scope, self.device_ref or self.identity, surface_children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 4,
            background = p.surface_detail,
            border = ui.border { top = 1, color = p.border_separator },
            padding = { left = 8, top = 8, right = 8, bottom = 8 },
        } (surface_children)
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.device_view.to_decl", tostring(err))
    end)
end

return true
