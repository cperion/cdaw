-- impl/authored/node.t
-- Authored.Node:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.node.resolve", "partial")


-- ChildGraphRole → code
local role_codes = { MainChild = 0, PreFXChild = 1, PostFXChild = 2, NoteFXChild = 3 }

function D.Authored.Node:resolve(ctx)
    return diag.wrap(ctx, "authored.node.resolve", "partial", function()
        -- Resolve kind
        local kind_ref = self.kind:resolve(ctx)
        local kind_code = kind_ref.kind_code

        -- Resolve params
        local params = diag.map(ctx, "authored.node.resolve.params",
            self.params, function(p) return p:resolve(ctx) end)

        -- Resolve mod slots
        local mod_slots = diag.map(ctx, "authored.node.resolve.mod_slots",
            self.mod_slots, function(ms) return ms:resolve(ctx) end)

        -- Resolve child graph refs
        local child_refs = L()
        for i = 1, #self.child_graphs do
            local cg = self.child_graphs[i]
            local child_graph = cg.graph:resolve(ctx)
            child_refs[i] = D.Resolved.ChildGraphRef(
                child_graph.id,
                role_codes[cg.role and cg.role.kind] or 0
            )
        end

        return D.Resolved.Node(
            self.id,
            kind_code,
            0, #params,           -- first_param, param_count
            0, 0,                 -- first_input, input_count (from ports)
            0, 0,                 -- first_output, output_count
            0, #mod_slots,        -- first_mod_slot, mod_slot_count
            0, #child_refs,       -- first_child_graph_ref, count
            self.enabled,
            nil,                  -- plugin_handle
            0, 0, 0, 0           -- arg0..arg3
        )
    end, function()
        return F.resolved_node(self.id)
    end)
end

return true
