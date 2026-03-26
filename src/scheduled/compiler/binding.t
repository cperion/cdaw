-- impl/scheduled/compiler/binding.t
-- Private scheduled binding quote compiler.


local function compile_value_with(self, ctx)
        if self.rate_class == 0 then
            local val = ctx and ctx.literals and ctx.literals[self.slot + 1]
            if val then
                local v = val.value
                return `[float](v)
            end
            local values = ctx and ctx.literal_values
            if values then
                local v = values[self.slot + 1] or 0.0
                return `[float](v)
            end
            return `0.0f
        elseif self.rate_class == 1 then
            local sym = ctx and ctx.init_slots_sym
            if sym then return `([sym][self.slot]) end
            return `0.0f
        elseif self.rate_class == 2 then
            local sym = ctx and ctx.block_slots_sym
            if sym then return `([sym][self.slot]) end
            return `0.0f
        elseif self.rate_class == 3 then
            local sym = ctx and ctx.sample_slots_sym
            if sym then return `([sym][self.slot]) end
            return `0.0f
        elseif self.rate_class == 4 then
            local sym = ctx and ctx.event_slots_sym
            if sym then return `([sym][self.slot]) end
            return `0.0f
        elseif self.rate_class == 5 then
            local sym = ctx and ctx.voice_slots_sym
            if sym then return `([sym][self.slot]) end
            return `0.0f
        end
        return `0.0f

end

return compile_value_with
