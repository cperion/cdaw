-- app/bootstrap.t
-- App-level bootstrap data and initial View construction.

local D = require("daw-unified")

local E = D.Editor
local V = D.View

local C = require("impl/view/_support/common")

local M = {}

function M.bootstrap_root()
    local list = C.list

    local project_ref = V.ProjectRef
    local track_1 = V.TrackRef(1)
    local track_2 = V.TrackRef(2)
    local track_3 = V.TrackRef(3)
    local scene_301 = V.SceneRef(301)
    local scene_302 = V.SceneRef(302)
    local scene_303 = V.SceneRef(303)
    local clip_201 = V.ClipRef(201)
    local clip_202 = V.ClipRef(202)
    local clip_203 = V.ClipRef(203)
    local clip_204 = V.ClipRef(204)
    local clip_205 = V.ClipRef(205)
    local dev_101 = V.DeviceRef(101)
    local dev_102 = V.DeviceRef(102)
    local dev_103 = V.DeviceRef(103)
    local send_11 = V.SendRef(1, 1)
    local send_21 = V.SendRef(2, 1)

    local function track_header(track_ref, role)
        local role_key = "track"
        if role.kind == "ArrangementHeaderRole" then
            role_key = "arrangement"
        elseif role.kind == "LauncherHeaderRole" then
            role_key = "launcher"
        elseif role.kind == "MixerHeaderRole" then
            role_key = "mixer"
        end

        return V.TrackHeaderView(
            track_ref,
            role,
            V.Identity("track_header_" .. role_key, V.IdentitySemantic(track_ref)),
            list(),
            list(
                V.TrackHeaderCommand(
                    role_key .. ".track." .. tostring(track_ref.track_id) .. ".select",
                    V.THCCSelectTrack,
                    track_ref,
                    nil,
                    nil,
                    nil)
            )
        )
    end

    local function track_param(track_ref, param_id)
        return V.ParamRef(E.TrackOwner(track_ref.track_id), param_id)
    end

    local function send_param(send_ref, param_id)
        return V.ParamRef(E.SendOwner(send_ref.track_id, send_ref.send_id), param_id)
    end

    local transport = V.TransportBar(
        true,
        true,
        true,
        true,
        V.Identity("transport", V.IdentitySemantic(project_ref)),
        list(),
        list(
            V.TransportCommand("transport.play", V.TCCPlay, nil, nil, nil),
            V.TransportCommand("transport.stop", V.TCCStop, nil, nil, nil),
            V.TransportCommand("transport.record", V.TCCToggleRecord, nil, nil, true),
            V.TransportCommand("transport.loop", V.TCCToggleLoop, nil, nil, true)
        )
    )

    local function lane(track_ref, clip_ref)
        return V.ArrangementLane(
            track_ref,
            V.Identity("arrangement_lane", V.IdentitySemantic(track_ref)),
            V.ArrangementLaneHeaderView(
                track_ref,
                V.Identity("arrangement_lane_header", V.IdentitySemantic(track_ref)),
                track_header(track_ref, V.ArrangementHeaderRole),
                list(),
                list()
            ),
            V.ArrangementLaneBodyView(
                track_ref,
                V.Identity("arrangement_lane_body", V.IdentitySemantic(track_ref)),
                list(),
                list(),
                clip_ref and list(
                    V.ArrangementClipView(
                        track_ref,
                        clip_ref,
                        V.Identity("arrangement_clip", V.IdentitySemantic(clip_ref)),
                        list(),
                        list(
                            V.ArrangementCommand(
                                "arrangement.clip." .. tostring(clip_ref.clip_id) .. ".select",
                                V.ACCSelectClip,
                                track_ref,
                                clip_ref,
                                nil,
                                nil,
                                nil,
                                nil,
                                nil,
                                nil,
                                nil)
                        )
                    )
                ) or list(),
                list()
            )
        )
    end

    local arrangement = V.ArrangementView(
        list(track_1, track_2, track_3),
        V.Identity("arrangement", V.IdentitySemantic(project_ref)),
        list(),
        list(),
        V.ArrangementRuler(1.0, 9.0, V.Identity("arrangement_ruler", V.IdentitySemantic(project_ref)), list(), list()),
        V.ArrangementGridView(1.0, 9.0, V.Identity("arrangement_grid", V.IdentitySemantic(project_ref)), list()),
        nil,
        nil,
        nil,
        list(
            lane(track_1, clip_201),
            lane(track_2, clip_202),
            lane(track_3, clip_203)
        )
    )

    local function launcher_scene(scene_ref)
        return V.LauncherSceneView(
            scene_ref,
            V.Identity("launcher_scene", V.IdentitySemantic(scene_ref)),
            list(),
            list(
                V.LauncherCommand(
                    "launcher.scene." .. tostring(scene_ref.scene_id) .. ".launch",
                    V.LCCLaunchScene,
                    nil,
                    scene_ref,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil),
                V.LauncherCommand(
                    "launcher.scene." .. tostring(scene_ref.scene_id) .. ".select",
                    V.LCCSelectScene,
                    nil,
                    scene_ref,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil)
            )
        )
    end

    local function launcher_slot(track_ref, scene_ref, slot_index, content_kind, clip_ref)
        local slot_ref = V.SlotRef(track_ref.track_id, slot_index)
        return V.LauncherSlotView(
            track_ref,
            scene_ref,
            slot_ref,
            content_kind,
            clip_ref,
            V.Identity("launcher_slot", V.IdentitySemantic(slot_ref)),
            list(),
            list(
                V.LauncherCommand(
                    "launcher.slot." .. tostring(track_ref.track_id) .. "." .. tostring(slot_index) .. ".launch",
                    V.LCCLaunchSlot,
                    track_ref,
                    scene_ref,
                    slot_ref,
                    clip_ref,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil),
                V.LauncherCommand(
                    "launcher.slot." .. tostring(track_ref.track_id) .. "." .. tostring(slot_index) .. ".select",
                    V.LCCSelectSlot,
                    track_ref,
                    scene_ref,
                    slot_ref,
                    clip_ref,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil)
            )
        )
    end

    local function launcher_column(track_ref, slots)
        return V.LauncherColumn(
            track_ref,
            V.Identity("launcher_column", V.IdentitySemantic(track_ref)),
            track_header(track_ref, V.LauncherHeaderRole),
            list(),
            list(),
            slots
        )
    end

    local launcher = V.LauncherView(
        list(track_1, track_2, track_3),
        list(scene_301, scene_302, scene_303),
        V.Identity("launcher", V.IdentitySemantic(project_ref)),
        list(),
        list(),
        list(
            launcher_scene(scene_301),
            launcher_scene(scene_302),
            launcher_scene(scene_303)
        ),
        V.LauncherStopRowView(
            V.Identity("launcher_stop_row", V.IdentitySemantic(project_ref)),
            list(),
            list(),
            list(
                V.LauncherStopCellView(track_1, V.Identity("launcher_stop_cell", V.IdentityKey("track_1")), list(), list(
                    V.LauncherCommand("launcher.track.1.stop", V.LCCStopTrack, track_1, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                )),
                V.LauncherStopCellView(track_2, V.Identity("launcher_stop_cell", V.IdentityKey("track_2")), list(), list(
                    V.LauncherCommand("launcher.track.2.stop", V.LCCStopTrack, track_2, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                )),
                V.LauncherStopCellView(track_3, V.Identity("launcher_stop_cell", V.IdentityKey("track_3")), list(), list(
                    V.LauncherCommand("launcher.track.3.stop", V.LCCStopTrack, track_3, nil, nil, nil, nil, nil, nil, nil, nil, nil)
                ))
            )
        ),
        list(
            launcher_column(track_1, list(
                launcher_slot(track_1, scene_301, 1, V.LauncherClipSlot, clip_201),
                launcher_slot(track_1, scene_302, 2, V.LauncherEmptySlot, nil),
                launcher_slot(track_1, scene_303, 3, V.LauncherClipSlot, clip_204)
            )),
            launcher_column(track_2, list(
                launcher_slot(track_2, scene_301, 1, V.LauncherClipSlot, clip_202),
                launcher_slot(track_2, scene_302, 2, V.LauncherStopSlot, nil),
                launcher_slot(track_2, scene_303, 3, V.LauncherEmptySlot, nil)
            )),
            launcher_column(track_3, list(
                launcher_slot(track_3, scene_301, 1, V.LauncherEmptySlot, nil),
                launcher_slot(track_3, scene_302, 2, V.LauncherClipSlot, clip_203),
                launcher_slot(track_3, scene_303, 3, V.LauncherClipSlot, clip_205)
            ))
        )
    )

    local function mixer_send(track_ref, send_ref)
        return V.MixerSendView(
            track_ref,
            send_ref,
            send_param(send_ref, 1),
            V.Identity("mixer_send", V.IdentitySemantic(send_ref)),
            list(),
            list(
                V.MixerCommand(
                    "mixer.send." .. tostring(send_ref.track_id) .. "." .. tostring(send_ref.send_id) .. ".level",
                    V.MCCSetSendLevel,
                    track_ref,
                    nil,
                    send_ref,
                    send_param(send_ref, 1),
                    nil,
                    nil,
                    0.0,
                    nil)
            )
        )
    end

    local function mixer_strip(track_ref, sends)
        local volume_param = track_param(track_ref, 1)
        local pan_param = track_param(track_ref, 2)
        return V.MixerStrip(
            track_ref,
            V.Identity("mixer_strip", V.IdentitySemantic(track_ref)),
            track_header(track_ref, V.MixerHeaderRole),
            V.MixerMeterView(track_ref, V.Identity("mixer_meter", V.IdentitySemantic(track_ref)), list()),
            V.MixerPanView(
                track_ref,
                pan_param,
                V.Identity("mixer_pan", V.IdentitySemantic(pan_param)),
                list(),
                list(
                    V.MixerCommand("mixer.track." .. tostring(track_ref.track_id) .. ".pan", V.MCCSetTrackPan, track_ref, nil, nil, pan_param, nil, nil, 0.0, nil)
                )
            ),
            V.MixerVolumeView(
                track_ref,
                volume_param,
                V.Identity("mixer_volume", V.IdentitySemantic(volume_param)),
                list(),
                list(
                    V.MixerCommand("mixer.track." .. tostring(track_ref.track_id) .. ".volume", V.MCCSetTrackVolume, track_ref, nil, nil, volume_param, nil, nil, 0.0, nil)
                )
            ),
            sends,
            list(),
            list(
                V.MixerCommand("mixer.track." .. tostring(track_ref.track_id) .. ".add_send", V.MCCAddSend, track_ref, nil, nil, nil, nil, nil, nil, nil)
            )
        )
    end

    local mixer = V.MixerView(
        list(track_1, track_2, track_3),
        V.Identity("mixer", V.IdentitySemantic(project_ref)),
        list(),
        list(),
        list(
            mixer_strip(track_1, list(mixer_send(track_1, send_11))),
            mixer_strip(track_2, list(mixer_send(track_2, send_21))),
            mixer_strip(track_3, list())
        )
    )

    local note_1 = V.NoteRef(203, 1)
    local note_2 = V.NoteRef(203, 2)
    local note_3 = V.NoteRef(203, 3)
    local note_4 = V.NoteRef(203, 4)

    local function make_piano_roll(prefix, opts)
        opts = opts or {}
        local lowest_pitch = opts.lowest_pitch or 48
        local highest_pitch = opts.highest_pitch or 72
        local visible_start = opts.visible_start or 1.0
        local visible_end = opts.visible_end or 9.0
        local note_specs = opts.note_specs or {
            { note_1, 67, 1.0, 2.0, 112, false },
            { note_2, 64, 2.0, 3.0, 98, true },
            { note_3, 60, 3.0, 4.5, 86, false },
            { note_4, 72, 5.0, 6.0, 120, false },
        }
        local include_velocity = opts.include_velocity ~= false

        local function key_space(name)
            return prefix .. "_" .. name
        end

        local function note_view(note_ref, pitch, start_beats, end_beats, velocity, selected)
            return V.PianoNoteView(
                clip_203,
                note_ref,
                pitch,
                start_beats,
                end_beats,
                velocity,
                false,
                selected,
                V.Identity(key_space("piano_note"), V.IdentitySemantic(note_ref)),
                list(),
                list(
                    V.PianoRollCommand(
                        prefix .. ".piano.note." .. tostring(note_ref.note_id) .. ".select",
                        V.PRCCSelectNotes,
                        clip_203,
                        list(note_ref),
                        nil,
                        nil,
                        pitch,
                        start_beats,
                        end_beats,
                        nil,
                        nil,
                        nil,
                        nil,
                        nil)
                )
            )
        end

        local velocity_lane = nil
        if include_velocity then
            velocity_lane = V.PianoVelocityLaneView(
                clip_203,
                V.Identity(key_space("piano_velocity"), V.IdentitySemantic(clip_203)),
                list(),
                list(),
                list(
                    V.PianoVelocityBarView(clip_203, note_1, 112, false, V.Identity(key_space("velocity_bar"), V.IdentitySemantic(note_1)), list(), list(
                        V.PianoRollCommand(prefix .. ".piano.velocity.1", V.PRCCSetVelocity, clip_203, list(note_1), nil, nil, nil, nil, nil, nil, nil, 112, nil, nil)
                    )),
                    V.PianoVelocityBarView(clip_203, note_2, 98, true, V.Identity(key_space("velocity_bar"), V.IdentitySemantic(note_2)), list(), list(
                        V.PianoRollCommand(prefix .. ".piano.velocity.2", V.PRCCSetVelocity, clip_203, list(note_2), nil, nil, nil, nil, nil, nil, nil, 98, nil, nil)
                    )),
                    V.PianoVelocityBarView(clip_203, note_3, 86, false, V.Identity(key_space("velocity_bar"), V.IdentitySemantic(note_3)), list(), list(
                        V.PianoRollCommand(prefix .. ".piano.velocity.3", V.PRCCSetVelocity, clip_203, list(note_3), nil, nil, nil, nil, nil, nil, nil, 86, nil, nil)
                    )),
                    V.PianoVelocityBarView(clip_203, note_4, 120, false, V.Identity(key_space("velocity_bar"), V.IdentitySemantic(note_4)), list(), list(
                        V.PianoRollCommand(prefix .. ".piano.velocity.4", V.PRCCSetVelocity, clip_203, list(note_4), nil, nil, nil, nil, nil, nil, nil, 120, nil, nil)
                    ))
                )
            )
        end

        local keys = {}
        for pitch = lowest_pitch, highest_pitch do
            local mod = pitch % 12
            local is_black = mod == 1 or mod == 3 or mod == 6 or mod == 8 or mod == 10
            C.push(keys, V.PianoKeyView(
                pitch,
                is_black,
                V.Identity(key_space("piano_key"), V.IdentityKey(prefix .. "_key_" .. tostring(pitch))),
                list(),
                list()
            ))
        end
        keys = list(unpack(keys))

        return V.PianoRollView(
            clip_203,
            V.Identity(key_space("piano_roll"), V.IdentitySemantic(clip_203)),
            list(),
            list(),
            V.PianoKeyboardView(lowest_pitch, highest_pitch, V.Identity(key_space("piano_keyboard"), V.IdentitySemantic(clip_203)), list(), list(), keys),
            V.PianoGridView(visible_start, visible_end, lowest_pitch, highest_pitch, V.Identity(key_space("piano_grid"), V.IdentitySemantic(clip_203)), list()),
            nil,
            nil,
            nil,
            list(
                note_view(note_specs[1][1], note_specs[1][2], note_specs[1][3], note_specs[1][4], note_specs[1][5], note_specs[1][6]),
                note_view(note_specs[2][1], note_specs[2][2], note_specs[2][3], note_specs[2][4], note_specs[2][5], note_specs[2][6]),
                note_view(note_specs[3][1], note_specs[3][2], note_specs[3][3], note_specs[3][4], note_specs[3][5], note_specs[3][6]),
                note_view(note_specs[4][1], note_specs[4][2], note_specs[4][3], note_specs[4][4], note_specs[4][5], note_specs[4][6])
            ),
            velocity_lane,
            list()
        )
    end

    local piano_roll_detail = make_piano_roll("detail", {
        lowest_pitch = 54,
        highest_pitch = 72,
        visible_start = 1.0,
        visible_end = 5.0,
        include_velocity = true,
        note_specs = {
            { note_1, 67, 1.0, 1.5, 112, false },
            { note_2, 64, 2.0, 2.6, 98, true },
            { note_3, 60, 3.0, 4.0, 86, false },
            { note_4, 72, 3.0, 3.7, 120, false },
        },
    })
    local browser = V.BrowserView(
        "devices",
        "Everything",
        V.Identity("browser", V.IdentityKey("right")),
        list(),
        list(),
        list(
            V.BrowserSourceView("devices", "Everything", true, V.Identity("browser_source", V.IdentityKey("devices")), list(), list(
                V.BrowserCommand("browser.source.devices", V.BCCSelectSource, "devices", nil, nil, nil, nil, nil)
            ))
        ),
        V.BrowserQueryView("Search", V.Identity("browser_query", V.IdentityKey("query")), list(), list()),
        list(
            V.BrowserSection(
                "fav_devices",
                "Categories",
                true,
                V.Identity("browser_section", V.IdentityKey("fav_devices")),
                list(),
                list(),
                list(
                    V.BrowserItem("amp", "Amp", nil, V.BrowserDeviceItem, false, false, nil, V.Identity("browser_item", V.IdentityKey("amp")), list(), list(
                        V.BrowserCommand("browser.item.amp", V.BCCCommitItem, nil, "fav_devices", "amp", nil, nil, nil)
                    )),
                    V.BrowserItem("polysynth", "Arpeggiator", nil, V.BrowserDeviceItem, false, false, dev_101, V.Identity("browser_item", V.IdentityKey("polysynth")), list(), list(
                        V.BrowserCommand("browser.item.polysynth", V.BCCCommitItem, nil, "fav_devices", "polysynth", dev_101, nil, nil)
                    )),
                    V.BrowserItem("delay_plus", "Audio Receiver", nil, V.BrowserDeviceItem, false, false, dev_103, V.Identity("browser_item", V.IdentityKey("delay_plus")), list(), list(
                        V.BrowserCommand("browser.item.delay_plus", V.BCCCommitItem, nil, "fav_devices", "delay_plus", dev_103, nil, nil)
                    )),
                    V.BrowserItem("eq5", "Compressor", nil, V.BrowserDeviceItem, false, false, dev_102, V.Identity("browser_item", V.IdentityKey("eq5")), list(), list(
                        V.BrowserCommand("browser.item.eq5", V.BCCCommitItem, nil, "fav_devices", "eq5", dev_102, nil, nil)
                    ))
                )
            )
        )
    )

    local inspector = V.InspectorView(
        V.SelectedTrack(track_1),
        V.Identity("inspector", V.IdentityKey("left")),
        list(),
        list(),
        list(
            V.InspectorTabView(
                V.TrackTab(track_1),
                "Track",
                V.Identity("inspector_tab", V.IdentityKey("track")),
                list(),
                list(
                    V.InspectorCommand("inspector.tab.track", V.ICCSelectTab, V.SelectedTrack(track_1), "Track", nil, nil, track_1, nil, nil, nil)
                ),
                list(
                    V.InspectorSectionView(
                        "overview",
                        "Hybrid Track",
                        true,
                        V.Identity("inspector_section", V.IdentityKey("overview")),
                        list(),
                        list(),
                        list(
                            V.InspectorFieldView("name", "Name", V.TextField, V.Identity("inspector_field", V.IdentityKey("name")), list(), list()),
                            V.InspectorFieldView("channel", "Channel", V.EnumField, V.Identity("inspector_field", V.IdentityKey("channel")), list(), list()),
                            V.InspectorFieldView("bend", "P. Bend", V.ActionField, V.Identity("inspector_field", V.IdentityKey("bend")), list(), list(
                                V.InspectorCommand("inspector.field.bend", V.ICCSetValue, V.SelectedTrack(track_1), "Track", "overview", "bend", track_1, nil, "Expr.", nil)
                            ))
                        )
                    ),
                    V.InspectorSectionView(
                        "routing",
                        "Routing",
                        true,
                        V.Identity("inspector_section", V.IdentityKey("routing")),
                        list(),
                        list(),
                        list(
                            V.InspectorFieldView("input", "Input", V.ActionField, V.Identity("inspector_field", V.IdentityKey("input")), list(), list(
                                V.InspectorCommand("inspector.field.input", V.ICCSetValue, V.SelectedTrack(track_1), "Track", "routing", "input", track_1, nil, "All ins", nil)
                            )),
                            V.InspectorFieldView("output", "Output", V.ActionField, V.Identity("inspector_field", V.IdentityKey("output")), list(), list(
                                V.InspectorCommand("inspector.field.output", V.ICCSetValue, V.SelectedTrack(track_1), "Track", "routing", "output", track_1, nil, "Master", nil)
                            ))
                        )
                    )
                )
            )
        )
    )

    local active_surface = V.ArrangementSurface
    local selection = V.SelectedTrack(track_1)

    local shell = V.Shell(
        transport,
        V.HybridMain(arrangement, launcher, mixer, V.PianoRollDetail(piano_roll_detail)),
        list(
            V.InspectorSidebar(inspector),
            V.BrowserSidebar(browser)
        ),
        V.StatusBar(
            "",
            "Bitwig-like shell grammar: Arrange / Mix / Edit",
            "Use ARRANGE / MIX / EDIT buttons to switch views",
            V.Identity("status", V.IdentitySemantic(project_ref)),
            list()
        )
    )

    return V.Root(
        shell,
        V.Focus(selection, active_surface),
        list()
    )
end

return M
