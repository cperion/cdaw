-- impl/classified/track.t
-- Classified.Track:schedule → Scheduled.TrackPlan

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("classified.track.schedule", "stub")


function D.Classified.Track:schedule(ctx)
    return diag.wrap(ctx, "classified.track.schedule", "stub", function()
        local volume = self.volume:schedule(ctx)
        local pan = self.pan:schedule(ctx)

        return D.Scheduled.TrackPlan(
            self.id,
            volume,
            pan,
            self.input_kind_code,
            self.input_arg0,
            self.input_arg1,
            0, 0,              -- first_step, step_count
            0, 0, 0,           -- work_buf, aux_buf, mix_in_buf
            0, 0,              -- out_left, out_right
            false              -- is_master
        )
    end, function()
        return F.scheduled_track_plan(self.id)
    end)
end

return true
