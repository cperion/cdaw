-- impl/editor/clip.t
-- Editor.Clip:lower, Editor.NoteRegion:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.clip.lower", "real")
diag.status("editor.note_region.lower", "real")


function D.Editor.NoteRegion:lower(ctx)
    return diag.wrap(ctx, "editor.note_region.lower", "real", function()
        -- Convert notes
        local notes = L()
        for i = 1, #self.notes do
            local n = self.notes[i]
            notes[i] = D.Authored.Note(
                n.id, n.pitch,
                n.start_beats, n.duration_beats,
                n.velocity, n.release_velocity,
                n.muted
            )
        end

        -- Convert expression lanes
        local expr_lanes = L()
        for i = 1, #self.expr_lanes do
            local lane = self.expr_lanes[i]
            local points = L()
            for j = 1, #lane.points do
                local pt = lane.points[j]
                points[j] = D.Authored.NoteExprPoint(
                    pt.time_beats, pt.value, pt.note_id
                )
            end
            expr_lanes[i] = D.Authored.NoteExprLane(
                F.note_expr_kind_e2a(lane.kind), points
            )
        end

        -- Intern as a NoteAsset — use a context-provided id allocator
        -- or a simple fallback id for now.
        local asset_id = ctx and ctx.alloc_note_asset_id
            and ctx:alloc_note_asset_id() or 0
        return D.Authored.NoteAsset(asset_id, notes, expr_lanes, 0, 0)
    end, function()
        return F.authored_note_asset(0)
    end)
end

function D.Editor.Clip:lower(ctx)
    return diag.wrap(ctx, "editor.clip.lower", "real", function()
        -- Convert content
        local content
        if self.content.kind == "AudioContent" then
            content = D.Authored.AudioContent(self.content.audio_asset_id)
        elseif self.content.kind == "NoteContent" then
            local note_asset = self.content.body:lower(ctx)
            -- The NoteRegion:lower returns a NoteAsset; we intern it and
            -- reference by id.
            if ctx and ctx.intern_note_asset then
                ctx:intern_note_asset(note_asset)
            end
            content = D.Authored.NoteContent(note_asset.id)
        else
            content = D.Authored.AudioContent(0)
        end

        -- Convert fades
        local fade_in = nil
        if self.fade_in then
            fade_in = D.Authored.FadeSpec(
                self.fade_in.duration_beats,
                F.fade_curve_e2a(self.fade_in.curve)
            )
        end
        local fade_out = nil
        if self.fade_out then
            fade_out = D.Authored.FadeSpec(
                self.fade_out.duration_beats,
                F.fade_curve_e2a(self.fade_out.curve)
            )
        end

        return D.Authored.Clip(
            self.id,
            content,
            self.start_beats,
            self.duration_beats,
            self.source_offset_beats,
            self.lane,
            self.muted,
            self.gain:lower(ctx),
            fade_in,
            fade_out
        )
    end, function()
        return F.authored_clip(self.id)
    end)
end

return true
