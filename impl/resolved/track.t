-- impl/resolved/track.t
-- Resolved.Track:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.track.classify", "stub")


function D.Resolved.Track:classify(ctx)
    return diag.wrap(ctx, "resolved.track.classify", "stub", function()
        -- Volume/pan param ids → Classified.Binding
        -- Rate class 0 = literal for now (real implementation classifies properly)
        local volume_binding = F.classified_binding(0, self.volume_param_id)
        local pan_binding = F.classified_binding(0, self.pan_param_id)

        return D.Classified.Track(
            self.id,
            self.channels,
            self.input_kind_code,
            self.input_arg0,
            self.input_arg1,
            volume_binding,
            pan_binding,
            self.device_graph_id,
            self.first_clip,
            self.clip_count,
            self.first_slot,
            self.slot_count,
            self.send_ids,
            self.output_track_id,
            self.group_track_id,
            self.muted,
            self.soloed,
            self.armed,
            self.monitor_input
        )
    end, function()
        return F.classified_track(self.id, self.channels)
    end)
end

return true
