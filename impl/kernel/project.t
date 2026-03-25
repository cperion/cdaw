-- impl/kernel/project.t
-- Kernel.Project:entry_fn → TerraFunc

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")

diag.status("kernel.project.entry_fn", "real")

function D.Kernel.Project:entry_fn()
    if self.entry then
        return self.entry
    end
    local terra noop_entry() end
    return noop_entry
end

return true
