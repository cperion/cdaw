-- impl/view/inspector/tab_view.t
-- Lowering helper for View.InspectorTabView.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local B = require("impl/view/components/button")
local section_view = require("impl/view/inspector/section_view")

local M = {}

function M.lower_button(tab, ctx, selected)
    local cmd = C.find_command(tab.commands, V.ICCSelectTab)
    local p = C.palette(ctx)
    return B.flat_button(ctx, tab.tab_key, cmd and cmd.action_id or nil, {
        key = C.make_scope(ctx, tab.identity, C.identity_key(tab.identity)),
        width = ctx.ui.fit(),
        height = ctx.ui.fixed(22),
        padding = { left = 8, top = 0, right = 8, bottom = 0 },
        background = selected and p.surface_selected or p.surface_control,
        border = C.border(ctx, selected and p.border_selected or p.border_control, 1),
        font_size = 11,
    })
end

function M.lower_content(tab, ctx, scope)
    local content_children = {}
    for j = 1, #tab.sections do
        C.push(content_children, section_view.lower(tab.sections[j], ctx, scope, j))
    end
    return content_children
end

return M
