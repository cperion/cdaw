-- impl/editor/scene.t
-- Editor.Scene:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.scene.lower", "real")


function D.Editor.Scene:lower(ctx)
    return diag.wrap(ctx, "editor.scene.lower", "real", function()
        local slots = L()
        for i = 1, #self.slots do
            local s = self.slots[i]
            slots[i] = D.Authored.SceneSlot(s.track_id, s.slot_index, s.stop_others)
        end

        return D.Authored.Scene(
            self.id,
            self.name,
            slots,
            self.quantize_override
                and F.quantize_e2a(self.quantize_override) or nil,
            self.tempo_override
        )
    end, function()
        return F.authored_scene(self.id, self.name)
    end)
end

return true
