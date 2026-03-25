-- impl/resolved/track.t
-- Resolved.Track:classify

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("resolved.track.classify", "real")


function D.Resolved.Track:classify(ctx)
    return diag.wrap(ctx, "resolved.track.classify", "real", function()
        -- Track volume/pan now point directly into the classified param table
        -- by flat-table index. No side lookup maps are needed.
        local volume_binding = F.classified_binding(0, 0)
        local pan_binding = F.classified_binding(0, 0)

        if ctx and ctx._classified_params then
            local vol_idx = self.volume_param_index
            local pan_idx = self.pan_param_index
            if vol_idx then
                local cp = ctx._classified_params[vol_idx + 1]
                if cp then volume_binding = cp.base_value end
            end
            if pan_idx then
                local cp = ctx._classified_params[pan_idx + 1]
                if cp then pan_binding = cp.base_value end
            end
        end

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
            self.first_send,
            self.send_count,
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
