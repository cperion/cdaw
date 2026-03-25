-- impl/editor/project.t
-- Editor.Project:lower
--
-- Pure project lowering. No opaque LowerCtx enters the semantic boundary.
-- Note assets produced by note clips are derived directly from the Editor
-- clips here and merged into the lowered AssetBank; no hidden attachment is
-- carried on lowered Authored.Clip values.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.project.lower", "real")

local lower_clip_note_asset = terralib.memoize(function(clip)
    if not clip or not clip.content or clip.content.kind ~= "NoteContent" then
        return nil
    end

    local asset = clip.content.body:lower()
    return D.Authored.NoteAsset(
        clip.id,
        asset.notes,
        asset.expr_lanes,
        asset.loop_start_beats,
        asset.loop_end_beats
    )
end)

local function collect_note_assets_from_clips(clips, out_by_id, out_list)
    for i = 1, #clips do
        local asset = lower_clip_note_asset(clips[i])
        if asset and out_by_id[asset.id] == nil then
            out_by_id[asset.id] = true
            out_list:insert(asset)
        end
    end
end

local lower_project = terralib.memoize(function(self)
    local transport = self.transport:lower()
    local tempo_map = self.tempo_map:lower()

    local tracks = diag.map(nil, "editor.project.lower.tracks",
        self.tracks, function(t) return t:lower() end)

    local scenes = diag.map(nil, "editor.project.lower.scenes",
        self.scenes, function(s) return s:lower() end)

    local base_bank = self.assets or F.authored_asset_bank()
    local merged_notes = L()
    local seen_note_ids = {}

    for i = 1, #base_bank.notes do
        local asset = base_bank.notes[i]
        merged_notes:insert(asset)
        seen_note_ids[asset.id] = true
    end
    for i = 1, #self.tracks do
        collect_note_assets_from_clips(self.tracks[i].clips, seen_note_ids, merged_notes)
    end

    local assets = D.Authored.AssetBank(
        base_bank.audio,
        merged_notes,
        base_bank.wavetables,
        base_bank.irs,
        base_bank.zone_banks
    )

    return D.Authored.Project(
        self.name,
        self.author,
        self.format_version,
        transport,
        tracks,
        scenes,
        tempo_map,
        assets
    )
end)

function D.Editor.Project:lower()
    return diag.wrap(nil, "editor.project.lower", "real", function()
        return lower_project(self)
    end, function()
        return F.authored_project(self.name, self.author, self.format_version)
    end)
end

return true
