-- tests/kernel_support.t
-- Helpers for invoking Kernel.Project with its owned state ABI.

local C = terralib.includec("string.h")
local M = {}

function M.alloc_unit_state(unit)
    local state_t = unit and unit.state_t or tuple()
    local state = nil
    local raw = terralib.cast(&uint8, 0)
    if state_t ~= tuple() then
        state = terralib.new(state_t)
        raw = terralib.cast(&uint8, state)
        C.memset(raw, 0, terralib.sizeof(state_t))
    end
    return raw, state
end

function M.alloc_state(kernel)
    local raw, state = M.alloc_unit_state({ state_t = kernel:state_type() })
    local init_fn = kernel:state_init_fn()
    init_fn(raw)
    return raw, state
end

function M.entry_with_state(kernel)
    local entry = kernel:entry_fn()
    local raw, state = M.alloc_state(kernel)
    return entry, raw, state
end

function M.run(kernel, out_l, out_r, frames)
    local entry, raw, state = M.entry_with_state(kernel)
    entry(out_l, out_r, frames, raw)
    return raw, state
end

return M
