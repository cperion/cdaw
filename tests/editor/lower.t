-- tests/editor/lower.t
-- Per-method tests for all 14 Editor → Authored lower methods.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

-- ══════════════════════════════════════════
-- 1. editor.transport.lower
-- ══════════════════════════════════════════
print("1. editor.transport.lower")
do
    local t = D.Editor.Transport(48000, 1024, 140, 0.1, 3, 8, D.Editor.Q1_4, true,
        D.Editor.TimeRange(2.0, 8.0))
    local ctx = {diagnostics = {}}
    local r = t:lower(ctx)
    check(r.sample_rate == 48000, "sample_rate=48000")
    check(r.buffer_size == 1024, "buffer_size=1024")
    check(r.bpm == 140, "bpm=140")
    check(approx(r.swing, 0.1), "swing=0.1")
    check(r.time_sig_num == 3, "time_sig_num=3")
    check(r.time_sig_den == 8, "time_sig_den=8")
    check(r.looping == true, "looping=true")
    check(r.loop_range ~= nil, "loop_range exists")
    if r.loop_range then
        check(approx(r.loop_range.start_beats, 2.0), "loop start=2.0")
        check(approx(r.loop_range.end_beats, 8.0), "loop end=8.0")
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 2. editor.tempo_map.lower
-- ══════════════════════════════════════════
print("2. editor.tempo_map.lower")
do
    local tm = D.Editor.TempoMap(
        L{D.Editor.TempoPoint(0, 120), D.Editor.TempoPoint(4, 90)},
        L{D.Editor.SigPoint(0, 4, 4), D.Editor.SigPoint(8, 6, 8)}
    )
    local ctx = {diagnostics = {}}
    local r = tm:lower(ctx)
    check(#r.tempo == 2, "2 tempo points")
    check(r.tempo[1].bpm == 120, "tempo[1] bpm=120")
    check(r.tempo[2].bpm == 90, "tempo[2] bpm=90")
    check(#r.signatures == 2, "2 time sig points")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 3. editor.param_value.lower
-- ══════════════════════════════════════════
print("3. editor.param_value.lower")
do
    -- Static
    local pv = D.Editor.ParamValue(42, "cutoff", 1000, 20, 20000,
        D.Editor.StaticValue(5000), D.Editor.Replace, D.Editor.NoSmoothing)
    local ctx = {diagnostics = {}}
    local r = pv:lower(ctx)
    check(r.id == 42, "id=42")
    check(r.name == "cutoff", "name=cutoff")
    check(r.default_value == 1000, "default=1000")
    check(r.min_value == 20, "min=20")
    check(r.max_value == 20000, "max=20000")

    -- Automation
    local pv2 = D.Editor.ParamValue(7, "vol", 1, 0, 1,
        D.Editor.AutomationRef(D.Editor.AutoCurve(
            L{D.Editor.AutoPoint(0, 0.5, D.Editor.Linear),
              D.Editor.AutoPoint(4, 1.0, D.Editor.Hold)},
            D.Editor.Linear)),
        D.Editor.Add, D.Editor.Lag(10))
    local r2 = pv2:lower(ctx)
    check(r2.id == 7, "auto id=7")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 4. editor.device.lower (NativeDevice)
-- ══════════════════════════════════════════
print("4. editor.device.lower — NativeDevice")
do
    local dev = D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
        10, "EQ", D.Authored.EQNode(L{D.Authored.EQBand(D.Authored.Peak)}),
        L{D.Editor.ParamValue(0, "freq", 1000, 20, 20000,
            D.Editor.StaticValue(2000), D.Editor.Replace, D.Editor.NoSmoothing),
          D.Editor.ParamValue(1, "gain", 0, -24, 24,
            D.Editor.StaticValue(3.0), D.Editor.Replace, D.Editor.NoSmoothing)},
        L(), nil, nil, nil, true, nil
    ))
    local ctx = {diagnostics = {}, alloc_graph_id = function() return 100 end}
    local r = dev:lower(ctx)
    check(r.id == 10, "node id=10")
    check(r.name == "EQ", "name=EQ")
    check(#r.params == 2, "2 params")
    check(r.enabled == true, "enabled=true")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 5. editor.device.lower (LayerDevice)
-- ══════════════════════════════════════════
print("5. editor.device.lower — LayerDevice")
do
    local pv = function(id, n, d) return D.Editor.ParamValue(id, n, d, 0, 4, D.Editor.StaticValue(d), D.Editor.Replace, D.Editor.NoSmoothing) end
    local layer = D.Editor.LayerDevice(D.Editor.LayerContainer(
        20, "Layers",
        L{D.Editor.Layer(1, "L1",
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    21, "G1", D.Authored.GainNode(),
                    L{pv(0, "g", 0.5)}, L(), nil, nil, nil, true, nil))
            }),
            pv(0, "vol", 1), pv(1, "pan", 0), false, nil)},
        L{pv(0, "mix", 0.8)},
        L(), nil, nil, nil, true, nil
    ))
    local gid = 200
    local ctx = {diagnostics = {}, alloc_graph_id = function() gid = gid + 1; return gid end}
    local r = layer:lower(ctx)
    check(r.id == 20, "layer id=20")
    check(#r.child_graphs >= 1, "has child_graphs")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 6. editor.device.lower (SelectorDevice)
-- ══════════════════════════════════════════
print("6. editor.device.lower — SelectorDevice")
do
    local sel = D.Editor.SelectorDevice(D.Editor.SelectorContainer(
        30, "Selector",
        D.Editor.ManualSelect(0),
        L{},  -- branches
        L(), L(), nil, nil, nil, true, nil
    ))
    local gid = 300
    local ctx = {diagnostics = {}, alloc_graph_id = function() gid = gid + 1; return gid end}
    local r = sel:lower(ctx)
    check(r.id == 30, "selector id=30")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 7. editor.device_chain.lower
-- ══════════════════════════════════════════
print("7. editor.device_chain.lower")
do
    local chain = D.Editor.DeviceChain(L{
        D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
            1, "A", D.Authored.GainNode(),
            L{D.Editor.ParamValue(0, "g", 1, 0, 4, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing)},
            L(), nil, nil, nil, true, nil)),
        D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
            2, "B", D.Authored.GainNode(),
            L{D.Editor.ParamValue(0, "g", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing)},
            L(), nil, nil, nil, true, nil)),
    })
    local gid = 0
    local ctx = {diagnostics = {}, alloc_graph_id = function() gid = gid + 1; return gid end}
    local r = chain:lower(ctx)
    check(r.layout.kind == "Serial", "layout=Serial")
    check(#r.nodes == 2, "2 nodes in chain")
    check(r.nodes[1].name == "A", "node[1]=A")
    check(r.nodes[2].name == "B", "node[2]=B")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 8. editor.track.lower
-- ══════════════════════════════════════════
print("8. editor.track.lower")
do
    local track = D.Editor.Track(42, "Lead", 2, D.Editor.AudioTrack,
        D.Editor.AudioInput(1, 0),
        D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.7), D.Editor.Replace, D.Editor.NoSmoothing),
        D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(-0.3), D.Editor.Replace, D.Editor.NoSmoothing),
        D.Editor.DeviceChain(L{}),
        L(), L(), L(),
        nil, nil,
        true, false,    -- muted, soloed
        true, false,    -- armed, monitor
        true, nil       -- phase_invert
    )
    local gid = 0
    local ctx = {diagnostics = {}, alloc_graph_id = function() gid = gid + 1; return gid end}
    local r = track:lower(ctx)
    check(r.id == 42, "track id=42")
    check(r.name == "Lead", "name=Lead")
    check(r.channels == 2, "channels=2")
    check(r.input.kind == "AudioInput", "input=AudioInput")
    check(r.muted == true, "muted")
    check(r.armed == true, "armed")
    check(r.phase_invert == true, "phase_invert")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 9. editor.clip.lower
