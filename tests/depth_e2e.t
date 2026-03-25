-- tests/depth_e2e.t
-- Deep end-to-end test: verifies structural data flows through
-- classify/schedule/compile with real content, not just shape.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass_count = 0
local fail_count = 0

local function check(cond, msg)
    if cond then
        pass_count = pass_count + 1
    else
        fail_count = fail_count + 1
        print("  FAIL: " .. msg)
    end
end

-- ══════════════════════════════════════════════════════════
-- Test 1: Literal table built from static params
-- ══════════════════════════════════════════════════════════
print("Test 1: Classify builds literal table from static params")
do
    local project = D.Editor.Project(
        "literal_test", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(-0.3), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Gain", D.Authored.GainNode(),
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.75), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil
                ))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        )},
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local ctx = {diagnostics = {}}
    local authored = project:lower(ctx)
    local resolved = authored:resolve(ctx)
    local classified = resolved:classify(ctx)

    check(#classified.literals > 0,
        "Classify should build a non-empty literal table, got " .. #classified.literals)
    print("  Literal count: " .. #classified.literals)
    for i = 1, #classified.literals do
        print("    literal[" .. (i-1) .. "] = " .. classified.literals[i].value)
    end

    -- Check that params have literal bindings
    check(#classified.params > 0, "Should have classified params")
    for i = 1, #classified.params do
        local p = classified.params[i]
        check(p.base_value.rate_class == 0 or p.base_value.rate_class == 2,
            "Param base_value should have rate_class 0 (literal) or 2 (block), got " .. p.base_value.rate_class)
    end
    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 2: Schedule allocates buffers and builds steps
-- ══════════════════════════════════════════════════════════
print("\nTest 2: Schedule allocates buffers and builds steps")
do
    local project = D.Editor.Project(
        "schedule_test", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Gain", D.Authored.GainNode(),
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.75), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil
                ))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        )},
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local ctx = {diagnostics = {}}
    local authored = project:lower(ctx)
    local resolved = authored:resolve(ctx)
    local classified = resolved:classify(ctx)
    local scheduled = classified:schedule(ctx)

    check(scheduled.total_buffers > 0,
        "Should allocate buffers, got " .. scheduled.total_buffers)
    print("  Buffers allocated: " .. scheduled.total_buffers)

    check(#scheduled.buffers > 0,
        "Should have buffer descriptors, got " .. #scheduled.buffers)

    check(#scheduled.tracks > 0,
        "Should have track plans, got " .. #scheduled.tracks)

    check(#scheduled.steps > 0,
        "Should have execution steps, got " .. #scheduled.steps)

    check(#scheduled.node_jobs > 0,
        "Should have node jobs, got " .. #scheduled.node_jobs)

    check(#scheduled.graph_plans > 0,
        "Should have graph plans, got " .. #scheduled.graph_plans)

    -- Check master output assignment
    check(scheduled.master_left >= 0,
        "master_left should be valid buffer index, got " .. scheduled.master_left)
    check(scheduled.master_right >= 0,
        "master_right should be valid buffer index, got " .. scheduled.master_right)

    -- Check track plan has buffer assignments
    local tp = scheduled.tracks[1]
    check(tp.work_buf >= 0,
        "Track work_buf should be valid, got " .. tp.work_buf)
    check(tp.out_left == scheduled.master_left,
        "Track out_left should point to master_left")
    check(tp.out_right == scheduled.master_right,
        "Track out_right should point to master_right")

    print("  Track work_buf=" .. tp.work_buf ..
        " out_left=" .. tp.out_left .. " out_right=" .. tp.out_right)
    print("  Master L=" .. scheduled.master_left .. " R=" .. scheduled.master_right)
    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 3: Kernel compiles a callable entry function
-- ══════════════════════════════════════════════════════════
print("\nTest 3: Kernel compiles callable entry with real structure")
do
    local project = D.Editor.Project(
        "kernel_test", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.8), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Gain", D.Authored.GainNode(),
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4, D.Editor.StaticValue(0.75), D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil
                ))
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        )},
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local ctx = {diagnostics = {}}
    local authored = project:lower(ctx)
    local resolved = authored:resolve(ctx)
    local classified = resolved:classify(ctx)
    local scheduled = classified:schedule(ctx)
    local kernel = scheduled:compile(ctx)
    local entry = kernel:entry_fn()

    check(entry ~= nil, "entry_fn should not be nil")
    check(type(entry) == "function" or terralib.isfunction(entry),
        "entry_fn should be callable, got " .. type(entry))

    -- Verify no diagnostics through the whole pipeline
    check(#ctx.diagnostics == 0,
        "Should have 0 diagnostics, got " .. #ctx.diagnostics)

    print("  Kernel compiled successfully")
    print("  Entry function: " .. tostring(entry))
    print("  Diagnostics: " .. #ctx.diagnostics)
    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
-- Test 4: Resolved flat tables have real content
-- ══════════════════════════════════════════════════════════
print("\nTest 4: Resolved flattening produces real content")
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
                        },
                        L(), nil, nil, nil, true, nil
                    )),
                    D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                        11, "Comp", D.Authored.CompressorNode(),
                        L{
                            D.Editor.ParamValue(0, "threshold", -20, -60, 0, D.Editor.StaticValue(-20), D.Editor.Replace, D.Editor.NoSmoothing),
                            D.Editor.ParamValue(1, "ratio", 4, 1, 20, D.Editor.StaticValue(4), D.Editor.Replace, D.Editor.NoSmoothing),
                        },
                        L(), nil, nil, nil, true, nil
                    ))
                }),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil
            ),
            D.Editor.Track(2, "Track 2", 2, D.Editor.AudioTrack, D.Editor.NoInput,
                D.Editor.ParamValue(0, "vol", 1, 0, 4, D.Editor.StaticValue(0.6), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.ParamValue(1, "pan", 0, -1, 1, D.Editor.StaticValue(0.5), D.Editor.Replace, D.Editor.NoSmoothing),
                D.Editor.DeviceChain(L{}),
                L(), L(), L(), nil, nil, false, false, false, false, false, nil
            ),
        },
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 140)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )

    local ctx = {diagnostics = {}}
    local authored = project:lower(ctx)
    local resolved = authored:resolve(ctx)

    check(#resolved.tracks == 2, "Should have 2 tracks, got " .. #resolved.tracks)
    check(#resolved.all_graphs >= 2, "Should have ≥2 graphs (one per track), got " .. #resolved.all_graphs)
    check(#resolved.all_nodes == 2, "Should have 2 nodes (EQ + Comp), got " .. #resolved.all_nodes)
    check(#resolved.all_params >= 7, "Should have ≥7 params (3+2 device + 2+2 track), got " .. #resolved.all_params)

    -- Check node kind codes are distinct and correct
    local eq_code = resolved.all_nodes[1].node_kind_code
    local comp_code = resolved.all_nodes[2].node_kind_code
    check(eq_code ~= comp_code, "EQ and Comp should have different kind codes")
    print("  EQ kind_code=" .. eq_code .. " Comp kind_code=" .. comp_code)

    -- Check params have correct values
    for i = 1, #resolved.all_params do
        local p = resolved.all_params[i]
        if p.name == "freq" then
            check(p.source.value == 1000,
                "freq param should have value 1000, got " .. p.source.value)
        elseif p.name == "ratio" then
            check(p.source.value == 4,
                "ratio param should have value 4, got " .. p.source.value)
        end
    end

    -- Push through classify and verify literals
    local classified = resolved:classify(ctx)
    check(#classified.literals >= 2, "Should have ≥2 literals, got " .. #classified.literals)
    print("  Literals: " .. #classified.literals)
    for i = 1, math.min(#classified.literals, 10) do
        print("    [" .. (i-1) .. "] = " .. classified.literals[i].value)
    end

    -- Push through schedule
    local scheduled = classified:schedule(ctx)
    check(#scheduled.tracks == 2, "Should have 2 track plans, got " .. #scheduled.tracks)
    check(scheduled.total_buffers >= 4, "Should have ≥4 buffers (2 master + 2 work), got " .. scheduled.total_buffers)
    check(#scheduled.node_jobs == 2, "Should have 2 node jobs, got " .. #scheduled.node_jobs)

    print("  Resolved: " .. #resolved.all_graphs .. " graphs, " ..
        #resolved.all_nodes .. " nodes, " .. #resolved.all_params .. " params")
    print("  Classified: " .. #classified.literals .. " literals")
    print("  Scheduled: " .. scheduled.total_buffers .. " buffers, " ..
        #scheduled.node_jobs .. " node_jobs, " .. #scheduled.steps .. " steps")
    print("  PASS")
end

-- ══════════════════════════════════════════════════════════
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
