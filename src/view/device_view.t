-- impl/view/device_view.t
-- View.DeviceView:to_decl()
-- Focused device panel: native params, container lanes, modulators.


local C = require("src/view/common")
local T = require("src/view/components/text")
local B = require("src/view/components/button")
local P = require("src/view/components/placeholder_panel")
local LR = require("src/view/components/list_row")
local PF = require("src/view/components/panel_frame")
local chain_view = require("src/view/device_chain/view")

local M = {}

-- ── Helper: lower a single param view ──

local function lower_param(param, scope)
    local ui = C.ui
    local p = C.palette()
    local pscope = C.make_scope(param.identity, C.identity_key(param.identity))
    local cmd = C.find_command(param.commands, "DSCCSetParamValue")
    local name = "Param " .. tostring(param.param_ref and param.param_ref.param_id or "?")
    if C._param_names and param.param_ref then
        name = C._param_names[C.encode_semantic_ref(param.param_ref)] or name
    end
    local row = LR.action_value(pscope:child("base"), name, cmd and cmd.action_id or nil, {
        button_text = "...",
        button_width = ui.fixed(32),
    })
    return P.wrap_node(pscope, param.param_ref or param.identity, row, {
        width = ui.grow(),
        height = ui.fixed(22),
    })
end

-- ── Helper: lower a modulation route view ──

local function lower_mod_route(route)
    local ui = C.ui
    local rscope = C.make_scope(route.identity, C.identity_key(route.identity))
    local row = LR.value_row(rscope:child("base"), "→ param " .. tostring(route.target_param_ref and route.target_param_ref.param_id or "?"),
        T.quiet_label(string.format("%.0f%%", (route.route_index or 0) * 100), {
            key = rscope:child("depth"),
            width = ui.fit(),
            font_size = 10,
        })
    )
    return P.wrap_node(rscope, route.identity, row, {
        width = ui.grow(),
        height = ui.fixed(22),
    })
end

-- ── Helper: lower a modulator view ──

local function lower_modulator(mod)
    local ui = C.ui
    local p = C.palette()
    local mscope = C.make_scope(mod.identity, C.identity_key(mod.identity))
    local children = {}
    C.push(children, T.body_label("Modulator " .. tostring(mod.modulator_ref and mod.modulator_ref.modulator_id or "?"), {
        key = mscope:child("title"),
        width = ui.grow(),
        font_size = 11,
    }))
    for i = 1, #mod.routes do
        C.push(children, lower_mod_route(mod.routes[i]))
    end
    P.overlay_children(mscope, mod.identity, children)
    return ui.column {
        key = mscope,
        width = ui.grow(),
        height = ui.fit(),
        gap = 1,
        padding = { left = 4, top = 4, right = 4, bottom = 4 },
        background = p.surface_inset,
        border = C.border( p.border_subtle, 1),
    } (children)
end

-- ── Helper: lower a device section view ──

local function lower_section(section, scope)
    local ui = C.ui
    local p = C.palette()
    local sscope = C.make_scope(section.identity, C.identity_key(section.identity))
    local children = {}

    -- Params
    for i = 1, #section.params do
        C.push(children, lower_param(section.params[i], sscope))
    end

    -- Modulators
    for i = 1, #section.modulators do
        C.push(children, lower_modulator(section.modulators[i]))
    end

    if #children == 0 then
        C.push(children, T.quiet_label("(empty)", {
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

    local section_node = PF.section( sscope:child("frame"), title, {}, children)
    local wrapped = { section_node }
    P.overlay_children(sscope, section.identity, wrapped)
    return C.ui.column {
        key = sscope,
        width = C.ui.grow(),
        height = C.ui.fit(),
        gap = 0,
    } (wrapped)
end

-- ── Helper: lower container lane (layer/selector/split) ──

local function lower_lane(lane_type, lane)
    local ui = C.ui
    local p = C.palette()
    local lscope = C.make_scope(lane.identity, C.identity_key(lane.identity))

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
    local chain_decl = chain_view.render(lane.chain)

    local children = {
        T.body_label(label, {
            key = lscope:child("title"),
            width = ui.grow(),
            font_size = 11,
        }),
        chain_decl,
    }
    P.overlay_children(lscope, lane.identity, children)

    return ui.column {
        key = lscope,
        width = ui.grow(),
        height = ui.fit(),
        gap = 2,
        padding = { left = 4, top = 4, right = 4, bottom = 4 },
        background = p.surface_inset,
        border = C.border( p.border_subtle, 1),
    } (children)
end

-- ── Helper: lower a list of sections ──

local function lower_sections(sections, scope)
    local children = {}
    for i = 1, #sections do
        C.push(children, lower_section(sections[i], scope))
    end
    return children
end

-- ═══════════════════════════════════════════════════════════════════════
-- DeviceView:to_decl — sum type dispatch
-- ═══════════════════════════════════════════════════════════════════════

local function lower(self)
        local ui = C.ui
        local p = C.palette()
        local scope = C.make_scope(self.identity, C.identity_key(self.identity))
        local k = self.kind

        -- Determine device name and header title
        local device_name = C.device_name(self.device_ref)
        local variant_label = "Device"
        if k == "NativeDeviceView" then variant_label = "Native Device"
        elseif k == "LayerContainerView" then variant_label = "Layer Container"
        elseif k == "SelectorContainerView" then variant_label = "Selector Container"
        elseif k == "SplitContainerView" then variant_label = "Split Container"
        elseif k == "GridContainerView" then variant_label = "Grid Container"
        end

        -- Header always renders so the local surface identity stays stable.
        local header_children = {
            T.strong_label(device_name, {
                key = scope:child("name"),
                width = ui.grow(),
                font_size = 12,
            }),
            T.quiet_label(variant_label, {
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

        local section_children = lower_sections(self.sections, scope)
        local lane_children = {}
        if k == "LayerContainerView" then
            for i = 1, #self.layers do
                C.push(lane_children, lower_lane("layer", self.layers[i]))
            end
        elseif k == "SelectorContainerView" then
            for i = 1, #self.branches do
                C.push(lane_children, lower_lane("selector", self.branches[i]))
            end
        elseif k == "SplitContainerView" then
            for i = 1, #self.bands do
                C.push(lane_children, lower_lane("split", self.bands[i]))
            end
        end

        for i = 1, #section_children do
            C.push(all_children, section_children[i])
        end

        if #lane_children > 0 then
            C.push(all_children, T.section_title("LANES", scope:child("lanes_title")))
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
        P.overlay_children(scope, self.device_ref or self.identity, surface_children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 4,
            background = p.surface_detail,
            border = ui.border { top = 1, color = p.border_separator },
            padding = { left = 8, top = 8, right = 8, bottom = 8 },
        } (surface_children)

end


M.render = lower


function M.lower(self)
    return M.render(self)
end
return M