-- ══════════════════════════════════════════
print("9. editor.clip.lower")
do
    local clip = D.Editor.Clip(
        7,
        D.Editor.AudioContent(99),
        1.0, 4.0, 0.5, 0,
        false,
        D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.9), D.Editor.Replace, D.Editor.NoSmoothing),
        D.Editor.FadeSpec(0.1, D.Editor.LinearFade),
        D.Editor.FadeSpec(0.2, D.Editor.EqualPower)
    )
    local ctx = {diagnostics = {}}
    local r = clip:lower(ctx)
    check(r.id == 7, "clip id=7")
    check(approx(r.start_beats, 1.0), "start=1.0")
    check(approx(r.duration_beats, 4.0), "dur=4.0")
    check(r.muted == false, "not muted")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 10. editor.note_region.lower
-- ══════════════════════════════════════════
print("10. editor.note_region.lower")
do
    local nr = D.Editor.NoteRegion(
        L{D.Editor.Note(0, 60, 0, 1, 100, nil, false, nil)},
        L{D.Editor.NoteExprLane(D.Editor.NotePressureExpr,
            L{D.Editor.NoteExprPoint(0, 0.5)})},
        0, 4
    )
    local nid = 0
    local ctx = {
        diagnostics = {},
        alloc_note_asset_id = function() nid = nid + 1; return nid end,
        intern_note_asset = function(self, a) end,
    }
    local r = nr:lower(ctx)
    check(r ~= nil, "produced NoteAsset")
    if r then
        check(#r.notes >= 1, "has notes")
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 11. editor.slot.lower
-- ══════════════════════════════════════════
print("11. editor.slot.lower")
do
    local slot = D.Editor.Slot(
        3,
        D.Editor.ClipSlot(99),
        D.Editor.LaunchBehavior(D.Editor.Gate, D.Editor.Q1_8, true, false,
            D.Editor.FollowAction(D.Editor.FNext, 1.0, 0.0, nil)),
        true
    )
    local ctx = {diagnostics = {}}
    local r = slot:lower(ctx)
    check(r.slot_index == 3, "slot_index=3")
    check(r.enabled == true, "enabled")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 12. editor.scene.lower
-- ══════════════════════════════════════════
print("12. editor.scene.lower")
do
    local scene = D.Editor.Scene(
        5, "Chorus",
        L{D.Editor.SceneSlot(1, 0, false), D.Editor.SceneSlot(2, 1, true)},
        D.Editor.Q1_4,
        150.0
    )
    local ctx = {diagnostics = {}}
    local r = scene:lower(ctx)
    check(r.id == 5, "scene id=5")
    check(r.name == "Chorus", "name=Chorus")
    check(#r.slots == 2, "2 scene slots")
    check(approx(r.tempo_override, 150.0), "tempo_override=150")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 13. editor.send.lower
-- ══════════════════════════════════════════
print("13. editor.send.lower")
do
    local send = D.Editor.Send(
        8, 99,
        D.Editor.ParamValue(0, "level", 0, 0, 1, D.Editor.StaticValue(0.6), D.Editor.Replace, D.Editor.NoSmoothing),
        true,   -- pre_fader
        true    -- enabled
    )
    local ctx = {diagnostics = {}}
    local r = send:lower(ctx)
    check(r.id == 8, "send id=8")
    check(r.target_track_id == 99, "target=99")
    check(r.pre_fader == true, "pre_fader")
    check(r.enabled == true, "enabled")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 14. editor.grid_patch.lower
-- ══════════════════════════════════════════
print("14. editor.grid_patch.lower")
do
    local gp = D.Editor.GridPatch(
        500,
        L{D.Editor.GridPort(1, "In", D.Editor.AudioHint, 1, false)},
        L{D.Editor.GridPort(2, "Out", D.Editor.AudioHint, 1, false)},
        L{D.Editor.GridModule(
            50, "Osc", D.Authored.SineOsc(),
            L{D.Editor.ParamValue(0, "freq", 440, 20, 20000, D.Editor.StaticValue(440), D.Editor.Replace, D.Editor.NoSmoothing)},
            true, nil, nil, nil
        )},
        L{D.Editor.GridCable(1, 0, 2, 0)},
        L{D.Editor.GridSource(50, 0, D.Editor.AudioIn, nil)},
        D.Editor.AudioDomain
    )
    local gid = 500
    local ctx = {diagnostics = {}, alloc_graph_id = function() gid = gid + 1; return gid end}
    local r = gp:lower(ctx)
    check(r.layout.kind == "Free", "layout=Free")
    check(#r.nodes >= 1, "has nodes")
    check(#r.inputs >= 1, "has inputs")
    check(#r.outputs >= 1, "has outputs")
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 15. editor.modulator.lower
-- ══════════════════════════════════════════
print("15. editor.modulator.lower")
do
    local mod = D.Editor.Modulator(
        60, "LFO", D.Authored.LFOMod(D.Authored.Sine),
        L{D.Editor.ParamValue(0, "rate", 1, 0.01, 100,
            D.Editor.StaticValue(4.0), D.Editor.Replace, D.Editor.NoSmoothing)},
        L{D.Editor.ModulationMap(10, 42, 0.5, false, nil, nil)},
        false, true
    )
    local ctx = {diagnostics = {}}
    local r = mod:lower(ctx)
    check(r ~= nil, "produced ModSlot")
    check(r.per_voice == false, "per_voice=false")
    check(#r.routings >= 1, "has routings")
    if #r.routings >= 1 then
        check(r.routings[1].target_param_id == 42, "route target=42")
        check(approx(r.routings[1].depth, 0.5), "route depth=0.5")
    end
    print("  PASS")
end

-- ══════════════════════════════════════════
-- 16. editor.project.lower (integration)
-- ══════════════════════════════════════════
print("16. editor.project.lower — full integration")
do
    local project = D.Editor.Project(
        "TestProject", "Author", 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "v", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "p", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{}),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L{D.Editor.Scene(1, "S1", L{}, nil, nil)},
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L{}),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )
    local ctx = {diagnostics = {}}
    local r = project:lower(ctx)
    check(r.name == "TestProject", "name")
    check(r.author == "Author", "author")
    check(#r.tracks == 1, "1 track")
    check(#r.scenes == 1, "1 scene")
    check(r.transport.sample_rate == 44100, "transport.sample_rate")
    print("  PASS")
end

-- Summary
print("")
print(string.format("Editor lower: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
