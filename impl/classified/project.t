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

    -- Carry through the literal table from classify
    ctx.literals = {}
    for i = 1, #classified.literals do
        ctx.literals[i] = classified.literals[i]
    end

    return ctx, next_buf
end


function D.Classified.Project:schedule(caller_ctx)
    return diag.wrap(caller_ctx, "classified.project.schedule", "real", function()
        local ctx = make_schedule_ctx(caller_ctx, self)

        local transport = self.transport:schedule(ctx)
        local tempo_map = self.tempo_map:schedule(ctx)

        -- Allocate master output buffers
        local master_left = ctx:alloc_buffer(1, true)
        local master_right = ctx:alloc_buffer(1, true)

        -- Schedule tracks: allocate work buffers per track
        local tracks = L()
        local steps = L()
        local node_jobs = L()
        local graph_plans = L()

        for i = 1, #self.tracks do
            local ct = self.tracks[i]

            -- Allocate per-track work buffer
            local work_buf = ctx:alloc_buffer(1, false)

            -- Schedule the track's volume/pan bindings
            local vol = ct.volume:schedule(ctx)
            local pan = ct.pan:schedule(ctx)

            -- Schedule node jobs for this track's graph
            local track_first_node_job = #node_jobs
            local track_node_count = 0
            for j = 1, #self.graphs do
                local g = self.graphs[j]
                if g.id == ct.device_graph_id then
                    -- Schedule each node in the graph
                    for k = 1, #g.node_ids do
                        local nid = g.node_ids[k]
                        -- Find the classified node
                        for m = 1, #self.nodes do
                            if self.nodes[m].id == nid then
                                local cn = self.nodes[m]
                                -- Node gets in_buf=work_buf, out_buf=work_buf (in-place for serial)
                                node_jobs:insert(D.Scheduled.NodeJob(
                                    cn.id, cn.node_kind_code,
                                    work_buf, work_buf,
                                    cn.first_param, cn.param_count,
                                    cn.runtime_state_slot, 0,
                                    cn.arg0, cn.arg1, cn.arg2, cn.arg3
                                ))
                                track_node_count = track_node_count + 1
                                break
                            end
                        end
                    end
                    -- Build a graph plan for this graph
                    graph_plans:insert(D.Scheduled.GraphPlan(
                        g.id,
                        track_first_node_job, track_node_count,
                        work_buf, work_buf,
                        0, 0
                    ))
                    break
                end
            end

            -- Build a step for this track
            steps:insert(D.Scheduled.Step(
                #steps, work_buf,
                -1, track_first_node_job,
                -1, -1, -1, -1
            ))

            tracks:insert(D.Scheduled.TrackPlan(
                ct.id,
                vol, pan,
                ct.input_kind_code, ct.input_arg0, ct.input_arg1,
                #steps - 1, 1,        -- first_step, step_count
                work_buf, -1, -1,     -- work_buf, aux_buf, mix_in_buf
                master_left, master_right,
                false                  -- is_master
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

        -- Build buffer list
        local buffers = L()
        for i = 1, #ctx._buffers do buffers:insert(ctx._buffers[i]) end

        -- Propagate diagnostics
        if caller_ctx then caller_ctx.diagnostics = ctx.diagnostics end

        local result = D.Scheduled.Project(
            transport, tempo_map,
            buffers, tracks, steps,
            graph_plans, node_jobs,
            L(), L(), L(), L(), L(),  -- send/mix/output/clip/mod jobs
            L(), scene_entries,
            param_bindings,
            init_ops, block_ops, block_pts,
            sample_ops, event_ops, voice_ops,
            #ctx._buffers,
            self.total_state_slots,
            master_left, master_right
        )

        -- Attach literal values for the compile phase (plain Lua field)
        result._literal_values = {}
        for i = 1, #ctx.literals do
            result._literal_values[i] = ctx.literals[i].value
        end

        return result
    end, function()
        return F.scheduled_project()
    end)
end

return true
