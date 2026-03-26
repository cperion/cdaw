-- impl/view/components/list_row.t
-- Shared compact row atoms for browser/inspector/list-like surfaces.
-- Row height follows design-tokens: default 22px (compact browser/inspector).

local C = require("src/view/common")
local T = require("src/view/components/text")
local B = require("src/view/components/button")

local M = {}

function M.button_row(ctx, scope, text, action, opts)
    opts = opts or {}
    local p = C.palette(ctx)
    return ctx.ui.button {
        key = scope,
        width = opts.width or ctx.ui.grow(),
        height = opts.height or ctx.ui.fixed(22),
        padding = opts.padding or { left = 8, top = 0, right = 8, bottom = 0 },
        text = text,
        action = action,
        background = opts.background or p.surface_panel,
        border = opts.border or ctx.ui.border { bottom = 1, color = p.border_subtle },
        text_color = opts.text_color or p.text_primary,
        font_size = opts.font_size or 11,
    }
end

function M.value_row(ctx, scope, lhs_text, rhs_node, opts)
    opts = opts or {}
    local p = C.palette(ctx)
    return ctx.ui.row {
        key = scope,
        width = ctx.ui.grow(),
        height = opts.height or ctx.ui.fixed(22),
        align_y = ctx.ui.align_y.center,
        padding = opts.padding or { left = 8, top = 0, right = 4, bottom = 0 },
        border = opts.border or ctx.ui.border { bottom = 1, color = p.border_subtle },
    } {
        T.quiet_label(ctx, lhs_text, {
            key = scope:child("lhs"),
            width = ctx.ui.grow(),
            font_size = opts.font_size or 11,
        }),
        rhs_node,
    }
end

function M.action_value(ctx, scope, lhs_text, action, opts)
    opts = opts or {}
    return M.value_row(ctx, scope, lhs_text,
        B.flat_button(ctx, opts.button_text or "Edit", action, {
            key = scope:child("action"),
            width = opts.button_width or ctx.ui.fixed(40),
            height = ctx.ui.fixed(18),
            padding = { left = 4, top = 0, right = 4, bottom = 0 },
            font_size = 10,
        }),
        opts)
end

return M
