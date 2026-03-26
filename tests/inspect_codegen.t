-- tests/inspect_codegen.t
-- Human-readable inspector for the slice/program pipeline.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local TICKS_PER_BEAT = 960

local function sum_track_slices(track_slices, field_path)
    local total = 0
    for i = 1, #track_slices do
        local v = track_slices[i]
        for part in field_path:gmatch("[^.]+") do v = v and v[part] or nil end
        total = total + (v and #v or 0)
    end
    return total
end

local function total_classified_literals(classified)
    local total = 0
    for i = 1, #classified.track_slices do
        total = total + #classified.track_slices[i].mixer_literals
        total = total + #classified.track_slices[i].device_graph.literals
    end
    return total
end

local function total_classified_params(classified)
    local total = 0
    for i = 1, #classified.track_slices do
        total = total + #classified.track_slices[i].mixer_params
        total = total + #classified.track_slices[i].device_graph.params
    end
    return total
end

local function total_scheduled_buffers(scheduled)
    local total = 0
    for i = 1, #scheduled.track_programs do total = total + scheduled.track_programs[i].total_buffers end
    return total
end

local function total_scheduled_node_programs(scheduled)
    local total = 0
    for i = 1, #scheduled.track_programs do total = total + #scheduled.track_programs[i].device_graph.node_programs end
    return total
end

local function make_project()
    return D.Editor.Project(
        "Dreaming in Amber", "Pi", 1,
        D.Editor.Transport(44100, 128, 122, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            D.Editor.Track(1, "Pad", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.7), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(-0.2), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(10, "Saw", D.Authored.SawOsc, L{D.Editor.ParamValue(0, "freq", 220, 1, 20000, D.Editor.StaticValue(220), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(11, "Gain", D.Authored.GainNode, L{D.Editor.ParamValue(0, "gain", 0.25, 0, 4, D.Editor.StaticValue(0.25), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(12, "Pan", D.Authored.PanNode, L{D.Editor.ParamValue(0, "pan", 0.1, -1, 1, D.Editor.StaticValue(0.1), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
                }), L(), L(), L(), nil, nil, false, false, false, false, false, nil),
            D.Editor.Track(2, "Bass", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.9), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(20, "Square", D.Authored.SquareOsc, L{D.Editor.ParamValue(0, "freq", 110, 1, 20000, D.Editor.StaticValue(110), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(21, "Saturator", D.Authored.SaturatorNode(D.Authored.Tanh), L{D.Editor.ParamValue(0, "drive", 1.5, 0.1, 10, D.Editor.StaticValue(1.5), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
                }), L(), L(), L(), nil, nil, false, false, false, false, false, nil),
            D.Editor.Track(3, "Lead", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0.2), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(30, "Sine", D.Authored.SineOsc, L{D.Editor.ParamValue(0, "freq", 440, 1, 20000, D.Editor.StaticValue(440), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(31, "Gain", D.Authored.GainNode, L{D.Editor.ParamValue(0, "gain", 0.4, 0, 4, D.Editor.StaticValue(0.4), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(32, "Clip", D.Authored.Clipper(D.Authored.HardClipM), L(), L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(33, "Pan", D.Authored.PanNode, L{D.Editor.ParamValue(0, "pan", 0.25, -1, 1, D.Editor.StaticValue(0.25), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
                }), L(), L(), L(), nil, nil, false, false, false, false, false, nil),
            D.Editor.Track(4, "Texture", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(-0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(40, "Saw", D.Authored.SawOsc, L{D.Editor.ParamValue(0, "freq", 330, 1, 20000, D.Editor.StaticValue(330), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(41, "Wavefolder", D.Authored.Wavefolder, L(), L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(42, "Gain", D.Authored.GainNode, L{D.Editor.ParamValue(0, "gain", 0.2, 0, 4, D.Editor.StaticValue(0.2), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
                }), L(), L(), L(), nil, nil, false, false, false, false, false, nil),
            D.Editor.Track(5, "Master", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(1.0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(50, "EQ", D.Authored.EQNode(L{D.Authored.EQBand(D.Authored.Peak)}), L{D.Editor.ParamValue(0, "freq", 1000, 20, 20000, D.Editor.StaticValue(1000), D.Editor.Replace, D.Editor.NoSmoothing), D.Editor.ParamValue(1, "gain", 1.5, -24, 24, D.Editor.StaticValue(1.5), D.Editor.Replace, D.Editor.NoSmoothing), D.Editor.ParamValue(2, "q", 1.0, 0.1, 10, D.Editor.StaticValue(1.0), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(51, "Comp", D.Authored.CompressorNode, L{D.Editor.ParamValue(0, "threshold", -12, -60, 0, D.Editor.StaticValue(-12), D.Editor.Replace, D.Editor.NoSmoothing), D.Editor.ParamValue(1, "ratio", 2, 1, 20, D.Editor.StaticValue(2), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(52, "Pan", D.Authored.PanNode, L{D.Editor.ParamValue(0, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing)}, L(), nil, nil, nil, true, nil))
                }), L(), L(), L(), nil, nil, false, false, false, false, false, nil)
        },
        L{D.Editor.Scene(1, "A", L(), D.Editor.Q1Bar, nil), D.Editor.Scene(2, "B", L(), D.Editor.Q1Bar, nil)},
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 122), D.Editor.TempoPoint(16, 126)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )
end

print("╔══════════════════════════════════════════════════════════╗")
print("║  Code Generation Inspector: \"Dreaming in Amber\"         ║")
print("║  5 tracks, 15 devices, 2 scenes, 2 tempo points         ║")
print("╚══════════════════════════════════════════════════════════╝")

local project = make_project()
local authored = project:lower()
print("\n── Phase 1: Editor → Authored ──")
print(string.format("  Tracks: %d", #authored.tracks))
print(string.format("  Scenes: %d", #authored.scenes))
for i = 1, #authored.tracks do
    local t = authored.tracks[i]
    print(string.format("    Track %d %-10s: %d nodes in device_graph (layout=%s)",
        i, t.name, #t.device_graph.nodes, tostring(t.device_graph.layout.kind or t.device_graph.layout)))
end

local resolved = authored:resolve(TICKS_PER_BEAT)
local resolved_graphs = sum_track_slices(resolved.track_slices, "device_graph.graphs")
local resolved_nodes = sum_track_slices(resolved.track_slices, "device_graph.nodes")
local resolved_params = sum_track_slices(resolved.track_slices, "mixer_params") + sum_track_slices(resolved.track_slices, "device_graph.params")
local resolved_curves = sum_track_slices(resolved.track_slices, "device_graph.curves")
print("\n── Phase 2: Authored → Resolved (slice flattening) ──")
print("  Slice tables:")
print(string.format("    graphs:             %d", resolved_graphs))
print(string.format("    nodes:              %d", resolved_nodes))
print(string.format("    params:             %d", resolved_params))
print(string.format("    curves:             %d", resolved_curves))
print(string.format("  Track slices: %d   Scenes: %d", #resolved.track_slices, #resolved.scenes))
print(string.format("  Tempo segments: %d", #resolved.tempo_map.segments))

local nk_names = {
    [0]="BasicSynth", [5]="GainNode", [6]="PanNode", [7]="EQNode", [8]="CompressorNode",
    [9]="GateNode", [10]="DelayNode", [11]="ReverbNode", [12]="ChorusNode", [15]="SaturatorNode",
    [27]="SubGraph", [28]="SineOsc", [29]="SawOsc", [30]="SquareOsc", [52]="Wavefolder", [53]="Clipper",
}
local kind_counts = {}
for i = 1, #resolved.track_slices do
    for j = 1, #resolved.track_slices[i].device_graph.nodes do
        local kc = resolved.track_slices[i].device_graph.nodes[j].node_kind_code
        kind_counts[kc] = (kind_counts[kc] or 0) + 1
    end
end
print("\n  Node kind distribution:")
local sorted_kinds = {}
for kc, count in pairs(kind_counts) do sorted_kinds[#sorted_kinds+1] = {kc, count} end
table.sort(sorted_kinds, function(a, b) return a[1] < b[1] end)
for _, pair in ipairs(sorted_kinds) do
    local name = nk_names[pair[1]] or ("kind_" .. pair[1])
    print(string.format("    %-20s (code=%2d): %d nodes", name, pair[1], pair[2]))
end

local static_count, auto_count = 0, 0
for i = 1, #resolved.track_slices do
    for j = 1, #resolved.track_slices[i].mixer_params do
        local p = resolved.track_slices[i].mixer_params[j]
        if p.source.source_kind == 0 then static_count = static_count + 1 else auto_count = auto_count + 1 end
    end
    for j = 1, #resolved.track_slices[i].device_graph.params do
        local p = resolved.track_slices[i].device_graph.params[j]
        if p.source.source_kind == 0 then static_count = static_count + 1 else auto_count = auto_count + 1 end
    end
end
print("\n  Param sources:")
print(string.format("    Static: %d   Automation: %d", static_count, auto_count))

local classified = resolved:classify()
print("\n── Phase 3: Resolved → Classified (rate classification) ──")
print(string.format("  Literal tables: %d entries", total_classified_literals(classified)))
print(string.format("  Total classified params: %d", total_classified_params(classified)))
local rc_names = {[0]="literal", [1]="init", [2]="block", [3]="sample", [4]="event", [5]="voice"}
local rc_counts = {}
for i = 1, #classified.track_slices do
    for j = 1, #classified.track_slices[i].mixer_params do
        local rc = classified.track_slices[i].mixer_params[j].base_value.rate_class
        rc_counts[rc] = (rc_counts[rc] or 0) + 1
    end
    for j = 1, #classified.track_slices[i].device_graph.params do
        local rc = classified.track_slices[i].device_graph.params[j].base_value.rate_class
        rc_counts[rc] = (rc_counts[rc] or 0) + 1
    end
end
print("\n  Param binding summary:")
for rc = 0, 5 do
    if rc_counts[rc] then
        print(string.format("    rate_class=%d (%-7s): %d params", rc, rc_names[rc], rc_counts[rc]))
    end
end

local scheduled = classified:schedule()
print("\n── Phase 4: Classified → Scheduled (program allocation) ──")
print(string.format("  Track programs: %d", #scheduled.track_programs))
print(string.format("  Aggregate buffers: %d", total_scheduled_buffers(scheduled)))
print(string.format("  Aggregate node programs: %d", total_scheduled_node_programs(scheduled)))
for i = 1, #scheduled.track_programs do
    local tp = scheduled.track_programs[i]
    print(string.format("    TrackProgram %d: track=%d work=buf[%d] outL=buf[%d] outR=buf[%d] node_programs=%d",
        i, tp.track.track_id, tp.track.work_buf, tp.master_left, tp.master_right, #tp.device_graph.node_programs))
end

print("\n── Phase 5: Scheduled → Kernel (Terra code generation) ──")
local kernel = scheduled:compile()
local entry = kernel:entry_fn()
print(string.format("  entry_fn: %s", tostring(entry)))
print(string.format("  Summary: tracks=%d resolved_nodes=%d resolved_params=%d classified_literals=%d",
    #authored.tracks, resolved_nodes, resolved_params, total_classified_literals(classified)))
print("\nInspect codegen: PASS")
