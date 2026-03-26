-- impl2/editor/scene.t
-- Editor.Scene:lower -> Authored.Scene

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
local A = types.Authored
local maps = require('src/support/enum_maps')(types.Editor, types.Authored)
    return function(self)
        local slots = L()
        for i = 1, #self.slots do
            local s = self.slots[i]
            slots[i] = A.SceneSlot(s.track_id, s.slot_index, s.stop_others)
        end
        local function lower_behavior(b)
            return A.LaunchBehavior(
                b.launch_quantize and maps.quantize(b.launch_quantize) or nil,
                maps.launch_play_mode(b.play_mode),
                maps.launch_release_action(b.on_release),
                b.quantize_to_loop,
                b.next_action and A.NextAction(b.next_action.enabled,
                    maps.next_action_kind(b.next_action.kind),
                    b.next_action.loops_before_action,
                    b.next_action.action_time_beats) or nil
            )
        end
        return A.Scene(
            self.id, self.name, slots,
            self.quantize_override and maps.quantize(self.quantize_override) or nil,
            self.tempo_override,
            self.override_launch_settings,
            lower_behavior(self.main),
            lower_behavior(self.alt)
        )
    end
end
