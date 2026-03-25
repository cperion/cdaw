-- impl/view/launcher/column.t
-- Lowering helpers for the Launcher family.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local B = require("impl/view/components/button")
local H = require("impl/view/components/track_header")

local M = {}

local function slot_label(slot, ctx)
    if slot.content_kind.kind == "LauncherClipSlot" and slot.clip_ref ~= nil then
        return C.clip_label(ctx, slot.clip_ref)
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

local function slot_border(slot, selection, ctx, p)
    if C.selection_is_slot(selection, slot.slot_ref) then
        return C.border(ctx, p.border_selected, 1)
    elseif slot.content_kind.kind == "LauncherClipSlot" then
        return C.border(ctx, p.clip_border, 1)
    elseif slot.content_kind.kind == "LauncherStopSlot" then
        return C.border(ctx, p.border_control, 1)
    end
    return C.border(ctx, p.border_subtle, 1)
end

function M.lower_scene(scene, ctx, selection)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = C.make_scope(ctx, scene.identity, C.identity_key(scene.identity))
    local selected = C.selection_is_scene(selection, scene.scene_ref)
    local cmd = C.find_command(scene.commands, V.LCCLaunchScene)
        or C.find_command(scene.commands, V.LCCSelectScene)

    return ui.button {
        key = scope,
        width = ui.grow(),
        height = ui.fixed(22),
        padding = { left = 4, top = 1, right = 4, bottom = 1 },
        text = tostring(scene.scene_ref.scene_id),
        action = cmd and cmd.action_id or nil,
        background = selected and p.surface_selected or p.surface_control,
        border = C.border(ctx, selected and p.border_selected or p.border_control, 1),
        text_color = p.text_primary,
        font_size = 10,
    }
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

function M.lower_stop_cell(cell, ctx)
    if cell == nil then return nil end
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = C.make_scope(ctx, cell.identity, C.identity_key(cell.identity))
    local cmd = C.find_command(cell.commands, V.LCCStopTrack)

    return B.flat_button(ctx, "■", cmd and cmd.action_id or nil, {
        key = scope,
        width = ui.grow(),
        height = ui.fixed(18),
        padding = { left = 0, top = 0, right = 0, bottom = 0 },
        background = p.surface_inset,
        border = C.border(ctx, p.border_control, 1),
        text_color = p.text_muted,
        font_size = 12,
    })
end

function M.lower_column(column, stop_cell, ctx, selection)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = C.make_scope(ctx, column.identity, C.identity_key(column.identity))
    local slot_children = {}

    for i = 1, #column.slots do
        local slot = column.slots[i]
        local slot_scope = C.make_scope(ctx, slot.identity, C.identity_key(slot.identity))
        local launch_cmd = C.find_command(slot.commands, V.LCCLaunchSlot)
        local select_cmd = C.find_command(slot.commands, V.LCCSelectSlot)
        local action = (launch_cmd and launch_cmd.action_id)
            or (select_cmd and select_cmd.action_id)

        C.push(slot_children, ui.button {
            key = slot_scope,
            width = ui.grow(),
            height = ui.fixed(22),
            padding = { left = 4, top = 1, right = 4, bottom = 1 },
            text = slot_label(slot, ctx),
            action = action,
            background = slot_background(slot, selection, p),
            border = slot_border(slot, selection, ctx, p),
            text_color = p.text_primary,
            font_size = 10,
        })
    end

    return ui.column {
        key = scope,
        width = ui.fixed(84),
        height = ui.grow(),
        gap = 4,
        padding = { left = 0, top = 0, right = 0, bottom = 0 },
    } {
        H.lower(column.header, ctx, selection),
        M.lower_stop_cell(stop_cell, ctx),
        ui.column {
            key = scope:child("slots"),
            width = ui.grow(),
            height = ui.fit(),
            gap = 4,
        } (slot_children),
    }
end

return M
