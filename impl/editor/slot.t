-- impl/editor/slot.t
-- Editor.Slot:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.slot.lower", "real")

local lower_slot = terralib.memoize(function(self)
    local content = F.slot_content_e2a(self.content)

    local follow = nil
    if self.behavior.follow then
        local ef = self.behavior.follow
        follow = D.Authored.FollowAction(
            F.follow_kind_e2a(ef.kind),
            ef.weight_a, ef.weight_b,
            ef.target_scene_id
        )
    end

    local behavior = D.Authored.LaunchBehavior(
        F.launch_mode_e2a(self.behavior.mode),
        self.behavior.quantize_override and F.quantize_e2a(self.behavior.quantize_override) or nil,
        self.behavior.legato,
        self.behavior.retrigger,
        follow
    )

    return D.Authored.Slot(self.slot_index, content, behavior, self.enabled)
end)

function D.Editor.Slot:lower()
    return diag.wrap(nil, "editor.slot.lower", "real", function()
        return lower_slot(self)
    end, function()
        return F.authored_slot(self.slot_index)
    end)
end

return true
