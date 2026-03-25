-- impl/editor/send.t
-- Editor.Send:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.send.lower", "real")

local lower_send = terralib.memoize(function(self)
    return D.Authored.Send(
        self.id,
        self.target_track_id,
        self.level:lower(),
        self.pre_fader,
        self.enabled
    )
end)

function D.Editor.Send:lower()
    return diag.wrap(nil, "editor.send.lower", "real", function()
        return lower_send(self)
    end, function()
        return F.authored_send(self.id, self.target_track_id)
    end)
end

return true
