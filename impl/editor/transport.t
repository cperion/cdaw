-- impl/editor/transport.t
-- Editor.Transport:lower, Editor.TempoMap:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.tempo_map.lower", "real")
diag.status("editor.transport.lower", "real")


function D.Editor.Transport:lower(ctx)
    return diag.wrap(ctx, "editor.transport.lower", "real", function()
        -- Convert Editor.TimeRange? → Authored.TimeRange?
        local loop_range = nil
        if self.loop_range then
            loop_range = D.Authored.TimeRange(
                self.loop_range.start_beats,
                self.loop_range.end_beats
            )
        end

        return D.Authored.Transport(
            self.sample_rate,
            self.buffer_size,
            self.bpm,
            self.swing,
            self.time_sig_num,
            self.time_sig_den,
            F.quantize_e2a(self.launch_quantize),
            self.looping,
            loop_range
        )
    end, function()
        return F.authored_transport()
    end)
end

function D.Editor.TempoMap:lower(ctx)
    return diag.wrap(ctx, "editor.tempo_map.lower", "real", function()
        local tempo = L()
        for i = 1, #self.tempo do
            local pt = self.tempo[i]
            tempo[i] = D.Authored.TempoPoint(pt.at_beats, pt.bpm)
        end
        local sigs = L()
        for i = 1, #self.signatures do
            local s = self.signatures[i]
            sigs[i] = D.Authored.SigPoint(s.at_beats, s.num, s.den)
        end
        return D.Authored.TempoMap(tempo, sigs)
    end, function()
        return F.authored_tempo_map()
    end)
end

return true
