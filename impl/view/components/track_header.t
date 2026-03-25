-- impl/view/components/track_header.t
-- Shared track-header lowering atom used by multiple View surfaces.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local B = require("impl/view/components/button")
local I = require("impl/view/components/icons")
local P = require("impl/view/components/placeholder_panel")

local M = {}

function M.lower(track_header, ctx, selection)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = C.make_scope(ctx, track_header.identity, "track_header")
    local selected = C.selection_is_track(selection, track_header.track_ref)
    local select_cmd = C.find_command(track_header.commands, V.THCCSelectTrack)

    local role_label = nil
    local height = 30
    local button_w = 16
    if track_header.role.kind == "ArrangementHeaderRole" then
        role_label = "HYBRID TRACK"
        height = 36
    elseif track_header.role.kind == "LauncherHeaderRole" then
        role_label = nil
        height = 28
    elseif track_header.role.kind == "MixerHeaderRole" then
        role_label = nil
        height = 26
    end

    local children = {
        ui.column {
            key = scope:child("color"),
            width = ui.fixed(3),
            height = ui.grow(),
            background = p.track_accent,
        } {},
        ui.column {
            key = scope:child("body"),
            width = ui.grow(),
            height = ui.grow(),
            gap = role_label and 1 or 0,
        } {
            T.strong_label(ctx, C.track_name(ctx, track_header.track_ref), {
                key = scope:child("title"),
                width = ui.grow(),
                font_size = 11,
            }),
            role_label and T.quiet_label(ctx, role_label, {
                key = scope:child("meta"),
                width = ui.grow(),
                font_size = 9,
                text_color = p.text_muted,
            }) or nil,
        },
        I.icon_button(ctx, scope:child("solo"), I.solo, nil, {
            size = button_w, icon_size = 14,
            icon_color = p.text_secondary,
        }),
        I.icon_button(ctx, scope:child("mute"), I.mute,
            select_cmd and select_cmd.action_id or nil, {
            size = button_w, icon_size = 14,
            icon_color = selected and p.text_primary or p.text_secondary,
        }),
    }
    P.overlay_children(ctx, scope, track_header.identity, children)

    return ui.row {
        key = scope,
        width = ui.grow(),
        height = ui.fixed(height),
        padding = { left = 6, top = 3, right = 6, bottom = 3 },
        gap = 6,
        align_y = ui.align_y.center,
        background = selected and p.surface_selected or p.surface_track_header,
        border = C.border(ctx, selected and p.border_selected or p.border_track_header, 1),
    } (children)
end

return M
