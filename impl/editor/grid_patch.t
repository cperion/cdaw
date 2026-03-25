-- impl/editor/grid_patch.t
-- Editor.GridPatch:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.grid_patch.lower", "real")

local lower_grid_patch = terralib.memoize(function(self)
    local inputs = L()
    for i = 1, #self.inputs do
        local p = self.inputs[i]
        inputs[i] = D.Authored.GraphPort(
            p.id, p.name, F.port_hint_e2a(p.hint), p.channels, p.optional
        )
    end
    local outputs = L()
    for i = 1, #self.outputs do
        local p = self.outputs[i]
        outputs[i] = D.Authored.GraphPort(
            p.id, p.name, F.port_hint_e2a(p.hint), p.channels, p.optional
        )
    end

    local nodes = L()
    for i = 1, #self.modules do
        local m = self.modules[i]
        local params = diag.map(nil, "editor.grid_patch.lower.module_params",
            m.params, function(p) return p:lower() end)
        nodes[i] = D.Authored.Node(
            m.id, m.name, m.kind,
            params, L(), L(),
            L(), L(),
            m.enabled,
            m.x, m.y
        )
    end

    local wires = L()
    for i = 1, #self.cables do
        local c = self.cables[i]
        wires[i] = D.Authored.Wire(
            c.from_module_id, c.from_port,
            c.to_module_id, c.to_port
        )
    end

    local pre_cords = L()
    for i = 1, #self.sources do
        local s = self.sources[i]
        pre_cords[i] = D.Authored.PreCord(
            s.to_module_id, s.to_port,
            F.grid_source_to_precord_kind(s.kind),
            s.arg0
        )
    end

    return D.Authored.Graph(
        self.id,
        inputs, outputs,
        nodes, wires, pre_cords,
        D.Authored.Free,
        F.domain_e2a(self.domain)
    )
end)

function D.Editor.GridPatch:lower()
    return diag.wrap(nil, "editor.grid_patch.lower", "real", function()
        return lower_grid_patch(self)
    end, function()
        return F.authored_graph(self.id, D.Authored.Free)
    end)
end

return true
