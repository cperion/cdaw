-- tools/memoize_probe.t
-- Empirical probe of terralib.memoize behavior.
--
-- Usage:
--   terra tools/memoize_probe.t

local DAW = require("daw")
local D = DAW.types

local function line()
    print(string.rep("─", 72))
end

print("╔════════════════════════════════════════════════════════════════════╗")
print("║                 Terra memoize behavior probe                     ║")
print("╚════════════════════════════════════════════════════════════════════╝")
print("")

-- 1. Same scalar args => same cached object
line()
print("1. Scalar keying")
local scalar_calls = 0
local make_add = terralib.memoize(function(x)
    scalar_calls = scalar_calls + 1
    local terra f(a:int)
        return a + [x]
    end
    return f
end)
local add1_a = make_add(1)
local add1_b = make_add(1)
local add2 = make_add(2)
print("generator calls:", scalar_calls)
print("same arg => same fn object:", add1_a == add1_b)
print("different arg => different fn:", add1_a == add2)
print("results:", add1_a(10), add1_b(10), add2(10))

-- 2. Returned tables are cached too
line()
print("2. Returned table identity is cached")
local table_calls = 0
local make_pair = terralib.memoize(function(x)
    table_calls = table_calls + 1
    local terra f(a:int)
        return a + [x]
    end
    return { fn = f, tag = x }
end)
local p1 = make_pair(7)
local p2 = make_pair(7)
local p3 = make_pair(8)
print("generator calls:", table_calls)
print("same arg => same returned table:", p1 == p2)
print("same arg => same nested fn:", p1.fn == p2.fn)
print("different arg => different nested fn:", p1.fn == p3.fn)

-- 3. Lua equality on plain tables: same reference hits, same shape does not
line()
print("3. Lua equality for plain table args")
local plain_calls = 0
local id_plain = terralib.memoize(function(t)
    plain_calls = plain_calls + 1
    return t
end)
local ta = { x = 1 }
local tb = { x = 1 }
local ra1 = id_plain(ta)
local ra2 = id_plain(ta)
local rb = id_plain(tb)
print("generator calls:", plain_calls)
print("same reference hits:", ra1 == ra2)
print("same shape different table misses:", ra1 == rb)

-- 4. ASDL unique values: equality depends on argument identity, especially lists
line()
print("4. ASDL unique values + memoize")
local proj_calls = 0
local id_project = terralib.memoize(function(p)
    proj_calls = proj_calls + 1
    return p
end)
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local shared_transport = D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil)
local shared_tracks = L()
local shared_scenes = L()
local shared_tempo = D.Editor.TempoMap(L(), L())
local shared_assets = D.Authored.AssetBank(L(), L(), L(), L(), L())
local pA = D.Editor.Project(
    "P", nil, 1,
    D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
    L(), L(), D.Editor.TempoMap(L(), L()), D.Authored.AssetBank(L(), L(), L(), L(), L()))
local pB = D.Editor.Project(
    "P", nil, 1,
    D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
    L(), L(), D.Editor.TempoMap(L(), L()), D.Authored.AssetBank(L(), L(), L(), L(), L()))
local pC = D.Editor.Project(
    "P", nil, 1,
    D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
    shared_tracks, shared_scenes, shared_tempo, shared_assets)
local pD = D.Editor.Project(
    "P", nil, 1,
    D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
    shared_tracks, shared_scenes, shared_tempo, shared_assets)
local pE = D.Editor.Project(
    "P", nil, 1,
    shared_transport, shared_tracks, shared_scenes, shared_tempo, shared_assets)
local pF = D.Editor.Project(
    "P", nil, 1,
    shared_transport, shared_tracks, shared_scenes, shared_tempo, shared_assets)
local rp1 = id_project(pA)
local rp2 = id_project(pB)
local rp3 = id_project(pC)
local rp4 = id_project(pD)
local rp5 = id_project(pE)
local rp6 = id_project(pF)
print("fresh lists each time => pA == pB:", pA == pB)
print("shared lists only => pC == pD:", pC == pD)
print("share all child args => pE == pF:", pE == pF)
print("memoize fresh/fresh hit:", rp1 == rp2)
print("memoize shared-lists hit:", rp3 == rp4)
print("memoize all-shared hit:", rp5 == rp6)
print("generator calls:", proj_calls)

-- 5. Function pointers
line()
print("5. Function pointers")
local terra mul3(a:int)
    return a * 3
end
print("fn object type:", type(mul3))
print("has getpointer:", mul3.getpointer ~= nil)
local ptr_before = mul3:getpointer()
print("pointer before call:", ptr_before)
print("call result:", mul3(5))
local ptr_after = mul3:getpointer()
print("pointer after call:", ptr_after)
print("same pointer before/after:", ptr_before == ptr_after)

-- 6. getpointer on memoized functions
line()
print("6. Pointer stability for memoized generated functions")
local mkptr = terralib.memoize(function(x)
    local terra f(a:int)
        return a + [x]
    end
    return f
end)
local mf1 = mkptr(42)
local mf2 = mkptr(42)
local mf3 = mkptr(43)
local mp1 = mf1:getpointer()
local mp2 = mf2:getpointer()
local mp3 = mf3:getpointer()
print("same arg => same fn object:", mf1 == mf2)
print("same arg => same pointer:", mp1 == mp2)
print("different arg => different pointer:", mp1 == mp3)
print("results:", mf1(1), mf2(1), mf3(1))

print("")
line()
print("Conclusions:")
print("  • terralib.memoize keys by Lua equality on its explicit parameters")
print("  • same scalar arg => cache hit")
print("  • same plain-table contents do NOT hit unless the table is the same reference")
print("  • ASDL values only hit when their constructor arguments hit by Lua equality")
print("  • fresh terralist/List arguments defeat identity-based cache hits")
print("  • structural sharing / argument reuse is therefore mandatory")
print("  • Terra functions expose getpointer(), compile(), and disas()")
print("  • memoized generated Terra functions preserve object identity and pointer identity per key")
line()
