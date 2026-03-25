-- impl/resolved/graph.t
-- Resolved.Graph:classify → Classified.Graph
--
-- Assigns wire flat-table indices and allocates signals for the graph's
-- ports. The ctx provides alloc_signal() for signal slot allocation and
-- _wire_base for flat wire table positioning.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.graph.classify", "real")


function D.Resolved.Graph:classify(ctx)
    return diag.wrap(ctx, "resolved.graph.classify", "real", function()
        -- Wire indices: self.wire_ids contains the flat wire indices
        -- from resolve. Compute first_wire and wire_count.
        local first_wire = 0
        local wire_count = #self.wire_ids
        if wire_count > 0 then
            first_wire = self.wire_ids[1]
        end

        -- Signal allocation: each graph gets a contiguous block of signals
        -- for its ports (inputs + outputs) from ctx.
        local signal_count = self.input_count + self.output_count
        local first_signal = 0
        if ctx and ctx.alloc_signal and signal_count > 0 then
            first_signal = ctx:alloc_signal(signal_count)
        end

        return D.Classified.Graph(
            self.id,
            self.layout_code,
            self.domain_code,
            self.first_input,
            self.input_count,
            self.first_output,
            self.output_count,
            self.node_ids,
            first_wire, wire_count,
            0, 0,                      -- first_feedback, feedback_count
            first_signal, signal_count
        )
    end, function()
        return F.classified_graph(self.id)
    end)
end

return true
