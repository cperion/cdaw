-- impl/scheduled/clip_job.t
-- Scheduled.ClipJob:compile → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.clip_job.compile", "stub")


function D.Scheduled.ClipJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.clip_job.compile", "stub", function()
        -- Stub: clip playback emits nothing (silence).
        -- Real implementation reads audio or note events from assets.
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
