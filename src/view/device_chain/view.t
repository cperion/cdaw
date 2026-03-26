-- impl/view/device_chain/view.t
-- View.DeviceChainView:to_decl()


local C = require("src/view/common")
local T = require("src/view/components/text")
local B = require("src/view/components/button")
local P = require("src/view/components/placeholder_panel")
local entry = require("src/view/device_chain/entry")

local M = {}

local function lower(self)
        local ui = C.ui
        local p = C.palette()
        local scope = C.make_scope(self.identity, "device_chain")
        local children = {}

        local add_cmd = C.find_command(self.commands, "DCCAddDevice")
        C.push(children, B.flat_button("+ Device", add_cmd and add_cmd.action_id or nil, {
            key = scope:child("add"),
            width = ui.fixed(72),
            background = p.surface_accent_soft,
            border = C.border( p.border_focus, 1),
        }))
        C.push(children, ui.spacer { key = scope:child("lead_gap"), width = ui.fixed(8), height = ui.fixed(0) })

        for i = 1, #self.entries do
            C.push(children, entry.lower(self.entries[i]))
            C.push(children, ui.spacer { key = scope:child("gap_" .. tostring(i)), width = ui.fixed(8), height = ui.fixed(0) })
        end

        local surface_children = {
            ui.row {
                key = scope:child("header"),
                width = ui.grow(),
                height = ui.fixed(22),
                align_y = ui.align_y.center,
            } {
                T.section_title("DETAIL PANEL / DEVICE CHAIN", scope:child("title")),
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
        P.overlay_children(scope, self.identity, surface_children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 8,
            background = p.surface_detail,
            border = ui.border { top = 1, color = p.border_separator },
            padding = { left = 8, top = 8, right = 8, bottom = 8 },
        } (surface_children)

end


M.render = lower


function M.lower(self)
    return M.render(self)
end
return M
