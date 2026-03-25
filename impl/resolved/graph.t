-- impl/resolved/graph.t
-- Resolved.Graph:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.graph.classify", "stub")


function D.Resolved.Graph:classify(ctx)
    return diag.wrap(ctx, "resolved.graph.classify", "stub", function()
        return D.Classified.Graph(
            self.id,
            self.layout_code,
            self.domain_code,
            self.first_input,
            self.input_count,
            self.first_output,
            self.output_count,
            self.node_ids,
            0, 0,              -- first_wire, wire_count (from flat table)
            0, 0,              -- first_feedback, feedback_count
            0, 0               -- first_signal, signal_count
        )
    end, function()
        return F.classified_graph(self.id)
    end)
end

return true
