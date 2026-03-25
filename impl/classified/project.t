-- impl/classified/project.t
-- Classified.GraphSlice:schedule -> Scheduled.GraphProgram
-- Classified.TrackSlice:schedule -> Scheduled.TrackProgram
-- Classified.Project:schedule -> Scheduled.Project

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L

diag.status("classified.graph_slice.schedule", "real")
diag.status("classified.track_slice.schedule", "real")
diag.status("classified.project.schedule", "real")

local function make_state(literals_owner)
    local st = {
        next_buf = 0,
        buffers = {},
        literals = {},
        literal_map = {},
    }
    local literals = literals_owner or nil
    if literals and literals.literals then literals = literals.literals end
    if literals then
        for i = 1, #literals do
            st.literals[i] = literals[i]
            st.literal_map[literals[i].value] = i - 1
        end
    end
    return st
end

local function alloc_buffer(st, channels, persistent)
    local idx = st.next_buf
    st.next_buf = idx + 1
    st.buffers[idx + 1] = D.Scheduled.Buffer(idx, channels or 1, false, persistent or false)
    return idx
end

local function ensure_literal(st, value)
    local existing = st.literal_map[value]
    if existing ~= nil then return existing end
    local slot = #st.literals
    st.literals[slot + 1] = D.Classified.Literal(value)
    st.literal_map[value] = slot
    return slot
end

local function to_list(tbl)
    local l = L()
    for i = 1, #tbl do l:insert(tbl[i]) end
    return l
end

local function schedule_graph_plan(graph, first_node_job, node_job_count, in_buf, out_buf)
    return D.Scheduled.GraphPlan(
        graph.id,
        first_node_job,
        node_job_count,
        in_buf,
        out_buf,
        graph.first_feedback or 0,
        graph.feedback_count or 0
    )
end

local function schedule_node_job(node, in_buf, out_buf)
    return D.Scheduled.NodeJob(
        node.id,
        node.node_kind_code,
        in_buf,
        out_buf,
        node.first_param,
        node.param_count,
        node.runtime_state_slot,
        node.state_size,
        node.arg0, node.arg1, node.arg2, node.arg3
    )
end

local function schedule_param_list(params)
    local out = L()
    for i = 1, #params do
        local p = params[i]
        out[i] = D.Scheduled.Param(
            p.id, p.node_id,
            p.default_value, p.min_value, p.max_value,
            p.base_value:schedule(),
            p.combine_code,
            p.smoothing_code, p.smoothing_ms,
            p.first_modulation, p.modulation_count,
            p.runtime_state_slot
        )
    end
    return out
end

local function schedule_param_bindings(params)
    local out = L()
    for i = 1, #params do out[i] = params[i].base_value:schedule() end
    return out
end

local function schedule_mod_slot_list(mod_slots)
    local out = L()
    for i = 1, #mod_slots do
        local ms = mod_slots[i]
        out[i] = D.Scheduled.ModSlot(
            ms.slot_index,
            ms.parent_node_id,
            ms.modulator_node_id,
            ms.modulator_kind_code,
            ms.first_param,
            ms.param_count,
            ms.arg0, ms.arg1, ms.arg2, ms.arg3,
            ms.per_voice,
            ms.first_route,
            ms.route_count,
            ms.state_size,
            ms.runtime_state_slot,
            ms.output_binding:schedule()
        )
    end
    return out
end

local function schedule_mod_route_list(mod_routes)
    local out = L()
    for i = 1, #mod_routes do
        local mr = mod_routes[i]
        out[i] = D.Scheduled.ModRoute(
            mr.mod_slot_index,
            mr.target_param_id,
            mr.depth:schedule(),
            mr.bipolar,
            mr.scale_binding_slot
        )
    end
    return out
end

local function schedule_literal_list(literals)
    local out = L()
    for i = 1, #literals do out[i] = D.Scheduled.Literal(literals[i].value) end
    return out
end

local function schedule_init_ops(init_ops)
    local out = L()
    for i = 1, #init_ops do
        local op = init_ops[i]
        out[i] = D.Scheduled.InitOp(
            op.kind, op.arg0, op.arg1,
            op.i0:schedule(),
            op.i1 and op.i1:schedule() or nil,
            op.state_slot
        )
    end
    return out
end

local function schedule_block_ops(block_ops)
    local out = L()
    for i = 1, #block_ops do
        local op = block_ops[i]
        out[i] = D.Scheduled.BlockOp(
            op.kind, op.first_pt, op.pt_count, op.interp, op.arg0,
            op.i0:schedule(),
            op.i1 and op.i1:schedule() or nil
        )
    end
    return out
