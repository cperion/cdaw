-- impl/scheduled/tempo_map.t
-- Scheduled.TempoMap:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.tempo_map.compile", "stub")


function D.Scheduled.TempoMap:compile(ctx)
    return diag.wrap(ctx, "scheduled.tempo_map.compile", "stub", function()
        -- Stub: tempo map compile emits nothing.
        -- Real implementation would emit tick→sample conversion logic.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
