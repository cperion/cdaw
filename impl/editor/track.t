-- impl/editor/track.t
-- Editor.Track:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.track.lower", "real")


function D.Editor.Track:lower(ctx)
    return diag.wrap(ctx, "editor.track.lower", "real", function()
        local input = F.track_input_e2a(self.input)
        local volume = self.volume:lower(ctx)
        local pan = self.pan:lower(ctx)
        local device_graph = self.devices:lower(ctx)

        local clips = diag.map(ctx, "editor.track.lower.clips",
            self.clips, function(c) return c:lower(ctx) end)

        local slots = diag.map(ctx, "editor.track.lower.slots",
            self.launcher_slots, function(s) return s:lower(ctx) end)

        local sends = diag.map(ctx, "editor.track.lower.sends",
            self.sends, function(s) return s:lower(ctx) end)

        return D.Authored.Track(
            self.id,
            self.name,
            self.channels,
            input,
            volume,
            pan,
            device_graph,
            clips,
            slots,
            sends,
            self.output_track_id,
            self.group_track_id,
            self.muted,
            self.soloed,
            self.armed,
            self.monitor_input,
            self.phase_invert
        )
    end, function()
        return F.authored_track(self.id, self.name, self.channels)
    end)
end

return true
