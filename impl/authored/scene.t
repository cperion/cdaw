-- impl/authored/scene.t
-- Authored.Scene:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.scene.resolve", "partial")


function D.Authored.Scene:resolve(ctx)
    return diag.wrap(ctx, "authored.scene.resolve", "partial", function()
        local slots = L()
        for i = 1, #self.slots do
            local s = self.slots[i]
            slots[i] = D.Resolved.SceneSlot(s.track_id, s.slot_index, s.stop_others)
        end

        local quant_code = 0
        if self.quantize_override then
            local qnames = {"QNone","Q1_64","Q1_32","Q1_16","Q1_8",
                "Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars"}
            for j, name in ipairs(qnames) do
                if self.quantize_override.kind == name then
                    quant_code = j - 1
                    break
                end
            end
        end

        return D.Resolved.Scene(
            self.id,
            self.name,
            slots,
            quant_code,
            self.tempo_override
        )
    end, function()
        return F.resolved_scene(self.id, self.name)
    end)
end

return true
