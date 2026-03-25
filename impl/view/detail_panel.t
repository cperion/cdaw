-- impl/view/detail_panel.t
-- Lowering helper for View.DetailPanel.

local C = require("impl/view/_support/common")
local P = require("impl/view/components/placeholder_panel")

local M = {}

function M.lower(detail_panel, ctx)
    if detail_panel == nil then return nil end
    if detail_panel.kind == "DeviceChainDetail" then
        return detail_panel.chain:to_decl(ctx)
    elseif detail_panel.kind == "PianoRollDetail" then
        return detail_panel.piano_roll:to_decl(ctx)
    end
    C.record_diag(ctx, "warning", "view.detail.unsupported", detail_panel.kind)
    return P.fallback_node(ctx, "detail/unsupported", "Unsupported detail panel", detail_panel.kind)
end

return M
