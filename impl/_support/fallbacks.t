-- impl/_support/fallbacks.t
-- Shared fallback constructors for every target phase.
--
-- Each function returns the smallest valid instance of its target type,
-- preserving identity (ids, names) from arguments when provided.
-- These are used by stub methods and by real methods when a child fails.

local D = require("daw-unified")
local List = require("terralist")

local F = {}

-- Shorthand: create a proper ASDL-compatible list from a plain table or varargs.
-- Every list field in an ASDL constructor requires a terralist.List, not a plain {}.
function F.L(t)
    if t == nil then return List() end
    if List:isclassof(t) then return t end
    local l = List()
    for i = 1, #t do l:insert(t[i]) end
    return l
end

local L = F.L   -- local alias for brevity below

-- ════════════════════════════════════════════════════════════
-- Enum / singleton mapping helpers
-- ════════════════════════════════════════════════════════════

-- Map Editor.Quantize → Authored.Quantize (same singleton names)
local quantize_names = {
    "QNone", "Q1_64", "Q1_32", "Q1_16", "Q1_8",
    "Q1_4", "Q1_2", "Q1Bar", "Q2Bars", "Q4Bars",
}
local editor_to_authored_quantize = {}
for _, name in ipairs(quantize_names) do
    if D.Editor[name] and D.Authored[name] then
        editor_to_authored_quantize[D.Editor[name]] = D.Authored[name]
    end
end
function F.quantize_e2a(eq)
    if eq == nil then return D.Authored.QNone end
    return editor_to_authored_quantize[eq]
        or (eq.kind and D.Authored[eq.kind])
        or D.Authored.QNone
end

-- Map Editor.InterpMode → Authored.InterpMode
function F.interp_e2a(ei)
    if ei == nil then return D.Authored.Linear end
    if ei.kind == "Smoothstep" then return D.Authored.Smoothstep end
    if ei.kind == "Hold" then return D.Authored.Hold end
    return D.Authored.Linear
end

-- Map Editor.CombineMode → Authored.CombineMode
function F.combine_e2a(ec)
    if ec == nil then return D.Authored.Replace end
    local name = ec.kind
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.Replace
end

-- Map Editor.Smoothing → Authored.Smoothing
function F.smoothing_e2a(es)
    if es == nil then return D.Authored.NoSmoothing end
    if es.kind == "Lag" then return D.Authored.Lag(es.ms) end
    return D.Authored.NoSmoothing
end

-- Map Editor.FadeCurve → Authored.FadeCurve
function F.fade_curve_e2a(fc)
    if fc == nil then return D.Authored.LinearFade end
    local name = fc.kind
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.LinearFade
end

-- Map Editor.TrackInput → Authored.TrackInput
function F.track_input_e2a(ei)
    if ei == nil then return D.Authored.NoInput end
    if ei.kind == "AudioInput" then return D.Authored.AudioInput(ei.device_id, ei.channel) end
    if ei.kind == "MIDIInput" then return D.Authored.MIDIInput(ei.device_id, ei.channel) end
    if ei.kind == "TrackInputTap" then return D.Authored.TrackInputTap(ei.track_id, ei.post_fader) end
    return D.Authored.NoInput
end

-- Map Editor.SignalDomain / GridDomain → Authored.SignalDomain
function F.domain_e2a(ed)
    if ed == nil then return D.Authored.AudioDomain end
    local name = ed.kind
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.AudioDomain
end

-- Map Editor.PortHint → Authored.PortHint
function F.port_hint_e2a(h)
    if h == nil then return D.Authored.AudioHint end
    local name = h.kind
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.AudioHint
end

-- Map Editor.LaunchMode → Authored.LaunchMode
function F.launch_mode_e2a(m)
    if m == nil then return D.Authored.Trigger end
    local name = m.kind
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.Trigger
end

-- Map Editor.FollowKind → Authored.FollowKind
function F.follow_kind_e2a(fk)
    if fk == nil then return D.Authored.FNone end
    local name = fk.kind
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.FNone
end

-- Map Editor.SlotContent → Authored.SlotContent
function F.slot_content_e2a(sc)
    if sc == nil then return D.Authored.EmptySlot end
    if sc.kind == "ClipSlot" then return D.Authored.ClipSlot(sc.clip_id) end
    if sc.kind == "StopSlot" then return D.Authored.StopSlot end
    return D.Authored.EmptySlot
end

-- Map Editor.NoteExprKind → Authored.NoteExprKind
function F.note_expr_kind_e2a(ek)
    if ek == nil then return D.Authored.NotePressureExpr end
    local name = ek.kind
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.NotePressureExpr
end

