-- tests/inspect_codegen.t
-- Builds a complex multi-track project and inspects the generated
-- Terra code at every phase: ASDL data, flat tables, literal table,
-- buffer allocation, and the final compiled native render function.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

-- ════════════════════════════════════════════════════════════════
-- BUILD: "Dreaming in Amber" — a 5-track synthetic project
-- ════════════════════════════════════════════════════════════════

local function PV(id, name, val, lo, hi)
    return D.Editor.ParamValue(id, name, val, lo, hi,
        D.Editor.StaticValue(val), D.Editor.Replace, D.Editor.NoSmoothing)
end

local function device(id, name, kind, params)
    return D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
        id, name, kind, L(params), L(), nil, nil, nil, true, nil
    ))
end

local project = D.Editor.Project(
    "Dreaming in Amber", "Terra DAW", 1,
    D.Editor.Transport(44100, 256, 128, 0, 4, 4, D.Editor.Q1_4, false,
        D.Editor.TimeRange(0, 16)),
    L{
        -- ── Track 1: Pad (sine osc → saturator → gain) ──
        D.Editor.Track(1, "Pad", 2, D.Editor.InstrumentTrack, D.Editor.NoInput,
            PV(0, "volume", 0.7, 0, 4),
            PV(1, "pan", -0.2, -1, 1),
            D.Editor.DeviceChain(L{
                device(100, "Sine", D.Authored.SineOsc(), {PV(0, "freq", 220, 20, 22050)}),
                device(101, "Warmth", D.Authored.SaturatorNode(D.Authored.Tanh), {PV(0, "drive", 1.5, 0.1, 10)}),
                device(102, "Trim", D.Authored.GainNode(), {PV(0, "gain", 0.6, 0, 4)}),
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        ),

        -- ── Track 2: Bass (saw osc → compressor) ──
        D.Editor.Track(2, "Bass", 2, D.Editor.InstrumentTrack, D.Editor.NoInput,
            PV(0, "volume", 0.9, 0, 4),
            PV(1, "pan", 0, -1, 1),
            D.Editor.DeviceChain(L{
                device(200, "SawBass", D.Authored.SawOsc(), {PV(0, "freq", 55, 20, 22050)}),
                device(201, "Squash", D.Authored.CompressorNode(), {
                    PV(0, "threshold", -12, -60, 0),
                    PV(1, "ratio", 6, 1, 20),
                }),
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        ),

        -- ── Track 3: Lead (square osc → EQ boost → clipper → gain) ──
        D.Editor.Track(3, "Lead", 2, D.Editor.InstrumentTrack, D.Editor.NoInput,
            PV(0, "volume", 0.5, 0, 4),
            PV(1, "pan", 0.4, -1, 1),
            D.Editor.DeviceChain(L{
                device(300, "SquareLead", D.Authored.SquareOsc(), {PV(0, "freq", 880, 20, 22050)}),
                device(301, "Presence", D.Authored.EQNode(L{D.Authored.EQBand(D.Authored.Peak)}), {
                    PV(0, "freq", 2500, 20, 20000),
                    PV(1, "gain", 4, -24, 24),
                    PV(2, "q", 1.2, 0.1, 10),
                }),
                device(302, "Limit", D.Authored.Clipper(D.Authored.HardClipM), {}),
                device(303, "Output", D.Authored.GainNode(), {PV(0, "gain", 0.35, 0, 4)}),
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        ),

        -- ── Track 4: Texture (sine → wavefolder → gain) ──
        D.Editor.Track(4, "Texture", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            PV(0, "volume", 0.3, 0, 4),
            PV(1, "pan", -0.6, -1, 1),
            D.Editor.DeviceChain(L{
                device(400, "Source", D.Authored.SineOsc(), {PV(0, "freq", 110, 20, 22050)}),
                device(401, "Fold", D.Authored.Wavefolder(), {}),
                device(402, "Level", D.Authored.GainNode(), {PV(0, "gain", 0.4, 0, 4)}),
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        ),

        -- ── Track 5: Master bus (EQ → compressor → gain) ──
        D.Editor.Track(5, "Master", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            PV(0, "volume", 1.0, 0, 4),
            PV(1, "pan", 0, -1, 1),
            D.Editor.DeviceChain(L{
                device(500, "MasterEQ", D.Authored.EQNode(L{D.Authored.EQBand(D.Authored.LowShelf)}), {
                    PV(0, "freq", 80, 20, 20000),
                    PV(1, "gain", 2, -24, 24),
                    PV(2, "q", 0.7, 0.1, 10),
                }),
                device(501, "BusComp", D.Authored.CompressorNode(), {
                    PV(0, "threshold", -8, -60, 0),
                    PV(1, "ratio", 3, 1, 20),
                }),
                device(502, "MasterGain", D.Authored.GainNode(), {PV(0, "gain", 0.85, 0, 4)}),
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil
        ),
    },
    L{
        D.Editor.Scene(1, "Intro", L{
            D.Editor.SceneSlot(1, 0, false),
            D.Editor.SceneSlot(2, 0, false),
        }, D.Editor.Q1Bar, nil),
        D.Editor.Scene(2, "Drop", L{
            D.Editor.SceneSlot(1, 0, false),
            D.Editor.SceneSlot(2, 0, false),
            D.Editor.SceneSlot(3, 0, false),
        }, D.Editor.Q1Bar, 140),
    },
    D.Editor.TempoMap(
        L{D.Editor.TempoPoint(0, 128), D.Editor.TempoPoint(16, 140)},
        L{D.Editor.SigPoint(0, 4, 4)}
    ),
    D.Authored.AssetBank(L(), L(), L(), L(), L())
)


-- ════════════════════════════════════════════════════════════════
-- PHASE 1: LOWER
-- ════════════════════════════════════════════════════════════════
print("╔══════════════════════════════════════════════════════════╗")
print("║  Code Generation Inspector: \"Dreaming in Amber\"         ║")
print("║  5 tracks, 15 devices, 2 scenes, 2 tempo points         ║")
print("╚══════════════════════════════════════════════════════════╝\n")

local ctx = {diagnostics = {}}

print("── Phase 1: Editor → Authored ──")
local authored = project:lower(ctx)
print(string.format("  Tracks: %d", #authored.tracks))
print(string.format("  Scenes: %d", #authored.scenes))
for i = 1, #authored.tracks do
    local t = authored.tracks[i]
    print(string.format("    Track %d %-10s: %d nodes in device_graph (layout=%s)",
        t.id, t.name, #t.device_graph.nodes,
        t.device_graph.layout.kind or tostring(t.device_graph.layout)))
end

-- ════════════════════════════════════════════════════════════════
-- PHASE 2: RESOLVE
-- ════════════════════════════════════════════════════════════════
print("\n── Phase 2: Authored → Resolved (tree flattening) ──")
local resolved = authored:resolve(ctx)
print(string.format("  Flat tables:"))
print(string.format("    all_graphs:          %d", #resolved.all_graphs))
print(string.format("    all_graph_ports:     %d", #resolved.all_graph_ports))
print(string.format("    all_nodes:           %d", #resolved.all_nodes))
print(string.format("    all_child_graph_refs:%d", #resolved.all_child_graph_refs))
print(string.format("    all_wires:           %d", #resolved.all_wires))
print(string.format("    all_params:          %d", #resolved.all_params))
print(string.format("    all_mod_slots:       %d", #resolved.all_mod_slots))
print(string.format("    all_mod_routes:      %d", #resolved.all_mod_routes))
print(string.format("    all_curves:          %d", #resolved.all_curves))
print(string.format("  Tracks: %d   Scenes: %d", #resolved.tracks, #resolved.scenes))
print(string.format("  Tempo segments: %d", #resolved.tempo_map.segments))

print("\n  Node kind distribution:")
local kind_counts = {}
local kind_names = {}
-- Build reverse map from node_kind.t order
local nk_names = {
    [0]="BasicSynth",[5]="GainNode",[6]="PanNode",[7]="EQNode",
    [8]="CompressorNode",[9]="GateNode",[10]="DelayNode",[11]="ReverbNode",
    [12]="ChorusNode",[15]="SaturatorNode",[27]="SubGraph",
    [28]="SineOsc",[29]="SawOsc",[30]="SquareOsc",[52]="Wavefolder",
    [53]="Clipper",
}
for i = 1, #resolved.all_nodes do
    local kc = resolved.all_nodes[i].node_kind_code
    kind_counts[kc] = (kind_counts[kc] or 0) + 1
end
local sorted_kinds = {}
for kc, count in pairs(kind_counts) do sorted_kinds[#sorted_kinds+1] = {kc, count} end
table.sort(sorted_kinds, function(a, b) return a[1] < b[1] end)
for _, pair in ipairs(sorted_kinds) do
    local name = nk_names[pair[1]] or ("kind_" .. pair[1])
    print(string.format("    %-20s (code=%2d): %d nodes", name, pair[1], pair[2]))
end

print("\n  Param sources:")
local static_count, auto_count = 0, 0
for i = 1, #resolved.all_params do
    if resolved.all_params[i].source.source_kind == 0 then static_count = static_count + 1
    else auto_count = auto_count + 1 end
end
print(string.format("    Static: %d   Automation: %d", static_count, auto_count))


-- ════════════════════════════════════════════════════════════════
-- PHASE 3: CLASSIFY
-- ════════════════════════════════════════════════════════════════
print("\n── Phase 3: Resolved → Classified (rate classification) ──")
local classified = resolved:classify(ctx)
print(string.format("  Literal table: %d entries", #classified.literals))
for i = 1, #classified.literals do
    print(string.format("    literal[%2d] = %10.4f", i-1, classified.literals[i].value))
end
print(string.format("  Total signals:     %d", classified.total_signals))
print(string.format("  Total state slots: %d", classified.total_state_slots))

print("\n  Param binding summary:")
local rc_names = {[0]="literal", [1]="init", [2]="block", [3]="sample", [4]="event", [5]="voice"}
local rc_counts = {}
for i = 1, #classified.params do
    local rc = classified.params[i].base_value.rate_class
    rc_counts[rc] = (rc_counts[rc] or 0) + 1
end
for rc = 0, 5 do
    if rc_counts[rc] then
        print(string.format("    rate_class=%d (%-7s): %d params", rc, rc_names[rc], rc_counts[rc]))
    end
end


-- ════════════════════════════════════════════════════════════════
-- PHASE 4: SCHEDULE
-- ════════════════════════════════════════════════════════════════
print("\n── Phase 4: Classified → Scheduled (buffer allocation) ──")
local scheduled = classified:schedule(ctx)
print(string.format("  Buffers allocated: %d", scheduled.total_buffers))
print(string.format("  Buffer descriptors: %d", #scheduled.buffers))
for i = 1, #scheduled.buffers do
    local b = scheduled.buffers[i]
    print(string.format("    buf[%d]: ch=%d interleaved=%s persistent=%s",
        b.index, b.channels, tostring(b.interleaved), tostring(b.persistent)))
end
print(string.format("  Master output: L=buf[%d] R=buf[%d]", scheduled.master_left, scheduled.master_right))

print(string.format("\n  Track plans: %d", #scheduled.tracks))
for i = 1, #scheduled.tracks do
    local tp = scheduled.tracks[i]
    print(string.format("    Track %d: work=buf[%d] out_L=buf[%d] out_R=buf[%d] vol_binding(rc=%d,s=%d)",
        tp.track_id, tp.work_buf, tp.out_left, tp.out_right,
        tp.volume.rate_class, tp.volume.slot))
end

print(string.format("\n  Graph plans: %d", #scheduled.graph_plans))
for i = 1, #scheduled.graph_plans do
    local gp = scheduled.graph_plans[i]
    print(string.format("    Graph %d: %d node jobs [%d..%d] in=buf[%d] out=buf[%d]",
        gp.graph_id, gp.node_job_count, gp.first_node_job, gp.first_node_job + gp.node_job_count - 1,
        gp.in_buf, gp.out_buf))
end

print(string.format("\n  Node jobs: %d", #scheduled.node_jobs))
for i = 1, #scheduled.node_jobs do
    local nj = scheduled.node_jobs[i]
    local name = nk_names[nj.kind_code] or ("kind_" .. nj.kind_code)
    print(string.format("    job[%2d]: node=%3d %-16s in=buf[%d] out=buf[%d] params[%d..%d]",
        i-1, nj.node_id, name, nj.in_buf, nj.out_buf,
        nj.first_param, nj.first_param + nj.param_count - 1))
end

print(string.format("\n  Steps: %d", #scheduled.steps))
print(string.format("  Scene entries: %d", #scheduled.scene_entries))
print(string.format("  Param bindings: %d", #scheduled.param_bindings))


-- ════════════════════════════════════════════════════════════════
-- PHASE 5: COMPILE
-- ════════════════════════════════════════════════════════════════
print("\n── Phase 5: Scheduled → Kernel (Terra code generation) ──")
local kernel = scheduled:compile(ctx)
local render = kernel:entry_fn()

lines = {}
if render then
    print("  ✅ Compiled render function:")
    print("")
    -- Print the generated Terra IR
    local fn_str = tostring(render)
    for line in fn_str:gmatch("[^\n]+") do
        lines[#lines+1] = line
    end
    print(string.format("  Total Terra IR lines: %d", #lines))
    print("")

    -- Print the full function
    for i = 1, #lines do
        print("  " .. lines[i])
    end
else
    print("  ❌ Compilation failed!")
    for i = 1, #ctx.diagnostics do
        print("    " .. (ctx.diagnostics[i].message or "?"))
    end
end


-- ════════════════════════════════════════════════════════════════
-- PHASE 6: RUN
-- ════════════════════════════════════════════════════════════════
print("\n── Phase 6: Execute compiled render ──")
local FRAMES = 256
local out_l = terralib.new(float[FRAMES])
local out_r = terralib.new(float[FRAMES])
render(out_l, out_r, FRAMES)

print(string.format("  Rendered %d frames", FRAMES))

-- Analyze output
local peak_l, peak_r = 0, 0
local rms_l, rms_r = 0, 0
local zero_count = 0
for i = 0, FRAMES - 1 do
    local vl, vr = out_l[i], out_r[i]
    if math.abs(vl) > peak_l then peak_l = math.abs(vl) end
    if math.abs(vr) > peak_r then peak_r = math.abs(vr) end
    rms_l = rms_l + vl * vl
    rms_r = rms_r + vr * vr
    if vl == 0 and vr == 0 then zero_count = zero_count + 1 end
end
rms_l = math.sqrt(rms_l / FRAMES)
rms_r = math.sqrt(rms_r / FRAMES)

print(string.format("  Peak:  L=%.6f  R=%.6f", peak_l, peak_r))
print(string.format("  RMS:   L=%.6f  R=%.6f", rms_l, rms_r))
print(string.format("  Peak dBFS: L=%.1f  R=%.1f",
    peak_l > 0 and 20*math.log10(peak_l) or -math.huge,
    peak_r > 0 and 20*math.log10(peak_r) or -math.huge))
print(string.format("  RMS dBFS:  L=%.1f  R=%.1f",
    rms_l > 0 and 20*math.log10(rms_l) or -math.huge,
    rms_r > 0 and 20*math.log10(rms_r) or -math.huge))
print(string.format("  Zero samples: %d / %d", zero_count, FRAMES))

print("\n  First 16 samples:")
for i = 0, 15 do
    print(string.format("    [%3d] L=%+10.6f  R=%+10.6f", i, out_l[i], out_r[i]))
end

-- Waveform ASCII art
print("\n  Waveform (L channel, 64 samples):")
local cols = 64
local rows = 12
local half = rows / 2
local grid = {}
for r = 1, rows do grid[r] = {} for c = 1, cols do grid[r][c] = " " end end
-- axis
for c = 1, cols do grid[half][c] = "─" end
for r = 1, rows do grid[r][1] = "│" end
grid[half][1] = "┼"
-- plot
local step = math.max(1, math.floor(FRAMES / cols))
for c = 1, cols do
    local v = out_l[(c-1) * step]
    local max_v = peak_l > 0 and peak_l or 1
    local norm = v / max_v  -- -1..1
    local row = math.floor(half - norm * (half - 1) + 0.5)
    row = math.max(1, math.min(rows, row))
    grid[row][c] = "█"
end
for r = 1, rows do
    local row_str = ""
    for c = 1, cols do row_str = row_str .. grid[r][c] end
    local label = ""
    if r == 1 then label = string.format(" +%.2f", peak_l)
    elseif r == rows then label = string.format(" -%.2f", peak_l)
    elseif r == half then label = "  0.00"
    end
    print("  " .. row_str .. label)
end

-- Summary
print("\n  Diagnostics: " .. #ctx.diagnostics)
print("")
print("════════════════════════════════════════════════════════════")
print("  Pipeline: Editor → Authored → Resolved → Classified")
print("            → Scheduled → Kernel → Native render")
print(string.format("  %d tracks, %d devices, %d params → %d literals",
    #authored.tracks,
    #resolved.all_nodes,
    #resolved.all_params,
    #classified.literals))
print(string.format("  %d buffers × %d frames = %d floats on stack",
    scheduled.total_buffers, FRAMES, scheduled.total_buffers * FRAMES))
print(string.format("  Compiled to %d lines of Terra IR", #lines))
print("  All values baked as compile-time constants")
print("════════════════════════════════════════════════════════════")
