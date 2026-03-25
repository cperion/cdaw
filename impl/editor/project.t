-- impl/editor/project.t
-- Editor.Project:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.project.lower", "partial")


function D.Editor.Project:lower(ctx)
    return diag.wrap(ctx, "editor.project.lower", "partial", function()
        local transport = self.transport:lower(ctx)
        local tempo_map = self.tempo_map:lower(ctx)

        local tracks = diag.map(ctx, "editor.project.lower.tracks",
            self.tracks, function(t) return t:lower(ctx) end)

        local scenes = diag.map(ctx, "editor.project.lower.scenes",
            self.scenes, function(s) return s:lower(ctx) end)

        return D.Authored.Project(
            self.name,
            self.author,
            self.format_version,
            transport,
            tracks,
            scenes,
            tempo_map,
            self.assets   -- AssetBank passes through (same type)
        )
    end, function()
        return F.authored_project(self.name, self.author, self.format_version)
    end)
end

return true
