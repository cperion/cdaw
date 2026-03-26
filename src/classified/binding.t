-- impl2/classified/binding.t
-- Classified.Binding:schedule -> Scheduled.Binding

return function(D)
    return function(self)
        return D.Binding(self.rate_class, self.slot)
    end
end
