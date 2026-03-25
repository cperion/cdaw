-- impl/view/mixer/strip.t
-- Lowering helpers for View.MixerStrip.
-- Strip layout: header → I/O → sends → (spacer) → meter/fader → vol readout.
-- The meter/fader area has a FIXED height so all strips align visually
-- regardless of send count. The spacer absorbs height differences.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local B = require("impl/view/components/button")
local I = require("impl/view/components/icons")

local M = {}

-- ── Header: accent strip + track name + arm/solo/mute ──

local function lower_strip_header(strip, ctx, selection, scope)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local selected = C.selection_is_track(selection, strip.track_ref)

    return ui.column {
        key = scope:child("header"),
        width = ui.grow(),
        height = ui.fit(),
        gap = 0,
    } {
        -- Accent strip (track color identity)
        ui.column {
            key = scope:child("accent"),
            width = ui.grow(),
            height = ui.fixed(3),
            background = p.track_accent,
        } {},
        -- Name + toggles
        ui.column {
            key = scope:child("header_body"),
            width = ui.grow(),
            height = ui.fit(),
            gap = 4,
            padding = { left = 6, top = 4, right = 6, bottom = 4 },
            background = selected and p.surface_selected or p.surface_track_header,
        } {
            T.strong_label(ctx, C.track_name(ctx, strip.track_ref), {
                key = scope:child("title"),
                width = ui.grow(),
                font_size = 11,
            }),
            ui.row {
                key = scope:child("toggles"),
                width = ui.grow(),
                height = ui.fixed(20),
                gap = 3,
                align_y = ui.align_y.center,
            } {
                I.icon_button(ctx, scope:child("arm"), I.arm, nil, {
                    size = 20, icon_size = 8,
                    icon_color = p.state_record,
                    background = p.surface_record,
                    border = C.border(ctx, p.border_record, 1),
                }),
                I.icon_button(ctx, scope:child("solo"), I.solo, nil, {
                    size = 20, icon_size = 16,
                    icon_color = p.text_secondary,
                }),
                I.icon_button(ctx, scope:child("mute"), I.mute, nil, {
                    size = 20, icon_size = 16,
                    icon_color = p.text_secondary,
                }),
            },
        },
    }
end

-- ── I/O block: input + output routing ──

local function lower_io_block(strip, ctx, scope)
    local ui = ctx.ui
    local p = C.palette(ctx)
    return ui.column {
        key = scope:child("io"),
        width = ui.grow(),
        height = ui.fit(),
        gap = 1,
    } {
        ui.label {
            key = scope:child("input"),
            width = ui.grow(),
            height = ui.fixed(18),
            padding = { left = 6, top = 0, right = 6, bottom = 0 },
            text = "All ins",
            background = p.surface_inset,
            text_color = p.text_secondary,
            font_size = 10,
        },
        ui.label {
            key = scope:child("output"),
            width = ui.grow(),
            height = ui.fixed(18),
            padding = { left = 6, top = 0, right = 6, bottom = 0 },
            text = "Master",
            background = p.surface_inset,
            text_color = p.text_secondary,
            font_size = 10,
        },
    }
end

-- ── Send slots ──

local function lower_sends(strip, ctx, scope)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local children = {}
    for i = 1, #strip.sends do
        local send = strip.sends[i]
        local cmd = C.find_command(send.commands, V.MCCSetSendLevel)
        C.push(children, B.flat_button(ctx, "FX " .. tostring(send.send_ref.send_id), cmd and cmd.action_id or nil, {
            key = C.make_scope(ctx, send.identity, C.identity_key(send.identity)),
            width = ui.grow(),
            height = ui.fixed(18),
            padding = { left = 6, top = 0, right = 6, bottom = 0 },
            font_size = 10,
            background = p.surface_inset,
            border = nil,
        }))
    end
    if #children == 0 then return nil end
    return ui.column {
        key = scope:child("sends"),
        width = ui.grow(),
        height = ui.fit(),
        gap = 1,
    } (children)
end

-- ── Meter + Fader (FIXED height for cross-strip alignment) ──

local METER_FADER_HEIGHT = 200

