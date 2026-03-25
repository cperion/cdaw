-- impl/view/mixer/view.t
-- View.MixerView:to_decl()
-- Mixer strip viewport with horizontal strip repetition.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.mixer_view.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local P = require("impl/view/components/placeholder_panel")
local strip = require("impl/view/mixer/strip")

function V.MixerView:to_decl(ctx)
    return diag.wrap(ctx, "view.mixer_view.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "mixer")
        local strip_children = {}

        for i = 1, #self.strips do
            C.push(strip_children, strip.lower(self.strips[i], ctx, ctx.selection))
        end

        local children = {
            ui.scroll_region {
                key = scope:child("strips_scroll"),
                width = ui.grow(),
                height = ui.grow(),
                horizontal = true,
                vertical = true,
                background = p.surface_main,
            } {
                ui.row {
                    key = scope:child("strips"),
                    width = ui.fit(),
                    height = ui.grow(),
                    gap = 1,
                    padding = { left = 0, top = 0, right = 0, bottom = 0 },
                    align_y = ui.align_y.top,
                } (strip_children),
            },
        }
        P.overlay_children(ctx, scope, self.identity, children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
            background = p.surface_main,
        } (children)
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.mixer_view.to_decl", tostring(err))
    end)
end

return true
