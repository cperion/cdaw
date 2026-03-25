-- tools/progress.t
-- Programmatic implementation progress report.
-- The ASDL schema is the SINGLE SOURCE OF TRUTH for what methods should exist.
-- diag.wrap()/diag.status() is the SINGLE SOURCE OF TRUTH for how done each is.
--
-- Usage:
--   terra tools/progress.t              # full report
--   terra tools/progress.t summary      # one-line summary
--   terra tools/progress.t phase        # per-phase breakdown
--   terra tools/progress.t runtime      # run fixture, show call stats
--   terra tools/progress.t all          # everything

local D = require("daw-unified")
local List = require("terralist")
require("impl/init")

local diag  = require("impl/_support/diagnostics")
local asdl_methods = require("tools/asdl_methods")

local mode = (arg and arg[1]) or "all"

-- ═══════════════════════════════════════════════════════════
-- 1. Parse ASDL: canonical method inventory (SOT)
-- ═══════════════════════════════════════════════════════════

local function dirname(path)
    return path:match("^(.*)/[^/]*$") or "."
end
local function script_dir()
    local src = debug.getinfo(1, "S").source
    assert(type(src) == "string" and src:sub(1,1) == "@")
    return dirname(src:sub(2))
end
local root = dirname(script_dir())

local canonical = asdl_methods.parse_all(root .. "/schema")

-- ═══════════════════════════════════════════════════════════
-- 2. Diff: ASDL inventory vs runtime registrations
-- ═══════════════════════════════════════════════════════════

local methods = {}  -- ordered list of { code, module, type_name, method_name, status }
local by_code = {}

