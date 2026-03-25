-- impl/editor/track.t
-- Editor.Track:lower

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.track.lower", "real")

local with_graph_id = terralib.memoize(function(graph, graph_id)
    if not graph then return F.authored_graph(graph_id or 0) end
    return D.Authored.Graph(
        graph_id or graph.id,
        graph.inputs,
        graph.outputs,
        graph.nodes,
        graph.wires,
        graph.pre_cords,
        graph.layout,
        graph.domain
    )
end)

local lower_track = terralib.memoize(function(self)
    local input = F.track_input_e2a(self.input)
    local volume = self.volume:lower()
    local pan = self.pan:lower()
    local device_graph = with_graph_id(self.devices:lower(), self.id)

    local clips = diag.map(nil, "editor.track.lower.clips",
        self.clips, function(c) return c:lower() end)

    local slots = diag.map(nil, "editor.track.lower.slots",
        self.launcher_slots, function(s) return s:lower() end)

    local sends = diag.map(nil, "editor.track.lower.sends",
        self.sends, function(s) return s:lower() end)

    return D.Authored.Track(
        self.id,
        self.name,
        self.channels,
        input,
        volume,
        pan,
        device_graph,
        clips,
        slots,
        sends,
        self.output_track_id,
        self.group_track_id,
        self.muted,
        self.soloed,
        self.armed,
        self.monitor_input,
        self.phase_invert
    )
end)

function D.Editor.Track:lower()
    return diag.wrap(nil, "editor.track.lower", "real", function()
        return lower_track(self)
    end, function()
        return F.authored_track(self.id, self.name, self.channels)
    end)
end

return true