-- Map Editor.GridSourceKind → Authored.PreCordKind
local grid_source_to_precord = {
    DevicePhase   = "PCDevicePhase",
    GlobalPhase   = "PCGlobalPhase",
    NotePitch     = "PCNotePitch",
    NoteGate      = "PCNoteGate",
    NoteVelocity  = "PCNoteVelocity",
    NotePressure  = "PCNotePressure",
    NoteTimbre    = "PCNoteTimbre",
    NoteGain      = "PCNoteGain",
    AudioIn       = "PCAudioIn",
    AudioInL      = "PCAudioInL",
    AudioInR      = "PCAudioInR",
    PreviousNote  = "PCPreviousNote",
}
function F.grid_source_to_precord_kind(gsk)
    if gsk == nil then return D.Authored.PCAudioIn end
    local name = grid_source_to_precord[gsk.kind]
    if name and D.Authored[name] then return D.Authored[name] end
    return D.Authored.PCAudioIn
end


-- ════════════════════════════════════════════════════════════
-- AUTHORED fallbacks
-- ════════════════════════════════════════════════════════════

function F.authored_param(id, name, default, min, max)
    return D.Authored.Param(
        id or 0,
        name or "stub",
        default or 0,
        min or 0,
        max or (max == nil and 1 or max),
        D.Authored.StaticValue(default or 0),
        D.Authored.Replace,
        D.Authored.NoSmoothing
    )
end

function F.authored_transport()
    return D.Authored.Transport(
        44100, 512, 120, 0, 4, 4,
        D.Authored.QNone, false, nil
    )
end

function F.authored_tempo_map()
    return D.Authored.TempoMap(L(), L())
end

function F.authored_graph(id, layout, domain)
    return D.Authored.Graph(
        id or 0,
        L(), L(),         -- inputs, outputs
        L(), L(), L(),    -- nodes, wires, pre_cords
        layout or D.Authored.Serial,
        domain or D.Authored.AudioDomain
    )
end

function F.authored_node(id, name, kind)
    return D.Authored.Node(
        id or 0,
        name or "stub",
        kind or D.Authored.GainNode(),
        L(), L(), L(),  -- params, inputs, outputs
        L(), L(),        -- mod_slots, child_graphs
        true             -- enabled
    )
end

function F.authored_mod_slot()
    local mod_node = F.authored_node(0, "stub_modulator", D.Authored.LFOMod(D.Authored.Sine))
    return D.Authored.ModSlot(mod_node, L(), false)
end

function F.authored_clip(id)
    return D.Authored.Clip(
        id or 0,
        D.Authored.AudioContent(0),
        0, 0, 0, 0,    -- start, duration, offset, lane
        true,           -- muted (silent fallback)
        F.authored_param(0, "gain", 1, 0, 4)
    )
end

function F.authored_note_asset(id)
    return D.Authored.NoteAsset(id or 0, L(), L(), 0, 0)
end

function F.authored_slot(slot_index)
    return D.Authored.Slot(
        slot_index or 0,
        D.Authored.EmptySlot,
        D.Authored.LaunchBehavior(D.Authored.Trigger, nil, false, false, nil),
        true
    )
end

function F.authored_scene(id, name)
    return D.Authored.Scene(id or 0, name or "stub", L(), nil, nil)
end

function F.authored_send(id, target_track_id)
    return D.Authored.Send(
        id or 0,
        target_track_id or 0,
        F.authored_param(0, "send_level", 0, 0, 1),
        false, true
    )
end

function F.authored_track(id, name, channels)
    return D.Authored.Track(
        id or 0,
        name or "stub",
        channels or 2,
        D.Authored.NoInput,
        F.authored_param(0, "volume", 1, 0, 4),
        F.authored_param(1, "pan", 0, -1, 1),
        F.authored_graph(0),
        L(), L(), L(),      -- clips, launcher_slots, sends
        nil, nil,            -- output_track_id, group_track_id
        false, false,        -- muted, soloed
        false, false,        -- armed, monitor_input
        false                -- phase_invert
    )
end

function F.authored_asset_bank()
    return D.Authored.AssetBank(L(), L(), L(), L(), L())
end

function F.authored_project(name, author, format_version)
    return D.Authored.Project(
        name or "stub",
        author,
        format_version or 1,
        F.authored_transport(),
        L(),  -- tracks
        L(),  -- scenes
        F.authored_tempo_map(),
        F.authored_asset_bank()
    )
end


