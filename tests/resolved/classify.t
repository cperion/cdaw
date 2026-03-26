-- tests/resolved/classify.t
-- Per-method tests for Resolved -> Classified classify methods.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local TICKS_PER_BEAT = 960

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

print("1. resolved.transport.classify")
do
    local t = D.Resolved.Transport(48000, 512, 140, 3, 8, 4, true, 1920, 7680, false, false, 0, 0, 0, 0, 0)
    local r = t:classify()
    check(r.sample_rate == 48000, "sample_rate")
    check(r.buffer_size == 512, "buffer_size")
    check(r.bpm == 140, "bpm")
    check(r.looping == true, "looping")
    print("  PASS")
end

print("2. resolved.tempo_map.classify")
do
    local tm = D.Resolved.TempoMap(L{
        D.Resolved.TempoSeg(0, 120, 0, 22.96875),
        D.Resolved.TempoSeg(3840, 60, 88200, 45.9375),
    })
    local r = tm:classify()
    check(#r.segments == 2, "2 segments")
    check(r.segments[1].start_tick == 0, "seg1 start")
    check(r.segments[1].end_tick == 3840, "seg1 end")
    check(r.segments[2].bpm == 60, "seg2 bpm")
    print("  PASS")
end

print("3. resolved.graph_slice.classify")
do
    local gs = D.Resolved.GraphSlice(
        L{D.Resolved.Graph(1, 0, 1, 0, 0, 0, 1, L{100}, L(), 0, 0, 0, 0, 0, 0)},
        L(),
        L{D.Resolved.Node(100, 10, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, true, nil, 0, 0, 0, 0)},
        L(),
        L(),
        L{D.Resolved.Param(10, 100, "gain", 0.5, 0, 1, D.Resolved.ParamSourceRef(0, 0.5, nil), 0, 0, 0)},
        L{D.Resolved.ModSlot(0, 100, 200, 156, 0, 0, 0, 0, 0, 0, false, 0, 0)},
        L{D.Resolved.ModRoute(0, 10, 0.25, false, nil, nil)},
        L()
    )
    local r = gs:classify()
    check(#r.graphs == 1, "1 graph")
    check(#r.nodes == 1, "1 node")
    check(r.nodes[1].state_size == 1, "delay state allocated")
    check(#r.params == 1, "1 param")
    check(#r.mod_slots == 1, "1 mod slot")
    check(#r.mod_routes == 1, "1 mod route")
    check(#r.literals >= 1, "literals interned")
    print("  PASS")
end

print("4. resolved.track_slice.classify")
do
    local ts = D.Resolved.TrackSlice(
        D.Resolved.Track(5, "Bass", 2, 1, 1, 0, 0, 1, 10, nil, nil, true, false, false, false, true),
        L{
            D.Resolved.Param(0, 0, "vol", 1, 0, 4, D.Resolved.ParamSourceRef(0, 0.7, nil), 0, 0, 0),
            D.Resolved.Param(1, 0, "pan", 0, -1, 1, D.Resolved.ParamSourceRef(0, 0.3, nil), 0, 0, 0)
        },
        L(), L(), L(), L(),
        D.Resolved.GraphSlice(L{D.Resolved.Graph(100, 0, 1, 0, 0, 0, 0, L(), L(), 0, 0, 0, 0, 0, 0)}, L(), L(), L(), L(), L(), L(), L(), L())
    )
    local r = ts:classify()
    check(r.track.id == 5, "track id")
    check(r.track.channels == 2, "channels")
    check(r.track.volume.rate_class == 0, "volume binding")
    check(r.track.pan.rate_class == 0, "pan binding")
    check(#r.mixer_literals >= 2, "mixer literals")
    check(r.device_graph ~= nil, "device graph classified")
    print("  PASS")
end

print("5. resolved.project.classify")
do
    local project = D.Editor.Project(
        "Test", nil, 1,
        D.Editor.Transport(44100, 256, 120, 4, 4, D.Editor.QNone, false, nil, false, nil),
        L{D.Editor.Track(1, "T1", nil, nil, 2, D.Editor.AudioTrack, D.Editor.NoInput, D.Editor.MasterOutput,
            D.Editor.ParamValue(0, "v", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "p", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "G", D.Authored.GainNode,
                    L{D.Editor.ParamValue(0, "g", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, true, nil))
            }),
            L(), L(), L(), L(), nil, true, false, false, false, false, false, D.Editor.CrossBoth, L(), nil)},
        L(), L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local c = project:lower():resolve(TICKS_PER_BEAT):classify()
    check(#c.track_slices == 1, "classified track slice")
    check(#c.track_slices[1].device_graph.graphs >= 1, "classified graphs")
    check(#c.track_slices[1].device_graph.nodes >= 1, "classified nodes")
    check(#c.track_slices[1].mixer_params >= 1, "classified params")
    check((#c.track_slices[1].mixer_literals + #c.track_slices[1].device_graph.literals) >= 1, "literals populated")
    print("  PASS")
end

print("")
print(string.format("Resolved classify: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
