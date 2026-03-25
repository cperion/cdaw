-- impl/view/device_chain/view.t
-- View.DeviceChainView:to_decl()

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.device_chain_view.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local B = require("impl/view/components/button")
local P = require("impl/view/components/placeholder_panel")
local entry = require("impl/view/device_chain/entry")

function V.DeviceChainView:to_decl(ctx)
    return diag.wrap(ctx, "view.device_chain_view.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "device_chain")
        local children = {}

        local add_cmd = C.find_command(self.commands, V.DCCAddDevice)
        C.push(children, B.flat_button(ctx, "+ Device", add_cmd and add_cmd.action_id or nil, {
            key = scope:child("add"),
            width = ui.fixed(72),
            background = p.surface_accent_soft,
            border = C.border(ctx, p.border_focus, 1),
        }))
        C.push(children, ui.spacer { key = scope:child("lead_gap"), width = ui.fixed(8), height = ui.fixed(0) })

        for i = 1, #self.entries do
            C.push(children, entry.lower(self.entries[i], ctx))
            C.push(children, ui.spacer { key = scope:child("gap_" .. tostring(i)), width = ui.fixed(8), height = ui.fixed(0) })
        end

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 8,
            background = p.surface_detail,
            border = ui.border { top = 1, color = p.border_separator },
            padding = { left = 8, top = 8, right = 8, bottom = 8 },
        } {
            ui.row {
                key = scope:child("header"),
                width = ui.grow(),
                height = ui.fixed(22),
                align_y = ui.align_y.center,
            } {
                T.section_title(ctx, "DETAIL PANEL / DEVICE CHAIN", scope:child("title")),
            },
            ui.scroll_region {
                key = scope:child("entries"),
                width = ui.grow(),
                height = ui.grow(),
                horizontal = true,
                vertical = true,
            } {
                ui.row {
                    key = scope:child("entries_row"),
                    width = ui.fit(),
                    height = ui.grow(),
                    gap = 0,
                    align_y = ui.align_y.top,
                } (children),
            },
        }
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.device_chain_view.to_decl", tostring(err))
    end)
end

return true
