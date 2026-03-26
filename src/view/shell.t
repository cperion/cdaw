-- impl/view/shell.t
-- View.Shell:to_decl()


local C = require("src/view/common")
local P = require("src/view/components/placeholder_panel")
local status_bar = require("src/view/status_bar")
local detail_panel = require("src/view/detail_panel")
local transport_bar = require("src/view/transport_bar")
local arrangement_view = require("src/view/arrangement/view")
local launcher_view = require("src/view/launcher/view")
local mixer_view = require("src/view/mixer/view")
local browser_view = require("src/view/browser/view")
local inspector_view = require("src/view/inspector/view")

local M = {}

local function wrap_fill(key, node, opts)
    local ui = C.ui
    opts = opts or {}
    return ui.column {
        key = ui.scope(key),
        width = opts.width or ui.grow(),
        height = opts.height or ui.grow(),
        gap = 0,
        background = opts.background,
        border = opts.border,
        visible_when = opts.visible_when,
    } {
        node,
    }
end

local function lower_detail(detail, key, height)
    if detail == nil then return nil end
    return wrap_fill(key .. "/detail", detail_panel.lower(detail), {
        width = C.ui.grow(),
        height = height or C.ui.fixed(244),
        border = C.ui.border { top = 1, color = C.palette().border_separator },
    })
end

local function lower_arrangement_stack(main_node, detail, key, background)
    local ui = C.ui
    local children = {
        wrap_fill(key .. "/main", main_node, {
            width = ui.grow(),
            height = ui.grow(),
            background = background,
        }),
    }
    local detail_node = lower_detail(detail, key, ui.fixed(244))
    if detail_node ~= nil then
        C.push(children, detail_node)
    end
    return ui.column {
        key = ui.scope(key),
        width = ui.grow(),
        height = ui.grow(),
        gap = 0,
        background = background,
    } (children)
end

local function lower_hybrid_arrange(main_area)
    local ui = C.ui
    local p = C.palette()
    local arrange_visible = ui.call("!=", ui.param_ref("mode_arrange"), 0)

    local top = ui.row {
        key = ui.scope("main_area/hybrid/arrange_top"),
        width = ui.grow(),
        height = ui.grow(),
        gap = 0,
        background = p.surface_main,
    } {
        wrap_fill("main_area/hybrid/launcher_strip", launcher_view.render(main_area.launcher), {
            width = ui.fixed(336),
            height = ui.grow(),
            background = p.surface_panel,
            border = ui.border { right = 1, color = p.border_separator },
        }),
        wrap_fill("main_area/hybrid/arrangement", arrangement_view.render(main_area.arrangement), {
            width = ui.grow(),
            height = ui.grow(),
            background = p.surface_main,
        }),
    }

    local children = { top }
    local detail_node = nil
    if main_area.detail_panel ~= nil and main_area.detail_panel.kind ~= "PianoRollDetail" then
        detail_node = lower_detail(main_area.detail_panel, "main_area/hybrid", ui.fixed(244))
    end
    if detail_node ~= nil then
        C.push(children, detail_node)
    end

    return ui.column {
        key = ui.scope("main_area/hybrid/arrange"),
        width = ui.grow(),
        height = ui.grow(),
        gap = 0,
        background = p.surface_main,
        visible_when = arrange_visible,
    } (children)
end

local function lower_hybrid_mix(main_area)
    local ui = C.ui
    local p = C.palette()
    local mix_visible = ui.call("!=", ui.param_ref("mode_mix"), 0)
    return wrap_fill("main_area/hybrid/mix", mixer_view.render(main_area.mixer), {
        width = ui.grow(),
        height = ui.grow(),
        background = p.surface_main,
        visible_when = mix_visible,
    })
end

local function lower_hybrid_edit(main_area)
    local ui = C.ui
    local p = C.palette()
    local edit_visible = ui.call("!=", ui.param_ref("mode_edit"), 0)
    if main_area.detail_panel ~= nil and main_area.detail_panel.kind == "PianoRollDetail" then
        return wrap_fill("main_area/hybrid/edit", detail_panel.lower(main_area.detail_panel), {
            width = ui.grow(),
            height = ui.grow(),
            background = p.surface_detail,
            visible_when = edit_visible,
        })
    end
    C.record_diag("warning", "view.main_area.edit_missing", "Edit mode requested without PianoRollDetail")
    return wrap_fill("main_area/hybrid/edit_missing", P.fallback_node("main_area/hybrid/edit_missing/node", "Edit view unavailable", "Expected PianoRollDetail for edit mode"), {
        width = ui.grow(),
        height = ui.grow(),
        background = p.surface_detail,
        visible_when = edit_visible,
    })
end

local function lower_hybrid_main(main_area)
    local ui = C.ui
    local p = C.palette()
    return ui.stack {
        key = ui.scope("main_area/hybrid/root"),
        width = ui.grow(),
        height = ui.grow(),
        background = p.surface_main,
    } {
        lower_hybrid_arrange(main_area),
        lower_hybrid_mix(main_area),
        lower_hybrid_edit(main_area),
    }
end

local function lower_main_area(main_area)
    local p = C.palette()

    if main_area.kind == "ArrangementMain" then
        return lower_arrangement_stack(
            arrangement_view.render(main_area.arrangement),
            main_area.detail_panel,
            "main_area/arrangement",
            p.surface_main)
    elseif main_area.kind == "LauncherMain" then
        return lower_arrangement_stack(
            launcher_view.render(main_area.launcher),
            main_area.detail_panel,
            "main_area/launcher",
            p.surface_main)
    elseif main_area.kind == "MixerMain" then
        return lower_arrangement_stack(
            mixer_view.render(main_area.mixer),
            main_area.detail_panel,
            "main_area/mixer",
            p.surface_main)
    elseif main_area.kind == "HybridMain" then
        return lower_hybrid_main(main_area)
    end

    C.record_diag("warning", "view.main_area.unsupported", main_area.kind)
    return P.fallback_node("main_area/unsupported", "Unsupported main area", main_area.kind)
end

local function lower(self)
        local ui = C.ui
        local p = C.palette()

        local browser = nil
        local inspector = nil
        for i = 1, #self.sidebars do
            local sidebar = self.sidebars[i]
            if sidebar.kind == "BrowserSidebar" then
                browser = browser_view.render(sidebar.browser)
            elseif sidebar.kind == "InspectorSidebar" then
                inspector = inspector_view.render(sidebar.inspector)
            end
        end

        local main = lower_main_area(self.main_area)
        local status = self.status_bar and status_bar.lower(self.status_bar) or nil

        local scope = ui.scope("app_shell/root")
        local children = {
            transport_bar.render(self.transport),
            ui.row {
                key = ui.scope("app_shell/workspace"),
                width = ui.grow(),
                height = ui.grow(),
                gap = 0,
                background = p.surface_main,
            } {
                inspector,
                main,
                browser,
            },
            status,
        }
        P.overlay_children(scope, "shell", children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
            background = p.surface_app,
            padding = 0,
        } (children)

end


M.render = lower


function M.lower(self)
    return M.render(self)
end
return M
