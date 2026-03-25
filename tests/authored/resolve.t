-- tests/authored/resolve.t
-- Per-method tests for all 14 Authored → Resolved resolve methods.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

-- ══════════════════════════════════════════
-- 1. authored.transport.resolve
-- ══════════════════════════════════════════
print("1. authored.transport.resolve")
do
    local t = D.Authored.Transport(48000, 256, 140, 0, 3, 8,
        D.Authored.Q1_4, true, D.Authored.TimeRange(4.0, 16.0))
    local ctx = {diagnostics = {}, ticks_per_beat = 480}
    local r = t:resolve(ctx)
    check(r.sample_rate == 48000, "sample_rate")
    check(r.buffer_size == 256, "buffer_size")
    check(r.bpm == 140, "bpm")
    check(r.looping == true, "looping")
    check(r.loop_start_tick == 4.0 * 480, "loop_start=" .. (4*480))
    check(r.loop_end_tick == 16.0 * 480, "loop_end=" .. (16*480))
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 2. authored.tempo_map.resolve (already tested in classify_schedule)
-- ══════════════════════════════════════════
print("2. authored.tempo_map.resolve")
do
    local tm = D.Authored.TempoMap(
        L{D.Authored.TempoPoint(0, 120)}, L())
    local ctx = {diagnostics = {}, ticks_per_beat = 960, sample_rate = 44100}
    local r = tm:resolve(ctx)
    check(#r.segments == 1, "1 segment")
    check(r.segments[1].bpm == 120, "bpm=120")
    check(r.segments[1].base_sample == 0, "base=0")
    local expected_spt = (60.0/120) * 44100 / 960
    check(approx(r.segments[1].samples_per_tick, expected_spt),
        "spt=" .. expected_spt)
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 3. authored.param.resolve
-- ══════════════════════════════════════════
print("3. authored.param.resolve")
do
    -- Static param
    local p = D.Authored.Param(42, "cutoff", 1000, 20, 20000,
        D.Authored.StaticValue(5000), D.Authored.Replace, D.Authored.NoSmoothing)
    local ctx = {diagnostics = {}}
    local r = p:resolve(ctx)
    check(r.id == 42, "id=42")
    check(r.name == "cutoff", "name")
    check(r.default_value == 1000, "default")
    check(r.source.source_kind == 0, "source_kind=0 (static)")
    check(approx(r.source.value, 5000), "value=5000")

    -- Automation param
    local p2 = D.Authored.Param(7, "vol", 1, 0, 1,
        D.Authored.AutomationRef(D.Authored.AutoCurve(
            L{D.Authored.AutoPoint(0, 0.5, D.Authored.Linear),
              D.Authored.AutoPoint(4, 1.0, D.Authored.Hold)},
            D.Authored.Linear)),
        D.Authored.Add, D.Authored.Lag(10))
    local r2 = p2:resolve(ctx)
    check(r2.id == 7, "auto id")
    check(r2.source.source_kind == 1, "source_kind=1 (automation)")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 4. authored.node_kind.resolve
-- ══════════════════════════════════════════
print("4. authored.node_kind.resolve")
do
    local ctx = {diagnostics = {}}
    local kinds = {
        {D.Authored.GainNode(), 5},
        {D.Authored.SineOsc(), 28},
        {D.Authored.SawOsc(), 29},
        {D.Authored.SquareOsc(), 30},
        {D.Authored.Clipper(D.Authored.HardClipM), 53},
        {D.Authored.Wavefolder(), 52},
        {D.Authored.CompressorNode(), 8},
    }
    for _, kp in ipairs(kinds) do
        local r = kp[1]:resolve(ctx)
        check(r.kind_code == kp[2],
            kp[1].kind .. " → code " .. kp[2] .. ", got " .. r.kind_code)
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 5. authored.graph.resolve
-- ══════════════════════════════════════════
print("5. authored.graph.resolve")
do
    local g = D.Authored.Graph(
        10,
        L{D.Authored.GraphPort(1, "In", D.Authored.AudioHint, 1, false)},
        L{D.Authored.GraphPort(2, "Out", D.Authored.AudioHint, 1, false)},
        L{D.Authored.Node(20, "Gain", D.Authored.GainNode(),
            L{D.Authored.Param(0, "g", 1, 0, 4, D.Authored.StaticValue(0.5),
              D.Authored.Replace, D.Authored.NoSmoothing)},
            L(), L(), L(), L(), true)},
        L(), L(),
        D.Authored.Serial, D.Authored.AudioDomain
    )
    local ctx = {diagnostics = {},
        alloc_graph_port_base = function(self, c) return 0 end}
    local r = g:resolve(ctx)
    check(r.id == 10, "graph id")
    check(r.layout_code == 0, "layout=serial(0)")
    check(r.domain_code == 1, "domain=audio(1)")
    check(r.input_count == 1, "1 input")
    check(r.output_count == 1, "1 output")
    check(#r.node_ids >= 1, "node_ids populated")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 6. authored.node.resolve
-- ══════════════════════════════════════════
print("6. authored.node.resolve")
do
    local n = D.Authored.Node(42, "EQ", D.Authored.EQNode(L{D.Authored.EQBand(D.Authored.Peak)}),
        L{D.Authored.Param(0, "freq", 1000, 20, 20000, D.Authored.StaticValue(2000),
          D.Authored.Replace, D.Authored.NoSmoothing),
          D.Authored.Param(1, "gain", 0, -24, 24, D.Authored.StaticValue(3),
          D.Authored.Replace, D.Authored.NoSmoothing)},
        L(), L(), L(), L(), true)
    local ctx = {diagnostics = {}}
    local r = n:resolve(ctx)
    check(r.id == 42, "node id")
    check(r.node_kind_code == 7, "kind_code=7 (EQNode)")
    check(r.param_count == 2, "param_count=2")
    check(r.enabled == true, "enabled")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 7. authored.track.resolve
-- ══════════════════════════════════════════
print("7. authored.track.resolve")
do
    local t = D.Authored.Track(
        5, "Bass", 2,
        D.Authored.AudioInput(1, 0),
        D.Authored.Param(0, "vol", 1, 0, 4, D.Authored.StaticValue(0.7),
            D.Authored.Replace, D.Authored.NoSmoothing),
        D.Authored.Param(1, "pan", 0, -1, 1, D.Authored.StaticValue(0.3),
            D.Authored.Replace, D.Authored.NoSmoothing),
        F.authored_graph(100),
        L(), L(), L(),
        nil, nil, true, false, false, false, true
    )
    local ctx = {diagnostics = {}}
    local r = t:resolve(ctx)
    check(r.id == 5, "track id")
    check(r.name == "Bass", "name")
    check(r.channels == 2, "channels")
    check(r.input_kind_code == 1, "AudioInput → code 1")
    check(r.input_arg0 == 1, "device_id=1")
    check(r.muted == true, "muted")
    check(r.phase_invert == true, "phase_invert")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 8. authored.clip.resolve
-- ══════════════════════════════════════════
print("8. authored.clip.resolve")
do
    local c = D.Authored.Clip(7,
        D.Authored.AudioContent(99),
        2.0, 4.0, 0.5, 0, false,
        D.Authored.Param(0, "gain", 1, 0, 4, D.Authored.StaticValue(0.8),
            D.Authored.Replace, D.Authored.NoSmoothing),
        D.Authored.FadeSpec(0.25, D.Authored.LinearFade),
        D.Authored.FadeSpec(0.5, D.Authored.EqualPower))
    local ctx = {diagnostics = {}, ticks_per_beat = 960}
    local r = c:resolve(ctx)
    check(r.id == 7, "clip id")
    check(r.content_kind == 0, "content_kind=0 (audio)")
    check(r.asset_id == 99, "asset_id=99")
    check(r.start_tick == 2.0 * 960, "start_tick")
    check(r.duration_tick == 4.0 * 960, "duration_tick")
    check(r.source_offset_tick == 0.5 * 960, "source_offset_tick")
    check(r.muted == false, "not muted")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 9. authored.slot.resolve
-- ══════════════════════════════════════════
print("9. authored.slot.resolve")
do
    local s = D.Authored.Slot(3,
        D.Authored.ClipSlot(42),
        D.Authored.LaunchBehavior(D.Authored.Gate, D.Authored.Q1_8, true, false,
            D.Authored.FollowAction(D.Authored.FNext, 1.0, 0.0, nil)),
        true)
    local ctx = {diagnostics = {}}
    local r = s:resolve(ctx)
    check(r.slot_index == 3, "slot_index=3")
    check(r.slot_kind == 1, "slot_kind=1 (clip)")
    check(r.clip_id == 42, "clip_id=42")
    check(r.legato == true, "legato")
    check(r.enabled == true, "enabled")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 10. authored.scene.resolve
-- ══════════════════════════════════════════
print("10. authored.scene.resolve")
do
    local sc = D.Authored.Scene(5, "Chorus",
        L{D.Authored.SceneSlot(1, 0, false)},
        D.Authored.Q1_4, 150.0)
    local ctx = {diagnostics = {}}
    local r = sc:resolve(ctx)
    check(r.id == 5, "scene id")
    check(r.name == "Chorus", "name")
    check(#r.slots == 1, "1 slot")
    check(approx(r.tempo_override, 150.0), "tempo=150")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 11. authored.send.resolve
-- ══════════════════════════════════════════
print("11. authored.send.resolve")
do
    local s = D.Authored.Send(8, 99,
        D.Authored.Param(0, "level", 0.5, 0, 1, D.Authored.StaticValue(0.6),
            D.Authored.Replace, D.Authored.NoSmoothing),
        true, true)
    local ctx = {diagnostics = {}}
    local r = s:resolve(ctx)
    check(r.id == 8, "send id")
    check(r.target_track_id == 99, "target=99")
    check(r.pre_fader == true, "pre_fader")
    check(r.enabled == true, "enabled")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 12. authored.mod_slot.resolve
-- ══════════════════════════════════════════
print("12. authored.mod_slot.resolve")
do
    local ms = D.Authored.ModSlot(
        D.Authored.Node(60, "LFO", D.Authored.LFOMod(D.Authored.Sine),
            L{D.Authored.Param(0, "rate", 4, 0.01, 100, D.Authored.StaticValue(4.0),
              D.Authored.Replace, D.Authored.NoSmoothing)},
            L(), L(), L(), L(), true),
        L{D.Authored.ModRoute(42, 0.5, false, nil, nil)},
        false)
    local ctx = {diagnostics = {},
        alloc_mod_slot_index = function(self) return 7 end,
        _current_parent_node_id = 100}
    local r = ms:resolve(ctx)
    check(r.slot_index == 7, "slot_index=7")
    check(r.parent_node_id == 100, "parent_node_id from ctx")
    check(r.modulator_node_id == 60, "modulator_node_id=60")
    check(r.per_voice == false, "per_voice=false")
    check(r.route_count == 1, "1 route")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 13. authored.asset_bank.resolve
-- ══════════════════════════════════════════
print("13. authored.asset_bank.resolve")
do
    local ab = D.Authored.AssetBank(
        L{D.Authored.AudioAsset(1, "/audio/kick.wav", 44100, 1, 22050)},
        L{D.Authored.NoteAsset(2,
            L{D.Authored.Note(0, 60, 0, 0.5, 100, nil, false)},
            L(), 0, 4)},
        L(), L(), L())
    local ctx = {diagnostics = {}}
    local r = ab:resolve(ctx)
    check(#r.audio == 1, "1 audio asset")
    check(r.audio[1].id == 1, "audio id=1")
    check(r.audio[1].path == "/audio/kick.wav", "audio path")
    check(#r.notes >= 1, "note assets resolved")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 14. authored.project.resolve (integration)
-- ══════════════════════════════════════════
print("14. authored.project.resolve — integration")
do
    local project = D.Authored.Project(
        "Test", nil, 1,
        D.Authored.Transport(44100, 256, 120, 0, 4, 4, D.Authored.QNone, false, nil),
        L{D.Authored.Track(1, "T1", 2, D.Authored.NoInput,
            D.Authored.Param(0, "v", 1, 0, 4, D.Authored.StaticValue(0.8),
                D.Authored.Replace, D.Authored.NoSmoothing),
            D.Authored.Param(1, "p", 0, -1, 1, D.Authored.StaticValue(0),
                D.Authored.Replace, D.Authored.NoSmoothing),
            F.authored_graph(10),
            L(), L(), L(), nil, nil, false, false, false, false, false)},
        L(), D.Authored.TempoMap(L{D.Authored.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local ctx = {diagnostics = {}}
    local r = project:resolve(ctx)
    check(#r.tracks == 1, "1 track")
    check(#r.all_graphs >= 1, "flat graphs populated")
    check(#r.all_params >= 2, "flat params >= 2 (vol + pan)")
    check(r.transport.sample_rate == 44100, "transport preserved")
    print("  PASS")
end

-- Summary
print("")
print(string.format("Authored resolve: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
