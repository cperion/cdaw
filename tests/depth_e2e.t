-- tests/depth_e2e.t
-- Deep end-to-end test on the slice/program pipeline surface.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local TICKS_PER_BEAT = 960

local pass_count = 0
local fail_count = 0

local function check(cond, msg)
    if cond then pass_count = pass_count + 1 else fail_count = fail_count + 1; print("  FAIL: " .. msg) end
end

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

local function total_scheduled_output_programs(scheduled)
    local total = 0
    for i = 1, #scheduled.track_programs do total = total + #scheduled.track_programs[i].output_programs end
    return total
end

print("Test 1: Classify builds literal tables from static params")
do
    local project = D.Editor.Project(
        "literal_test", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(-0.3), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Gain", D.Authored.GainNode,
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.75), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))

    local classified = project:lower():resolve(TICKS_PER_BEAT):classify()
    local literal_count = total_classified_literals(classified)
    check(literal_count > 0, "non-empty classified literal tables")
    print("  Literal count: " .. literal_count)
    check(total_classified_params(classified) > 0, "classified params exist")
    print("  PASS")
end

print("\nTest 2: Schedule allocates buffers and builds programs")
do
    local project = D.Editor.Project(
        "schedule_test", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Gain", D.Authored.GainNode,
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.75), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))

    local scheduled = project:lower():resolve(TICKS_PER_BEAT):classify():schedule()
    check(#scheduled.track_programs > 0, "track programs exist")
    check(total_scheduled_buffers(scheduled) > 0, "buffers allocated")
    check(total_scheduled_node_programs(scheduled) > 0, "node programs exist")
    check(total_scheduled_output_programs(scheduled) > 0, "output programs exist")
    local tp = scheduled.track_programs[1]
    check(tp.track.work_buf >= 0, "track work_buf valid")
    check(tp.master_left >= 0 and tp.master_right >= 0, "master buffers valid")
    print("  Buffers allocated: " .. total_scheduled_buffers(scheduled))
    print("  PASS")
end

print("\nTest 3: Kernel compiles a callable entry function")
do
    local project = D.Editor.Project(
        "kernel_test", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Gain", D.Authored.GainNode,
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.75), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))

    local kernel = project:lower():resolve(TICKS_PER_BEAT):classify():schedule():compile()
    local entry = kernel:entry_fn()
    check(entry ~= nil, "entry_fn should not be nil")
    check(type(entry) == "function" or terralib.isfunction(entry), "entry should be callable")
    print("  PASS")
end

print("\nTest 4: Resolved/Classified/Scheduled slices have real content")
do
    local project = D.Editor.Project(
        "flatten_test", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{
            D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        10, "EQ", D.Authored.EQNode(L{D.Authored.EQBand(D.Authored.Peak)}),
                        L{
                            D.Editor.ParamValue(0, "freq", 1000, 20, 20000, D.Editor.StaticValue(1000), D.Editor.Replace, D.Editor.NoSmoothing),
                            D.Editor.ParamValue(1, "gain", 0, -24, 24, D.Editor.StaticValue(3.5), D.Editor.Replace, D.Editor.NoSmoothing),
                            D.Editor.ParamValue(2, "q", 1, 0.1, 10, D.Editor.StaticValue(1.4), D.Editor.Replace, D.Editor.NoSmoothing),
                        }, L(), nil, nil, nil, true, nil)),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        11, "Comp", D.Authored.CompressorNode,
                        L{
                            D.Editor.ParamValue(0, "threshold", -20, -60, 0, D.Editor.StaticValue(-20), D.Editor.Replace, D.Editor.NoSmoothing),
                            D.Editor.ParamValue(1, "ratio", 4, 1, 20, D.Editor.StaticValue(4), D.Editor.Replace, D.Editor.NoSmoothing),
                        }, L(), nil, nil, nil, true, nil))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil),
            D.Editor.Track(2, "Track 2", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.6), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{}),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil),
        },
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 140)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))

    local resolved = project:lower():resolve(TICKS_PER_BEAT)
    local classified = resolved:classify()
    local scheduled = classified:schedule()

    local resolved_tracks = #resolved.track_slices
    local resolved_graphs = sum_track_slices(resolved.track_slices, "device_graph.graphs")
    local resolved_nodes = sum_track_slices(resolved.track_slices, "device_graph.nodes")
    local resolved_params = sum_track_slices(resolved.track_slices, "mixer_params") + sum_track_slices(resolved.track_slices, "device_graph.params")

    check(resolved_tracks == 2, "2 resolved track slices")
    check(resolved_graphs >= 2, "at least 2 resolved graphs")
    check(resolved_nodes == 2, "2 resolved nodes")
    check(resolved_params >= 7, "at least 7 resolved params")
    check(total_classified_literals(classified) >= 2, "classified literals populated")
    check(#scheduled.track_programs == 2, "2 track programs")
    check(total_scheduled_node_programs(scheduled) == 2, "2 scheduled node programs")

    print("  Resolved: " .. resolved_graphs .. " graphs, " .. resolved_nodes .. " nodes, " .. resolved_params .. " params")
    print("  Classified: " .. total_classified_literals(classified) .. " literals")
    print("  Scheduled: " .. total_scheduled_buffers(scheduled) .. " buffers, " .. total_scheduled_node_programs(scheduled) .. " node_programs, " .. total_scheduled_output_programs(scheduled) .. " output_programs")
    print("  PASS")
end

print("\nTest 5: Automation curves become block ops/program ops")
do
    local project = D.Editor.Project(
        "automation_test", nil, 1,
        D.Editor.Transport(44100, 128, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4,
                D.Editor.AutomationRef(D.Editor.AutoCurve(L{D.Editor.AutoPoint(0, 0.2), D.Editor.AutoPoint(1, 0.8)}, D.Editor.Linear)),
                D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(-1), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    9, "Square", D.Authored.SquareOsc,
                    L{D.Editor.ParamValue(0, "freq", 100, 1, 20000, D.Editor.StaticValue(100), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))

    local resolved = project:lower():resolve(TICKS_PER_BEAT)
    local classified = resolved:classify()
    local scheduled = classified:schedule()
    local ts = classified.track_slices[1]
    local tp = scheduled.track_programs[1]

    check(#resolved.track_slices[1].mixer_curves >= 1, "resolved mixer curves attached")
    check(#ts.mixer_block_ops >= 1, "classified mixer block ops populated")
    check(#ts.mixer_block_pts >= 2, "classified mixer block points populated")
    check(ts.track.volume.rate_class == 2 or ts.track.pan.rate_class == 2, "at least one block-rate mixer binding")
    check(#tp.mixer_block_ops >= 1, "scheduled mixer block ops populated")
    check(#tp.mixer_block_pts >= 2, "scheduled mixer block points populated")
    check(tp:compile() ~= nil, "track program compiles")
    print("  PASS")
end

print("")
if fail_count == 0 then
    print("════════════════════════════════════════")
    print("ALL DEPTH TESTS PASSED (" .. pass_count .. " checks)")
    print("════════════════════════════════════════")
else
    print("════════════════════════════════════════")
    print("FAILURES: " .. fail_count .. " / " .. (pass_count + fail_count))
    print("════════════════════════════════════════")
    os.exit(1)
end
