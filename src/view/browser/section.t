-- impl/view/browser/section.t
-- Lowering helper for View.BrowserSection.

local C = require("src/view/common")
local F = require("src/view/components/panel_frame")
local item = require("src/view/browser/item")
local P = require("src/view/components/placeholder_panel")

local M = {}

function M.lower(section, ctx, parent_scope, index)
    local item_children = {}
    for j = 1, #section.items do
        C.push(item_children, item.lower(section.items[j], ctx))
    end

    local scope = C.make_scope(ctx, section.identity, C.identity_key(section.identity))
    local section_node = F.section(ctx,
        scope:child("frame"),
        section.label,
        {
            padding = { left = 0, top = 4, right = 0, bottom = 4 },
            body_background = C.palette(ctx).surface_panel,
            body_border = C.border(ctx, C.palette(ctx).border_subtle, 1),
        },
        item_children)
    local children = { section_node }
    P.overlay_children(ctx, scope, section.identity, children)
    return ctx.ui.column {
        key = scope,
        width = ctx.ui.grow(),
        height = ctx.ui.fit(),
        gap = 0,
    } (children)
end

return M
