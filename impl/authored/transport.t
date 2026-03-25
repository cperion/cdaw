-- impl/authored/transport.t
-- Authored.Transport:resolve, Authored.TempoMap:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.tempo_map.resolve", "real")
diag.status("authored.transport.resolve", "real")

local DEFAULT_TICKS_PER_BEAT = 960
local DEFAULT_SAMPLE_RATE = 44100

local quantize_codes = {}
local qnames = {"QNone","Q1_64","Q1_32","Q1_16","Q1_8","Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars"}
for i, name in ipairs(qnames) do
    if D.Authored[name] then quantize_codes[D.Authored[name]] = i - 1 end
end
local function quantize_to_code(q)
    if q == nil then return 0 end
    return quantize_codes[q] or (q.kind and quantize_codes[q.kind]) or 0
end

local resolve_transport = terralib.memoize(function(self, ticks_per_beat)
    local loop_start = 0
    local loop_end = 0
    if self.loop_range then
        loop_start = self.loop_range.start_beats * ticks_per_beat
        loop_end = self.loop_range.end_beats * ticks_per_beat
    end

    return D.Resolved.Transport(
        self.sample_rate,
        self.buffer_size,
        self.bpm,
        self.swing,
        self.time_sig_num,
        self.time_sig_den,
        quantize_to_code(self.launch_quantize),
        self.looping,
        loop_start,
        loop_end
    )
end)

local resolve_tempo_map_for = terralib.memoize(function(self, ticks_per_beat, sample_rate)
    local segments = L()
    if #self.tempo == 0 then
        return D.Resolved.TempoMap(segments)
    end

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
            local delta_ticks = seg_data[i].start_tick - prev.start_tick
            base_sample = prev.base_sample + delta_ticks * prev.spt
        end
        seg_data[i].base_sample = base_sample
    end

    for i = 1, #seg_data do
        local sd = seg_data[i]
        segments[i] = D.Resolved.TempoSeg(sd.start_tick, sd.bpm, sd.base_sample, sd.spt)
    end

    return D.Resolved.TempoMap(segments)
end)

function D.Authored.Transport:resolve(ticks_per_beat)
    ticks_per_beat = type(ticks_per_beat) == "number" and ticks_per_beat or DEFAULT_TICKS_PER_BEAT
    return diag.wrap(nil, "authored.transport.resolve", "real", function()
        return resolve_transport(self, ticks_per_beat)
    end, function()
        return F.resolved_transport()
    end)
end

function D.Authored.TempoMap:resolve(ticks_per_beat, sample_rate)
    ticks_per_beat = type(ticks_per_beat) == "number" and ticks_per_beat or DEFAULT_TICKS_PER_BEAT
    sample_rate = type(sample_rate) == "number" and sample_rate or DEFAULT_SAMPLE_RATE
    return diag.wrap(nil, "authored.tempo_map.resolve", "real", function()
        return resolve_tempo_map_for(self, ticks_per_beat, sample_rate)
    end, function()
        return F.resolved_tempo_map()
    end)
end

return true
