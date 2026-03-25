-- impl/scheduled/compiler/mod_job.t
-- Private scheduled mod-job quote compiler.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_binding_value = require("impl/scheduled/compiler/binding")
local L = F.L
diag.status("scheduled.mod_job.quote", "partial")

local C = terralib.includec("math.h")

local NK = {
    LFOMod = 156,
}

local function get_param_binding(param_bindings, first_param, index)
    return param_bindings[first_param + index + 1]
end

local function compile_with(self, ctx)
    return diag.wrap(ctx, "scheduled.mod_job.quote", "partial", function()
        assert(ctx and ctx.sample_slots_sym, "ModJob:compile requires ctx.sample_slots_sym")

        local sample_slots = ctx.sample_slots_sym
        local state = ctx.state_sym
        local slot = self.output_state_slot

        if self.kind_code == NK.LFOMod then
            local rate_b = get_param_binding(ctx.param_bindings or {}, self.first_param, 0)
            local rate_q = rate_b and compile_binding_value(rate_b, ctx) or `0.0f
            local block_sample = ctx.block_sample or 0.0
            local sample_rate = ctx.sample_rate or 44100.0
            local shape_code = self.arg0 or 0
            local tau = 6.283185307179586
            local cycles_q = `(([float](block_sample / sample_rate)) * [rate_q])
            local frac_q = `(([cycles_q]) - C.floorf([cycles_q]))
            local out_q

            if shape_code == 1 then
                out_q = `(1.0f - 4.0f * C.fabsf(([frac_q]) - 0.5f))
            elseif shape_code == 2 then
                out_q = `C.copysignf(1.0f, C.sinf(([cycles_q]) * [float](tau)))
            elseif shape_code == 3 then
                out_q = `(([frac_q]) * 2.0f - 1.0f)
            elseif shape_code == 4 then
                local whole_q = `C.floorf([cycles_q])
                local n_q = `(C.sinf([whole_q] * 12.9898f) * 43758.5453f)
                local nfrac_q = `([n_q] - C.floorf([n_q]))
                out_q = `([nfrac_q] * 2.0f - 1.0f)
            else
                out_q = `C.sinf(([cycles_q]) * [float](tau))
            end

            if self.runtime_state_slot >= 0 and self.state_size > 0 and state then
                local s0 = self.runtime_state_slot
                return quote
                    [sample_slots][slot] = [out_q]
                    [state][s0] = [frac_q]
                end
            end

            return quote
                [sample_slots][slot] = [out_q]
            end
        end

        local output_q = compile_binding_value(self.output, ctx)
        return quote
            [sample_slots][slot] = [output_q]
        end
    end, function()
        return F.noop_quote()
    end)
end

return compile_with
