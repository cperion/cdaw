-- impl/authored/param.t
-- Authored.Param:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.param.resolve", "real")

local DEFAULT_TICKS_PER_BEAT = 960
local combine_codes = {
    Replace = 0, Add = 1, Multiply = 2, ModMin = 3, ModMax = 4,
}
local smoothing_codes = { NoSmoothing = 0, Lag = 1 }

local function deterministic_curve_id(param)
    return tonumber(param.id) or 0
end

local resolve_param = terralib.memoize(function(self, ticks_per_beat)
    local source_kind = 0
    local source_value = self.default_value
    local curve_id = nil

    if self.source.kind == "StaticValue" then
        source_kind = 0
        source_value = self.source.value
    elseif self.source.kind == "AutomationRef" then
        source_kind = 1
        source_value = self.default_value
        curve_id = deterministic_curve_id(self)
    end

    local smooth_code = smoothing_codes[self.smoothing and self.smoothing.kind] or 0
    local smooth_ms = 0
    if self.smoothing and self.smoothing.kind == "Lag" then
        smooth_ms = self.smoothing.ms
    end

    return D.Resolved.Param(
        self.id,
        0,
        self.name,
        self.default_value,
        self.min_value,
        self.max_value,
        D.Resolved.ParamSourceRef(source_kind, source_value, curve_id),
        combine_codes[self.combine and self.combine.kind] or 0,
        smooth_code,
        smooth_ms
    )
end)

function D.Authored.Param:resolve(ticks_per_beat)
    ticks_per_beat = type(ticks_per_beat) == "number" and ticks_per_beat or DEFAULT_TICKS_PER_BEAT
    return diag.wrap(nil, "authored.param.resolve", "real", function()
        return resolve_param(self, ticks_per_beat)
    end, function()
        return F.resolved_param(self.id, self.name)
    end)
end

return true
