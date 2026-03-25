-- impl/authored/scene.t
-- Authored.Scene:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.scene.resolve", "real")

local qnames = {"QNone","Q1_64","Q1_32","Q1_16","Q1_8","Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars"}
local quantize_codes = {}
for i, name in ipairs(qnames) do quantize_codes[name] = i - 1 end

local resolve_scene = terralib.memoize(function(self)
    local slots = L()
    for i = 1, #self.slots do
        local s = self.slots[i]
        slots[i] = D.Resolved.SceneSlot(s.track_id, s.slot_index, s.stop_others)
    end

    local quant_code = 0
    if self.quantize_override then
        quant_code = quantize_codes[self.quantize_override.kind] or 0
    end

    return D.Resolved.Scene(
        self.id,
        self.name,
        slots,
        quant_code,
        self.tempo_override
    )
end)

function D.Authored.Scene:resolve()
    return diag.wrap(nil, "authored.scene.resolve", "real", function()
        return resolve_scene(self)
    end, function()
        return F.resolved_scene(self.id, self.name)
    end)
end

return true
