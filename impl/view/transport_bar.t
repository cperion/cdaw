-- impl/view/transport_bar.t
-- View.TransportBar:to_decl()
-- Bitwig-style transport spine: flat row, no group boxing.
-- design-tokens: region.transport.bg = surface.panel

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.transport_bar.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local B = require("impl/view/components/button")
local I = require("impl/view/components/icons")
local P = require("impl/view/components/placeholder_panel")

function V.TransportBar:to_decl(ctx)
    return diag.wrap(ctx, "view.transport_bar.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "transport")
        local play_cmd = C.find_command(self.commands, V.TCCPlay)
        local stop_cmd = C.find_command(self.commands, V.TCCStop)
        local rec_cmd = C.find_command(self.commands, V.TCCToggleRecord)
        local loop_cmd = C.find_command(self.commands, V.TCCToggleLoop)

        -- Left cluster: project + transport controls
        local left_children = {
            B.flat_button(ctx, "FILE", nil, {
                key = scope:child("file"),
                width = ui.fixed(38),
                height = ui.fixed(24),
                padding = { left = 0, top = 0, right = 0, bottom = 0 },
                font_size = 10,
            }),
            B.flat_button(ctx, "PLAY", play_cmd and play_cmd.action_id or nil, {
                key = scope:child("play"),
                width = ui.fixed(38),
                height = ui.fixed(24),
                padding = { left = 0, top = 0, right = 0, bottom = 0 },
                font_size = 10,
            }),
            I.icon_button(ctx, scope:child("stop"), I.stop,
                stop_cmd and stop_cmd.action_id or nil, {
                size = 24, icon_size = 12, icon_color = p.text_primary,
            }),
            I.icon_button(ctx, scope:child("record"), I.record,
                rec_cmd and rec_cmd.action_id or nil, {
                size = 24, icon_size = 14, icon_color = p.state_record,
                background = p.surface_record,
                border = C.border(ctx, p.border_record, 1),
            }),
        }
        if self.show_loop then
            C.push(left_children, I.icon_button(ctx, scope:child("loop"), I.loop,
                loop_cmd and loop_cmd.action_id or nil, {
                size = 24, icon_size = 12, icon_color = p.text_primary,
            }))
        end

        local left = ui.row {
            key = scope:child("left"),
            width = ui.fit(),
            height = ui.fit(),
            gap = 2,
            align_y = ui.align_y.center,
        } (left_children)

        -- Center: tempo/time display (instrument-like, high legibility)
        local center = ui.row {
            key = scope:child("center"),
            width = ui.fit(),
            height = ui.fixed(28),
            gap = 8,
            align_y = ui.align_y.center,
            padding = { left = 12, top = 0, right = 12, bottom = 0 },
            background = p.surface_inset,
            border = C.border(ctx, p.border_subtle, 1),
        } {
            T.mono_label(ctx, "110.00", {
                key = scope:child("tempo"),
                font_size = 14,
                text_color = p.track_accent,
            }),
            T.mono_label(ctx, "1.1.1.00", {
                key = scope:child("bars"),
                font_size = 14,
                text_color = p.text_primary,
            }),
            T.quiet_label(ctx, "4/4", {
                key = scope:child("timesig"),
                font_size = 12,
                text_color = p.track_accent,
            }),
            T.mono_label(ctx, "0:00.000", {
                key = scope:child("clock"),
                font_size = 12,
                text_color = p.text_secondary,
            }),
        }

        -- Right cluster: ADD / EDIT
        local right = ui.row {
            key = scope:child("right"),
            width = ui.fit(),
            height = ui.fit(),
            gap = 2,
            align_y = ui.align_y.center,
        } {
            B.flat_button(ctx, "ADD", nil, {
                key = scope:child("add"),
                width = ui.fixed(36),
                height = ui.fixed(24),
                padding = { left = 0, top = 0, right = 0, bottom = 0 },
                font_size = 10,
            }),
            B.flat_button(ctx, "EDIT", nil, {
                key = scope:child("edit"),
                width = ui.fixed(36),
                height = ui.fixed(24),
                padding = { left = 0, top = 0, right = 0, bottom = 0 },
                font_size = 10,
                background = p.surface_selected,
                border = C.border(ctx, p.border_selected, 1),
            }),
        }

        return ui.row {
            key = scope,
            width = ui.grow(),
            height = ui.fixed(38),
            padding = { left = 6, top = 0, right = 6, bottom = 0 },
            gap = 0,
            align_y = ui.align_y.center,
            background = p.surface_transport,
            border = ui.border { bottom = 1, color = p.border_separator },
        } {
            left,
            ui.spacer { key = scope:child("grow_l"), width = ui.grow(), height = ui.fixed(0) },
            center,
            ui.spacer { key = scope:child("grow_r"), width = ui.grow(), height = ui.fixed(0) },
            right,
        }
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.transport_bar.to_decl", tostring(err))
    end)
end

return true
