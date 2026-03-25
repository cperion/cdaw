-- impl/resolved/transport.t
-- Resolved.Transport:classify, Resolved.TempoMap:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.tempo_map.classify", "real")
diag.status("resolved.transport.classify", "real")

local classify_transport = terralib.memoize(function(self)
    return D.Classified.Transport(
        self.sample_rate,
        self.buffer_size,
        self.bpm,
        self.swing,
        self.time_sig_num,
        self.time_sig_den,
        self.launch_quant_code,
        self.looping,
        self.loop_start_tick,
        self.loop_end_tick
    )
end)

local classify_tempo_map = terralib.memoize(function(self)
    local segments = L()
    for i = 1, #self.segments do
        local s = self.segments[i]
        local end_tick = (i < #self.segments) and self.segments[i + 1].start_tick or (s.start_tick + 1e9)
        segments[i] = D.Classified.TempoSeg(
            s.start_tick,
            end_tick,
            s.bpm,
            s.base_sample,
            s.samples_per_tick
        )
    end
    return D.Classified.TempoMap(segments)
end)

function D.Resolved.Transport:classify()
    return diag.wrap(nil, "resolved.transport.classify", "real", function()
        return classify_transport(self)
    end, function()
        return F.classified_transport()
    end)
end

function D.Resolved.TempoMap:classify()
    return diag.wrap(nil, "resolved.tempo_map.classify", "real", function()
        return classify_tempo_map(self)
    end, function()
        return F.classified_tempo_map()
    end)
end

return true
