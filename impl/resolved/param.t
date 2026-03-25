-- impl/resolved/param.t
-- Resolved.Param:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.param.classify", "real")


function D.Resolved.Param:classify(ctx)
    return diag.wrap(ctx, "resolved.param.classify", "real", function()
        -- Determine base value binding from source
        -- rate_class: 0=literal 1=init 2=block 3=sample 4=event 5=voice
        local rate_class = 0   -- literal by default
        local slot = 0

        if self.source.source_kind == 0 then
            -- Static value: literal
            rate_class = 0
            slot = ctx and ctx.alloc_literal and ctx:alloc_literal(self.source.value) or 0
        elseif self.source.source_kind == 1 then
            -- Automation: block rate
            rate_class = 2
            slot = ctx and ctx.alloc_block_slot and ctx:alloc_block_slot() or 0
        end

        return D.Classified.Param(
            self.id,
            self.node_id,
            self.default_value,
            self.min_value,
            self.max_value,
            D.Classified.Binding(rate_class, slot),
            self.combine_code,
            self.smoothing_code,
            self.smoothing_ms,
            0, 0,              -- first_modulation, modulation_count
            0                  -- runtime_state_slot
        )
    end, function()
        return F.classified_param(self.id, self.node_id)
    end)
end

return true
