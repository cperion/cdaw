-- impl/scheduled/tempo_map.t
-- Scheduled.TempoMap:compile → TerraQuote
--
-- Emits a tick_to_sample Terra function at the top level (not nested
-- in a quote), then returns a quote that's a no-op. The function is
-- stored on ctx.tick_to_sample_fn for other compiled code to call.
--
-- tick → sample conversion:
--   sample = seg.base_sample + (tick - seg.start_tick) * seg.samples_per_tick

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.tempo_map.compile", "real")


function D.Scheduled.TempoMap:compile(ctx)
    return diag.wrap(ctx, "scheduled.tempo_map.compile", "real", function()
        local segs = {}
        for i = 1, #self.segs do segs[i] = self.segs[i] end

        if #segs == 0 then
            -- No tempo data: build identity function
            local terra identity(tick: double): double return tick end
            if ctx then ctx.tick_to_sample_fn = identity end
            return quote end
        end

        -- Build segment data as compile-time constants
        local n = #segs

        -- Pre-extract all segment values at Lua time
        local first_spt = segs[1].samples_per_tick

        -- Generate the tick_to_sample function at the Lua/Terra top level
        local tick_to_sample = terra(tick: double): double
            escape
                -- Linear search from last segment backwards
                for i = n, 1, -1 do
                    local st = segs[i].start_tick
                    local bs = segs[i].base_sample
                    local sp = segs[i].samples_per_tick
                    emit quote
                        if tick >= [double](st) then
                            return [double](bs) + (tick - [double](st)) * [double](sp)
                        end
                    end
                end
            end
            -- Before first segment: use first segment's rate
            return tick * [double](first_spt)
        end

        -- Store on ctx for other compile methods to use
        if ctx then ctx.tick_to_sample_fn = tick_to_sample end

        return quote end
    end, function()
        return F.noop_quote()
    end)
end

return true
