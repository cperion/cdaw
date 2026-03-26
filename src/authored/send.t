-- impl2/authored/send.t
-- Authored.Send:resolve -> Resolved.Send

return function(R)
    return function(self)
        local level_param = self.level:resolve()
        return R.Send(self.id, self.target_track_id, level_param.id, self.pre_fader, self.enabled)
    end
end
