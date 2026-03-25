-- impl/authored/init.t
-- Installs Authored-phase method implementations.
-- Load order: parent/base methods first, then composite methods.

require("impl/authored/node_kind")    -- NodeKind:resolve (parent, propagates to all variants)
require("impl/authored/param")
require("impl/authored/send")
require("impl/authored/transport")
require("impl/authored/clip")
require("impl/authored/slot")
require("impl/authored/scene")
require("impl/authored/graph")
require("impl/authored/asset_bank")
require("impl/authored/track")
require("impl/authored/project")

return true
