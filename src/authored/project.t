-- impl2/authored/project.t
-- Authored.Project:resolve -> Resolved.Project

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(R)
    return function(self, ticks_per_beat)
        local sample_rate = (self.transport and self.transport.sample_rate) or 44100
        local transport = self.transport:resolve(ticks_per_beat)
        local tempo_map = self.tempo_map:resolve(ticks_per_beat, sample_rate)
        local track_slices = L()
        for i = 1, #self.tracks do track_slices[i] = self.tracks[i]:resolve(ticks_per_beat) end
        local scenes = L()
        for i = 1, #self.scenes do scenes[i] = self.scenes[i]:resolve() end
        local assets = self.assets and self.assets:resolve(ticks_per_beat) or R.AssetBank(L(), L(), L(), L(), L())
        return R.Project(transport, tempo_map, track_slices, scenes, assets)
    end
end
