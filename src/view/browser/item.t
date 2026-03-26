-- impl/view/browser/item.t
-- Lowering helper for View.BrowserItem.


local C = require("src/view/common")
local R = require("src/view/components/list_row")
local P = require("src/view/components/placeholder_panel")

local M = {}

function M.lower(item)
    local p = C.palette()
    local scope = C.make_scope(item.identity, C.identity_key(item.identity))
    local commit_cmd = C.find_command(item.commands, "BCCCommitItem")
    local row = R.button_row(scope:child("base"), item.label,
        commit_cmd and commit_cmd.action_id or nil,
        {
            background = item.selected and p.surface_selected or p.surface_panel,
            text_color = item.disabled and p.text_disabled or p.text_primary,
        })
    return P.wrap_node(scope, item.identity, row, {
        width = C.ui.grow(),
        height = C.ui.fixed(22),
    })
end

return M
