-- impl/view/root.t
-- View.Root:to_decl()

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.root.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local P = require("impl/view/components/placeholder_panel")

function V.Root:to_decl(ctx)
    return diag.wrap(ctx, "view.root.to_decl", "real", function()
        local ui = ctx.ui
        local params = C.list(
            ui.param("status_left") { type = ui.types.string, default = "shell online" },
            ui.param("status_center") { type = ui.types.string, default = "Bitwig-like shell grammar: Arrange / Mix / Edit" },
            ui.param("status_right") { type = ui.types.string, default = "Click ARRANGE / MIX / EDIT to switch views" },
            ui.param("mode_arrange") { type = ui.types.number, default = 1 },
            ui.param("mode_mix") { type = ui.types.number, default = 0 },
            ui.param("mode_edit") { type = ui.types.number, default = 0 }
        )
        return ui.component("terra_daw") {
            params = params,
            root = self.shell:to_decl(ctx),
        }
    end, function(err)
        local ui = ctx.ui
        return ui.component("terra_daw_error") {
            root = P.fallback_node(ctx, "app/root_error", "Root lowering failed", tostring(err)),
        }
    end)
end

return true
