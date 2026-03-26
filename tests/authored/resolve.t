-- tests/authored/resolve.t
-- Per-method tests for Authored -> Resolved resolve methods.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

print("1. authored.transport.resolve")
do
    local t = D.Authored.Transport(48000, 256, 140, 0, 3, 8,
        D.Authored.Q1_4, true, D.Authored.TimeRange(4.0, 16.0))
    local r = t:resolve(480)
    check(r.sample_rate == 48000, "sample_rate")
    check(r.buffer_size == 256, "buffer_size")
    check(r.bpm == 140, "bpm")
    check(r.looping == true, "looping")
    check(r.loop_start_tick == 4.0 * 480, "loop_start")
    check(r.loop_end_tick == 16.0 * 480, "loop_end")
    print("  PASS")
end

print("2. authored.tempo_map.resolve")
do
    local tm = D.Authored.TempoMap(L{D.Authored.TempoPoint(0, 120)}, L())
    local r = tm:resolve(960, 44100)
    local expected_spt = (60.0/120) * 44100 / 960
    check(#r.segments == 1, "1 segment")
    check(r.segments[1].bpm == 120, "bpm=120")
    check(r.segments[1].base_sample == 0, "base=0")
    check(approx(r.segments[1].samples_per_tick, expected_spt), "samples_per_tick")
    print("  PASS")
end

print("3. authored.param.resolve")
do
    local p = D.Authored.Param(42, "cutoff", 1000, 20, 20000,
        D.Authored.StaticValue(5000), D.Authored.Replace, D.Authored.NoSmoothing)
    local r = p:resolve(960)
    check(r.id == 42, "id=42")
    check(r.source.source_kind == 0, "static source")
    check(approx(r.source.value, 5000), "value=5000")

    local p2 = D.Authored.Param(7, "vol", 1, 0, 1,
        D.Authored.AutomationRef(D.Authored.AutoCurve(
            L{D.Authored.AutoPoint(0, 0.5), D.Authored.AutoPoint(4, 1.0)},
            D.Authored.Linear)),
        D.Authored.Add, D.Authored.Lag(10))
    local r2 = p2:resolve(960)
    check(r2.source.source_kind == 1, "automation source")
    check(r2.source.curve_id == 7, "curve_id propagated")
    print("  PASS")
end

print("4. authored.send.resolve")
do
    local s = D.Authored.Send(9, 2,
        D.Authored.Param(0, "lvl", 1, 0, 1, D.Authored.StaticValue(0.5), D.Authored.Replace, D.Authored.NoSmoothing),
        true, true)
    local r = s:resolve()
    check(r.id == 9, "send id")
    check(r.target_track_id == 2, "target")
    check(r.level_param_id == 0, "level param id")
    print("  PASS")
end

print("5. authored.clip.resolve")
do
    local c = D.Authored.Clip(7,
        D.Authored.AudioContent(99),
        2.0, 4.0, 0.5, 0, false,
        D.Authored.Param(0, "gain", 1, 0, 4, D.Authored.StaticValue(0.8), D.Authored.Replace, D.Authored.NoSmoothing),
        D.Authored.FadeSpec(0.25, D.Authored.LinearFade),
        D.Authored.FadeSpec(0.5, D.Authored.EqualPower))
    local r = c:resolve(960)
    check(r.id == 7, "clip id")
    check(r.content_kind == 0, "audio clip")
    check(r.asset_id == 99, "asset_id")
    check(r.start_tick == 2.0 * 960, "start_tick")
    check(r.duration_tick == 4.0 * 960, "duration_tick")
    check(r.source_offset_tick == 0.5 * 960, "source_offset_tick")
    print("  PASS")
end

print("6. authored.slot.resolve")
do
    local s = D.Authored.Slot(3,
        D.Authored.ClipSlot(42),
        D.Authored.LaunchBehavior(D.Authored.Gate, D.Authored.Q1_8, true, false,
            D.Authored.FollowAction(D.Authored.FNext, 1.0, 0.0, nil)),
        true)
    local r = s:resolve()
    check(r.slot_index == 3, "slot_index")
    check(r.slot_kind == 1, "clip slot")
    check(r.clip_id == 42, "clip_id")
    check(r.enabled == true, "enabled")
    print("  PASS")
end

print("7. authored.scene.resolve")
do
    local sc = D.Authored.Scene(1, "Verse", L{D.Authored.SceneSlot(9, 2, true)}, D.Authored.Q1Bar, nil)
    local r = sc:resolve()
    check(r.id == 1, "scene id")
    check(#r.slots == 1, "1 scene slot")
    check(r.quant_code == 7, "Q1Bar code")
    print("  PASS")
end

print("8. authored.graph.resolve")
do
    local g = D.Authored.Graph(
        10,
        L{D.Authored.GraphPort(1, "In", D.Authored.AudioHint, 1, false)},
        L{D.Authored.GraphPort(2, "Out", D.Authored.AudioHint, 1, false)},
        L{D.Authored.Node(20, "Gain", D.Authored.GainNode,
            L{D.Authored.Param(0, "g", 1, 0, 4, D.Authored.StaticValue(0.5), D.Authored.Replace, D.Authored.NoSmoothing)},
            L(), L(), L(), L(), true)},
        L(), L(),
        D.Authored.Serial, D.Authored.AudioDomain
    )
    local r = g:resolve(960)
    check(#r.graphs == 1, "1 graph")
    check(r.graphs[1].id == 10, "graph id")
    check(r.graphs[1].layout_code == 0, "serial layout")
    check(r.graphs[1].domain_code == 1, "audio domain")
    check(#r.nodes >= 1, "nodes populated")
    print("  PASS")
end

print("9. authored.track.resolve")
do
    local t = D.Authored.Track(
        5, "Bass", 2,
        D.Authored.AudioInput(1, 0),
        D.Authored.Param(0, "vol", 1, 0, 4, D.Authored.StaticValue(0.7), D.Authored.Replace, D.Authored.NoSmoothing),
        D.Authored.Param(1, "pan", 0, -1, 1, D.Authored.StaticValue(0.3), D.Authored.Replace, D.Authored.NoSmoothing),
        D.Authored.Graph(100, L(), L(), L(), L(), L(), D.Authored.Serial, D.Authored.AudioDomain),
        L(), L(), L(),
        nil, nil, true, false, false, false, true
    )
    local r = t:resolve(960)
    check(r.track.id == 5, "track id")
    check(r.track.channels == 2, "channels")
    check(r.track.input_kind_code == 1, "audio input")
    check(r.track.muted == true, "muted")
    check(#r.mixer_params >= 2, "mixer params")
    print("  PASS")
end

print("10. authored.node_kind.resolve")
do
    local kinds = {
        {D.Authored.GainNode, 5},
        {D.Authored.SineOsc, 28},
        {D.Authored.SawOsc, 29},
        {D.Authored.SquareOsc, 30},
        {D.Authored.Clipper(D.Authored.HardClipM), 53},
        {D.Authored.Wavefolder, 52},
        {D.Authored.CompressorNode, 8},
    }
    for _, kp in ipairs(kinds) do
        local r = kp[1]:resolve()
        check(r.kind_code == kp[2], kp[1].kind .. " code")
    end
    print("  PASS")
end

print("11. authored.asset_bank.resolve")
do
    local ab = D.Authored.AssetBank(
        L{D.Authored.AudioAsset(1, "/audio/kick.wav", 44100, 1, 22050)},
        L{D.Authored.NoteAsset(2, L{D.Authored.Note(0, 60, 0, 0.5, 100, nil, false)}, L(), 0, 4)},
        L(), L(), L())
    local r = ab:resolve(960)
    check(#r.audio == 1, "1 audio asset")
    check(r.audio[1].id == 1, "audio id")
    check(#r.notes >= 1, "note assets resolved")
    print("  PASS")
end

print("12. authored.project.resolve")
do
    local project = D.Authored.Project(
        "Test", nil, 1,
        D.Authored.Transport(44100, 256, 120, 0, 4, 4, D.Authored.QNone, false, nil),
        L{D.Authored.Track(1, "T1", 2, D.Authored.NoInput,
            D.Authored.Param(0, "v", 1, 0, 4, D.Authored.StaticValue(0.8), D.Authored.Replace, D.Authored.NoSmoothing),
            D.Authored.Param(1, "p", 0, -1, 1, D.Authored.StaticValue(0), D.Authored.Replace, D.Authored.NoSmoothing),
            D.Authored.Graph(10, L(), L(), L(), L(), L(), D.Authored.Serial, D.Authored.AudioDomain),
            L(), L(), L(), nil, nil, false, false, false, false, false)},
        L(), D.Authored.TempoMap(L{D.Authored.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local r = project:resolve(960)
    check(#r.track_slices == 1, "1 track slice")
    check(#r.track_slices[1].device_graph.graphs >= 1, "graph slice populated")
    check(#r.track_slices[1].mixer_params >= 2, "mixer params >= 2")
    check(r.transport.sample_rate == 44100, "transport preserved")
    print("  PASS")
end

print("")
print(string.format("Authored resolve: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
