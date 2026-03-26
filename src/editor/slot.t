-- editor/slot.t
-- Editor.Slot:lower -> Authored.Slot

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)

    local function lower_next_action(na)
        if not na then return nil end
        return A.NextAction(na.enabled, maps.next_action_kind(na.kind),
            na.loops_before_action, na.action_time_beats)
    end

    local function lower_behavior(b)
        return A.LaunchBehavior(
            b.launch_quantize and maps.quantize(b.launch_quantize) or nil,
            maps.launch_play_mode(b.play_mode),
            maps.launch_release_action(b.on_release),
            b.quantize_to_loop,
            lower_next_action(b.next_action)
        )
    end

    return function(self)
        return A.Slot(
            self.slot_index,
            maps.slot_content(self.content),
            lower_behavior(self.main),
            lower_behavior(self.alt),
            self.enabled
        )
    end
end
