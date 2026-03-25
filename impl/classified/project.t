-- impl/classified/project.t
-- Classified.Project:schedule → Scheduled.Project

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.project.schedule", "partial")


function D.Classified.Project:schedule(ctx)
    return diag.wrap(ctx, "classified.project.schedule", "partial", function()
        local transport = self.transport:schedule(ctx)
        local tempo_map = self.tempo_map:schedule(ctx)

        local tracks = diag.map(ctx, "classified.project.schedule.tracks",
            self.tracks, function(t) return t:schedule(ctx) end)

        local graph_plans = diag.map(ctx, "classified.project.schedule.graphs",
            self.graphs, function(g) return g:schedule(ctx) end)

        local node_jobs = diag.map(ctx, "classified.project.schedule.nodes",
            self.nodes, function(n) return n:schedule(ctx) end)

        -- Convert scenes to scene entries
        local scene_entries = L()
        for i = 1, #self.scenes do
            local s = self.scenes[i]
            scene_entries[i] = D.Scheduled.SceneEntry(
                s.id,
                0, 0,          -- first_slot, slot_count
                s.quant_code,
                s.tempo_override
            )
        end

        -- Convert param bindings
        local param_bindings = L()
        for i = 1, #self.params do
            local p = self.params[i]
            param_bindings[i] = p.base_value:schedule(ctx)
        end

        -- Convert classified ops → scheduled ops (pass through for stubs)
        local init_ops = L()
        for i = 1, #self.init_ops do
            local op = self.init_ops[i]
            init_ops[i] = D.Scheduled.InitOp(
                op.kind, op.arg0, op.arg1,
                op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil,
                op.state_slot
            )
        end

        local block_ops = L()
        for i = 1, #self.block_ops do
            local op = self.block_ops[i]
            block_ops[i] = D.Scheduled.BlockOp(
                op.kind, op.first_pt, op.pt_count,
                op.interp, op.arg0,
                op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil
            )
        end

        local block_pts = L()
        for i = 1, #self.block_pts do
            local bp = self.block_pts[i]
            block_pts[i] = D.Scheduled.BlockPt(bp.tick, bp.value)
        end

        local sample_ops = L()
        for i = 1, #self.sample_ops do
            local op = self.sample_ops[i]
            sample_ops[i] = D.Scheduled.SampleOp(
                op.kind,
                op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil,
                op.arg0, op.arg1, op.arg2,
                op.state_slot
            )
        end

        local event_ops = L()
        for i = 1, #self.event_ops do
            local op = self.event_ops[i]
            event_ops[i] = D.Scheduled.EventOp(
                op.kind, op.event_code,
                op.min_v, op.max_v, op.state_slot
            )
        end

        local voice_ops = L()
        for i = 1, #self.voice_ops do
            local op = self.voice_ops[i]
            voice_ops[i] = D.Scheduled.VoiceOp(
                op.kind,
                op.i0:schedule(ctx),
                op.i1 and op.i1:schedule(ctx) or nil,
                op.arg0, op.arg1, op.arg2,
                op.state_slot
            )
        end

        return D.Scheduled.Project(
            transport,
            tempo_map,
            L(),                -- buffers
            tracks,
            L(),                -- steps
            graph_plans,
            node_jobs,
            L(),                -- send_jobs
            L(),                -- mix_jobs
            L(),                -- output_jobs
            L(),                -- clip_jobs
            L(),                -- mod_jobs
            L(),                -- launch_entries
            scene_entries,
            param_bindings,
            init_ops,
            block_ops,
            block_pts,
            sample_ops,
            event_ops,
            voice_ops,
            0,                 -- total_buffers
            0,                 -- total_state_slots
            0, 0               -- master_left, master_right
        )
    end, function()
        return F.scheduled_project()
    end)
end

return true
