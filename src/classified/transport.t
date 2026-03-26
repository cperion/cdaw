-- impl2/classified/transport.t
-- Classified.Transport:schedule, Classified.TempoMap:schedule

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local D = types.Scheduled
    local function schedule_transport(self)
        return D.Transport(
            self.sample_rate, self.buffer_size,
            self.bpm,
            self.time_sig_num, self.time_sig_den,
            self.launch_quant_code, self.looping,
            self.loop_start_tick, self.loop_end_tick,
            self.fill_active, self.groove_enabled,
            self.groove_shuffle_rate, self.groove_shuffle_amount,
            self.groove_accent_rate, self.groove_accent_amount,
            self.groove_accent_phase
        )
    end

    local function schedule_tempo_map(self)
        local segs = L()
        for i = 1, #self.segments do
            local s = self.segments[i]
            segs[i] = D.TempoSeg(
                s.start_tick, s.end_tick, s.bpm,
                s.base_sample, s.samples_per_tick
            )
        end
        return D.TempoMap(segs)
    end

    return {
        transport = schedule_transport,
        tempo_map = schedule_tempo_map,
    }
end
