-- tests/session_sharing.t
-- Structural sharing checks for app/session persistent edit helpers.

local D = require("daw-unified")
local session = require("app/session")
local F = require("impl/_support/fallbacks")
local L = F.L

local pass, fail = 0, 0
local function check(cond, msg)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        print("  FAIL: " .. msg)
    end
end

local function static_param(id, name, value, mn, mx)
    return D.Editor.ParamValue(
        id, name, value, mn, mx,
        D.Editor.StaticValue(value),
        D.Editor.Replace,
        D.Editor.NoSmoothing
    )
end

local function make_track(track_id, name, osc_id, gain_id)
    return D.Editor.Track(
        track_id, name, 2, D.Editor.AudioTrack, D.Editor.NoInput,
        static_param(0, "vol", 0.8, 0, 4),
        static_param(1, "pan", 0.0, -1, 1),
        D.Editor.DeviceChain(L{
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                osc_id, name .. " Osc", D.Authored.SquareOsc(),
                L{static_param(0, "freq", 110, 1, 20000)},
                L(), nil, nil, nil, true, nil
            )),
            D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                gain_id, name .. " Gain", D.Authored.GainNode(),
                L{static_param(0, "gain", 0.5, 0, 4)},
                L(), nil, nil, nil, true, nil
            ))
        }),
        L(), L(), L(), nil, nil,
        false, false, false, false, false, nil
    )
end

local project = D.Editor.Project(
    "session_sharing", nil, 1,
    D.Editor.Transport(44100, 64, 120, 0, 4, 4, D.Editor.QNone, false, nil),
    L{
        make_track(1, "Track 1", 10, 11),
        make_track(2, "Track 2", 20, 21),
    },
    L(),
    D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
    D.Authored.AssetBank(L(), L(), L(), L(), L())
)

print("1. update_project_param preserves untouched subtrees")
do
    local old = project
    local old_track1 = old.tracks[1]
    local old_track2 = old.tracks[2]
    local old_track2_chain = old_track2.devices

    local new_project = session.update_project_param(old, 10, 0, 220)

    check(new_project ~= old, "project should change")
    check(new_project.tracks[1] ~= old_track1, "edited track should change")
    check(new_project.tracks[2] == old_track2, "untouched sibling track should be shared")
    check(new_project.tracks[2].devices == old_track2_chain, "untouched sibling chain should be shared")
    check(new_project.scenes == old.scenes, "untouched scenes should be shared")
    check(new_project.tempo_map == old.tempo_map, "tempo map should be shared")
    check(new_project.assets == old.assets, "assets should be shared")
    print("  PASS")
end

print("2. update_project_param same value is a no-op")
do
    local changed = session.update_project_param(project, 10, 0, 220)
    local unchanged = session.update_project_param(changed, 10, 0, 220)

    check(unchanged == changed, "same-value param set should preserve project identity")
    print("  PASS")
end

print("3. update_project_track_volume preserves device structure")
do
    local old = project
    local old_track1 = old.tracks[1]
    local old_track2 = old.tracks[2]

    local new_project = session.update_project_track_volume(old, 1, 0.4)

    check(new_project ~= old, "project should change")
    check(new_project.tracks[1] ~= old_track1, "edited track should change")
    check(new_project.tracks[1].devices == old_track1.devices, "track devices should be shared on volume edit")
    check(new_project.tracks[2] == old_track2, "untouched sibling track should be shared")
    check(new_project.tracks[2].devices == old_track2.devices, "untouched sibling chain should be shared")
    print("  PASS")
end

print("")
print(string.format("Session sharing: %d pass, %d fail (%d total)", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
