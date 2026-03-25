-- impl/authored/graph.t
-- Authored.Graph:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.graph.resolve", "partial")


-- Layout → code: Serial=0, Free=1, Parallel=2, Switched=3, Split=4
local layout_codes = {
    Serial = 0, Free = 1, Parallel = 2, Switched = 3, Split = 4,
}
-- Domain → code: NoteDomain=0, AudioDomain=1, HybridDomain=2, ControlDomain=3
local domain_codes = {
    NoteDomain = 0, AudioDomain = 1, HybridDomain = 2, ControlDomain = 3,
}
-- PortHint → code
local hint_codes = {
    AudioHint = 0, ControlHint = 1, GateHint = 2,
    PitchHint = 3, PhaseHint = 4, TriggerHint = 5,
}

function D.Authored.Graph:resolve(ctx)
    return diag.wrap(ctx, "authored.graph.resolve", "partial", function()
        local layout_code = layout_codes[self.layout.kind or self.layout] or 0
        local domain_code = domain_codes[self.domain.kind or self.domain] or 1

        -- Resolve ports
        local port_base = ctx and ctx.alloc_graph_port_base
            and ctx:alloc_graph_port_base(#self.inputs + #self.outputs) or 0
        local all_ports = L()
        for i = 1, #self.inputs do
            local p = self.inputs[i]
            all_ports:insert(D.Resolved.GraphPort(
                p.id, p.name,
                hint_codes[p.hint and p.hint.kind] or 0,
                p.channels, p.optional
            ))
        end
        for i = 1, #self.outputs do
            local p = self.outputs[i]
            all_ports:insert(D.Resolved.GraphPort(
                p.id, p.name,
                hint_codes[p.hint and p.hint.kind] or 0,
                p.channels, p.optional
            ))
        end

        -- Resolve nodes (delegate to Node:resolve)
        local node_ids = L()
        for i = 1, #self.nodes do
            local node = self.nodes[i]:resolve(ctx)
            node_ids[i] = node.id
        end

        -- Resolve wires
        local wire_ids = L()
        for i = 1, #self.wires do
            local w = self.wires[i]
            wire_ids[i] = i - 1  -- sequential wire index
        end

        return D.Resolved.Graph(
            self.id,
            layout_code,
            domain_code,
            port_base, #self.inputs,
            port_base + #self.inputs, #self.outputs,
            node_ids,
            wire_ids,
            0, #self.pre_cords,    -- first_precord, precord_count
            0, 0, 0, 0            -- arg0..arg3
        )
    end, function()
        return F.resolved_graph(self.id)
    end)
end

return true
