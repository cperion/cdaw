-- impl/resolved/node.t
-- Resolved.Node:classify → Classified.Node
--
-- Assigns signal_offset and state allocation for the node.
-- Nodes that need runtime state (delay lines, envelopes, etc.)
-- get state slots from ctx.alloc_state_slot().

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.node.classify", "real")

-- Node kinds that require runtime state.
-- Maps kind_code → state size (number of floats).
local state_sizes = {
    [10] = 1,     -- DelayNode: write pointer (circular buffer state is separate)
    [11] = 4,     -- ReverbNode: 4 comb filter states
    [12] = 2,     -- ChorusNode: phase + delay state
    [156] = 1,    -- LFOMod: phase accumulator
    [157] = 2,    -- ADSRMod: stage + level
}


function D.Resolved.Node:classify(ctx)
    return diag.wrap(ctx, "resolved.node.classify", "real", function()
        -- Signal offset: position in the global signal table
        -- Nodes that produce/consume signals get a contiguous block
        local signal_offset = 0
        local io_count = self.input_count + self.output_count
        if ctx and ctx.alloc_signal and io_count > 0 then
            signal_offset = ctx:alloc_signal(io_count)
        end

        -- State allocation: nodes with runtime state get slots
        local state_size = state_sizes[self.node_kind_code] or 0
        local state_offset = 0
        local runtime_state_slot = 0
        if state_size > 0 and ctx and ctx.alloc_state_slot then
            state_offset = ctx:alloc_state_slot(state_size)
            runtime_state_slot = state_offset
        end

        return D.Classified.Node(
            self.id,
            self.node_kind_code,
            self.first_param,
            self.param_count,
            signal_offset,
            state_offset,
            state_size,
            self.first_mod_slot,
            self.mod_slot_count,
            self.first_child_graph_ref,
            self.child_graph_ref_count,
            self.enabled,
            runtime_state_slot,
            self.arg0, self.arg1, self.arg2, self.arg3
        )
    end, function()
        return F.classified_node(self.id)
    end)
end

return true
