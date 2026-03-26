-- impl/view/status_bar.t
-- Lowering helper for View.StatusBar.
-- Bitwig-style bottom bar: mode buttons (ARRANGE/MIX/EDIT) always visible,
-- active state shown by accent text + subtle bg, inactive by muted text.

local C = require("src/view/common")
local T = require("src/view/components/text")
local B = require("src/view/components/button")
local P = require("src/view/components/placeholder_panel")

local M = {}

local function mode_button_variant(scope, label, action, active_expr, active)
    local ui = C.ui
    local p = C.palette()
    return B.flat_button(label, action, {
        key = scope,
        width = ui.fixed(64),
        height = ui.fixed(20),
        padding = { left = 0, top = 0, right = 0, bottom = 0 },
        background = active and p.surface_selected or nil,
        border = active and C.border( p.border_selected, 1) or C.border( p.border_subtle, 1),
        font_size = 10,
        text_color = active and p.track_accent or p.text_muted,
        visible_when = active_expr,
    })
end

local function mode_button(scope, label, action, param_name)
    local ui = C.ui
    local active_expr = ui.call("!=", ui.param_ref(param_name), 0)
    local inactive_expr = ui.call("==", ui.param_ref(param_name), 0)
    return ui.stack {
        key = scope,
        width = ui.fixed(64),
        height = ui.fixed(20),
    } {
        mode_button_variant(scope:child("on"), label, action, active_expr, true),
        mode_button_variant(scope:child("off"), label, action, inactive_expr, false),
    }
end

function M.lower(status_bar)
    local ui = C.ui
    local p = C.palette()
    local scope = C.make_scope(status_bar.identity, "status")
    local center_text = C._dynamic_status and ui.param_ref("status_center") or (status_bar.center_text or "")
    local right_text = C._dynamic_status and ui.param_ref("status_right") or (status_bar.right_text or "")

    local children = {
        mode_button(scope:child("arrange"), "ARRANGE", "app.mode.arrange", "mode_arrange"),
        mode_button(scope:child("mix"), "MIX", "app.mode.mix", "mode_mix"),
        mode_button(scope:child("edit"), "EDIT", "app.mode.edit", "mode_edit"),
        ui.spacer { key = scope:child("grow_a"), width = ui.grow(), height = ui.fixed(0) },
        T.quiet_label(center_text, {
            key = scope:child("center"),
            width = ui.fit(),
            font_size = 10,
        }),
        ui.spacer { key = scope:child("grow_b"), width = ui.grow(), height = ui.fixed(0) },
        T.quiet_label(right_text, {
            key = scope:child("right"),
            width = ui.fit(),
            font_size = 10,
        }),
    }
    P.overlay_children(scope, status_bar.identity, children)

    return ui.row {
        key = scope,
        width = ui.grow(),
        height = ui.fixed(26),
        padding = { left = 6, top = 3, right = 8, bottom = 3 },
        gap = 4,
        align_y = ui.align_y.center,
        background = p.surface_status,
        border = ui.border { top = 1, color = p.border_separator },
    } (children)
end

return M
