-- impl2/editor/track.t
-- Editor.Track:lower -> Authored.Track

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    return function(self)
        local input = maps.track_input(self.input)
        local volume = self.volume:lower()
        local pan = self.pan:lower()

        local device_graph = self.devices:lower()
        if device_graph then
            device_graph = A.Graph(self.id, device_graph.inputs, device_graph.outputs, device_graph.nodes, device_graph.wires, device_graph.pre_cords, device_graph.layout, device_graph.domain)
        else
            device_graph = A.Graph(self.id, L(), L(), L(), L(), L(), A.Serial, A.AudioDomain)
        end

        local clips = L()
        for i = 1, #self.clips do clips[i] = self.clips[i]:lower() end
        local slots = L()
        for i = 1, #self.launcher_slots do slots[i] = self.launcher_slots[i]:lower() end
        local sends = L()
        for i = 1, #self.sends do sends[i] = self.sends[i]:lower() end

        -- Derive output_track_id from TrackFeedOutput; others map to nil.
        local output_track_id = nil
        if self.output and self.output.kind == "TrackFeedOutput" then
            output_track_id = self.output.track_id
        end

        return A.Track(
            self.id, self.name, self.channels,
            input, volume, pan, device_graph,
            clips, slots, sends,
            output_track_id, self.group_track_id,
            self.muted, self.soloed, self.armed, self.monitor_input, self.phase_invert
        )
    end
end