end

local function schedule_block_pts(block_pts)
    local out = L()
    for i = 1, #block_pts do out[i] = D.Scheduled.BlockPt(block_pts[i].tick, block_pts[i].value) end
    return out
end

local function schedule_sample_ops(sample_ops)
    local out = L()
    for i = 1, #sample_ops do
        local op = sample_ops[i]
        out[i] = D.Scheduled.SampleOp(
            op.kind, op.i0:schedule(),
            op.i1 and op.i1:schedule() or nil,
            op.arg0, op.arg1, op.arg2, op.state_slot
        )
    end
    return out
end

local function schedule_event_ops(event_ops)
    local out = L()
    for i = 1, #event_ops do
        local op = event_ops[i]
        out[i] = D.Scheduled.EventOp(op.kind, op.event_code, op.min_v, op.max_v, op.state_slot)
    end
    return out
end

local function schedule_voice_ops(voice_ops)
    local out = L()
    for i = 1, #voice_ops do
        local op = voice_ops[i]
        out[i] = D.Scheduled.VoiceOp(
            op.kind, op.i0:schedule(),
            op.i1 and op.i1:schedule() or nil,
            op.arg0, op.arg1, op.arg2, op.state_slot
        )
    end
    return out
end

local schedule_graph_program_impl = terralib.memoize(function(self, transport, tempo_map)
    local st = make_state(self.literals)
    local scheduled_transport = transport and transport:schedule() or F.scheduled_transport()
    local scheduled_tempo_map = tempo_map and tempo_map:schedule() or F.scheduled_tempo_map()

    local graph = self.graphs[1] or F.classified_graph(0)
    local in_buf = alloc_buffer(st, 1, false)
    local out_buf = alloc_buffer(st, 1, false)

    local node_jobs = L()
    local prev_out = in_buf
    for i = 1, #self.nodes do
        local node_in = prev_out
        local node_out = (i == #self.nodes) and out_buf or alloc_buffer(st, 1, false)
        node_jobs[i] = schedule_node_job(self.nodes[i], node_in, node_out)
        prev_out = node_out
    end

    return D.Scheduled.GraphProgram(
        scheduled_transport,
        scheduled_tempo_map,
        to_list(st.buffers),
        schedule_graph_plan(graph, 0, #node_jobs, in_buf, out_buf),
        node_jobs,
        schedule_param_list(self.params),
        schedule_mod_slot_list(self.mod_slots),
        schedule_mod_route_list(self.mod_routes),
        schedule_param_bindings(self.params),
        schedule_literal_list(st.literals),
        schedule_init_ops(self.init_ops),
        schedule_block_ops(self.block_ops),
        schedule_block_pts(self.block_pts),
        schedule_sample_ops(self.sample_ops),
        schedule_event_ops(self.event_ops),
        schedule_voice_ops(self.voice_ops),
        st.next_buf,
        self.total_state_slots
    )
end)

local schedule_track_program_impl = terralib.memoize(function(self, transport, tempo_map)
    local st = make_state(self.mixer_literals)
    local scheduled_transport = transport and transport:schedule() or F.scheduled_transport()
    local scheduled_tempo_map = tempo_map and tempo_map:schedule() or F.scheduled_tempo_map()

    local device_graph = self.device_graph:schedule(transport, tempo_map)

    local unity_slot = ensure_literal(st, 1.0)
    local unity_binding = D.Scheduled.Binding(0, unity_slot)

    local work_buf = alloc_buffer(st, 1, false)
    local mix_in_buf = alloc_buffer(st, 1, false)
    local master_left = alloc_buffer(st, 1, true)
    local master_right = alloc_buffer(st, 1, true)

    local clip_jobs = L()
    for i = 1, #self.clips do
        local clip = self.clips[i]
        if not clip.muted then
            clip_jobs:insert(D.Scheduled.ClipJob(
                clip.id,
                clip.content_kind,
                clip.asset_id,
                work_buf,
                clip.start_tick,
                clip.end_tick,
                clip.source_offset_tick,
                clip.gain:schedule(),
                false,
                clip.fade_in_tick,
                clip.fade_in_curve_code,
                clip.fade_out_tick,
                clip.fade_out_curve_code
            ))
        end
    end

    local send_jobs = L()
    for i = 1, #self.sends do
        local send = self.sends[i]
        send_jobs:insert(D.Scheduled.SendJob(
            work_buf,
            mix_in_buf,
            send.level:schedule(),
            send.pre_fader,
            send.enabled
        ))
    end

    local mix_jobs = L{D.Scheduled.MixJob(mix_in_buf, work_buf, unity_binding)}
    local output_jobs = L{D.Scheduled.OutputJob(
        work_buf,
        master_left,
        master_right,
        self.track.volume:schedule(),
        self.track.pan:schedule()
    )}

    local steps = L()
    steps:insert(D.Scheduled.Step(0, -1, (#clip_jobs > 0 and 0 or -1), (#device_graph.node_jobs > 0 and 0 or -1), -1, (#send_jobs > 0 and 0 or -1), 0, 0))
    for i = 2, #clip_jobs do steps:insert(D.Scheduled.Step(#steps, -1, i - 1, -1, -1, -1, -1, -1)) end
    for i = 2, #send_jobs do steps:insert(D.Scheduled.Step(#steps, -1, -1, -1, -1, i - 1, -1, -1)) end

    local launch_entries = L()
    for i = 1, #self.slots do
        local slot = self.slots[i]
        launch_entries[i] = D.Scheduled.LaunchEntry(
            self.track.id,
            slot.slot_index,
            slot.slot_kind,
            slot.clip_id,
            slot.launch_mode_code,
            slot.quant_code,
            slot.legato,
            slot.retrigger,
            slot.follow_kind_code,
            slot.follow_weight_a,
            slot.follow_weight_b,
            slot.follow_target_scene_id,
            slot.enabled
        )
    end

    return D.Scheduled.TrackProgram(
        scheduled_transport,
        scheduled_tempo_map,
        to_list(st.buffers),
        D.Scheduled.TrackPlan(
            self.track.id,
            self.track.volume:schedule(),
            self.track.pan:schedule(),
            self.track.input_kind_code,
            self.track.input_arg0,
            self.track.input_arg1,
            0,
            #steps,
            work_buf,
            -1,
            mix_in_buf,
            master_left,
            master_right,
            false
        ),
        steps,
        device_graph,
        send_jobs,
        mix_jobs,
        output_jobs,
        clip_jobs,
        L(),
        launch_entries,
        schedule_param_list(self.mixer_params),
        schedule_param_bindings(self.mixer_params),
        schedule_literal_list(st.literals),
        schedule_init_ops(self.mixer_init_ops),
        schedule_block_ops(self.mixer_block_ops),
        schedule_block_pts(self.mixer_block_pts),
        schedule_sample_ops(self.mixer_sample_ops),
        schedule_event_ops(self.mixer_event_ops),
        schedule_voice_ops(self.mixer_voice_ops),
        st.next_buf,
        self.device_graph.total_state_slots,
        master_left,
        master_right
    )
end)

local schedule_project_impl = terralib.memoize(function(self)
    local transport = self.transport:schedule()
    local tempo_map = self.tempo_map:schedule()

    local track_programs = diag.map_or(nil, "classified.project.schedule.track_slices",
        self.track_slices,
        function(ts)
            return ts:schedule(self.transport, self.tempo_map)
        end,
        function(ts)
            local id = ts and ts.track and ts.track.id or 0
            return F.scheduled_track_program(id)
        end)

    local scene_entries = L()
    for i = 1, #self.scenes do
        local s = self.scenes[i]
        scene_entries[i] = D.Scheduled.SceneEntry(s.id, s.first_slot, s.slot_count, s.quant_code, s.tempo_override)
    end

    return D.Scheduled.Project(transport, tempo_map, track_programs, scene_entries)
end)

function D.Classified.GraphSlice:schedule(transport, tempo_map)
    return diag.wrap(nil, "classified.graph_slice.schedule", "real", function()
        return schedule_graph_program_impl(self, transport, tempo_map)
    end, function()
        local id = (#self.graphs > 0 and self.graphs[1].id) or 0
        return F.scheduled_graph_program(id)
    end)
end

function D.Classified.TrackSlice:schedule(transport, tempo_map)
    return diag.wrap(nil, "classified.track_slice.schedule", "real", function()
        return schedule_track_program_impl(self, transport, tempo_map)
    end, function()
        local id = self.track and self.track.id or 0
        return F.scheduled_track_program(id)
    end)
end

function D.Classified.Project:schedule()
    return diag.wrap(nil, "classified.project.schedule", "real", function()
        return schedule_project_impl(self)
    end, function()
        return F.scheduled_project()
    end)
end

return true
