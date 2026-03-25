-- impl/view/piano_roll/view.t
-- View.PianoRollView:to_decl()

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.piano_roll_view.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local P = require("impl/view/components/placeholder_panel")

local function note_name(pitch)
    local names = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
    local octave = math.floor(pitch / 12) - 1
    return names[(pitch % 12) + 1] .. tostring(octave)
end

local function piano_variant(piano_roll)
    local key_space = piano_roll.identity and tostring(piano_roll.identity.key_space or "") or ""
    local is_editor = key_space:find("editor_", 1, true) == 1
    return {
        is_editor = is_editor,
        keyboard_w = is_editor and 84 or 72,
        ruler_left_w = is_editor and 84 or 72,
        row_h = is_editor and 16 or 20,
        note_h = is_editor and 12 or 18,
        width_per_beat = is_editor and 122 or 88,
        header_h = is_editor and 18 or 24,
        ruler_h = is_editor and 18 or 24,
        velocity_h = is_editor and 0 or 84,
        font_size = is_editor and 10 or 11,
        key_font_size = is_editor and 9 or 10,
    }
end

local function row_background(ctx, pitch, highest_pitch)
    local p = C.palette(ctx)
    local is_black = (pitch % 12) == 1 or (pitch % 12) == 3 or (pitch % 12) == 6 or (pitch % 12) == 8 or (pitch % 12) == 10
    if pitch == highest_pitch or (pitch % 12) == 0 then
        return p.surface_arrangement_lane
    end
    return is_black and p.surface_inset or p.surface_arrangement_canvas
end

local function build_note_row(notes, pitch, piano_roll, variant, ctx, scope)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local beat_span = math.max(1.0, piano_roll.grid.visible_end_beats - piano_roll.grid.visible_start_beats)
    local width_per_beat = variant.width_per_beat
    local children = {}
    local placed_x = 0

    table.sort(notes, function(a, b)
        if a.start_beats == b.start_beats then
            return a.note_ref.note_id < b.note_ref.note_id
        end
        return a.start_beats < b.start_beats
    end)

    for i = 1, #notes do
        local note = notes[i]
        local start_offset = math.max(0, (note.start_beats - piano_roll.grid.visible_start_beats) * width_per_beat)
        local pre = start_offset - placed_x
        if pre > 0 then
            C.push(children, ui.spacer {
                key = scope:child("pre_" .. tostring(note.note_ref.note_id)),
                width = ui.fixed(pre),
                height = ui.fixed(0),
            })
        end

        local select_cmd = C.find_command(note.commands, V.PRCCSelectNotes)
        local note_width = math.max(22, (note.end_beats - note.start_beats) * width_per_beat)
        C.push(children, ui.button {
            key = C.make_scope(ctx, note.identity, C.identity_key(note.identity)),
            width = ui.fixed(note_width),
            height = ui.fixed(variant.note_h),
            padding = { left = 4, top = 0, right = 4, bottom = 0 },
            text = note_name(note.pitch),
            action = select_cmd and select_cmd.action_id or nil,
            background = note.selected and p.clip_selected_bg or p.clip_bg,
            border = C.border(ctx, note.selected and p.border_selected or p.clip_border, 1),
            text_color = p.text_primary,
            font_size = variant.font_size,
        })
        placed_x = start_offset + note_width
        C.push(children, ui.spacer {
            key = scope:child("gap_" .. tostring(i)),
            width = ui.fixed(4),
            height = ui.fixed(0),
        })
    end

    local total_width = beat_span * width_per_beat + 48
    if total_width > placed_x then
        C.push(children, ui.spacer {
            key = scope:child("tail"),
            width = ui.fixed(total_width - placed_x),
            height = ui.fixed(0),
        })
    end

    return ui.row {
        key = scope,
        width = ui.fit(),
        height = ui.fixed(variant.row_h),
        gap = 0,
        align_y = ui.align_y.center,
        background = row_background(ctx, pitch, piano_roll.keyboard.highest_pitch),
        border = ui.border { bottom = 1, color = p.border_separator },
    } (children)
end

local function lower_velocity_lane(piano_roll, variant, ctx, scope)
    if piano_roll.velocity_lane == nil or variant.velocity_h <= 0 then return nil end
    local ui = ctx.ui
    local p = C.palette(ctx)
    local width_per_beat = variant.width_per_beat
    local beat_span = math.max(1.0, piano_roll.grid.visible_end_beats - piano_roll.grid.visible_start_beats)
    local children = {}
    local placed_x = 0

    for i = 1, #piano_roll.velocity_lane.bars do
        local bar = piano_roll.velocity_lane.bars[i]
        local note = nil
        for j = 1, #piano_roll.notes do
            if C.semantic_ref_eq(piano_roll.notes[j].note_ref, bar.note_ref) then
                note = piano_roll.notes[j]
                break
            end
        end
        local start_beats = note and note.start_beats or piano_roll.grid.visible_start_beats
        local x = math.max(0, (start_beats - piano_roll.grid.visible_start_beats) * width_per_beat)
        local pre = x - placed_x
        if pre > 0 then
            C.push(children, ui.spacer {
                key = scope:child("pre_" .. tostring(i)),
                width = ui.fixed(pre),
                height = ui.fixed(0),
            })
        end
        local cmd = C.find_command(bar.commands, V.PRCCSetVelocity)
        local bar_max_h = variant.velocity_h - 14
        local h = math.max(10, math.floor((bar.value / 127.0) * bar_max_h))
        C.push(children, ui.spacer {
            key = scope:child("bar_gap_" .. tostring(i)),
            width = ui.fixed(0),
            height = ui.fixed(bar_max_h - h),
        })
        C.push(children, ui.button {
            key = C.make_scope(ctx, bar.identity, C.identity_key(bar.identity)),
            width = ui.fixed(16),
            height = ui.fixed(h),
            padding = { left = 0, top = 0, right = 0, bottom = 0 },
            text = "",
            action = cmd and cmd.action_id or nil,
            background = bar.selected and p.clip_selected_bg or p.clip_bg,
            border = C.border(ctx, bar.selected and p.border_selected or p.clip_border, 1),
        })
        placed_x = x + 16
        C.push(children, ui.spacer {
            key = scope:child("gap_" .. tostring(i)),
            width = ui.fixed(6),
            height = ui.fixed(0),
        })
    end

    local total_width = beat_span * width_per_beat + 48
    if total_width > placed_x then
        C.push(children, ui.spacer {
            key = scope:child("tail"),
            width = ui.fixed(total_width - placed_x),
            height = ui.fixed(0),
        })
    end

    return ui.row {
        key = scope,
        width = ui.fit(),
        height = ui.fixed(variant.velocity_h),
        gap = 0,
        align_y = ui.align_y.bottom,
        background = p.surface_panel,
        border = ui.border { top = 1, color = p.border_separator },
        padding = { left = 8, top = 4, right = 8, bottom = 4 },
    } (children)
