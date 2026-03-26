-- impl2/authored/asset_bank.t
-- Authored.AssetBank:resolve -> Resolved.AssetBank

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(R)
    local loop_mode_codes = { NoLoop = 0, LoopFwd = 1, LoopPingPong = 2, LoopRev = 3 }

    return function(self, ticks_per_beat)
        local audio = L()
        for i = 1, #self.audio do
            local a = self.audio[i]
            audio[i] = R.AudioAsset(a.id, a.path, a.sample_rate, a.channels, a.length_samples)
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
                    events:insert(R.NoteEvent(0, start_tick, n.pitch, n.velocity, 0))
                    events:insert(R.NoteEvent(1, end_tick, n.pitch, n.release_velocity or 0, 0))
                end
            end
            table.sort(events, function(a, b) return a.tick < b.tick end)
            notes[i] = R.NoteAsset(na.id, events, na.loop_start_beats * ticks_per_beat, na.loop_end_beats * ticks_per_beat)
        end
        local wavetables = L()
        for i = 1, #self.wavetables do
            local w = self.wavetables[i]
            wavetables[i] = R.WavetableAsset(w.id, w.path, w.frames)
        end
        local irs = L()
        for i = 1, #self.irs do
            local ir = self.irs[i]
            irs[i] = R.IRAsset(ir.id, ir.path, ir.sample_rate)
        end
        local zone_banks = L()
        for i = 1, #self.zone_banks do
            local zb = self.zone_banks[i]
            local zones = L()
            for j = 1, #zb.zones do
                local z = zb.zones[j]
                zones[j] = R.SampleZone(z.path, z.root, z.lo_note, z.hi_note, z.lo_vel, z.hi_vel,
                    z.loop_start, z.loop_end, loop_mode_codes[z.loop_mode and z.loop_mode.kind] or 0)
            end
            zone_banks[i] = R.ZoneBank(zb.id, zones)
        end
        return R.AssetBank(audio, notes, wavetables, irs, zone_banks)
    end
end