-- ════════════════════════════════════════════════════════════
-- RESOLVED fallbacks
-- ════════════════════════════════════════════════════════════

function F.resolved_transport()
    return D.Resolved.Transport(
        44100, 512, 120, 0, 4, 4,
        0,           -- launch_quant_code
        false,       -- looping
        0, 0         -- loop ticks
    )
end

function F.resolved_tempo_map()
    return D.Resolved.TempoMap(L())
end

function F.resolved_track(id, name, channels)
    return D.Resolved.Track(
        id or 0,
        name or "stub",
        channels or 2,
        0, 0, 0,          -- input_kind_code, input_arg0, input_arg1
        0, 1,             -- volume_param_index, pan_param_index
        0,                -- device_graph_id
        0, 0,             -- first_clip, clip_count
        0, 0,             -- first_slot, slot_count
        0, 0,             -- first_send, send_count
        nil, nil,         -- output_track_id, group_track_id
        false, false,     -- muted, soloed
        false, false,     -- armed, monitor_input
        false             -- phase_invert
    )
end

function F.resolved_track_slice(id, name, channels)
    return D.Resolved.TrackSlice(
        F.resolved_track(id, name, channels),
        L{F.resolved_param(0, "volume"), F.resolved_param(1, "pan")},
        L(),
        L(),
        L(),
        L(),
        F.resolved_graph_slice(0)
    )
end

function F.resolved_send(id, target_track_id)
    return D.Resolved.Send(id or 0, target_track_id or 0, 0, false, true)
end

function F.resolved_clip(id)
    return D.Resolved.Clip(
        id or 0,
        0, 0,                -- content_kind, asset_id
        0, 0, 0, 0,         -- start_tick, duration_tick, source_offset_tick, lane
        true,                -- muted (silent)
        0,                   -- gain_param_id
        0, 0,                -- fade_in_tick, fade_in_curve_code
        0, 0                 -- fade_out_tick, fade_out_curve_code
    )
end

function F.resolved_slot(slot_index)
    return D.Resolved.Slot(
        slot_index or 0,
        0, 0,              -- slot_kind=empty, clip_id
        0, 0,              -- launch_mode_code, quant_code
        false, false,      -- legato, retrigger
        0, 0, 0,           -- follow_kind_code, weights
        nil,               -- follow_target_scene_id
        true               -- enabled
    )
end

function F.resolved_scene(id, name)
    return D.Resolved.Scene(id or 0, name or "stub", L(), 0, nil)
end

function F.resolved_graph(id)
    return D.Resolved.Graph(
        id or 0,
        0, 0,              -- layout_code=serial, domain_code=audio
        0, 0,              -- first_input, input_count
        0, 0,              -- first_output, output_count
        L(), L(),          -- node_ids, wire_ids
        0, 0,              -- first_precord, precord_count
        0, 0, 0, 0        -- arg0..arg3
    )
end

function F.resolved_graph_slice(id)
    return D.Resolved.GraphSlice(
        L{F.resolved_graph(id)},
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L()
    )
end

function F.resolved_node(id)
    return D.Resolved.Node(
        id or 0,
        0,                 -- node_kind_code (GainNode)
        0, 0,              -- first_param, param_count
        0, 0,              -- first_input, input_count
        0, 0,              -- first_output, output_count
        0, 0,              -- first_mod_slot, mod_slot_count
        0, 0,              -- first_child_graph_ref, child_graph_ref_count
        true,              -- enabled
        nil,               -- plugin_handle
        0, 0, 0, 0        -- arg0..arg3
    )
end

function F.resolved_mod_slot()
    return D.Resolved.ModSlot(
        0, 0,
        0, 0,
        0, 0,
        0, 0, 0, 0,
        false,
        0, 0
    )
end

function F.resolved_mod_route()
    return D.Resolved.ModRoute(0, 0, 0, false, nil, nil)
end

function F.resolved_param(id, name)
    return D.Resolved.Param(
        id or 0,
        0,                 -- node_id
        name or "stub",
        0, 0, 1,           -- default, min, max
        D.Resolved.ParamSourceRef(0, 0, nil),
        0, 0, 0           -- combine_code, smoothing_code, smoothing_ms
    )
end

function F.resolved_node_kind_ref(code)
    return D.Resolved.NodeKindRef(code or 0)
end

function F.resolved_asset_bank()
    return D.Resolved.AssetBank(L(), L(), L(), L(), L())
end

function F.resolved_project()
    return D.Resolved.Project(
        F.resolved_transport(),
        F.resolved_tempo_map(),
        L(),                -- track_slices
        L(),                -- scenes
        F.resolved_asset_bank()
    )
