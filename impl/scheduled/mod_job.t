-- impl/scheduled/mod_job.t
-- Scheduled.ModJob:compile → TerraQuote
--
-- Evaluates a modulator node and writes its output to the output state slot.
-- The modulator's signal is then available for ModRoutes to read and apply
-- to target parameters.
--
-- Currently supports: reading the modulator's output binding as a constant.
-- Real per-sample modulation (LFO, ADSR) requires state management (future).
--
-- ctx must provide: bufs_sym, frames_sym, BS, literal_values.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.mod_job.compile", "real")


local function resolve_binding_value(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end


function D.Scheduled.ModJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.mod_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "ModJob:compile requires ctx.bufs_sym")

        -- The modulator output is written to a state slot.
        -- For now, resolve the output binding as a constant and store it.
        -- Real LFO/ADSR would compute per-sample values using state.
        local output_val = resolve_binding_value(self.output, ctx.literal_values or {})

        -- If output_state_slot is valid and we have a state array, write to it.
        -- For compile-time constant modulators, this is a no-op since the
        -- downstream param already has the literal value baked in.
        if self.output_state_slot >= 0 and ctx.state_sym then
            local slot = self.output_state_slot
            return quote
                ctx.state_sym[slot] = [float](output_val)
            end
        end

        -- No state array available: modulation is baked into literal values
        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
