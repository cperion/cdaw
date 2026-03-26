-- impl2/authored/scene.t
-- Authored.Scene:resolve -> Resolved.Scene

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(R)
    local qnames = {"QNone","Q1_64","Q1_32","Q1_16","Q1_8","Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars"}
    local quantize_codes = {}
    for i, name in ipairs(qnames) do quantize_codes[name] = i - 1 end

    return function(self)
        local slots = L()
        for i = 1, #self.slots do
            local s = self.slots[i]
            slots[i] = R.SceneSlot(s.track_id, s.slot_index, s.stop_others)
        end
        local quant_code = self.quantize_override and (quantize_codes[self.quantize_override.kind] or 0) or 0
        return R.Scene(self.id, self.name, slots, quant_code, self.tempo_override)
    end
end
