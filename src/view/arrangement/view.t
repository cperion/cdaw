-- impl/view/arrangement/view.t
-- View.ArrangementView:to_decl()


local C = require("src/view/common")
local T = require("src/view/components/text")
local P = require("src/view/components/placeholder_panel")
local lane = require("src/view/arrangement/lane")

local M = {}

local function lower(self, ctx)
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "arrangement")
        local lane_children = {}
        for i = 1, #self.lanes do
            C.push(lane_children, lane.lower(self.lanes[i], ctx, ctx.selection))
        end

        local ruler_text = "1.1      1.2      1.3      1.4      2.1      2.2      2.3      2.4"
        if self.ruler ~= nil then
            ruler_text = string.format("%.1f → %.1f", self.ruler.visible_start_beats, self.ruler.visible_end_beats)
        end

        local children = {
            ui.row {
                key = scope:child("ruler"),
                width = ui.grow(),
                height = ui.fixed(20),
                padding = { left = 176, top = 2, right = 10, bottom = 2 },
                background = p.surface_ruler,
                border = ui.border { bottom = 1, color = p.border_separator },
            } {
                T.quiet_label(ctx, ruler_text, {
                    key = scope:child("ruler_text"),
                    font_size = 11,
                    text_color = p.text_primary,
                }),
            },
            ui.scroll_region {
                key = scope:child("lanes_scroll"),
                width = ui.grow(),
                height = ui.grow(),
                vertical = true,
                background = p.surface_arrangement,
            } (lane_children),
        }
        P.overlay_children(ctx, scope, self.identity, children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
            background = p.surface_arrangement,
            border = ui.border { right = 1, color = p.border_separator },
        } (children)

end


M.lower = lower


return M
