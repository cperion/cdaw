-- impl/authored/asset_bank.t
-- Authored.AssetBank:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.asset_bank.resolve", "real")

local DEFAULT_TICKS_PER_BEAT = 960
local loop_mode_codes = { NoLoop = 0, LoopFwd = 1, LoopPingPong = 2, LoopRev = 3 }

local resolve_asset_bank = terralib.memoize(function(self, ticks_per_beat)
    local audio = L()
    for i = 1, #self.audio do
        local a = self.audio[i]
        audio[i] = D.Resolved.AudioAsset(a.id, a.path, a.sample_rate, a.channels, a.length_samples)
    end

    local notes = L()
    for i = 1, #self.notes do
        local na = self.notes[i]
        local events = L()
        for j = 1, #na.notes do
            local n = na.notes[j]
            if not n.muted then
                local start_tick = n.start_beats * ticks_per_beat
                local end_tick = (n.start_beats + n.duration_beats) * ticks_per_beat
                events:insert(D.Resolved.NoteEvent(0, start_tick, n.pitch, n.velocity, 0))
                events:insert(D.Resolved.NoteEvent(1, end_tick, n.pitch, n.release_velocity or 0, 0))
            end
        end
        table.sort(events, function(a, b) return a.tick < b.tick end)
        notes[i] = D.Resolved.NoteAsset(
            na.id,
            events,
            na.loop_start_beats * ticks_per_beat,
            na.loop_end_beats * ticks_per_beat
        )
    end

    local wavetables = L()
    for i = 1, #self.wavetables do
        local w = self.wavetables[i]
        wavetables[i] = D.Resolved.WavetableAsset(w.id, w.path, w.frames)
    end

    local irs = L()
    for i = 1, #self.irs do
        local ir = self.irs[i]
        irs[i] = D.Resolved.IRAsset(ir.id, ir.path, ir.sample_rate)
    end

    local zone_banks = L()
    for i = 1, #self.zone_banks do
        local zb = self.zone_banks[i]
        local zones = L()
        for j = 1, #zb.zones do
            local z = zb.zones[j]
            zones[j] = D.Resolved.SampleZone(
                z.path, z.root,
                z.lo_note, z.hi_note,
                z.lo_vel, z.hi_vel,
                z.loop_start, z.loop_end,
                loop_mode_codes[z.loop_mode and z.loop_mode.kind] or 0
            )
        end
        zone_banks[i] = D.Resolved.ZoneBank(zb.id, zones)
    end

    return D.Resolved.AssetBank(audio, notes, wavetables, irs, zone_banks)
end)

function D.Authored.AssetBank:resolve(ticks_per_beat)
    ticks_per_beat = type(ticks_per_beat) == "number" and ticks_per_beat or DEFAULT_TICKS_PER_BEAT
    return diag.wrap(nil, "authored.asset_bank.resolve", "real", function()
        return resolve_asset_bank(self, ticks_per_beat)
    end, function()
        return F.resolved_asset_bank()
    end)
end

return true
