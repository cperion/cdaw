-- impl/editor/clip.t
-- Editor.Clip:lower, Editor.NoteRegion:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.clip.lower", "real")
diag.status("editor.note_region.lower", "real")

local function fold_id(acc, n)
    n = math.floor(tonumber(n) or 0)
    acc = (acc * 1103515245 + n + 12345) % 2147483647
    if acc <= 0 then acc = 1 end
    return acc
end

local function default_note_asset_id(region)
    local acc = 17
    for i = 1, #region.notes do
        local n = region.notes[i]
        acc = fold_id(acc, n.id)
        acc = fold_id(acc, n.pitch)
        acc = fold_id(acc, (n.start_beats or 0) * 960)
        acc = fold_id(acc, (n.duration_beats or 0) * 960)
        acc = fold_id(acc, n.velocity)
    end
    for i = 1, #region.expr_lanes do
        local lane = region.expr_lanes[i]
        acc = fold_id(acc, i)
        for j = 1, #lane.points do
            local pt = lane.points[j]
            acc = fold_id(acc, (pt.time_beats or 0) * 960)
            acc = fold_id(acc, (pt.value or 0) * 1000)
            acc = fold_id(acc, pt.note_id or -1)
        end
    end
    return acc
end

local lower_note_region_as = terralib.memoize(function(self, asset_id)
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

    return D.Authored.NoteAsset(asset_id, notes, expr_lanes, 0, 0)
end)

local lower_clip = terralib.memoize(function(self)
    local content

    if self.content.kind == "AudioContent" then
        content = D.Authored.AudioContent(self.content.audio_asset_id)
    elseif self.content.kind == "NoteContent" then
        content = D.Authored.NoteContent(self.id)
    else
        content = D.Authored.AudioContent(0)
    end

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
        self.gain:lower(),
        fade_in,
        fade_out
    )
end)

function D.Editor.NoteRegion:lower()
    return diag.wrap(nil, "editor.note_region.lower", "real", function()
        return lower_note_region_as(self, default_note_asset_id(self))
    end, function()
        return F.authored_note_asset(0)
    end)
end

function D.Editor.Clip:lower()
    return diag.wrap(nil, "editor.clip.lower", "real", function()
        return lower_clip(self)
    end, function()
        return F.authored_clip(self.id)
    end)
end

return true
