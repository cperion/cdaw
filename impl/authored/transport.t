-- impl/authored/transport.t
-- Authored.Transport:resolve, Authored.TempoMap:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.tempo_map.resolve", "partial")
diag.status("authored.transport.resolve", "partial")


-- Map Authored.Quantize → numeric code
local quantize_codes = {}
local qnames = {"QNone","Q1_64","Q1_32","Q1_16","Q1_8","Q1_4","Q1_2","Q1Bar","Q2Bars","Q4Bars"}
for i, name in ipairs(qnames) do
    if D.Authored[name] then quantize_codes[D.Authored[name]] = i - 1 end
end
local function quantize_to_code(q)
    if q == nil then return 0 end
    return quantize_codes[q] or (q.kind and quantize_codes[q.kind]) or 0
end

function D.Authored.Transport:resolve(ctx)
    return diag.wrap(ctx, "authored.transport.resolve", "partial", function()
        local loop_start = 0
        local loop_end = 0
        if self.loop_range then
            local ticks_per_beat = (ctx and ctx.ticks_per_beat) or 960
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
    end, function()
        return F.resolved_transport()
    end)
end

function D.Authored.TempoMap:resolve(ctx)
    return diag.wrap(ctx, "authored.tempo_map.resolve", "partial", function()
        local ticks_per_beat = (ctx and ctx.ticks_per_beat) or 960
        local segments = L()

        if #self.tempo == 0 then
            -- No tempo points: single segment at default bpm
            -- Cannot compute samples_per_tick without bpm — use default
            return D.Resolved.TempoMap(L())
        end

        for i = 1, #self.tempo do
            local pt = self.tempo[i]
            local start_tick = pt.at_beats * ticks_per_beat
            local bpm = pt.bpm
            local sample_rate = (ctx and ctx.sample_rate) or 44100
            -- samples_per_tick = (60 / bpm) * sample_rate / ticks_per_beat
            local spt = (60.0 / bpm) * sample_rate / ticks_per_beat
            -- base_sample: cumulative sample position (simplified: 0 for stub)
            local base_sample = 0
            segments[i] = D.Resolved.TempoSeg(start_tick, bpm, base_sample, spt)
        end

        return D.Resolved.TempoMap(segments)
    end, function()
        return F.resolved_tempo_map()
    end)
end

return true
