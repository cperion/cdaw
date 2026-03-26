-- impl2/view/all.t
-- All View.*.to_decl methods. These delegate to impl/view/* modules which contain
-- the actual TerraUI lowering logic. The View methods read View types and produce
-- TerraUI Decl nodes, so they don't need type constructors.

local C = require("src/view/common")
local P = require("src/view/components/placeholder_panel")

local root_view = require("src/view/root")
local shell_view = require("src/view/shell")
local transport_bar = require("src/view/transport_bar")
local arrangement_view = require("src/view/arrangement/view")
local launcher_view = require("src/view/launcher/view")
local mixer_view = require("src/view/mixer/view")
local piano_roll_view = require("src/view/piano_roll/view")
local device_chain_view = require("src/view/device_chain/view")
local device_view_mod = require("src/view/device_view")
local grid_patch_view = require("src/view/grid_patch_view")
local inspector_view = require("src/view/inspector/view")
local browser_view = require("src/view/browser/view")

-- The factory receives nothing (View methods don't construct ASDL types).
return function()
    local function wrap_to_decl(lower_fn)
        return function(self)
            local ctx = C.new_view_ctx()
            return lower_fn(self, ctx)
        end
    end

    return {
        root = function(self)
            local ctx = C.new_view_ctx {
                selection = self.focus and self.focus.selection or nil,
                active_surface = self.focus and self.focus.active_surface or nil,
                dynamic_status_params = true,
            }
            return root_view.lower(self, ctx)
        end,
        shell = wrap_to_decl(shell_view.lower),
        transport_bar = wrap_to_decl(transport_bar.lower),
        arrangement = wrap_to_decl(arrangement_view.lower),
        launcher = wrap_to_decl(launcher_view.lower),
        mixer = wrap_to_decl(mixer_view.lower),
        piano_roll = wrap_to_decl(piano_roll_view.lower),
        device_chain = wrap_to_decl(device_chain_view.lower),
        device = wrap_to_decl(device_view_mod.lower),
        grid_patch = wrap_to_decl(grid_patch_view.lower),
        inspector = wrap_to_decl(inspector_view.lower),
        browser = wrap_to_decl(browser_view.lower),
    }
end
