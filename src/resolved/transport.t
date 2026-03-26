-- impl2/resolved/transport.t
-- Resolved.Transport:classify, Resolved.TempoMap:classify

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local D = types.Classified
    local function classify_transport(self)
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

    local function classify_tempo_map(self)
        local segments = L()
        for i = 1, #self.segments do
            local s = self.segments[i]
            local end_tick = (i < #self.segments) and self.segments[i + 1].start_tick or (s.start_tick + 1e9)
            segments[i] = D.TempoSeg(
                s.start_tick, end_tick, s.bpm,
                s.base_sample, s.samples_per_tick
            )
        end
        return D.TempoMap(segments)
    end

    return {
        transport = classify_transport,
        tempo_map = classify_tempo_map,
    }
end