for _, m in ipairs(canonical) do
    local status = diag.method_status[m.code] or "none"
    local entry = {
        code        = m.code,
        module      = m.module,
        type_name   = m.type_name,
        method_name = m.method_name,
        returns     = m.returns,
        signature   = m.signature,
        status      = status,
    }
    methods[#methods + 1] = entry
    by_code[m.code] = entry
end

-- Check for orphan registrations (registered but not in ASDL)
local orphans = {}
for code, st in pairs(diag.method_status) do
    if not by_code[code] then
        orphans[#orphans + 1] = { code = code, status = st }
    end
end
table.sort(orphans, function(a, b) return a.code < b.code end)

-- ═══════════════════════════════════════════════════════════
-- 3. Counts
-- ═══════════════════════════════════════════════════════════

local total = #methods
local counts = { none = 0, stub = 0, partial = 0, real = 0 }
for _, m in ipairs(methods) do
    counts[m.status] = (counts[m.status] or 0) + 1
end

-- Phase grouping
local phase_for = {
    Editor     = "editor",
    View       = "view",
    Authored   = "authored",
    Resolved   = "resolved",
    Classified = "classified",
    Scheduled  = "scheduled",
    Kernel     = "kernel",
}
local phase_order = { "editor", "view", "authored", "resolved", "classified", "scheduled", "kernel" }
local phase_labels = {
    editor     = "Editor → Authored",
    view       = "View → TerraUI",
    authored   = "Authored → Resolved",
    resolved   = "Resolved → Classified",
    classified = "Classified → Scheduled",
    scheduled  = "Scheduled → Kernel",
    kernel     = "Kernel",
}
local pc = {}
for _, p in ipairs(phase_order) do
    pc[p] = { total = 0, none = 0, stub = 0, partial = 0, real = 0 }
end
for _, m in ipairs(methods) do
    local p = phase_for[m.module] or "?"
    if pc[p] then
        pc[p].total = pc[p].total + 1
        pc[p][m.status] = (pc[p][m.status] or 0) + 1
    end
end

-- ═══════════════════════════════════════════════════════════
-- Display helpers
-- ═══════════════════════════════════════════════════════════

local function bar(real, partial, stub, none, total, width)
    width = width or 30
    if total == 0 then return string.rep("·", width) end
    local r = math.floor(real / total * width + 0.5)
    local p = math.floor(partial / total * width + 0.5)
    local s = math.floor(stub / total * width + 0.5)
    local n = width - r - p - s
    if n < 0 then n = 0 end
    return string.rep("█", r) .. string.rep("▓", p) .. string.rep("░", s) .. string.rep("·", n)
end

local function pct(n, t)
    if t == 0 then return "  0%" end
    return string.format("%3d%%", math.floor(n / t * 100 + 0.5))
end

local status_icon  = { none = "·", stub = "░", partial = "▓", real = "█" }
local status_label = { none = "    ", stub = "STUB", partial = "PART", real = "REAL" }

-- ═══════════════════════════════════════════════════════════
-- Summary
-- ═══════════════════════════════════════════════════════════

local function print_summary()
    local done = counts.real + counts.partial
    print(string.format(
        "Terra DAW: %d/%d methods implemented  │  %s real  %s partial  %s stub  %s none",
        done, total, pct(counts.real, total), pct(counts.partial, total),
        pct(counts.stub, total), pct(counts.none, total)))
    print("  " .. bar(counts.real, counts.partial, counts.stub, counts.none, total, 50)
        .. string.format("  █ %d  ▓ %d  ░ %d  · %d",
            counts.real, counts.partial, counts.stub, counts.none))
end

-- ═══════════════════════════════════════════════════════════
-- Phase breakdown
-- ═══════════════════════════════════════════════════════════

local function print_phase()
    print("")
    print(string.format("%-26s %4s %4s %4s %4s %4s  %s",
        "Phase", "Tot", "Real", "Part", "Stub", "None", ""))
    print(string.rep("─", 85))

    for _, p in ipairs(phase_order) do
        local c = pc[p]
        print(string.format("%-26s %4d %4d %4d %4d %4d  %s",
            phase_labels[p] or p, c.total, c.real, c.partial, c.stub, c.none,
            bar(c.real, c.partial, c.stub, c.none, c.total, 24)))
    end
    print(string.rep("─", 85))
    print(string.format("%-26s %4d %4d %4d %4d %4d  %s",
        "TOTAL", total, counts.real, counts.partial, counts.stub, counts.none,
        bar(counts.real, counts.partial, counts.stub, counts.none, total, 24)))
end

-- ═══════════════════════════════════════════════════════════
-- Detail
-- ═══════════════════════════════════════════════════════════

local function print_detail()
    print("")
    print(string.format("%-42s %-4s  %s", "Method (from ASDL)", "Stat", "Signature"))
    print(string.rep("─", 100))

    local cur_phase = nil
    for _, m in ipairs(methods) do
        local p = phase_for[m.module] or "?"
        if p ~= cur_phase then
            cur_phase = p
            print(string.format("\n  ── %s ──", phase_labels[p] or p))
        end
        local sig = m.module .. "." .. m.type_name .. ":" .. m.method_name
            .. " → " .. m.returns
        print(string.format("  %s %-40s %-4s  %s",
            status_icon[m.status] or "?", m.code,
            status_label[m.status] or "?", sig))
    end

    if #orphans > 0 then
        print(string.format("\n  ── Orphan registrations (not in ASDL) ──"))
        for _, o in ipairs(orphans) do
            print(string.format("  ⚠ %-40s %-4s", o.code, o.status))
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- Runtime fixture
-- ═══════════════════════════════════════════════════════════

local function L(t)
    if t == nil then return List() end
    if List:isclassof(t) then return t end
    local l = List()
    for i = 1, #t do l:insert(t[i]) end
    return l
end

local function print_runtime()
    print("")
    print("Running fixture through full pipeline...")

    -- Reset call stats
    for k in pairs(diag.method_calls) do diag.method_calls[k] = nil end

    local function mp(id, name, val, mn, mx)
        return D.Editor.ParamValue(id, name, val, mn, mx,
            D.Editor.StaticValue(val), D.Editor.Replace, D.Editor.NoSmoothing)
    end

    local body = D.Editor.NativeDeviceBody(
        1, "Gain", D.Authored.GainNode(),
        L{ mp(1, "gain", 1, 0, 4) }, L(), nil, nil, nil, true, nil)

    local track = D.Editor.Track(
        1, "Track 1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
        mp(0, "volume", 1, 0, 4), mp(1, "pan", 0, -1, 1),
        D.Editor.DeviceChain(L{ D.Editor.NativeDevice(body) }),
        L{ D.Editor.Clip(1, D.Editor.NoteContent(
            D.Editor.NoteRegion(
                L{ D.Editor.Note(1, 60, 0, 1, 100, nil, false, nil) }, L()
            )), 0, 4, 0, 0, false, mp(0, "cg", 1, 0, 4), nil, nil, nil) },
        L{ D.Editor.Slot(0, D.Editor.EmptySlot,
            D.Editor.LaunchBehavior(D.Editor.Trigger, nil, false, false, nil), true) },
        L{ D.Editor.Send(1, 0, mp(0, "sl", 0.5, 0, 1), false, true) },
        nil, nil, false, false, false, false, false, nil)

    local project = D.Editor.Project(
        "Fixture", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{ track }, L(), D.Editor.TempoMap(L(), L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))

    local ctx = { diagnostics = {}, ticks_per_beat = 960, sample_rate = 44100 }
    local ctr = 0
    ctx.alloc_graph_id = function() ctr = ctr + 1; return ctr end
    ctx.alloc_note_asset_id = function() ctr = ctr + 1; return ctr end

    local ok, err = pcall(function()
        local a = project:lower(ctx)
        local r = a:resolve(ctx)
        local c = r:classify(ctx)
        local s = c:schedule(ctx)
        local k = s:compile(ctx)
        local _ = k:entry_fn()
    end)

    print(ok and "  Pipeline OK" or ("  Pipeline FAILED: " .. tostring(err)))

    -- Show call stats
    print("")
    print(string.format("  %-40s %5s %5s %5s", "Method", "Calls", "OK", "Fall"))
    print("  " .. string.rep("─", 60))

    local call_codes = {}
    for code in pairs(diag.method_calls) do call_codes[#call_codes + 1] = code end
    table.sort(call_codes)

    local tc, tok, tfb = 0, 0, 0
    for _, code in ipairs(call_codes) do
        local c = diag.method_calls[code]
        tc = tc + c.calls; tok = tok + c.successes; tfb = tfb + c.fallbacks
        print(string.format("  %s %-38s %5d %5d %5d",
            c.fallbacks > 0 and "⚠" or "✓", code, c.calls, c.successes, c.fallbacks))
    end
    print("  " .. string.rep("─", 60))
    print(string.format("  %-40s %5d %5d %5d", "TOTAL", tc, tok, tfb))

    if #ctx.diagnostics > 0 then
        print(string.format("\n  Diagnostics: %d", #ctx.diagnostics))
        for i = 1, math.min(#ctx.diagnostics, 5) do
            local d = ctx.diagnostics[i]
            print(string.format("    [%s] %s", d.severity, d.code))
        end
        if #ctx.diagnostics > 5 then
            print("    ... and " .. (#ctx.diagnostics - 5) .. " more")
        end
    else
        print("\n  No diagnostics (all methods succeeded).")
    end
end

-- ═══════════════════════════════════════════════════════════
-- Main
-- ═══════════════════════════════════════════════════════════

print("╔══════════════════════════════════════════════════════╗")
print("║         Terra DAW — Implementation Progress         ║")
print("║  ASDL schema = source of truth for method inventory ║")
print("╚══════════════════════════════════════════════════════╝")

print_summary()

if mode == "phase" or mode == "all" then print_phase() end
if mode == "detail" or mode == "all" then print_detail() end
if mode == "runtime" or mode == "all" then print_runtime() end

print("")
