-- impl/authored/param.t
-- Authored.Param:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.param.resolve", "real")


-- Combine mode → code: Replace=0, Add=1, Multiply=2, ModMin=3, ModMax=4
local combine_codes = {
    Replace = 0, Add = 1, Multiply = 2, ModMin = 3, ModMax = 4,
}

-- Smoothing → codes
local smoothing_codes = { NoSmoothing = 0, Lag = 1 }

-- Interp → codes
local interp_codes = { Linear = 0, Smoothstep = 1, Hold = 2 }

function D.Authored.Param:resolve(ctx)
    return diag.wrap(ctx, "authored.param.resolve", "real", function()
        -- Determine source ref
        local source_kind = 0  -- 0 = static
        local source_value = self.default_value
        local curve_id = nil

        if self.source.kind == "StaticValue" then
            source_kind = 0
            source_value = self.source.value
        elseif self.source.kind == "AutomationRef" then
            source_kind = 1
            source_value = self.default_value
            -- Intern the automation curve in the resolve context
            local curve = self.source.curve
            local ticks_per_beat = (ctx and ctx.ticks_per_beat) or 960
            local points = L()
            for i = 1, #curve.points do
                local pt = curve.points[i]
                points[i] = D.Resolved.AutoPoint(
                    pt.time_beats * ticks_per_beat,
                    pt.value
                )
            end
            local interp = interp_codes[curve.mode and curve.mode.kind] or 0
            local cid = ctx and ctx.alloc_curve_id and ctx:alloc_curve_id() or 0
            local resolved_curve = D.Resolved.AutoCurve(cid, points, interp)
            if ctx and ctx.intern_curve then
                ctx:intern_curve(resolved_curve)
            end
            curve_id = cid
        end

        local combine = combine_codes[self.combine and self.combine.kind] or 0
        local smooth_code = smoothing_codes[self.smoothing and self.smoothing.kind] or 0
        local smooth_ms = 0
        if self.smoothing and self.smoothing.kind == "Lag" then
            smooth_ms = self.smoothing.ms
        end

        return D.Resolved.Param(
            self.id,
            0,                 -- node_id (set by parent during resolve)
            self.name,
            self.default_value,
            self.min_value,
            self.max_value,
            D.Resolved.ParamSourceRef(source_kind, source_value, curve_id),
            combine,
            smooth_code,
            smooth_ms
        )
    end, function()
        return F.resolved_param(self.id, self.name)
    end)
end

return true
