-- impl2/editor/modulator.t
-- Editor.Modulator:lower -> Authored.ModSlot

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    return function(self)
        local params = L()
        for i = 1, #self.params do params[i] = self.params[i]:lower() end

        local mod_node = A.Node(
            self.id, self.name, self.kind,
            params, L(), L(), L(), L(),
            self.enabled
        )

        local routes = L()
        for i = 1, #self.mappings do
            local m = self.mappings[i]
            routes[i] = A.ModRoute(m.target_param_id, m.depth, m.bipolar, m.scale_modulator_id, m.scale_param_id)
        end

        return A.ModSlot(mod_node, routes, self.per_voice)
    end
end
