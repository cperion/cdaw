-- impl2/editor/device_chain.t
-- Editor.DeviceChain:lower -> Authored.Graph

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

local function fold_id(acc, n)
    n = math.floor(tonumber(n) or 0)
    acc = (acc * 1103515245 + n + 12345) % 2147483647
    if acc <= 0 then acc = 1 end
    return acc
end

local function default_graph_id(chain)
    local acc = 23
    for i = 1, #chain.devices do
        local body = chain.devices[i].body
        acc = fold_id(acc, body and body.id or i)
    end
    return acc
end

return function(A, maps)
    return function(self)
        local nodes = L()
        for i = 1, #self.devices do nodes[i] = self.devices[i]:lower() end
        return A.Graph(default_graph_id(self), L(), L(), nodes, L(), L(), A.Serial, A.AudioDomain)
    end
end
