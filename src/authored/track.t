-- impl2/authored/track.t
-- Authored.Track:resolve -> Resolved.TrackSlice

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(R)
    local interp_codes = { Linear = 0, Smoothstep = 1, Hold = 2 }

    local function authored_curve_to_resolved(param, ticks_per_beat)
        if not param.source or param.source.kind ~= "AutomationRef" then return nil end
        local curve = param.source.curve
        local points = L()
        for i = 1, #curve.points do
            local pt = curve.points[i]
            points[i] = R.AutoPoint(pt.time_beats * ticks_per_beat, pt.value)
        end
        return R.AutoCurve(tonumber(param.id) or 0, points, interp_codes[curve.mode and curve.mode.kind] or 0)
    end

    local function encode_input(input)
        if input == nil or input.kind == "NoInput" then return 0, 0, 0 end
        if input.kind == "AudioInput" then return 1, input.device_id, input.channel end
        if input.kind == "MIDIInput" then return 2, input.device_id, input.channel end
        if input.kind == "TrackInputTap" then return 3, input.track_id, input.post_fader and 1 or 0 end
        return 0, 0, 0
    end

    return function(self, ticks_per_beat)
        local ik, ia0, ia1 = encode_input(self.input)
        local mixer_params = L()
        mixer_params[1] = self.volume:resolve(ticks_per_beat)
        mixer_params[2] = self.pan:resolve(ticks_per_beat)
        local mixer_curves = L()
        local c = authored_curve_to_resolved(self.volume, ticks_per_beat)
        if c then mixer_curves:insert(c) end
        c = authored_curve_to_resolved(self.pan, ticks_per_beat)
        if c then mixer_curves:insert(c) end

        local device_graph = self.device_graph:resolve(ticks_per_beat)

        local clips = L()
        for i = 1, #self.clips do
            clips[i] = self.clips[i]:resolve(ticks_per_beat)
            local gain_param = self.clips[i].gain:resolve(ticks_per_beat)
            mixer_params:insert(gain_param)
            c = authored_curve_to_resolved(self.clips[i].gain, ticks_per_beat)
            if c then mixer_curves:insert(c) end
        end

        local slots = L()
        for i = 1, #self.launcher_slots do slots[i] = self.launcher_slots[i]:resolve() end

        local sends = L()
        for i = 1, #self.sends do
            sends[i] = self.sends[i]:resolve()
            local level_param = self.sends[i].level:resolve(ticks_per_beat)
            mixer_params:insert(level_param)
            c = authored_curve_to_resolved(self.sends[i].level, ticks_per_beat)
            if c then mixer_curves:insert(c) end
        end

        local track = R.Track(self.id, self.name, self.channels,
            ik, ia0, ia1, 0, 1,
            (#device_graph.graphs > 0 and device_graph.graphs[1].id) or 0,
            self.output_track_id, self.group_track_id,
            self.muted, self.soloed, self.armed, self.monitor_input, self.phase_invert)

        return R.TrackSlice(track, mixer_params, mixer_curves, clips, slots, sends, device_graph)
    end
end
