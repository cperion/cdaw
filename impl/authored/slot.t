-- impl/authored/slot.t
-- Authored.Slot:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.slot.resolve", "partial")


local slot_kind_codes = { EmptySlot = 0, ClipSlot = 1, StopSlot = 2 }
local launch_mode_codes = { Trigger = 0, Gate = 1, Toggle = 2, Repeat = 3 }
local follow_kind_codes = {
    FNone = 0, FNext = 1, FPrev = 2, FFirst = 3,
    FLast = 4, FOther = 5, FRandom = 6, FStop = 7,
}
local quantize_codes_list = {
    "QNone","Q1_64","Q1_32","Q1_16","Q1_8","Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars",
}
local quantize_codes = {}
for i, name in ipairs(quantize_codes_list) do quantize_codes[name] = i - 1 end

function D.Authored.Slot:resolve(ctx)
    return diag.wrap(ctx, "authored.slot.resolve", "partial", function()
        local sk = slot_kind_codes[self.content.kind] or 0
        local clip_id = 0
        if self.content.kind == "ClipSlot" then
            clip_id = self.content.clip_id
        end

        local mode_code = launch_mode_codes[self.behavior.mode and self.behavior.mode.kind] or 0
        local quant_code = 0
        if self.behavior.quantize_override then
            quant_code = quantize_codes[self.behavior.quantize_override.kind] or 0
        end

        local follow_code = 0
        local fw_a, fw_b = 0, 0
        local fw_target = nil
        if self.behavior.follow then
            local f = self.behavior.follow
            follow_code = follow_kind_codes[f.kind and f.kind.kind] or 0
            fw_a = f.weight_a
            fw_b = f.weight_b
            fw_target = f.target_scene_id
        end

        return D.Resolved.Slot(
            self.slot_index,
            sk,
            clip_id,
            mode_code,
            quant_code,
            self.behavior.legato,
            self.behavior.retrigger,
            follow_code,
            fw_a, fw_b,
            fw_target,
            self.enabled
        )
    end, function()
        return F.resolved_slot(self.slot_index)
    end)
end

return true
