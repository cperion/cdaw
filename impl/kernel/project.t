-- impl/kernel/project.t
-- Kernel.Project:entry_fn → TerraFunc

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")

diag.status("kernel.project.entry_fn", "real")

function D.Kernel.Project:entry_fn()
    -- Return the compiled render function.
    -- The project compile attaches it as _render_fn.
    if self._render_fn then
        return self._render_fn
    end
    -- Fallback: no-op
    local terra noop_entry() end
    return noop_entry
end

return true
