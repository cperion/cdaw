-- tests/resolved_slices.t
-- Smoke test for new Resolved -> Classified slice surface.

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. msg) end
end

print("1. Resolved.GraphSlice:classify -> Classified.GraphSlice")
do
    local rp = D.Resolved.Param(
        10, 100, "gain",
        0.5, 0, 1,
        D.Resolved.ParamSourceRef(0, 0.5, nil),
        0, 0, 0
    )
    local gs = D.Resolved.GraphSlice(
        L{D.Resolved.Graph(1, 0, 1, 0, 0, 0, 1, L{100}, L(), 0, 0, 0, 0, 0, 0)},
        L(),
        L{D.Resolved.Node(100, 5, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, true, nil, 0, 0, 0, 0)},
        L(),
        L(),
        L{rp},
        L(),
        L(),
        L()
    )
    local cg = gs:classify()
    check(#cg.graphs == 1, "1 graph")
    check(#cg.nodes == 1, "1 node")
    check(#cg.params == 1, "1 param")
    print("  PASS")
end

print("2. Resolved.TrackSlice:classify -> Classified.TrackSlice")
do
    local ts = D.Resolved.TrackSlice(
        D.Resolved.Track(1, "T", 2, 0, 0, 0, 0, 1, 10, 0, 0, 0, 0, 0, 0, nil, nil, false, false, false, false, false),
        L{
            D.Resolved.Param(0, 0, "volume", 0.8, 0, 4, D.Resolved.ParamSourceRef(0, 0.8, nil), 0, 0, 0),
            D.Resolved.Param(1, 0, "pan", 0.0, -1, 1, D.Resolved.ParamSourceRef(0, 0.0, nil), 0, 0, 0)
        },
        L(),
        L(),
        L(),
        L(),
        F.resolved_graph_slice(10)
    )
    local ct = ts:classify()
    check(ct.track.id == 1, "track id")
    check(#ct.mixer_params == 2, "2 mixer params")
    check(ct.track.volume.rate_class == 0, "volume binding")
    check(#ct.device_graph.graphs >= 1, "device graph slice")
    print("  PASS")
end

print("3. Resolved.Project:classify -> Classified.Project(track_slices)")
do
    local rp = D.Resolved.Project(
        F.resolved_transport(),
        F.resolved_tempo_map(),
        L{D.Resolved.TrackSlice(
            D.Resolved.Track(1, "T", 2, 0, 0, 0, 0, 1, 10, 0, 0, 0, 0, 0, 0, nil, nil, false, false, false, false, false),
            L{
                D.Resolved.Param(0, 0, "volume", 0.8, 0, 4, D.Resolved.ParamSourceRef(0, 0.8, nil), 0, 0, 0),
                D.Resolved.Param(1, 0, "pan", 0.0, -1, 1, D.Resolved.ParamSourceRef(0, 0.0, nil), 0, 0, 0)
            },
            L(),
            L(),
            L(),
            L(),
            F.resolved_graph_slice(10)
        )},
        L(),
        F.resolved_asset_bank()
    )
    local cp = rp:classify()
    check(#cp.track_slices == 1, "1 track slice")
    check(cp.track_slices[1].track.id == 1, "slice track id")
    check(cp.transport ~= nil, "transport preserved")
    check(cp.track_slices[1].device_graph ~= nil, "device graph classified")
    print("  PASS")
end

print("")
print(string.format("Resolved slices: %d pass, %d fail (%d total)", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
