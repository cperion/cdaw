-- impl/view/arrangement/view.t
-- View.ArrangementView:to_decl()

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.arrangement_view.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local P = require("impl/view/components/placeholder_panel")
local lane = require("impl/view/arrangement/lane")

local M = {}

local function lower(self, ctx)
    return diag.wrap(ctx, "view.arrangement_view.to_decl", "real", function()
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
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.arrangement_view.to_decl", tostring(err))
    end)
end

local to_decl_impl = terralib.memoize(function(self)
    return lower(self, C.new_view_ctx())
end)

M.lower = lower

function V.ArrangementView:to_decl()
    return to_decl_impl(self)
end

return M
