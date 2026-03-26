-- impl/view/launcher/column.t
-- Lowering helpers for the Launcher family.


local C = require("src/view/common")
local B = require("src/view/components/button")
local H = require("src/view/components/track_header")
local P = require("src/view/components/placeholder_panel")

local M = {}

local function slot_label(slot)
    if slot.content_kind.kind == "LauncherClipSlot" and slot.clip_ref ~= nil then
        return C.clip_label(slot.clip_ref)
    elseif slot.content_kind.kind == "LauncherStopSlot" then
        return "Stop clip"
    end
    return "Empty"
end

local function slot_background(slot, selection, p)
    if C.selection_is_slot(selection, slot.slot_ref) then
        return p.surface_selected
    elseif slot.content_kind.kind == "LauncherClipSlot" then
        return p.clip_bg
    elseif slot.content_kind.kind == "LauncherStopSlot" then
        return p.surface_inset
    end
    return p.surface_panel
end

local function slot_border(slot, selection, p)
    if C.selection_is_slot(selection, slot.slot_ref) then
        return C.border( p.border_selected, 1)
    elseif slot.content_kind.kind == "LauncherClipSlot" then
        return C.border( p.clip_border, 1)
    elseif slot.content_kind.kind == "LauncherStopSlot" then
        return C.border( p.border_control, 1)
    end
    return C.border( p.border_subtle, 1)
end

function M.lower_scene(scene, selection)
    local ui = C.ui
    local p = C.palette()
    local scope = C.make_scope(scene.identity, C.identity_key(scene.identity))
    local selected = C.selection_is_scene(selection, scene.scene_ref)
    local cmd = C.find_command(scene.commands, "LCCLaunchScene")
        or C.find_command(scene.commands, "LCCSelectScene")

    local button = ui.button {
        key = scope:child("base"),
        width = ui.grow(),
        height = ui.fixed(22),
        padding = { left = 4, top = 1, right = 4, bottom = 1 },
        text = tostring(scene.scene_ref.scene_id),
        action = cmd and cmd.action_id or nil,
        background = selected and p.surface_selected or p.surface_control,
        border = C.border( selected and p.border_selected or p.border_control, 1),
        text_color = p.text_primary,
        font_size = 10,
    }
    return P.wrap_node(scope, scene.identity, button, {
        width = ui.grow(),
        height = ui.fixed(22),
    })
end

function M.find_stop_cell(stop_row, track_ref)
    if stop_row == nil then return nil end
    for i = 1, #stop_row.cells do
        local cell = stop_row.cells[i]
        if C.semantic_ref_eq(cell.track_ref, track_ref) then
            return cell
        end
    end
    return nil
end

function M.lower_stop_cell(cell)
    if cell == nil then return nil end
    local ui = C.ui
    local p = C.palette()
    local scope = C.make_scope(cell.identity, C.identity_key(cell.identity))
    local cmd = C.find_command(cell.commands, "LCCStopTrack")

    local button = B.flat_button("■", cmd and cmd.action_id or nil, {
        key = scope:child("base"),
        width = ui.grow(),
        height = ui.fixed(18),
        padding = { left = 0, top = 0, right = 0, bottom = 0 },
        background = p.surface_inset,
        border = C.border( p.border_control, 1),
        text_color = p.text_muted,
        font_size = 12,
    })
    return P.wrap_node(scope, cell.identity, button, {
        width = ui.grow(),
        height = ui.fixed(18),
    })
end

function M.lower_column(column, stop_cell, selection)
    local ui = C.ui
    local p = C.palette()
    local scope = C.make_scope(column.identity, C.identity_key(column.identity))
    local slot_children = {}

    for i = 1, #column.slots do
        local slot = column.slots[i]
        local slot_scope = C.make_scope(slot.identity, C.identity_key(slot.identity))
        local launch_cmd = C.find_command(slot.commands, "LCCLaunchSlot")
        local select_cmd = C.find_command(slot.commands, "LCCSelectSlot")
        local action = (launch_cmd and launch_cmd.action_id)
            or (select_cmd and select_cmd.action_id)

        local slot_button = ui.button {
            key = slot_scope:child("base"),
            width = ui.grow(),
            height = ui.fixed(22),
            padding = { left = 4, top = 1, right = 4, bottom = 1 },
            text = slot_label(slot),
            action = action,
            background = slot_background(slot, selection, p),
            border = slot_border(slot, selection, p),
            text_color = p.text_primary,
            font_size = 10,
        }
        C.push(slot_children, P.wrap_node(slot_scope, slot.identity, slot_button, {
            width = ui.grow(),
            height = ui.fixed(22),
        }))
    end

    local children = {
        H.lower(column.header, selection),
        M.lower_stop_cell(stop_cell),
        ui.column {
            key = scope:child("slots"),
            width = ui.grow(),
            height = ui.fit(),
            gap = 4,
        } (slot_children),
    }
    P.overlay_children(scope, column.identity, children)

    return ui.column {
        key = scope,
        width = ui.fixed(84),
        height = ui.grow(),
        gap = 4,
        padding = { left = 0, top = 0, right = 0, bottom = 0 },
    } (children)
end

return M
