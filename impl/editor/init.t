-- impl/editor/init.t
-- Installs Editor-phase method implementations.
-- Load order: leaf methods first, then composite methods.

require("impl/editor/param_value")
require("impl/editor/send")
require("impl/editor/modulator")
require("impl/editor/transport")
require("impl/editor/clip")
require("impl/editor/slot")
require("impl/editor/scene")
require("impl/editor/grid_patch")
require("impl/editor/device_chain")
require("impl/editor/device")
require("impl/editor/track")
require("impl/editor/project")

return true
