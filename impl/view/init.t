-- impl/view/init.t
-- Installs View-phase method implementations in a stable load order.
local diag = require("impl/_support/diagnostics")

-- View methods not yet implemented (exist in ASDL, no code yet)
diag.status("view.device_view.to_decl", "stub")
diag.status("view.grid_patch_view.to_decl", "stub")

require("impl/view/_support/common")
require("impl/view/components/text")
require("impl/view/components/button")
require("impl/view/components/placeholder_panel")
require("impl/view/components/panel_frame")
require("impl/view/components/list_row")
require("impl/view/components/track_header")

require("impl/view/transport_bar")
require("impl/view/arrangement/lane")
require("impl/view/arrangement/view")
require("impl/view/launcher/column")
require("impl/view/launcher/view")
require("impl/view/mixer/strip")
require("impl/view/mixer/view")
require("impl/view/piano_roll/view")
require("impl/view/device_chain/entry")
require("impl/view/device_chain/view")
require("impl/view/browser/item")
require("impl/view/browser/section")
require("impl/view/browser/view")
require("impl/view/inspector/field_view")
require("impl/view/inspector/section_view")
require("impl/view/inspector/tab_view")
require("impl/view/inspector/view")
require("impl/view/status_bar")
require("impl/view/detail_panel")
require("impl/view/shell")
require("impl/view/root")

return true
