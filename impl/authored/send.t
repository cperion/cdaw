-- impl/authored/send.t
-- Authored.Send:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.send.resolve", "real")

local resolve_send = terralib.memoize(function(self)
    local level_param = self.level:resolve()
    return D.Resolved.Send(
        self.id,
        self.target_track_id,
        level_param.id,
        self.pre_fader,
        self.enabled
    )
end)

function D.Authored.Send:resolve()
    return diag.wrap(nil, "authored.send.resolve", "real", function()
        return resolve_send(self)
    end, function()
        return F.resolved_send(self.id, self.target_track_id)
    end)
end

return true
