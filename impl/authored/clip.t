-- impl/authored/clip.t
-- Authored.Clip:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.clip.resolve", "partial")


-- Fade curve → code: LinearFade=0, EqualPower=1, SCurve=2, ExpoFade=3
local fade_codes = { LinearFade = 0, EqualPower = 1, SCurve = 2, ExpoFade = 3 }

-- Content kind → code: AudioContent=0, NoteContent=1
local content_codes = { AudioContent = 0, NoteContent = 1 }

function D.Authored.Clip:resolve(ctx)
    return diag.wrap(ctx, "authored.clip.resolve", "partial", function()
        local ticks_per_beat = (ctx and ctx.ticks_per_beat) or 960

        local content_kind = content_codes[self.content.kind] or 0
        local asset_id = 0
        if self.content.kind == "AudioContent" then
            asset_id = self.content.audio_asset_id
        elseif self.content.kind == "NoteContent" then
            asset_id = self.content.note_asset_id
        end

        local gain_param = self.gain:resolve(ctx)

        local fade_in_tick = 0
        local fade_in_curve = 0
        if self.fade_in then
            fade_in_tick = self.fade_in.duration_beats * ticks_per_beat
            fade_in_curve = fade_codes[self.fade_in.curve and self.fade_in.curve.kind] or 0
        end

        local fade_out_tick = 0
        local fade_out_curve = 0
        if self.fade_out then
            fade_out_tick = self.fade_out.duration_beats * ticks_per_beat
            fade_out_curve = fade_codes[self.fade_out.curve and self.fade_out.curve.kind] or 0
        end

        return D.Resolved.Clip(
            self.id,
            content_kind,
            asset_id,
            self.start_beats * ticks_per_beat,
            self.duration_beats * ticks_per_beat,
            self.source_offset_beats * ticks_per_beat,
            self.lane,
            self.muted,
            gain_param.id,
            fade_in_tick, fade_in_curve,
            fade_out_tick, fade_out_curve
        )
    end, function()
        return F.resolved_clip(self.id)
    end)
end

return true
