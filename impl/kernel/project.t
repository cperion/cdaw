-- impl/kernel/project.t
-- Kernel.Project:entry_fn → TerraFunc

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")

diag.status("kernel.project.entry_fn", "stub")

function D.Kernel.Project:entry_fn()
    -- Stub: return a no-op terra function.
    -- Real implementation composes the API functions into a single
    -- render entry point callable from the audio thread.
    local terra noop_entry() end
    return noop_entry
end

return true
