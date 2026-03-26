-- impl/view/browser/view.t
-- View.BrowserView:to_decl()
-- Right sidebar browser: search, source tabs, scrollable item list.


local C = require("src/view/common")
local T = require("src/view/components/text")
local B = require("src/view/components/button")
local P = require("src/view/components/placeholder_panel")
local section = require("src/view/browser/section")

local M = {}

local function lower(self, ctx)
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "browser")

        local source_children = {}
        for i = 1, #self.sources do
            local src = self.sources[i]
            local cmd = C.find_command(src.commands, "BCCSelectSource")
            local src_scope = C.make_scope(ctx, src.identity, C.identity_key(src.identity))
            local src_node = B.flat_button(ctx, src.label, cmd and cmd.action_id or nil, {
                key = src_scope:child("base"),
                width = ui.grow(),
                height = ui.fixed(22),
                padding = { left = 6, top = 0, right = 6, bottom = 0 },
                background = src.selected and p.surface_selected or p.surface_inset,
                border = C.border(ctx, src.selected and p.border_selected or p.border_subtle, 1),
                text_color = p.text_primary,
                font_size = 11,
            })
            C.push(source_children, P.wrap_node(ctx, src_scope, src.identity, src_node, {
                width = ui.grow(),
                height = ui.fixed(22),
            }))
        end

        local section_children = {}
        for i = 1, #self.sections do
            C.push(section_children, section.lower(self.sections[i], ctx, scope, i))
        end

        local children = {
            T.section_title(ctx, "EVERYTHING", scope:child("title")),
            ui.label {
                key = scope:child("query"),
                width = ui.grow(),
                height = ui.fixed(22),
                padding = { left = 6, top = 0, right = 6, bottom = 0 },
                text = self.query or "Everything",
                background = p.surface_inset,
                border = C.border(ctx, p.border_control, 1),
                text_color = p.text_muted,
                font_size = 11,
            },
            ui.column {
                key = scope:child("sources"),
                width = ui.grow(),
                height = ui.fit(),
                gap = 2,
            } (source_children),
            ui.scroll_region {
                key = scope:child("sections"),
                width = ui.grow(),
                height = ui.grow(),
                vertical = true,
            } (section_children),
        }
        P.overlay_children(ctx, scope, self.identity, children)

        return ui.column {
            key = scope,
            width = ui.fixed(200),
            height = ui.grow(),
            gap = 4,
            background = p.surface_sidebar,
            border = ui.border { left = 1, color = p.border_separator },
            padding = { left = 6, top = 6, right = 6, bottom = 6 },
        } (children)

end


M.lower = lower


return M
