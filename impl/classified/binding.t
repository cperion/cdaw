-- impl/classified/binding.t
-- Classified.Binding:schedule

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.binding.schedule", "real")

local schedule_binding = terralib.memoize(function(self)
    return D.Scheduled.Binding(self.rate_class, self.slot)
end)

function D.Classified.Binding:schedule()
    return diag.wrap(nil, "classified.binding.schedule", "real", function()
        return schedule_binding(self)
    end, function()
        return F.scheduled_binding(0, 0)
    end)
end

return true
