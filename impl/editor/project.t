-- impl/editor/project.t
-- Editor.Project:lower
--
-- Project lowering is the root of Editor→Authored. It provides a proper
-- LowerCtx to child lowering calls so that:
--   • graph ids are allocated sequentially (alloc_graph_id)
--   • note asset ids are allocated (alloc_note_asset_id)
--   • note assets interned during clip lowering are collected (intern_note_asset)
--   • the final AssetBank merges interned note assets with the original bank

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.project.lower", "real")


-- Build a full LowerCtx, merging caller-provided ctx fields with
-- project-level allocators. Caller ctx may already have some fields
-- (e.g. diagnostics); we preserve those.
local function make_lower_ctx(caller_ctx)
    local ctx = caller_ctx or {}
    ctx.diagnostics = ctx.diagnostics or {}

    -- Graph id allocator: starts after 0 (0 is reserved for fallbacks)
    local next_graph_id = 1
    if not ctx.alloc_graph_id then
        ctx.alloc_graph_id = function(self)
            local id = next_graph_id
            next_graph_id = next_graph_id + 1
            return id
        end
    end

    -- Note asset id allocator
    local next_note_asset_id = 1
    if not ctx.alloc_note_asset_id then
        ctx.alloc_note_asset_id = function(self)
            local id = next_note_asset_id
            next_note_asset_id = next_note_asset_id + 1
            return id
        end
    end

    -- Note asset intern: collect note assets created by clip lowering
    local interned_note_assets = {}
    if not ctx.intern_note_asset then
        ctx.intern_note_asset = function(self, asset)
            interned_note_assets[#interned_note_assets + 1] = asset
        end
    end
    ctx._interned_note_assets = interned_note_assets

    return ctx
end


function D.Editor.Project:lower(caller_ctx)
    return diag.wrap(caller_ctx, "editor.project.lower", "real", function()
        local ctx = make_lower_ctx(caller_ctx)

        local transport = self.transport:lower(ctx)
        local tempo_map = self.tempo_map:lower(ctx)

        local tracks = diag.map(ctx, "editor.project.lower.tracks",
            self.tracks, function(t) return t:lower(ctx) end)

        local scenes = diag.map(ctx, "editor.project.lower.scenes",
            self.scenes, function(s) return s:lower(ctx) end)

        -- Merge interned note assets into the asset bank
        local base_bank = self.assets or F.authored_asset_bank()
        local merged_notes = L()
        -- Keep existing authored notes
        for i = 1, #base_bank.notes do
            merged_notes:insert(base_bank.notes[i])
        end
        -- Append newly interned ones from clip lowering
        for i = 1, #ctx._interned_note_assets do
            merged_notes:insert(ctx._interned_note_assets[i])
        end
        local assets = D.Authored.AssetBank(
            base_bank.audio,
            merged_notes,
            base_bank.wavetables,
            base_bank.irs,
            base_bank.zone_banks
        )

        -- Propagate diagnostics back to caller ctx
        if caller_ctx then
            caller_ctx.diagnostics = ctx.diagnostics
        end

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
    end, function()
        return F.authored_project(self.name, self.author, self.format_version)
    end)
end

return true
