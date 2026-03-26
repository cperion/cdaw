-- impl2/editor/grid_patch.t
-- Editor.GridPatch:lower -> Authored.Graph

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(A, maps)
    return function(self)
        local inputs = L()
        for i = 1, #self.inputs do
            local p = self.inputs[i]
            inputs[i] = A.GraphPort(p.id, p.name, maps.port_hint(p.hint), p.channels, p.optional)
        end
        local outputs = L()
        for i = 1, #self.outputs do
            local p = self.outputs[i]
            outputs[i] = A.GraphPort(p.id, p.name, maps.port_hint(p.hint), p.channels, p.optional)
        end
        local nodes = L()
        for i = 1, #self.modules do
            local m = self.modules[i]
            local params = L()
            for j = 1, #m.params do params[j] = m.params[j]:lower() end
            nodes[i] = A.Node(m.id, m.name, m.kind, params, L(), L(), L(), L(), m.enabled, m.x, m.y)
        end
        local wires = L()
        for i = 1, #self.cables do
            local c = self.cables[i]
            wires[i] = A.Wire(c.from_module_id, c.from_port, c.to_module_id, c.to_port)
        end
        local pre_cords = L()
        for i = 1, #self.sources do
            local s = self.sources[i]
            pre_cords[i] = A.PreCord(s.to_module_id, s.to_port, maps.grid_source_to_precord_kind(s.kind), s.arg0)
        end
        return A.Graph(self.id, inputs, outputs, nodes, wires, pre_cords, A.Free, maps.domain(self.domain))
    end
end
