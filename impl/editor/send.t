-- impl/editor/send.t
-- Editor.Send:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.send.lower", "real")


function D.Editor.Send:lower(ctx)
    return diag.wrap(ctx, "editor.send.lower", "real", function()
        return D.Authored.Send(
            self.id,
            self.target_track_id,
            self.level:lower(ctx),
            self.pre_fader,
            self.enabled
        )
    end, function()
        return F.authored_send(self.id, self.target_track_id)
    end)
end

return true
