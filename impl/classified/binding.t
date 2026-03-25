-- impl/classified/binding.t
-- Classified.Binding:schedule → Scheduled.Binding

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.binding.schedule", "real")


function D.Classified.Binding:schedule(ctx)
    return diag.wrap(ctx, "classified.binding.schedule", "real", function()
        return D.Scheduled.Binding(self.rate_class, self.slot)
    end, function()
        return F.scheduled_binding(0, 0)
    end)
end

return true
