-- impl/classified/project.t
-- Classified.Project:schedule → Scheduled.Project
--
-- The schedule phase allocates buffer indices, builds per-track steps,
-- and wires node jobs into an execution plan. It also carries the
-- literal table through for Kernel compilation.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.project.schedule", "real")


local function make_schedule_ctx(caller_ctx, classified)
    local ctx = caller_ctx or {}
    ctx.diagnostics = ctx.diagnostics or {}

    -- Buffer allocator: each buffer is a mono float array of buffer_size
    local next_buf = 0
    ctx._buffers = {}
    ctx.alloc_buffer = function(self, channels, persistent)
        local idx = next_buf
        next_buf = next_buf + 1
        ctx._buffers[idx + 1] = D.Scheduled.Buffer(idx, channels or 1, false, persistent or false)
        return idx
    end

    -- Carry through the literal table from classify, but allow schedule-time
    -- helpers to add a small number of structural literals (e.g. unity gain).
    ctx.literals = {}
    ctx._literal_map = {}
    for i = 1, #classified.literals do
        ctx.literals[i] = classified.literals[i]
        ctx._literal_map[classified.literals[i].value] = i - 1
    end
    ctx.ensure_literal = function(self, value)
        local existing = ctx._literal_map[value]
        if existing ~= nil then return existing end
        local slot = #ctx.literals
        ctx.literals[slot + 1] = D.Classified.Literal(value)
        ctx._literal_map[value] = slot
        return slot
    end

    return ctx, next_buf
end


