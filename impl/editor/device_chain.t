-- impl/editor/device_chain.t
-- Editor.DeviceChain:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.device_chain.lower", "real")

local function fold_id(acc, n)
    n = math.floor(tonumber(n) or 0)
    acc = (acc * 1103515245 + n + 12345) % 2147483647
    if acc <= 0 then acc = 1 end
    return acc
end

local function default_graph_id(chain)
    local acc = 23
    for i = 1, #chain.devices do
        local dev = chain.devices[i]
        local body = dev.body
        acc = fold_id(acc, body and body.id or i)
    end
    return acc
end

local lower_device_chain = terralib.memoize(function(self)
    local nodes = diag.map(nil, "editor.device_chain.lower.device",
        self.devices, function(dev) return dev:lower() end)

    return D.Authored.Graph(
        default_graph_id(self),
        L(), L(),
        nodes,
        L(),
        L(),
        D.Authored.Serial,
        D.Authored.AudioDomain
    )
end)

function D.Editor.DeviceChain:lower()
    return diag.wrap(nil, "editor.device_chain.lower", "real", function()
        return lower_device_chain(self)
    end, function()
        return F.authored_graph(0)
    end)
end

return true
