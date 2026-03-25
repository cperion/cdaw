-- impl/view/browser/item.t
-- Lowering helper for View.BrowserItem.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local R = require("impl/view/components/list_row")
local P = require("impl/view/components/placeholder_panel")

local M = {}

function M.lower(item, ctx)
    local p = C.palette(ctx)
    local scope = C.make_scope(ctx, item.identity, C.identity_key(item.identity))
    local commit_cmd = C.find_command(item.commands, V.BCCCommitItem)
    local row = R.button_row(ctx, scope:child("base"), item.label,
        commit_cmd and commit_cmd.action_id or nil,
        {
            background = item.selected and p.surface_selected or p.surface_panel,
            text_color = item.disabled and p.text_disabled or p.text_primary,
        })
    return P.wrap_node(ctx, scope, item.identity, row, {
        width = ctx.ui.grow(),
        height = ctx.ui.fixed(22),
    })
end

return M
