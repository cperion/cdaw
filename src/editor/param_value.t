-- impl2/editor/param_value.t
-- Editor.ParamValue:lower -> Authored.Param

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(A, maps)
    return function(self)
        local source
        if self.source.kind == "StaticValue" then
            source = A.StaticValue(self.source.value)
        elseif self.source.kind == "AutomationRef" then
            local curve = self.source.curve
            local points = L()
            for i = 1, #curve.points do
                local pt = curve.points[i]
                points[i] = A.AutoPoint(pt.time_beats, pt.value)
            end
            source = A.AutomationRef(A.AutoCurve(points, maps.interp(curve.mode)))
        else
            source = A.StaticValue(self.default_value)
        end
        return A.Param(
            self.id, self.name,
            self.default_value, self.min_value, self.max_value,
            source, maps.combine(self.combine), maps.smoothing(self.smoothing)
        )
    end
end
