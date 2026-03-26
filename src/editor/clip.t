-- impl2/editor/clip.t
-- Editor.Clip:lower, Editor.NoteRegion:lower

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

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

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    local function lower_note_region(self)
        local asset_id = default_note_asset_id(self)
        local notes = L()
        for i = 1, #self.notes do
            local n = self.notes[i]
            notes[i] = A.AuthoredNote(n.id, n.pitch, n.start_beats, n.duration_beats, n.velocity, n.release_velocity, n.muted)
        end
        local expr_lanes = L()
        for i = 1, #self.expr_lanes do
            local lane = self.expr_lanes[i]
            local points = L()
            for j = 1, #lane.points do
                local pt = lane.points[j]
                points[j] = A.NoteExprPoint(pt.time_beats, pt.value, pt.note_id)
            end
            expr_lanes[i] = A.NoteExprLane(maps.note_expr_kind(lane.kind), points)
        end
        return A.NoteAsset(asset_id, notes, expr_lanes, 0, 0)
    end

    local function lower_clip(self)
        local content
        if self.content.kind == "AudioContent" then
            content = A.AudioContent(self.content.audio_asset_id)
        elseif self.content.kind == "NoteContent" then
            content = A.NoteContent(self.id)
        else
            content = A.AudioContent(0)
        end
        local fade_in = self.fade_in and A.FadeSpec(self.fade_in.duration_beats, maps.fade_curve(self.fade_in.curve)) or nil
        local fade_out = self.fade_out and A.FadeSpec(self.fade_out.duration_beats, maps.fade_curve(self.fade_out.curve)) or nil
        return A.Clip(
            self.id, content,
            self.start_beats, self.duration_beats, self.source_offset_beats, self.lane,
            self.muted, self.gain:lower(), fade_in, fade_out
        )
    end

    return {
        note_region = lower_note_region,
        clip = lower_clip,
    }
end