end

function V.PianoRollView:to_decl(ctx)
    return diag.wrap(ctx, "view.piano_roll_view.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "piano_roll")
        local variant = piano_variant(self)
        local pitch_children = {}
        local key_children = {}
        local notes_by_pitch = {}

        for i = 1, #self.notes do
            local note = self.notes[i]
            local bucket = notes_by_pitch[note.pitch]
            if bucket == nil then
                bucket = {}
                notes_by_pitch[note.pitch] = bucket
            end
            C.push(bucket, note)
        end

        for pitch = self.keyboard.highest_pitch, self.keyboard.lowest_pitch, -1 do
            local key_scope = scope:child("key_" .. tostring(pitch))
            local is_black = (pitch % 12) == 1 or (pitch % 12) == 3 or (pitch % 12) == 6 or (pitch % 12) == 8 or (pitch % 12) == 10
            C.push(key_children, ui.row {
                key = key_scope,
                width = ui.grow(),
                height = ui.fixed(variant.row_h),
                padding = { left = 6, top = 1, right = 6, bottom = 1 },
                background = is_black and p.surface_track_column or p.surface_ruler,
                border = ui.border { bottom = 1, color = p.border_separator },
                align_y = ui.align_y.center,
            } {
                T.quiet_label(ctx, note_name(pitch), {
                    key = key_scope:child("label"),
                    width = ui.grow(),
                    font_size = variant.key_font_size,
                    text_color = is_black and p.text_primary or p.text_muted,
                }),
            })
            C.push(pitch_children, build_note_row(notes_by_pitch[pitch] or {}, pitch, self, variant, ctx, scope:child("row_" .. tostring(pitch))))
        end

        local velocity_row = lower_velocity_lane(self, variant, ctx, scope:child("velocity"))
        local ruler_text = variant.is_editor and "1.1.1      1.1.2      1.1.3      1.1.4      1.2"
            or string.format("%.1f      %.1f      %.1f      %.1f", self.grid.visible_start_beats, self.grid.visible_start_beats + 1, self.grid.visible_start_beats + 2, self.grid.visible_start_beats + 3)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
            background = p.surface_detail,
        } {
            ui.row {
                key = scope:child("header"),
                width = ui.grow(),
                height = ui.fixed(variant.header_h),
                padding = { left = 8, top = 2, right = 8, bottom = 2 },
                background = p.surface_ruler,
                border = ui.border { bottom = 1, color = p.border_separator },
            } {
                T.section_title(ctx, variant.is_editor and "EDIT" or "EDIT / PIANO ROLL", scope:child("title")),
            },
            ui.row {
                key = scope:child("ruler_row"),
                width = ui.grow(),
                height = ui.fixed(variant.ruler_h),
                background = p.surface_ruler,
                border = ui.border { bottom = 1, color = p.border_separator },
            } {
                ui.spacer { key = scope:child("ruler_left"), width = ui.fixed(variant.ruler_left_w), height = ui.fixed(0) },
                T.quiet_label(ctx, ruler_text, {
                    key = scope:child("ruler_text"),
                    width = ui.grow(),
                    font_size = variant.key_font_size,
                    text_color = p.text_primary,
                }),
            },
            ui.row {
                key = scope:child("body"),
                width = ui.grow(),
                height = ui.grow(),
                gap = 0,
                background = p.surface_detail,
            } {
                ui.column {
                    key = scope:child("keyboard"),
                    width = ui.fixed(variant.keyboard_w),
                    height = ui.grow(),
                    gap = 0,
                    background = p.surface_track_column,
                    border = ui.border { right = 1, color = p.border_separator },
                } (key_children),
                ui.scroll_region {
                    key = scope:child("grid_scroll"),
                    width = ui.grow(),
                    height = ui.grow(),
                    horizontal = true,
                    vertical = true,
                    background = p.surface_arrangement_canvas,
                } {
                    ui.column {
                        key = scope:child("grid_rows"),
                        width = ui.fit(),
                        height = ui.fit(),
                        gap = 0,
                    } (pitch_children),
                },
            },
            velocity_row,
        }
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.piano_roll_view.to_decl", tostring(err))
    end)
end

return true
