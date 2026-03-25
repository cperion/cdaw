-- impl/scheduled/binding.t
-- Scheduled.Binding:compile_value → TerraQuote

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.binding.compile_value", "partial")


function D.Scheduled.Binding:compile_value(ctx)
    return diag.wrap(ctx, "scheduled.binding.compile_value", "partial", function()
        -- rate_class: 0=literal 1=init 2=block 3=sample 4=event 5=voice
        -- For literal bindings, return a constant.
        -- For everything else, return 0 as stub.
        if self.rate_class == 0 then
            -- Literal: look up the value in the literal table
            local val = ctx and ctx.literals and ctx.literals[self.slot + 1]
            if val then
                local v = val.value
                return `[float](v)
            end
            return `0.0f
        end
        -- Stub: all other rate classes return zero
        return `0.0f
    end, function()
        return F.noop_quote()
    end)
end

return true
