-- impl/view/shell.t
-- View.Shell:to_decl()

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.shell.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local P = require("impl/view/components/placeholder_panel")
local status_bar = require("impl/view/status_bar")
local detail_panel = require("impl/view/detail_panel")

local function wrap_fill(ctx, key, node, opts)
    local ui = ctx.ui
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

local function lower_detail(detail, ctx, key, height)
    if detail == nil then return nil end
    return wrap_fill(ctx, key .. "/detail", detail_panel.lower(detail, ctx), {
        width = ctx.ui.grow(),
        height = height or ctx.ui.fixed(244),
        border = ctx.ui.border { top = 1, color = C.palette(ctx).border_separator },
    })
end

local function lower_arrangement_stack(arrangement, detail, ctx, key, background)
    local ui = ctx.ui
    local children = {
        wrap_fill(ctx, key .. "/main", arrangement, {
            width = ui.grow(),
            height = ui.grow(),
            background = background,
        }),
    }
    local detail_node = lower_detail(detail, ctx, key, ui.fixed(244))
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

local function lower_hybrid_arrange(main_area, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local arrange_visible = ui.call("!=", ui.param_ref("mode_arrange"), 0)

    local top = ui.row {
        key = ui.scope("main_area/hybrid/arrange_top"),
        width = ui.grow(),
        height = ui.grow(),
        gap = 0,
        background = p.surface_main,
    } {
        wrap_fill(ctx, "main_area/hybrid/launcher_strip", main_area.launcher:to_decl(ctx), {
            width = ui.fixed(336),
            height = ui.grow(),
            background = p.surface_panel,
            border = ui.border { right = 1, color = p.border_separator },
        }),
        wrap_fill(ctx, "main_area/hybrid/arrangement", main_area.arrangement:to_decl(ctx), {
            width = ui.grow(),
            height = ui.grow(),
            background = p.surface_main,
        }),
    }

    local children = { top }
    local detail_node = nil
    if main_area.detail_panel ~= nil and main_area.detail_panel.kind ~= "PianoRollDetail" then
        detail_node = lower_detail(main_area.detail_panel, ctx, "main_area/hybrid", ui.fixed(244))
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

local function lower_hybrid_mix(main_area, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local mix_visible = ui.call("!=", ui.param_ref("mode_mix"), 0)
    return wrap_fill(ctx, "main_area/hybrid/mix", main_area.mixer:to_decl(ctx), {
        width = ui.grow(),
        height = ui.grow(),
        background = p.surface_main,
        visible_when = mix_visible,
    })
end

local function lower_hybrid_edit(main_area, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local edit_visible = ui.call("!=", ui.param_ref("mode_edit"), 0)
    if ctx.edit_piano_roll ~= nil then
        return wrap_fill(ctx, "main_area/hybrid/edit", ctx.edit_piano_roll:to_decl(ctx), {
            width = ui.grow(),
            height = ui.grow(),
            background = p.surface_detail,
            visible_when = edit_visible,
        })
    elseif main_area.detail_panel ~= nil and main_area.detail_panel.kind == "PianoRollDetail" then
        return wrap_fill(ctx, "main_area/hybrid/edit", main_area.detail_panel.piano_roll:to_decl(ctx), {
            width = ui.grow(),
            height = ui.grow(),
            background = p.surface_detail,
            visible_when = edit_visible,
        })
    end
    C.record_diag(ctx, "warning", "view.main_area.edit_missing", "Edit mode requested without PianoRollDetail")
    return wrap_fill(ctx, "main_area/hybrid/edit_missing", P.fallback_node(ctx, "main_area/hybrid/edit_missing/node", "Edit view unavailable", "Expected PianoRollDetail for edit mode"), {
        width = ui.grow(),
        height = ui.grow(),
        background = p.surface_detail,
        visible_when = edit_visible,
    })
end

local function lower_hybrid_main(main_area, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    return ui.stack {
        key = ui.scope("main_area/hybrid/root"),
        width = ui.grow(),
        height = ui.grow(),
        background = p.surface_main,
    } {
        lower_hybrid_arrange(main_area, ctx),
        lower_hybrid_mix(main_area, ctx),
        lower_hybrid_edit(main_area, ctx),
    }
end

local function lower_main_area(main_area, ctx)
    local p = C.palette(ctx)

    if main_area.kind == "ArrangementMain" then
        return lower_arrangement_stack(
            main_area.arrangement:to_decl(ctx),
            main_area.detail_panel,
            ctx,
            "main_area/arrangement",
            p.surface_main)
    elseif main_area.kind == "LauncherMain" then
        return lower_arrangement_stack(
            main_area.launcher:to_decl(ctx),
            main_area.detail_panel,
            ctx,
            "main_area/launcher",
            p.surface_main)
    elseif main_area.kind == "MixerMain" then
        return lower_arrangement_stack(
            main_area.mixer:to_decl(ctx),
            main_area.detail_panel,
            ctx,
            "main_area/mixer",
            p.surface_main)
    elseif main_area.kind == "HybridMain" then
        return lower_hybrid_main(main_area, ctx)
    end

    C.record_diag(ctx, "warning", "view.main_area.unsupported", main_area.kind)
    return P.fallback_node(ctx, "main_area/unsupported", "Unsupported main area", main_area.kind)
end

function V.Shell:to_decl(ctx)
    return diag.wrap(ctx, "view.shell.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)

        local browser = nil
        local inspector = nil
        for i = 1, #self.sidebars do
            local sidebar = self.sidebars[i]
            if sidebar.kind == "BrowserSidebar" then
                browser = sidebar.browser:to_decl(ctx)
            elseif sidebar.kind == "InspectorSidebar" then
                inspector = sidebar.inspector:to_decl(ctx)
            end
        end

        local main = lower_main_area(self.main_area, ctx)
        local status = self.status_bar and status_bar.lower(self.status_bar, ctx) or nil

        local scope = ui.scope("app_shell/root")
        local children = {
            self.transport:to_decl(ctx),
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
        P.overlay_children(ctx, scope, "shell", children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
            background = p.surface_app,
            padding = 0,
        } (children)
    end, function(err)
        return P.fallback_node(ctx, "shell/root", "view.shell.to_decl", tostring(err))
    end)
end

return true
