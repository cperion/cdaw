-- impl/view/device_chain/entry.t
-- Lowering helper for View.DeviceEntry.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local B = require("impl/view/components/button")
local P = require("impl/view/components/placeholder_panel")

local M = {}

function M.lower(entry, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local entry_scope = C.make_scope(ctx, entry.identity, C.identity_key(entry.identity))
    local toggle_cmd = C.find_command(entry.commands, V.DECCToggleDeviceEnabled)

    local children = {
        T.strong_label(ctx, C.device_name(ctx, entry.device_ref), {
            key = entry_scope:child("title"),
            width = ui.grow(),
            font_size = 12,
        }),
        T.quiet_label(ctx, "Native device", {
            key = entry_scope:child("kind"),
            width = ui.grow(),
            font_size = 11,
        }),
        ui.spacer { key = entry_scope:child("grow"), width = ui.fixed(0), height = ui.grow() },
        B.flat_button(ctx, "Enabled", toggle_cmd and toggle_cmd.action_id or nil, {
            key = entry_scope:child("enable"),
            width = ui.grow(),
        }),
    }
    P.overlay_children(ctx, entry_scope, entry.device_ref or entry.identity, children)

    return ui.column {
        key = entry_scope,
        width = ui.fixed(140),
        height = ui.fixed(150),
        gap = 8,
        padding = { left = 10, top = 10, right = 10, bottom = 10 },
        background = p.surface_device,
        border = C.border(ctx, p.border_authored, 1),
    } (children)
end

return M
