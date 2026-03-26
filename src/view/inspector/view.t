-- impl/view/inspector/view.t
-- View.InspectorView:to_decl()
-- Left sidebar inspector: compact, dense, Bitwig-style.


local C = require("src/view/common")
local T = require("src/view/components/text")
local P = require("src/view/components/placeholder_panel")
local tab_view = require("src/view/inspector/tab_view")

local M = {}

local function lower(self)
        local ui = C.ui
        local p = C.palette()
        local scope = C.make_scope(self.identity, "inspector")
        local tab_children = {}
        local content_children = {}

        for i = 1, #self.tabs do
            local tab = self.tabs[i]
            C.push(tab_children, tab_view.lower_button(tab, i == 1))
            if i == 1 then
                local active_children = tab_view.lower_content(tab, scope)
                for j = 1, #active_children do
                    C.push(content_children, active_children[j])
                end
            end
        end

        local children = {
            T.section_title("INSPECTOR", scope:child("title")),
            ui.row {
                key = scope:child("tabs"),
                width = ui.grow(),
                height = ui.fit(),
                gap = 2,
            } (tab_children),
            ui.scroll_region {
                key = scope:child("content"),
                width = ui.grow(),
                height = ui.grow(),
                vertical = true,
            } (content_children),
        }
        P.overlay_children(scope, self.identity, children)

        return ui.column {
            key = scope,
            width = ui.fixed(160),
            height = ui.grow(),
            gap = 4,
            background = p.surface_sidebar,
            border = ui.border { right = 1, color = p.border_separator },
            padding = { left = 6, top = 6, right = 6, bottom = 6 },
        } (children)

end


M.render = lower


function M.lower(self)
    return M.render(self)
end
return M
