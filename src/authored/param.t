-- impl2/authored/param.t
-- Authored.Param:resolve -> Resolved.Param

return function(types)
local R = types.Resolved
    local combine_codes = { Replace = 0, Add = 1, Multiply = 2, ModMin = 3, ModMax = 4 }
    local smoothing_codes = { NoSmoothing = 0, Lag = 1 }

    return function(self, ticks_per_beat)
        local source_kind, source_value, curve_id = 0, self.default_value, nil
        if self.source.kind == "StaticValue" then
            source_value = self.source.value
        elseif self.source.kind == "AutomationRef" then
            source_kind = 1
            curve_id = tonumber(self.id) or 0
        end
        local smooth_code = smoothing_codes[self.smoothing and self.smoothing.kind] or 0
        local smooth_ms = (self.smoothing and self.smoothing.kind == "Lag") and self.smoothing.ms or 0
        return R.Param(self.id, 0, self.name, self.default_value, self.min_value, self.max_value,
            R.ParamSourceRef(source_kind, source_value, curve_id),
            combine_codes[self.combine and self.combine.kind] or 0,
            smooth_code, smooth_ms)
    end
end