end


-- ════════════════════════════════════════════════════════════
-- CLASSIFIED fallbacks
-- ════════════════════════════════════════════════════════════

function F.classified_binding(rate_class, slot)
    return D.Classified.Binding(rate_class or 0, slot or 0)
end

function F.classified_transport()
    return D.Classified.Transport(
        44100, 512, 120, 0, 4, 4,
        0, false, 0, 0
    )
end

function F.classified_tempo_map()
    return D.Classified.TempoMap(L())
end

function F.classified_track(id, channels)
    return D.Classified.Track(
        id or 0,
        channels or 2,
        0, 0, 0,                      -- input_kind_code, arg0, arg1
        F.classified_binding(0, 0),   -- volume (literal 0)
        F.classified_binding(0, 0),   -- pan (literal 0)
        0,                            -- device_graph_id
        0, 0,                         -- first_clip, clip_count
        0, 0,                         -- first_slot, slot_count
        0, 0,                         -- first_send, send_count
        nil, nil,                     -- output_track_id, group_track_id
        false, false,                 -- muted_structural, solo_structural
        false, false                  -- armed, monitor_input
    )
end

function F.classified_graph(id)
    return D.Classified.Graph(
        id or 0,
        0, 0,              -- layout_code, domain_code
        0, 0,              -- first_input, input_count
        0, 0,              -- first_output, output_count
        L(),               -- node_ids
        0, 0,              -- first_wire, wire_count
        0, 0,              -- first_feedback, feedback_count
        0, 0               -- first_signal, signal_count
    )
end

function F.classified_node(id)
    return D.Classified.Node(
        id or 0,
        0,                 -- node_kind_code
        0, 0,              -- first_param, param_count
        0, 0, 0,           -- signal_offset, state_offset, state_size
        0, 0,              -- first_mod_slot, mod_slot_count
        0, 0,              -- first_child_graph_ref, child_graph_ref_count
        true,              -- enabled
        0,                 -- runtime_state_slot
        0, 0, 0, 0        -- arg0..arg3
    )
end

function F.classified_param(id, node_id)
    return D.Classified.Param(
        id or 0,
        node_id or 0,
        0, 0, 1,                      -- default, min, max
        F.classified_binding(0, 0),    -- base_value
        0,                             -- combine_code
        0, 0,                          -- smoothing_code, smoothing_ms
        0, 0,                          -- first_modulation, modulation_count
        0                              -- runtime_state_slot
    )
end

function F.classified_mod_slot()
    return D.Classified.ModSlot(
        0, 0,
        0, 0,
        0, 0,
        0, 0, 0, 0,
        false,
        0, 0,
        0, 0,
        F.classified_binding(0, 0)
    )
end

function F.classified_mod_route()
    return D.Classified.ModRoute(
        0, 0,                          -- mod_slot_index, target_param_id
        F.classified_binding(0, 0),    -- depth
        false,                         -- bipolar
        nil                            -- scale_binding_slot
    )
end

function F.classified_graph_slice(id)
    return D.Classified.GraphSlice(
        L{F.classified_graph(id)},
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        0,
        0
    )
end

function F.classified_track_slice(id, channels)
    return D.Classified.TrackSlice(
        F.classified_track(id, channels),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        F.classified_graph_slice(0)
    )
end

function F.classified_project()
    return D.Classified.Project(
        F.classified_transport(),
        F.classified_tempo_map(),
        L(),                -- track_slices
        L()                 -- scenes
    )
end


-- ════════════════════════════════════════════════════════════
-- SCHEDULED fallbacks
-- ════════════════════════════════════════════════════════════

function F.scheduled_binding(rate_class, slot)
    return D.Scheduled.Binding(rate_class or 0, slot or 0)
end

function F.scheduled_transport()
    return D.Scheduled.Transport(
        44100, 512, 120, 0, 4, 4,
        0, false, 0, 0
    )
end

function F.scheduled_tempo_map()
    return D.Scheduled.TempoMap(L())
end

function F.scheduled_track_plan(track_id)
    return D.Scheduled.TrackPlan(
        track_id or 0,
        F.scheduled_binding(0, 0),  -- volume
        F.scheduled_binding(0, 0),  -- pan
        0, 0, 0,                    -- input_kind_code, arg0, arg1
        0, 0,                       -- first_step, step_count
        0, 0, 0,                    -- work_buf, aux_buf, mix_in_buf
        0, 0,                       -- out_left, out_right
        false                       -- is_master
    )
