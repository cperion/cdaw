-- impl2/editor/project.t
-- Editor.Project:lower -> Authored.Project

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    local function lower_clip_note_asset(clip)
        if not clip or not clip.content or clip.content.kind ~= "NoteContent" then return nil end
        local asset = clip.content.body:lower()
        return A.NoteAsset(clip.id, asset.notes, asset.expr_lanes, asset.loop_start_beats, asset.loop_end_beats)
    end

    local function collect_note_assets(clips, seen, out)
        for i = 1, #clips do
            local asset = lower_clip_note_asset(clips[i])
            if asset and not seen[asset.id] then
                seen[asset.id] = true
                out:insert(asset)
            end
        end
    end

    return function(self)
        local transport = self.transport:lower()
        local tempo_map = self.tempo_map:lower()
        local tracks = L()
        for i = 1, #self.tracks do tracks[i] = self.tracks[i]:lower() end
        local scenes = L()
        for i = 1, #self.scenes do scenes[i] = self.scenes[i]:lower() end

        local base_bank = self.assets or A.AssetBank(L(), L(), L(), L(), L())
        local merged_notes = L()
        local seen = {}
        for i = 1, #base_bank.notes do
            merged_notes:insert(base_bank.notes[i])
            seen[base_bank.notes[i].id] = true
        end
        for i = 1, #self.tracks do
            collect_note_assets(self.tracks[i].clips, seen, merged_notes)
        end

        local assets = A.AssetBank(base_bank.audio, merged_notes, base_bank.wavetables, base_bank.irs, base_bank.zone_banks)
        return A.Project(self.name, self.author, self.format_version, transport, tracks, scenes, tempo_map, assets)
    end
end
