-- impl/view/detail_panel.t
-- Lowering helper for View.DetailPanel.

local C = require("src/view/common")
local P = require("src/view/components/placeholder_panel")
local chain_view = require("src/view/device_chain/view")
local device_view = require("src/view/device_view")
local grid_patch_view = require("src/view/grid_patch_view")
local piano_roll_view = require("src/view/piano_roll/view")

local M = {}

function M.lower(detail_panel)
    if detail_panel == nil then return nil end
    if detail_panel.kind == "DeviceChainDetail" then
        return chain_view.render(detail_panel.chain)
    elseif detail_panel.kind == "DeviceDetail" then
        return device_view.render(detail_panel.device)
    elseif detail_panel.kind == "GridDetail" then
        return grid_patch_view.render(detail_panel.patch)
    elseif detail_panel.kind == "PianoRollDetail" then
        return piano_roll_view.render(detail_panel.piano_roll)
    end
    C.record_diag("warning", "view.detail.unsupported", detail_panel.kind)
    return P.fallback_node("detail/unsupported", "Unsupported detail panel", detail_panel.kind)
end

return M
