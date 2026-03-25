-- impl/classified/track.t
-- Classified.Track:schedule → Scheduled.TrackPlan
--
-- Schedules a track: resolves vol/pan bindings and collects clip/send
-- indices for the track plan. Buffer allocation and step building are
-- done by project.schedule which calls this method.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.track.schedule", "real")


function D.Classified.Track:schedule(ctx)
    return diag.wrap(ctx, "classified.track.schedule", "real", function()
        local volume = self.volume:schedule(ctx)
        local pan = self.pan:schedule(ctx)

        -- Buffer allocation comes from ctx (set by project.schedule)
        local work_buf = (ctx and ctx._track_work_buf and ctx._track_work_buf[self.id]) or 0
        local out_left = (ctx and ctx._master_left) or 0
        local out_right = (ctx and ctx._master_right) or 0

        return D.Scheduled.TrackPlan(
            self.id,
            volume,
            pan,
            self.input_kind_code,
            self.input_arg0,
            self.input_arg1,
            0, 0,                  -- first_step, step_count (set by project.schedule)
            work_buf, -1, -1,      -- work_buf, aux_buf, mix_in_buf
            out_left, out_right,
            false                  -- is_master
        )
    end, function()
        return F.scheduled_track_plan(self.id)
    end)
end

return true
