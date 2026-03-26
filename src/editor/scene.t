-- impl2/editor/scene.t
-- Editor.Scene:lower -> Authored.Scene

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    return function(self)
        local slots = L()
        for i = 1, #self.slots do
            local s = self.slots[i]
            slots[i] = A.SceneSlot(s.track_id, s.slot_index, s.stop_others)
        end
        return A.Scene(
            self.id, self.name, slots,
            self.quantize_override and maps.quantize(self.quantize_override) or nil,
            self.tempo_override
        )
    end
end
