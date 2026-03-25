-- impl/authored/track.t
-- Authored.Track:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.track.resolve", "partial")


-- TrackInput → (kind_code, arg0, arg1)
-- NoInput=0, AudioInput=1, MIDIInput=2, TrackInputTap=3
local function encode_input(input)
    if input == nil or input.kind == "NoInput" then return 0, 0, 0 end
    if input.kind == "AudioInput" then return 1, input.device_id, input.channel end
    if input.kind == "MIDIInput" then return 2, input.device_id, input.channel end
    if input.kind == "TrackInputTap" then return 3, input.track_id, input.post_fader and 1 or 0 end
    return 0, 0, 0
end

function D.Authored.Track:resolve(ctx)
    return diag.wrap(ctx, "authored.track.resolve", "partial", function()
        local ik, ia0, ia1 = encode_input(self.input)

        local volume = self.volume:resolve(ctx)
        local pan = self.pan:resolve(ctx)
        local device_graph = self.device_graph:resolve(ctx)

        local clips = diag.map(ctx, "authored.track.resolve.clips",
            self.clips, function(c) return c:resolve(ctx) end)
        local slots = diag.map(ctx, "authored.track.resolve.slots",
            self.launcher_slots, function(s) return s:resolve(ctx) end)
        local sends = diag.map(ctx, "authored.track.resolve.sends",
            self.sends, function(s) return s:resolve(ctx) end)

        local send_ids = L()
        for i = 1, #sends do send_ids[i] = sends[i].id end

        return D.Resolved.Track(
            self.id,
            self.name,
            self.channels,
            ik, ia0, ia1,
            volume.id,
            pan.id,
            device_graph.id,
            0, #clips,        -- first_clip, clip_count (set by flattening)
            0, #slots,        -- first_slot, slot_count
            send_ids,
            self.output_track_id,
            self.group_track_id,
            self.muted,
            self.soloed,
            self.armed,
            self.monitor_input,
            self.phase_invert
        )
    end, function()
        return F.resolved_track(self.id, self.name, self.channels)
    end)
end

return true
