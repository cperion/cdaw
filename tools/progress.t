-- tools/progress.t
-- Programmatic implementation progress report.
--
-- Inventory sources of truth:
--   • schema text (`methods {}` blocks) for canonical method inventory
--   • loaded ASDL context (`D`) for canonical variant inventory
--   • diag.wrap()/diag.status() for method maturity
--   • diag.variant_family()/diag.variant_status() for variant maturity
--
-- Usage:
--   terra tools/progress.t              # full report
--   terra tools/progress.t summary      # one-line summaries
--   terra tools/progress.t phase        # per-phase breakdowns
--   terra tools/progress.t detail       # method + variant detail
--   terra tools/progress.t variants     # variant detail only
--   terra tools/progress.t runtime      # run fixture, show call stats
--   terra tools/progress.t all          # everything

local D = require("daw-unified")
local List = require("terralist")
require("impl/init")

local diag  = require("impl/_support/diagnostics")
local asdl_methods = require("tools/asdl_methods")

local mode = (arg and arg[1]) or "all"

-- ═══════════════════════════════════════════════════════════
-- 1. Parse ASDL: canonical method inventory (text metadata)
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
-- 2. Diff: ASDL method inventory vs runtime registrations
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

local orphans = {}
for code, st in pairs(diag.method_status) do
    if not by_code[code] then
        orphans[#orphans + 1] = { code = code, status = st }
    end
end
table.sort(orphans, function(a, b) return a.code < b.code end)

-- ═══════════════════════════════════════════════════════════
-- 3. Variant inventory (live ASDL runtime)
-- ═══════════════════════════════════════════════════════════

local function lookup_class(module_name, type_name)
    local ns = D[module_name]
    return ns and ns[type_name] or nil
end

local function collect_variants(module_name, type_name)
    local cls = lookup_class(module_name, type_name)
    local out, seen = {}, {}
    if not cls or not cls.members then return out end

    for member in pairs(cls.members) do
        if type(member) == "table" and member ~= cls then
            local name = rawget(member, "kind")
            if type(name) == "string" and not seen[name] then
                seen[name] = true
                out[#out + 1] = name
            end
        end
    end

    table.sort(out)
    return out
end

local function method_variant_family(m)
    local fam = diag.variant_families[m.code]
    if fam then return fam end

    local own_variants = collect_variants(m.module, m.type_name)
    if #own_variants > 0 then
        return { module = m.module, type_name = m.type_name }
    end
    return nil
end

local variants = {}          -- flat list of variant work items
local variant_groups = {}    -- ordered list grouped by method
local variant_group_by_code = {}
local known_variant_names = {}

for _, m in ipairs(canonical) do
    local fam = method_variant_family(m)
    if fam then
        local names = collect_variants(fam.module, fam.type_name)
        if #names > 0 then
            local group = {
                code = m.code,
                method_module = m.module,
                method_type_name = m.type_name,
                method_name = m.method_name,
                family_module = fam.module,
                family_type_name = fam.type_name,
                total = 0,
                none = 0,
                stub = 0,
                partial = 0,
                real = 0,
                items = {},
            }
            variant_groups[#variant_groups + 1] = group
            variant_group_by_code[m.code] = group
            known_variant_names[m.code] = {}

            for _, variant_name in ipairs(names) do
                known_variant_names[m.code][variant_name] = true
                local status = ((diag.variant_statuses[m.code] or {})[variant_name]) or "none"
                local item = {
                    code = m.code,
                    method_module = m.module,
                    method_type_name = m.type_name,
                    method_name = m.method_name,
                    family_module = fam.module,
                    family_type_name = fam.type_name,
                    variant_name = variant_name,
                    status = status,
                }
                variants[#variants + 1] = item
                group.items[#group.items + 1] = item
                group.total = group.total + 1
                group[status] = (group[status] or 0) + 1
            end
        end
    end
end

local variant_orphans = {}
for code, reg in pairs(diag.variant_statuses) do
    if not by_code[code] then
        for variant_name, status in pairs(reg) do
            variant_orphans[#variant_orphans + 1] = {
                code = code,
                variant_name = variant_name,
                status = status,
                why = "method not in ASDL inventory",
            }
        end
    elseif not known_variant_names[code] then
        for variant_name, status in pairs(reg) do
            variant_orphans[#variant_orphans + 1] = {
                code = code,
                variant_name = variant_name,
                status = status,
                why = "method has no declared variant family",
            }
        end
    else
        for variant_name, status in pairs(reg) do
            if not known_variant_names[code][variant_name] then
                variant_orphans[#variant_orphans + 1] = {
                    code = code,
                    variant_name = variant_name,
                    status = status,
                    why = "unknown variant in declared family",
                }
            end
        end
    end
end
for code, fam in pairs(diag.variant_families) do
    if not by_code[code] then
        variant_orphans[#variant_orphans + 1] = {
            code = code,
            variant_name = fam.module .. "." .. fam.type_name,
            status = "-",
            why = "variant family declared for unknown method",
        }
    elseif not known_variant_names[code] then
        variant_orphans[#variant_orphans + 1] = {
            code = code,
            variant_name = fam.module .. "." .. fam.type_name,
            status = "-",
            why = "declared variant family resolved to no variants",
        }
    end
end
table.sort(variant_orphans, function(a, b)
    if a.code ~= b.code then return a.code < b.code end
    return tostring(a.variant_name) < tostring(b.variant_name)
end)

-- ═══════════════════════════════════════════════════════════
-- 4. Counts
-- ═══════════════════════════════════════════════════════════

local total = #methods
local counts = { none = 0, stub = 0, partial = 0, real = 0 }
for _, m in ipairs(methods) do
    counts[m.status] = (counts[m.status] or 0) + 1
end

local variant_total = #variants
local variant_counts = { none = 0, stub = 0, partial = 0, real = 0 }
for _, v in ipairs(variants) do
    variant_counts[v.status] = (variant_counts[v.status] or 0) + 1
end

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
local vpc = {}
for _, p in ipairs(phase_order) do
    pc[p] = { total = 0, none = 0, stub = 0, partial = 0, real = 0 }
    vpc[p] = { total = 0, none = 0, stub = 0, partial = 0, real = 0 }
end
for _, m in ipairs(methods) do
    local p = phase_for[m.module] or "?"
    if pc[p] then
        pc[p].total = pc[p].total + 1
        pc[p][m.status] = (pc[p][m.status] or 0) + 1
    end
end
for _, v in ipairs(variants) do
    local p = phase_for[v.method_module] or "?"
    if vpc[p] then
        vpc[p].total = vpc[p].total + 1
        vpc[p][v.status] = (vpc[p][v.status] or 0) + 1
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
local status_label = { none = "NONE", stub = "STUB", partial = "PART", real = "REAL" }

-- ═══════════════════════════════════════════════════════════
-- Summary
-- ═══════════════════════════════════════════════════════════

local function print_summary()
    local done = counts.real + counts.partial
    print(string.format(
        "Methods : %d/%d implemented  │  %s real  %s partial  %s stub  %s none",
        done, total, pct(counts.real, total), pct(counts.partial, total),
        pct(counts.stub, total), pct(counts.none, total)))
    print("  " .. bar(counts.real, counts.partial, counts.stub, counts.none, total, 50)
        .. string.format("  █ %d  ▓ %d  ░ %d  · %d",
            counts.real, counts.partial, counts.stub, counts.none))

    if variant_total > 0 then
        local vdone = variant_counts.real + variant_counts.partial
        print(string.format(
            "Variants: %d/%d implemented  │  %s real  %s partial  %s stub  %s none",
            vdone, variant_total,
            pct(variant_counts.real, variant_total),
            pct(variant_counts.partial, variant_total),
            pct(variant_counts.stub, variant_total),
            pct(variant_counts.none, variant_total)))
        print("  " .. bar(variant_counts.real, variant_counts.partial, variant_counts.stub, variant_counts.none, variant_total, 50)
            .. string.format("  █ %d  ▓ %d  ░ %d  · %d",
                variant_counts.real, variant_counts.partial, variant_counts.stub, variant_counts.none))
    else
        print("Variants: no variant families registered")
    end
end

-- ═══════════════════════════════════════════════════════════
-- Phase breakdown
-- ═══════════════════════════════════════════════════════════

local function print_phase_table(title, per_phase, grand_total, grand_counts)
    print("")
    print(title)
    print(string.format("%-26s %4s %4s %4s %4s %4s  %s",
        "Phase", "Tot", "Real", "Part", "Stub", "None", ""))
    print(string.rep("─", 85))

    for _, p in ipairs(phase_order) do
        local c = per_phase[p]
        print(string.format("%-26s %4d %4d %4d %4d %4d  %s",
            phase_labels[p] or p, c.total, c.real, c.partial, c.stub, c.none,
            bar(c.real, c.partial, c.stub, c.none, c.total, 24)))
    end
    print(string.rep("─", 85))
    print(string.format("%-26s %4d %4d %4d %4d %4d  %s",
        "TOTAL", grand_total,
        grand_counts.real, grand_counts.partial, grand_counts.stub, grand_counts.none,
        bar(grand_counts.real, grand_counts.partial, grand_counts.stub, grand_counts.none, grand_total, 24)))
end

local function print_phase()
    print_phase_table("Method phase breakdown", pc, total, counts)
    if variant_total > 0 then
        print_phase_table("Variant phase breakdown", vpc, variant_total, variant_counts)
    end
end

-- ═══════════════════════════════════════════════════════════
-- Detail
-- ═══════════════════════════════════════════════════════════

local function print_method_detail()
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
        print(string.format("\n  ── Orphan method registrations (not in ASDL) ──"))
        for _, o in ipairs(orphans) do
            print(string.format("  ⚠ %-40s %-4s", o.code, o.status))
        end
    end
end

local function print_variant_detail()
    if variant_total == 0 then return end

    print("")
    print("Variant detail")
    print(string.rep("─", 100))

    for _, g in ipairs(variant_groups) do
        local fam = g.family_module .. "." .. g.family_type_name
        print(string.format("\n  ▸ %-40s  [%s]  %d total  (%d real, %d part, %d stub, %d none)",
            g.code, fam, g.total, g.real, g.partial, g.stub, g.none))
        for _, v in ipairs(g.items) do
            print(string.format("      %s %-24s %-4s",
                status_icon[v.status] or "?",
                v.variant_name,
                status_label[v.status] or "?"))
        end
    end

    if #variant_orphans > 0 then
        print(string.format("\n  ── Orphan variant registrations ──"))
        for _, o in ipairs(variant_orphans) do
            print(string.format("  ⚠ %-40s %-24s %-4s  %s",
                o.code, tostring(o.variant_name), tostring(o.status), o.why))
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

    local ok, err = pcall(function()
        local a = project:lower(ctx)
        local r = a:resolve(ctx)
        local c = r:classify(ctx)
        local s = c:schedule(ctx)
        local k = s:compile(ctx)
        local _ = k:entry_fn()
    end)

    print(ok and "  Pipeline OK" or ("  Pipeline FAILED: " .. tostring(err)))

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
print("║  schema text = methods   •   ASDL runtime = variants║")
print("╚══════════════════════════════════════════════════════╝")

print_summary()

if mode == "phase" or mode == "all" then print_phase() end
if mode == "detail" or mode == "all" then
    print_method_detail()
    print_variant_detail()
end
if mode == "variants" or mode == "variant" then print_variant_detail() end
if mode == "runtime" or mode == "all" then print_runtime() end

print("")
