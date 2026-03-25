-- impl/authored/project.t
-- Authored.Project:resolve -> Resolved.Project

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L

diag.status("authored.project.resolve", "real")

local resolve_project = terralib.memoize(function(self, ticks_per_beat)
    local sample_rate = (self.transport and self.transport.sample_rate) or 44100
    local transport = self.transport:resolve(ticks_per_beat)
    local tempo_map = self.tempo_map:resolve(ticks_per_beat, sample_rate)

    local track_slices = diag.map_or(nil, "authored.project.resolve.track_slices",
        self.tracks,
        function(t) return t:resolve(ticks_per_beat) end,
        function(t) return F.resolved_track_slice(t and t.id, t and t.name, t and t.channels) end)

    local scenes = diag.map(nil, "authored.project.resolve.scenes",
        self.scenes, function(s) return s:resolve() end)

    local assets = self.assets and self.assets:resolve(ticks_per_beat) or F.resolved_asset_bank()

    return D.Resolved.Project(transport, tempo_map, track_slices, scenes, assets)
end)

function D.Authored.Project:resolve(ticks_per_beat)
    assert(type(ticks_per_beat) == "number", "Authored.Project:resolve requires explicit number ticks_per_beat")

    return diag.wrap(nil, "authored.project.resolve", "real", function()
        return resolve_project(self, ticks_per_beat)
    end, function()
        return F.resolved_project()
    end)
end

return true
