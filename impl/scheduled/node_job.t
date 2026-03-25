-- impl/scheduled/node_job.t
-- Scheduled.NodeJob:compile → TerraQuote
--
-- Fallback behavior: silence for generators, passthrough for effects.
-- Real implementations override per kind_code.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.node_job.compile", "stub")


function D.Scheduled.NodeJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.node_job.compile", "stub", function()
        -- Stub: all node jobs compile to silence / no-op.
        -- This is the correct degraded behavior: the node produces no output.
        -- When individual node kinds are implemented, they override this
        -- by dispatching on self.kind_code.
        diag.record(ctx, "warning", "scheduled.node_job.compile.stub",
            "NodeJob compile not implemented for kind_code " .. tostring(self.kind_code))
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