function D.Classified.Project:schedule(caller_ctx)
    return diag.wrap(caller_ctx, "classified.project.schedule", "real", function()
        local ctx = make_schedule_ctx(caller_ctx, self)

        local transport = self.transport:schedule(ctx)
        local tempo_map = self.tempo_map:schedule(ctx)

        local transport_unity_slot = ctx:ensure_literal(1.0)
        local unity_binding = D.Scheduled.Binding(0, transport_unity_slot)

        -- Allocate master output buffers
        local master_left = ctx:alloc_buffer(1, true)
        local master_right = ctx:alloc_buffer(1, true)
        ctx._master_left = master_left
        ctx._master_right = master_right

        -- Prebuild lookups and per-track buffers.
        local graph_by_id = {}
        for i = 1, #self.graphs do graph_by_id[self.graphs[i].id] = self.graphs[i] end

        local node_by_id = {}
        for i = 1, #self.nodes do node_by_id[self.nodes[i].id] = self.nodes[i] end

        local work_buf_by_track = {}
        local mix_in_buf_by_track = {}
        ctx._track_work_buf = {}
        for i = 1, #self.tracks do
            local ct = self.tracks[i]
            local work_buf = ctx:alloc_buffer(1, false)
            local mix_in_buf = ctx:alloc_buffer(1, false)
            work_buf_by_track[ct.id] = work_buf
            mix_in_buf_by_track[ct.id] = mix_in_buf
            ctx._track_work_buf[ct.id] = work_buf
        end

        local tracks = L()
        local steps = L()
        local graph_plans = L()
        local node_jobs = L()
        local clip_jobs = L()
        local mod_jobs = L()
        local send_jobs = L()
        local mix_jobs = L()
        local output_jobs = L()

        ctx._graph_first_job = {}
        ctx._graph_job_count = {}
        ctx._graph_in_buf = {}
        ctx._graph_out_buf = {}
        ctx._node_in_buf = {}
        ctx._node_out_buf = {}

        local function add_step(clear_buf, clip_job, node_job, mod_job, send_job, mix_job, output_job)
            steps:insert(D.Scheduled.Step(
                #steps,
                clear_buf,
                clip_job or -1,
                node_job or -1,
                mod_job or -1,
                send_job or -1,
                mix_job or -1,
                output_job or -1
            ))
        end

        local function append_extra_steps(job_indices, field)
            for i = 2, #job_indices do
                if field == "clip" then
                    add_step(-1, job_indices[i], -1, -1, -1, -1, -1)
                elseif field == "mod" then
                    add_step(-1, -1, -1, job_indices[i], -1, -1, -1)
                elseif field == "send" then
                    add_step(-1, -1, -1, -1, job_indices[i], -1, -1)
                elseif field == "mix" then
                    add_step(-1, -1, -1, -1, -1, job_indices[i], -1)
                elseif field == "output" then
                    add_step(-1, -1, -1, -1, -1, -1, job_indices[i])
                end
            end
        end

        for i = 1, #self.tracks do
            local ct = self.tracks[i]
            local work_buf = work_buf_by_track[ct.id]
            local mix_in_buf = mix_in_buf_by_track[ct.id]
            local vol = ct.volume:schedule(ctx)
            local pan = ct.pan:schedule(ctx)
            local graph = graph_by_id[ct.device_graph_id]
            local node_ids_in_graph = {}

            -- Graph/node scheduling for the track's device graph.
            local track_first_node_job = #node_jobs
            local track_node_count = 0
            if graph then
                ctx._graph_in_buf[graph.id] = work_buf
                ctx._graph_out_buf[graph.id] = work_buf
                ctx._graph_first_job[graph.id] = track_first_node_job
                for j = 1, #graph.node_ids do
                    local nid = graph.node_ids[j]
                    node_ids_in_graph[nid] = true
                    local cn = node_by_id[nid]
                    if cn then
                        ctx._node_in_buf[nid] = work_buf
                        ctx._node_out_buf[nid] = work_buf
                        node_jobs:insert(cn:schedule(ctx))
                        track_node_count = track_node_count + 1
                    end
                end
                ctx._graph_job_count[graph.id] = track_node_count
                graph_plans:insert(graph:schedule(ctx))
            end

            -- Track-local clip jobs.
            local clip_job_indices = {}
            for j = 0, ct.clip_count - 1 do
                local clip = self.clips[ct.first_clip + j + 1]
                if clip and not clip.muted then
                    local gain = clip.gain:schedule(ctx)
                    clip_jobs:insert(D.Scheduled.ClipJob(
                        clip.id,
                        clip.content_kind,
                        clip.asset_id,
                        work_buf,
                        clip.start_tick,
                        clip.end_tick,
                        clip.source_offset_tick,
                        gain,
                        false,
                        clip.fade_in_tick,
                        clip.fade_in_curve_code,
                        clip.fade_out_tick,
                        clip.fade_out_curve_code
                    ))
                    clip_job_indices[#clip_job_indices + 1] = #clip_jobs - 1
                end
            end

            -- Track-local mod jobs for nodes that belong to this graph.
            local mod_job_indices = {}
            for j = 1, #self.mod_slots do
                local ms = self.mod_slots[j]
                if node_ids_in_graph[ms.parent_node_id] then
                    mod_jobs:insert(D.Scheduled.ModJob(
                        ms.modulator_node_id,
                        ms.parent_node_id,
                        ms.per_voice,
                        ms.first_route,
                        ms.route_count,
                        ms.output_binding.slot,
                        ms.output_binding:schedule(ctx)
                    ))
                    mod_job_indices[#mod_job_indices + 1] = #mod_jobs - 1
                end
            end

            -- Send jobs write into the target track's mix-in buffer.
            local send_job_indices = {}
            for j = 0, ct.send_count - 1 do
                local send = self.sends[ct.first_send + j + 1]
                if send then
                    local target_mix_in = mix_in_buf_by_track[send.target_track_id]
                    if target_mix_in then
                        send_jobs:insert(D.Scheduled.SendJob(
                            work_buf,
                            target_mix_in,
                            send.level:schedule(ctx),
                            send.pre_fader,
                            send.enabled
                        ))
                        send_job_indices[#send_job_indices + 1] = #send_jobs - 1
                    end
                end
            end

            -- If this track receives sends, fold them into its work buffer.
            local mix_job_indices = {}
            mix_jobs:insert(D.Scheduled.MixJob(mix_in_buf, work_buf, unity_binding))
            mix_job_indices[#mix_job_indices + 1] = #mix_jobs - 1

            -- Final output for the track goes through an explicit OutputJob.
            local output_job_indices = {}
            output_jobs:insert(D.Scheduled.OutputJob(
                work_buf,
                master_left,
                master_right,
                vol,
                pan
            ))
            output_job_indices[#output_job_indices + 1] = #output_jobs - 1

            local first_step = #steps
            add_step(
                -1,
                clip_job_indices[1] or -1,
                track_node_count > 0 and track_first_node_job or -1,
                mod_job_indices[1] or -1,
                send_job_indices[1] or -1,
                mix_job_indices[1] or -1,
                output_job_indices[1] or -1
            )
            append_extra_steps(clip_job_indices, "clip")
            append_extra_steps(mod_job_indices, "mod")
            append_extra_steps(send_job_indices, "send")
            append_extra_steps(mix_job_indices, "mix")
            append_extra_steps(output_job_indices, "output")
            local step_count = #steps - first_step

            tracks:insert(D.Scheduled.TrackPlan(
                ct.id,
                vol, pan,
                ct.input_kind_code, ct.input_arg0, ct.input_arg1,
                first_step, step_count,
                work_buf, -1, mix_in_buf,
                master_left, master_right,
                false
            ))
        end

        -- Scene entries
        local scene_entries = L()
        for i = 1, #self.scenes do
            local s = self.scenes[i]
            scene_entries:insert(D.Scheduled.SceneEntry(
                s.id, 0, 0, s.quant_code, s.tempo_override
            ))
        end

        -- Param bindings
        local param_bindings = L()
        for i = 1, #self.params do
            param_bindings:insert(self.params[i].base_value:schedule(ctx))
        end

        -- Convert classified ops (pass through)
        local init_ops = L()
        for i = 1, #self.init_ops do
            local op = self.init_ops[i]
            init_ops:insert(D.Scheduled.InitOp(
                op.kind, op.arg0, op.arg1,
                op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil,
                op.state_slot
            ))
        end
        local block_ops = L()
        for i = 1, #self.block_ops do
            local op = self.block_ops[i]
            block_ops:insert(D.Scheduled.BlockOp(
                op.kind, op.first_pt, op.pt_count, op.interp, op.arg0,
                op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil
            ))
        end
        local block_pts = L()
        for i = 1, #self.block_pts do
            block_pts:insert(D.Scheduled.BlockPt(self.block_pts[i].tick, self.block_pts[i].value))
        end
        local sample_ops = L()
        for i = 1, #self.sample_ops do
            local op = self.sample_ops[i]
            sample_ops:insert(D.Scheduled.SampleOp(
                op.kind, op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil,
                op.arg0, op.arg1, op.arg2, op.state_slot
            ))
        end
        local event_ops = L()
        for i = 1, #self.event_ops do
            local op = self.event_ops[i]
            event_ops:insert(D.Scheduled.EventOp(op.kind, op.event_code, op.min_v, op.max_v, op.state_slot))
        end
        local voice_ops = L()
        for i = 1, #self.voice_ops do
            local op = self.voice_ops[i]
            voice_ops:insert(D.Scheduled.VoiceOp(
                op.kind, op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil,
                op.arg0, op.arg1, op.arg2, op.state_slot
            ))
        end

        local literals = L()
        for i = 1, #ctx.literals do
            literals:insert(D.Scheduled.Literal(ctx.literals[i].value))
        end

        local params = L()
        for i = 1, #self.params do
            local p = self.params[i]
            params:insert(D.Scheduled.Param(
                p.id, p.node_id,
                p.default_value, p.min_value, p.max_value,
                p.base_value:schedule(ctx),
                p.combine_code,
                p.smoothing_code, p.smoothing_ms,
                p.first_modulation, p.modulation_count,
                p.runtime_state_slot
            ))
        end

        local mod_slots = L()
        for i = 1, #self.mod_slots do
            local ms = self.mod_slots[i]
            mod_slots:insert(D.Scheduled.ModSlot(
                ms.slot_index,
                ms.parent_node_id,
                ms.modulator_node_id,
                ms.per_voice,
                ms.first_route,
                ms.route_count,
                ms.output_binding:schedule(ctx)
            ))
        end

        local mod_routes = L()
        for i = 1, #self.mod_routes do
            local mr = self.mod_routes[i]
            mod_routes:insert(D.Scheduled.ModRoute(
                mr.mod_slot_index,
                mr.target_param_id,
                mr.depth:schedule(ctx),
                mr.bipolar,
                mr.scale_binding_slot
            ))
        end

        -- Build buffer list
        local buffers = L()
        for i = 1, #ctx._buffers do buffers:insert(ctx._buffers[i]) end

        -- Propagate diagnostics
        if caller_ctx then caller_ctx.diagnostics = ctx.diagnostics end

        return D.Scheduled.Project(
            transport, tempo_map,
            buffers, tracks, steps,
            graph_plans, node_jobs,
            send_jobs, mix_jobs, output_jobs, clip_jobs, mod_jobs,
            L(), scene_entries,
            literals, params, mod_slots, mod_routes,
            param_bindings,
            init_ops, block_ops, block_pts,
            sample_ops, event_ops, voice_ops,
            #ctx._buffers,
            self.total_state_slots,
            master_left, master_right
        )
    end, function()
        return F.scheduled_project()
    end)
end

return true
