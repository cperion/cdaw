-- impl/view/inspector/tab_view.t
-- Lowering helper for View.InspectorTabView.


local C = require("src/view/common")
local B = require("src/view/components/button")
local P = require("src/view/components/placeholder_panel")
local section_view = require("src/view/inspector/section_view")

local M = {}

function M.lower_button(tab, selected)
    local cmd = C.find_command(tab.commands, "ICCSelectTab")
    local p = C.palette()
    local scope = C.make_scope(tab.identity, C.identity_key(tab.identity))
    local button = B.flat_button(tab.tab_key, cmd and cmd.action_id or nil, {
        key = scope:child("base"),
        width = C.ui.fit(),
        height = C.ui.fixed(22),
        padding = { left = 8, top = 0, right = 8, bottom = 0 },
        background = selected and p.surface_selected or p.surface_control,
        border = C.border( selected and p.border_selected or p.border_control, 1),
        font_size = 11,
    })
    return P.wrap_node(scope, tab.identity, button, {
        width = C.ui.fit(),
        height = C.ui.fixed(22),
    })
end

function M.lower_content(tab, scope)
    local content_children = {}
    for j = 1, #tab.sections do
        C.push(content_children, section_view.lower(tab.sections[j], scope, j))
    end
    return content_children
end

return M
