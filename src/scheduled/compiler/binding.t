-- src/scheduled/compiler/binding.t
-- Compile a Scheduled.Binding to a Terra quote.
--
-- Takes explicit slot symbols, not a ctx bag.
-- All semantic dependencies are explicit parameters.
--
--   compile(binding, literal_values, init_sym, block_sym, sample_sym, event_sym, voice_sym)
--
-- rate_class meanings:
--   0 = literal  (slot = index into literal_values table)
--   1 = init     (slot = index into init_slots array)
--   2 = block    (slot = index into block_slots array)
--   3 = sample   (slot = index into sample_slots array)
--   4 = event    (slot = index into event_slots array)
--   5 = voice    (slot = index into voice_slots array)

local function compile(binding, literal_values, init_sym, block_sym, sample_sym, event_sym, voice_sym)
    if not binding then return `0.0f end
    local rc = binding.rate_class
    local sl = binding.slot

    if rc == 0 then
        local v = literal_values and literal_values[sl + 1] or 0.0
        return `[float](v)
    elseif rc == 1 then
        if init_sym   then return `([init_sym][sl])   end
    elseif rc == 2 then
        if block_sym  then return `([block_sym][sl])  end
    elseif rc == 3 then
        if sample_sym then return `([sample_sym][sl]) end
    elseif rc == 4 then
        if event_sym  then return `([event_sym][sl])  end
    elseif rc == 5 then
        if voice_sym  then return `([voice_sym][sl])  end
    end
    return `0.0f
end

return compile
