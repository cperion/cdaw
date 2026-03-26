-- impl/view/arrangement/lane.t
-- Lowering helper for View.ArrangementLane.


local C = require("src/view/common")
local H = require("src/view/components/track_header")
local P = require("src/view/components/placeholder_panel")

local M = {}

function M.lower(lane, ctx, selection)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = C.make_scope(ctx, lane.identity, "arrangement_lane")
    local body_scope = C.make_scope(ctx, lane.body.identity, C.identity_key(lane.identity) .. "/body")

    local clip_children = {}
    for i = 1, #lane.body.clips do
        local clip = lane.body.clips[i]
        local info = C.clip_layout(ctx, clip.clip_ref) or {
            offset = 16,
            width = 96,
            label = C.clip_label(ctx, clip.clip_ref),
        }
        if info.offset > 0 then
            C.push(clip_children, ui.spacer {
                key = body_scope:child("pre_" .. tostring(clip.clip_ref.clip_id)),
                width = ui.fixed(info.offset),
                height = ui.fixed(0),
            })
        end
        local selected = C.selection_is_clip(selection, clip.clip_ref)
        local select_cmd = C.find_command(clip.commands, "ACCSelectClip")
        local clip_scope = C.make_scope(ctx, clip.identity, C.identity_key(clip.identity))
        local clip_button = ui.button {
            key = clip_scope:child("base"),
            width = ui.fixed(info.width),
            height = ui.fixed(20),
            padding = { left = 6, top = 1, right = 6, bottom = 1 },
            text = info.label,
            action = select_cmd and select_cmd.action_id or nil,
            background = selected and p.clip_selected_bg or p.clip_bg,
            border = C.border(ctx, selected and p.border_selected or p.clip_border, 1),
            text_color = p.text_primary,
            font_size = 11,
        }
        C.push(clip_children, P.wrap_node(ctx, clip_scope, clip.identity, clip_button, {
            width = ui.fixed(info.width),
            height = ui.fixed(20),
        }))
        C.push(clip_children, ui.spacer {
            key = body_scope:child("gap_" .. tostring(i)),
            width = ui.fixed(8),
            height = ui.fixed(0),
        })
    end

    local children = {
        ui.column {
            key = C.make_scope(ctx, lane.header.identity, C.identity_key(lane.header.identity)),
            width = ui.fixed(168),
            height = ui.grow(),
            background = p.surface_track_column,
            border = ui.border { right = 1, bottom = 1, color = p.border_separator },
            padding = { left = 4, top = 4, right = 4, bottom = 4 },
        } {
            H.lower(lane.header.track_header, ctx, selection),
        },
        ui.row {
            key = body_scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
            align_y = ui.align_y.center,
            padding = { left = 8, top = 0, right = 8, bottom = 0 },
            background = p.surface_arrangement_canvas,
        } (clip_children),
    }
    P.overlay_children(ctx, scope, lane.identity, children)

    return ui.row {
        key = scope,
        width = ui.grow(),
        height = ui.fixed(44),
        gap = 0,
        background = p.surface_arrangement_lane,
        border = ui.border { bottom = 1, color = p.border_separator },
    } (children)
end

return M
