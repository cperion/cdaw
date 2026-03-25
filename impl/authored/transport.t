-- impl/authored/transport.t
-- Authored.Transport:resolve, Authored.TempoMap:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.tempo_map.resolve", "real")
diag.status("authored.transport.resolve", "real")


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
    return diag.wrap(ctx, "authored.transport.resolve", "real", function()
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
    return diag.wrap(ctx, "authored.tempo_map.resolve", "real", function()
        local ticks_per_beat = (ctx and ctx.ticks_per_beat) or 960
        local segments = L()
        local sample_rate = (ctx and ctx.sample_rate) or 44100

        if #self.tempo == 0 then
            return D.Resolved.TempoMap(L())
        end

        -- First pass: compute start_tick and samples_per_tick for each segment
        local seg_data = {}
        for i = 1, #self.tempo do
            local pt = self.tempo[i]
            local start_tick = pt.at_beats * ticks_per_beat
            local bpm = pt.bpm
            -- samples_per_tick = (60 / bpm) * sample_rate / ticks_per_beat
            local spt = (60.0 / bpm) * sample_rate / ticks_per_beat
            seg_data[i] = { start_tick = start_tick, bpm = bpm, spt = spt }
        end

        -- Second pass: compute cumulative base_sample
        -- base_sample[1] = 0
        -- base_sample[i] = base_sample[i-1] + (start_tick[i] - start_tick[i-1]) * spt[i-1]
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
    end, function()
        return F.resolved_tempo_map()
    end)
end

return true
