-- impl/editor/param_value.t
-- Editor.ParamValue:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.param_value.lower", "real")


function D.Editor.ParamValue:lower(ctx)
    return diag.wrap(ctx, "editor.param_value.lower", "real", function()
        -- Convert source
        local source
        if self.source.kind == "StaticValue" then
            source = D.Authored.StaticValue(self.source.value)
        elseif self.source.kind == "AutomationRef" then
            local curve = self.source.curve
            local points = L()
            for i = 1, #curve.points do
                local pt = curve.points[i]
                points[i] = D.Authored.AutoPoint(pt.time_beats, pt.value)
            end
            source = D.Authored.AutomationRef(
                D.Authored.AutoCurve(points, F.interp_e2a(curve.mode))
            )
        else
            source = D.Authored.StaticValue(self.default_value)
        end

        return D.Authored.Param(
            self.id,
            self.name,
            self.default_value,
            self.min_value,
            self.max_value,
            source,
            F.combine_e2a(self.combine),
            F.smoothing_e2a(self.smoothing)
        )
    end, function()
        return F.authored_param(self.id, self.name, self.default_value,
            self.min_value, self.max_value)
    end)
end

return true
