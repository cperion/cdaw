-- impl/classified/transport.t
-- Classified.Transport:schedule, Classified.TempoMap:schedule

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.tempo_map.schedule", "real")
diag.status("classified.transport.schedule", "real")

local schedule_transport = terralib.memoize(function(self)
    return D.Scheduled.Transport(
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

local schedule_tempo_map = terralib.memoize(function(self)
    local segs = L()
    for i = 1, #self.segments do
        local s = self.segments[i]
        segs[i] = D.Scheduled.TempoSeg(
            s.start_tick, s.end_tick, s.bpm,
            s.base_sample, s.samples_per_tick
        )
    end
    return D.Scheduled.TempoMap(segs)
end)

function D.Classified.Transport:schedule()
    return diag.wrap(nil, "classified.transport.schedule", "real", function()
        return schedule_transport(self)
    end, function()
        return F.scheduled_transport()
    end)
end

function D.Classified.TempoMap:schedule()
    return diag.wrap(nil, "classified.tempo_map.schedule", "real", function()
        return schedule_tempo_map(self)
    end, function()
        return F.scheduled_tempo_map()
    end)
end

return true
