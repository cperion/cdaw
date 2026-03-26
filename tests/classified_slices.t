-- tests/classified_slices.t
-- Smoke test for new Classified -> Scheduled program surface.

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

local pass, fail = 0, 0
local function check(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. msg) end
end

print("1. Classified.GraphSlice:schedule -> Scheduled.GraphProgram")
do
    local gs = D.Classified.GraphSlice(
        L{D.Classified.Graph(1, 0, 1, 0, 0, 0, 1, L{100}, 0, 0, 0, 0, 0, 1)},
        L(),
        L{D.Classified.Node(100, 5, 0, 1, 0, 0, 0, 0, 0, 0, 0, true, 0, 0, 0, 0, 0)},
        L(),
        L(),
        L(),
        L{D.Classified.Param(10, 100, 0.5, 0, 1, D.Classified.Binding(0, 0), 0, 0, 0, 0, 0, 0)},
        L(),
        L(),
        L{D.Classified.Literal(0.5)},
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        1,
        0
    )
    local gp = gs:schedule(D.Classified.Transport(44100, 512, 120, 0, 4, 4, 0, false, 0, 0), D.Classified.TempoMap(L()))
    check(gp.graph.graph_id == 1, "graph id")
    check(#gp.node_programs == 1, "1 node program")
    check(#gp.literals == 1, "1 literal")
    print("  PASS")
end

print("2. Classified.TrackSlice:schedule -> Scheduled.TrackProgram")
do
    local ts = D.Classified.TrackSlice(
        D.Classified.Track(1, 2, 0, 0, 0, D.Classified.Binding(0, 0), D.Classified.Binding(0, 1), 10, 0, 0, 0, 0, 0, 0, nil, nil, false, false, false, false),
        L{
            D.Classified.Param(0, 0, 0.8, 0, 4, D.Classified.Binding(0, 0), 0, 0, 0, 0, 0, 0),
            D.Classified.Param(1, 0, 0.0, -1, 1, D.Classified.Binding(0, 1), 0, 0, 0, 0, 0, 0)
        },
        L(),
        L(),
        L(),
        L{D.Classified.Literal(0.8), D.Classified.Literal(0.0)},
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        D.Classified.GraphSlice(L{D.Classified.Graph(10, 0, 1, 0, 0, 0, 0, L(), 0, 0, 0, 0, 0, 0)}, L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), 0, 0)
    )
    local tp = ts:schedule(D.Classified.Transport(44100, 512, 120, 0, 4, 4, 0, false, 0, 0), D.Classified.TempoMap(L()))
    check(tp.track.track_id == 1, "track id")
    check(#tp.mixer_params == 2, "2 mixer params")
    check(tp.device_graph.graph.graph_id == 10 or tp.device_graph.graph.graph_id == 0, "graph program present")
    print("  PASS")
end

print("3. Classified.Project:schedule -> Scheduled.Project(track_programs)")
do
    local cp = D.Classified.Project(
        D.Classified.Transport(44100, 512, 120, 0, 4, 4, 0, false, 0, 0),
        D.Classified.TempoMap(L()),
        L{D.Classified.TrackSlice(D.Classified.Track(1, 2, 0, 0, 0, D.Classified.Binding(0,0), D.Classified.Binding(0,0), 0, nil, nil, false, false, false, false), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), D.Classified.GraphSlice(L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), L(), 0, 0))},
        L()
    )
    local sp = cp:schedule()
    check(#sp.track_programs == 1, "1 track program")
    check(sp.track_programs[1].track.track_id == 1, "program track id")
    check(#sp.scene_entries == 0, "0 scene entries")
    print("  PASS")
end

print("")
print(string.format("Classified slices: %d pass, %d fail (%d total)", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
