-- impl2/authored/slot.t
-- Authored.Slot:resolve -> Resolved.Slot

return function(types)
local R = types.Resolved
    local slot_kind_codes = { EmptySlot = 0, ClipSlot = 1, StopSlot = 2 }
    local launch_mode_codes = { Trigger = 0, Gate = 1, Toggle = 2, Repeat = 3 }
    local follow_kind_codes = { FNone = 0, FNext = 1, FPrev = 2, FFirst = 3, FLast = 4, FOther = 5, FRandom = 6, FStop = 7 }
    local qnames = {"QNone","Q1_64","Q1_32","Q1_16","Q1_8","Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars"}
    local quantize_codes = {}
    for i, name in ipairs(qnames) do quantize_codes[name] = i - 1 end

    return function(self)
        local sk = slot_kind_codes[self.content.kind] or 0
        local clip_id = self.content.kind == "ClipSlot" and self.content.clip_id or 0
        local mode_code = launch_mode_codes[self.behavior.mode and self.behavior.mode.kind] or 0
        local quant_code = self.behavior.quantize_override and (quantize_codes[self.behavior.quantize_override.kind] or 0) or 0
        local follow_code, fw_a, fw_b, fw_target = 0, 0, 0, nil
        if self.behavior.follow then
            local f = self.behavior.follow
            follow_code = follow_kind_codes[f.kind and f.kind.kind] or 0
            fw_a, fw_b, fw_target = f.weight_a, f.weight_b, f.target_scene_id
        end
        return R.Slot(self.slot_index, sk, clip_id, mode_code, quant_code,
            self.behavior.legato, self.behavior.retrigger,
            follow_code, fw_a, fw_b, fw_target, self.enabled)
    end
end
