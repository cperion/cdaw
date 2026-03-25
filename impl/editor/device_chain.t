-- impl/editor/device_chain.t
-- Editor.DeviceChain:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.device_chain.lower", "real")


function D.Editor.DeviceChain:lower(ctx)
    return diag.wrap(ctx, "editor.device_chain.lower", "real", function()
        -- Lower each device to an Authored.Node, collecting into a serial graph.
        local nodes = diag.map(ctx, "editor.device_chain.lower.device",
            self.devices, function(dev) return dev:lower(ctx) end)

        -- Infer wires for serial chaining: each node output feeds next node
        -- input. In the stub, leave wires empty — serial layout infers them.
        local graph_id = ctx and ctx.alloc_graph_id
            and ctx:alloc_graph_id() or 0

        return D.Authored.Graph(
            graph_id,
            L(), L(),          -- inputs, outputs (filled by resolve)
            nodes,
            L(),               -- wires (serial layout infers)
            L(),               -- pre_cords
            D.Authored.Serial,
            D.Authored.AudioDomain
        )
    end, function()
        return F.authored_graph(0)
    end)
end

return true
