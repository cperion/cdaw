-- impl/view/inspector/view.t
-- View.InspectorView:to_decl()
-- Left sidebar inspector: compact, dense, Bitwig-style.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.inspector_view.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local P = require("impl/view/components/placeholder_panel")
local tab_view = require("impl/view/inspector/tab_view")

function V.InspectorView:to_decl(ctx)
    return diag.wrap(ctx, "view.inspector_view.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "inspector")
        local tab_children = {}
        local content_children = {}

        for i = 1, #self.tabs do
            local tab = self.tabs[i]
            C.push(tab_children, tab_view.lower_button(tab, ctx, i == 1))
            if i == 1 then
                local active_children = tab_view.lower_content(tab, ctx, scope)
                for j = 1, #active_children do
                    C.push(content_children, active_children[j])
                end
            end
        end

        return ui.column {
            key = scope,
            width = ui.fixed(160),
            height = ui.grow(),
            gap = 4,
            background = p.surface_sidebar,
            border = ui.border { right = 1, color = p.border_separator },
            padding = { left = 6, top = 6, right = 6, bottom = 6 },
        } {
            T.section_title(ctx, "INSPECTOR", scope:child("title")),
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
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.inspector_view.to_decl", tostring(err))
    end)
end

return true
