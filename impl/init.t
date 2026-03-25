-- impl/init.t
-- Installs ASDL-method implementation trees.
-- Load order follows phase dependencies:
--   Editor → Authored → Resolved → Classified → Scheduled → Kernel
-- View is independent (references Editor, lowers to TerraUI).

require("impl/view/init")
require("impl/editor/init")
require("impl/authored/init")
require("impl/resolved/init")
require("impl/classified/init")
require("impl/scheduled/init")
require("impl/kernel/init")

return true
