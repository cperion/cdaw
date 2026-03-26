-- impl2/editor/transport.t
-- Editor.Transport:lower, Editor.TempoMap:lower

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    local function lower_transport(self)
        local loop_range = nil
        if self.loop_range then
            loop_range = A.TimeRange(self.loop_range.start_beats, self.loop_range.end_beats)
        end
        return A.Transport(
            self.sample_rate, self.buffer_size,
            self.bpm, self.swing,
            self.time_sig_num, self.time_sig_den,
            maps.quantize(self.launch_quantize),
            self.looping, loop_range
        )
    end

    local function lower_tempo_map(self)
        local tempo = L()
        for i = 1, #self.tempo do
            local pt = self.tempo[i]
            tempo[i] = A.TempoPoint(pt.at_beats, pt.bpm)
        end
        local sigs = L()
        for i = 1, #self.signatures do
            local s = self.signatures[i]
            sigs[i] = A.SigPoint(s.at_beats, s.num, s.den)
        end
        return A.TempoMap(tempo, sigs)
    end

    return {
        transport = lower_transport,
        tempo_map = lower_tempo_map,
    }
end
