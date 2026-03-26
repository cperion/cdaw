-- tests/kernel/entry.t
-- Test for Kernel.Project:entry_fn

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end
local function approx(a,b,t) return math.abs(a-b) < (t or 0.001) end

print("1. kernel.project.entry_fn")
do
    local project = D.Editor.Project(
        "Test", nil, 1,
        D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "T1", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "v", 1, 0, 4, D.Editor.StaticValue(1.0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "p", 0, -1, 1, D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{}),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(), D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
    local a = project:lower()
    local r = a:resolve(960)
    local c = r:classify()
    local s = c:schedule()
    local k = s:compile()
    check(k ~= nil, "kernel produced")

    local entry = k:entry_fn()
    check(entry ~= nil, "entry_fn returned something")

    -- entry_fn returns the render function
    if entry then
        local out_l = terralib.new(float[64])
        local out_r = terralib.new(float[64])
        entry(out_l, out_r, 64)
        -- Empty graph should still compile to a valid silent entry.
        check(approx(out_l[0], 0.0), "render output = 0.0 silence, got " .. out_l[0])
    end
    print("  PASS")
end

print("")
print(string.format("Kernel entry: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
