-- impl/view/browser/item.t
-- Lowering helper for View.BrowserItem.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local R = require("impl/view/components/list_row")

local M = {}

function M.lower(item, ctx)
    local p = C.palette(ctx)
    local commit_cmd = C.find_command(item.commands, V.BCCCommitItem)
    return R.button_row(ctx, C.make_scope(ctx, item.identity, C.identity_key(item.identity)), item.label,
        commit_cmd and commit_cmd.action_id or nil,
        {
            background = item.selected and p.surface_selected or p.surface_panel,
            text_color = item.disabled and p.text_disabled or p.text_primary,
        })
end

return M
