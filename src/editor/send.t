-- impl2/editor/send.t
-- Editor.Send:lower -> Authored.Send

return function(A, maps)
    return function(self)
        return A.Send(self.id, self.target_track_id, self.level:lower(), self.pre_fader, self.enabled)
    end
end
