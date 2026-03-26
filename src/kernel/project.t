-- impl2/kernel/project.t
-- Kernel.Project:entry_fn -> TerraFunc (bare impl, no boilerplate)

return function(D)
    return function(self)
        if self.entry then return self.entry end
        local terra noop_entry() end
        return noop_entry
    end
end
