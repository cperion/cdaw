-- impl/view/root.t
-- View.Root lower

local C = require("src/view/common")
local P = require("src/view/components/placeholder_panel")
local shell_view = require("src/view/shell")

local M = {}

local function mode_defaults(active_surface)
    local kind = active_surface and active_surface.kind or "ArrangementSurface"
    if kind == "MixerSurface" then return 0, 1, 0
    elseif kind == "PianoRollSurface" then return 0, 0, 1 end
    return 1, 0, 0
end

function M.lower(self, ctx)
    local ui = ctx.ui
    local status_bar = self.shell and self.shell.status_bar or nil
    local status_left = status_bar and status_bar.left_text or "shell online"
    local status_center = status_bar and status_bar.center_text or "Bitwig-like shell grammar: Arrange / Mix / Edit"
    local status_right = status_bar and status_bar.right_text or "Click ARRANGE / MIX / EDIT to switch views"
    local mode_arrange, mode_mix, mode_edit = mode_defaults(self.focus and self.focus.active_surface)
    local params = C.list(
        ui.param("status_left") { type = ui.types.string, default = status_left },
        ui.param("status_center") { type = ui.types.string, default = status_center },
        ui.param("status_right") { type = ui.types.string, default = status_right },
        ui.param("mode_arrange") { type = ui.types.number, default = mode_arrange },
        ui.param("mode_mix") { type = ui.types.number, default = mode_mix },
        ui.param("mode_edit") { type = ui.types.number, default = mode_edit }
    )
    return ui.component("terra_daw") {
        params = params,
        root = shell_view.lower(self.shell, ctx),
    }
end

return M
