-- src/kernel/project.t
-- Kernel.Project runtime accessors.

return function(types)
    return {
        entry_fn = function(self)
            if self.fn then return self.fn end
            local terra noop_entry(output_left: &float, output_right: &float, frames: int32, state_raw: &uint8) end
            return noop_entry
        end,

        state_type = function(self)
            return self.state_t or tuple()
        end,

        state_init_fn = function(self)
            if self.init_fn then return self.init_fn end
            local terra noop_init(state_raw: &uint8) end
            return noop_init
        end,
    }
end
