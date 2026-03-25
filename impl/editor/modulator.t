-- impl/editor/modulator.t
-- Editor.Modulator:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.modulator.lower", "real")

local lower_modulator = terralib.memoize(function(self)
    local params = diag.map(nil, "editor.modulator.lower.params",
        self.params, function(p) return p:lower() end)

    local mod_node = D.Authored.Node(
        self.id,
        self.name,
        self.kind,
        params,
        L(), L(),
        L(), L(),
        self.enabled
    )

    local routes = L()
    for i = 1, #self.mappings do
        local m = self.mappings[i]
        routes[i] = D.Authored.ModRoute(
            m.target_param_id,
            m.depth,
            m.bipolar,
            m.scale_modulator_id,
            m.scale_param_id
        )
    end

    return D.Authored.ModSlot(mod_node, routes, self.per_voice)
end)

function D.Editor.Modulator:lower()
    return diag.wrap(nil, "editor.modulator.lower", "real", function()
        return lower_modulator(self)
    end, function()
        return F.authored_mod_slot()
    end)
end

return true
