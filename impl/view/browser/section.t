-- impl/view/browser/section.t
-- Lowering helper for View.BrowserSection.

local C = require("impl/view/_support/common")
local F = require("impl/view/components/panel_frame")
local item = require("impl/view/browser/item")

local M = {}

function M.lower(section, ctx, parent_scope, index)
    local item_children = {}
    for j = 1, #section.items do
        C.push(item_children, item.lower(section.items[j], ctx))
    end

    return F.section(ctx,
        C.make_scope(ctx, section.identity, C.identity_key(section.identity)),
        section.label,
        {
            padding = { left = 0, top = 4, right = 0, bottom = 4 },
            body_background = C.palette(ctx).surface_panel,
            body_border = C.border(ctx, C.palette(ctx).border_subtle, 1),
        },
        item_children)
end

return M
