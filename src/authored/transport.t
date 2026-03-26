-- impl2/authored/transport.t
-- Authored.Transport:resolve, Authored.TempoMap:resolve

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local R = types.Resolved
    local qnames = {"QNone","Q1_64","Q1_32","Q1_16","Q1_8","Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars"}
    local quantize_codes = {}
    for i, name in ipairs(qnames) do quantize_codes[name] = i - 1 end
    local function quantize_to_code(q)
        if q == nil then return 0 end
        return quantize_codes[q.kind] or 0
    end

    local function resolve_transport(self, ticks_per_beat)
        local loop_start, loop_end = 0, 0
        if self.loop_range then
            loop_start = self.loop_range.start_beats * ticks_per_beat
            loop_end = self.loop_range.end_beats * ticks_per_beat
        end
        return R.Transport(self.sample_rate, self.buffer_size, self.bpm,
            self.time_sig_num, self.time_sig_den, quantize_to_code(self.launch_quantize),
            self.looping, loop_start, loop_end,
            self.fill_active, self.groove_enabled,
            self.groove_shuffle_rate, self.groove_shuffle_amount,
            self.groove_accent_rate, self.groove_accent_amount,
            self.groove_accent_phase)
    end

    local function resolve_tempo_map(self, ticks_per_beat, sample_rate)
        local segments = L()
        if #self.tempo == 0 then return R.TempoMap(segments) end
        local seg_data = {}
        for i = 1, #self.tempo do
            local pt = self.tempo[i]
            local start_tick = pt.at_beats * ticks_per_beat
            local bpm = pt.bpm
            local spt = (60.0 / bpm) * sample_rate / ticks_per_beat
            seg_data[i] = { start_tick = start_tick, bpm = bpm, spt = spt }
        end
        for i = 1, #seg_data do
            local base_sample = 0
            if i > 1 then
                local prev = seg_data[i - 1]
                base_sample = prev.base_sample + (seg_data[i].start_tick - prev.start_tick) * prev.spt
            end
            seg_data[i].base_sample = base_sample
        end
        for i = 1, #seg_data do
            local sd = seg_data[i]
            segments[i] = R.TempoSeg(sd.start_tick, sd.bpm, sd.base_sample, sd.spt)
        end
        return R.TempoMap(segments)
    end

    return {
        transport = resolve_transport,
        tempo_map = resolve_tempo_map,
    }
end