end

function F.scheduled_graph_plan(graph_id)
    return D.Scheduled.GraphPlan(
        graph_id or 0,
        0, 0,              -- first_node_job, node_job_count
        0, 0,              -- in_buf, out_buf
        0, 0               -- first_feedback, feedback_count
    )
end

function F.scheduled_node_job(node_id)
    return D.Scheduled.NodeJob(
        node_id or 0,
        0,                 -- kind_code
        0, 0,              -- in_buf, out_buf
        0, 0,              -- first_param, param_count
        0, 0,              -- state_slot, state_size
        0, 0, 0, 0        -- arg0..arg3
    )
end

function F.scheduled_node_program(node_id)
    return D.Scheduled.NodeProgram(
        F.scheduled_node_job(node_id),
        L(),
        L(),
        L(),
        L(),
        L(),
        F.scheduled_transport(),
        F.scheduled_tempo_map()
    )
end

function F.scheduled_mod_program()
    return D.Scheduled.ModProgram(
        D.Scheduled.ModJob(0, 0, 0, 0, 0, 0, 0, 0, 0, false, 0, 0, 0, 0, 0, F.scheduled_binding(0, 0)),
        L(),
        L(),
        F.scheduled_transport(),
        F.scheduled_tempo_map()
    )
end

function F.scheduled_clip_program()
    return D.Scheduled.ClipProgram(
        D.Scheduled.ClipJob(0, 0, 0, 0, 0, 0, 0, F.scheduled_binding(0, 0), false, 0, 0, 0, 0),
        L(),
        F.scheduled_transport(),
        F.scheduled_tempo_map()
    )
end

function F.scheduled_send_program()
    return D.Scheduled.SendProgram(
        D.Scheduled.SendJob(0, 0, F.scheduled_binding(0, 0), false, false),
        L(),
        F.scheduled_transport(),
        F.scheduled_tempo_map()
    )
end

function F.scheduled_mix_program()
    return D.Scheduled.MixProgram(
        D.Scheduled.MixJob(0, 0, F.scheduled_binding(0, 0)),
        L(),
        F.scheduled_transport(),
        F.scheduled_tempo_map()
    )
end

function F.scheduled_output_program()
    return D.Scheduled.OutputProgram(
        D.Scheduled.OutputJob(0, 0, 0, F.scheduled_binding(0, 0), F.scheduled_binding(0, 0)),
        L(),
        F.scheduled_transport(),
        F.scheduled_tempo_map()
    )
end

function F.scheduled_graph_program(graph_id)
    return D.Scheduled.GraphProgram(
        F.scheduled_transport(),
        F.scheduled_tempo_map(),
        L(),
        F.scheduled_graph_plan(graph_id),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        0,
        0
    )
end

function F.scheduled_track_program(track_id)
    return D.Scheduled.TrackProgram(
        F.scheduled_transport(),
        F.scheduled_tempo_map(),
        L(),
        F.scheduled_track_plan(track_id),
        F.scheduled_graph_program(0),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        L(),
        0,
        0,
        0,
        0
    )
end

function F.scheduled_project()
    return D.Scheduled.Project(
        F.scheduled_transport(),
        F.scheduled_tempo_map(),
        L(),               -- track_programs
        L()                -- scene_entries
    )
end


-- ════════════════════════════════════════════════════════════
-- KERNEL fallbacks
-- ════════════════════════════════════════════════════════════

function F.kernel_unit()
    local terra noop_unit() end
    return D.Kernel.Unit(noop_unit, tuple())
end

function F.kernel_project()
    local stub_type = tuple()
    local terra noop_entry(output_left : &float, output_right : &float, frames : int32)
        for i = 0, frames do
            output_left[i] = 0.0f
            output_right[i] = 0.0f
        end
    end

    local buffers = D.Kernel.Buffers(
        stub_type, stub_type, stub_type, stub_type, stub_type
    )
    local state = D.Kernel.State(
        stub_type, stub_type, stub_type,
        stub_type, stub_type, stub_type
    )
    local api = D.Kernel.API(
        noop_entry, noop_entry, noop_entry,
        noop_entry, noop_entry, noop_entry,
        noop_entry, noop_entry, noop_entry,
        noop_entry, noop_entry, noop_entry,
        noop_entry, noop_entry, noop_entry,
        noop_entry, noop_entry
    )

    return D.Kernel.Project(buffers, state, api, noop_entry)
end

-- No-op TerraQuote for compile methods that return quotes
function F.noop_quote()
    return quote end
end


return F
