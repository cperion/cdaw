-- impl/view/browser/section.t
-- Lowering helper for View.BrowserSection.

local C = require("src/view/common")
local F = require("src/view/components/panel_frame")
local item = require("src/view/browser/item")
local P = require("src/view/components/placeholder_panel")

local M = {}

function M.lower(section, parent_scope, index)
    local item_children = {}
    for j = 1, #section.items do
        C.push(item_children, item.lower(section.items[j]))
    end

    local scope = C.make_scope(section.identity, C.identity_key(section.identity))
    local section_node = F.section(
        scope:child("frame"),
        section.label,
        {
            padding = { left = 0, top = 4, right = 0, bottom = 4 },
            body_background = C.palette().surface_panel,
            body_border = C.border( C.palette().border_subtle, 1),
        },
        item_children)
    local children = { section_node }
    P.overlay_children(scope, section.identity, children)
    return C.ui.column {
        key = scope,
        width = C.ui.grow(),
        height = C.ui.fit(),
        gap = 0,
    } (children)
end

return M
