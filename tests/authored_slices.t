-- tests/authored_slices.t
-- Smoke test for new Authored -> Resolved slice surface.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

local pass, fail = 0, 0
local function check(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. msg) end
end

print("1. Authored.Track:resolve -> Resolved.TrackSlice")
do
    local t = D.Authored.Track(
        1, "T", 2,
        D.Authored.NoInput,
        D.Authored.Param(0, "vol", 1, 0, 4, D.Authored.StaticValue(0.8), D.Authored.Replace, D.Authored.NoSmoothing),
        D.Authored.Param(1, "pan", 0, -1, 1, D.Authored.StaticValue(0), D.Authored.Replace, D.Authored.NoSmoothing),
        D.Authored.Graph(10, L(), L(), L(), L(), L(), D.Authored.Serial, D.Authored.AudioDomain),
        L(), L(), L(), nil, nil, false, false, false, false, false
    )
    local s = t:resolve(960)
    check(s.track.id == 1, "track id")
    check(#s.mixer_params == 2, "2 mixer params")
    check(#s.mixer_curves == 0, "0 mixer curves")
    check(#s.device_graph.graphs >= 1, "graph slice populated")
    print("  PASS")
end

print("2. Authored.Project:resolve -> Resolved.Project(track_slices)")
do
    local p = D.Authored.Project(
        "P", nil, 1,
        D.Authored.Transport(44100, 64, 120, 0, 4, 4, D.Authored.QNone, false, nil),
        L{D.Authored.Track(
            1, "T", 2,
            D.Authored.NoInput,
            D.Authored.Param(0, "vol", 1, 0, 4, D.Authored.StaticValue(0.8), D.Authored.Replace, D.Authored.NoSmoothing),
            D.Authored.Param(1, "pan", 0, -1, 1, D.Authored.StaticValue(0), D.Authored.Replace, D.Authored.NoSmoothing),
            D.Authored.Graph(10, L(), L(), L(), L(), L(), D.Authored.Serial, D.Authored.AudioDomain),
            L(), L(), L(), nil, nil, false, false, false, false, false
        )},
        L(),
        D.Authored.TempoMap(L{D.Authored.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L())
    )
    local r = p:resolve(960)
    check(#r.track_slices == 1, "1 track slice")
    check(r.track_slices[1].track.id == 1, "slice track id")
    print("  PASS")
end

print("")
print(string.format("Authored slices: %d pass, %d fail (%d total)", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