local function lower_meter_fader(strip, ctx, scope)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local pan_cmd = C.find_command(strip.pan.commands, V.MCCSetTrackPan)
    local vol_cmd = C.find_command(strip.volume.commands, V.MCCSetTrackVolume)

    return ui.column {
        key = scope:child("signal"),
        width = ui.grow(),
        height = ui.fixed(METER_FADER_HEIGHT),
        gap = 4,
        padding = { left = 4, top = 4, right = 4, bottom = 4 },
    } {
        -- Pan row
        ui.row {
            key = scope:child("pan_row"),
            width = ui.grow(),
            height = ui.fixed(14),
            gap = 4,
            align_y = ui.align_y.center,
        } {
            T.quiet_label(ctx, "Pan", { key = scope:child("pan_lbl"), font_size = 9, width = ui.fit() }),
            ui.spacer { key = scope:child("pan_sp"), width = ui.grow(), height = ui.fixed(0) },
            T.quiet_label(ctx, "C", { key = scope:child("pan_val"), font_size = 9, text_color = p.text_secondary, width = ui.fit() }),
        },
        -- Pan control
        B.flat_button(ctx, "Pan", pan_cmd and pan_cmd.action_id or nil, {
            key = scope:child("pan_ctl"),
            width = ui.grow(),
            height = ui.fixed(18),
            padding = { left = 0, top = 0, right = 0, bottom = 0 },
            font_size = 10,
            background = p.surface_inset,
            border = C.border(ctx, p.border_subtle, 1),
        }),
        -- Meter + fader combined area (grows within the fixed signal block)
        ui.row {
            key = scope:child("meter_fader"),
            width = ui.grow(),
            height = ui.grow(),
            gap = 4,
        } {
            -- Meter column (narrow)
            ui.column {
                key = scope:child("meter_col"),
                width = ui.fixed(12),
                height = ui.grow(),
                gap = 0,
            } {
                ui.column {
                    key = scope:child("meter_track"),
                    width = ui.grow(),
                    height = ui.grow(),
                    background = p.surface_inset,
                    border = C.border(ctx, p.border_subtle, 1),
                    padding = { left = 2, top = 2, right = 2, bottom = 2 },
                    gap = 0,
                } {
                    ui.spacer { key = scope:child("meter_gap"), width = ui.fixed(0), height = ui.grow() },
                    ui.column {
                        key = scope:child("meter_fill"),
                        width = ui.grow(),
                        height = ui.fixed(24),
                        background = p.track_accent,
                    } {},
                },
            },
            -- Fader column
            ui.column {
                key = scope:child("fader_col"),
                width = ui.grow(),
                height = ui.grow(),
                gap = 0,
            } {
                ui.column {
                    key = scope:child("fader_track"),
                    width = ui.grow(),
                    height = ui.grow(),
                    background = p.surface_inset,
                    border = C.border(ctx, p.border_subtle, 1),
                    padding = { left = 8, top = 4, right = 8, bottom = 4 },
                    gap = 0,
                } {
                    ui.spacer { key = scope:child("fader_gap"), width = ui.fixed(0), height = ui.grow() },
                    ui.button {
                        key = scope:child("fader_thumb"),
                        width = ui.grow(),
                        height = ui.fixed(10),
                        padding = { left = 0, top = 0, right = 0, bottom = 0 },
                        text = "",
                        action = vol_cmd and vol_cmd.action_id or nil,
                        background = p.surface_control_hover,
                        border = C.border(ctx, p.border_strong, 1),
                    },
                    ui.column {
                        key = scope:child("fader_fill"),
                        width = ui.grow(),
                        height = ui.fixed(40),
                        background = p.clip_bg,
                    } {},
                },
            },
        },
        -- Volume readout
        ui.row {
            key = scope:child("vol_row"),
            width = ui.grow(),
            height = ui.fixed(14),
            gap = 4,
            align_y = ui.align_y.center,
        } {
            T.quiet_label(ctx, "Vol", { key = scope:child("vol_lbl"), font_size = 9, width = ui.fit() }),
            ui.spacer { key = scope:child("vol_sp"), width = ui.grow(), height = ui.fixed(0) },
            T.quiet_label(ctx, "-10.0", { key = scope:child("vol_val"), font_size = 9, text_color = p.track_accent, width = ui.fit() }),
        },
    }
end

-- ── Full strip assembly ──

function M.lower(strip, ctx, selection)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = C.make_scope(ctx, strip.identity, C.identity_key(strip.identity))

    local children = {
        lower_strip_header(strip, ctx, selection, scope),
        lower_io_block(strip, ctx, scope),
    }
    local sends = lower_sends(strip, ctx, scope)
    if sends then C.push(children, sends) end
    -- Spacer absorbs height differences from varying send counts,
    -- keeping the meter/fader at a stable bottom position.
    C.push(children, ui.spacer {
        key = scope:child("flex"),
        width = ui.fixed(0),
        height = ui.grow(),
    })
    C.push(children, lower_meter_fader(strip, ctx, scope))

    return ui.column {
        key = scope,
        width = ui.fixed(120),
        height = ui.grow(),
        gap = 4,
        padding = { left = 0, top = 0, right = 0, bottom = 0 },
        background = p.surface_panel,
        border = C.border(ctx, p.border_subtle, 1),
    } (children)
end

return M
