-- impl2/editor/slot.t
-- Editor.Slot:lower -> Authored.Slot

return function(A, maps)
    return function(self)
        local follow = nil
        if self.behavior.follow then
            local f = self.behavior.follow
            follow = A.FollowAction(
                maps.follow_kind(f.kind),
                f.weight_a, f.weight_b, f.target_scene_id
            )
        end
        return A.Slot(
            self.slot_index,
            maps.slot_content(self.content),
            A.LaunchBehavior(
                maps.launch_mode(self.behavior.mode),
                self.behavior.quantize_override and maps.quantize(self.behavior.quantize_override) or nil,
                self.behavior.legato,
                self.behavior.retrigger,
                follow
            ),
            self.enabled
        )
    end
end
