-- impl/view/launcher/view.t
-- View.LauncherView:to_decl()

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
diag.status("view.launcher_view.to_decl", "real")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local P = require("impl/view/components/placeholder_panel")
local column = require("impl/view/launcher/column")

local M = {}

local function lower(self, ctx)
    return diag.wrap(ctx, "view.launcher_view.to_decl", "real", function()
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, "launcher")
        local scene_children = {}
        local column_children = {}

        for i = 1, #self.scenes do
            C.push(scene_children, column.lower_scene(self.scenes[i], ctx, ctx.selection))
        end
        for i = 1, #self.columns do
            local col = self.columns[i]
            local stop_cell = column.find_stop_cell(self.stop_row, col.track_ref)
            C.push(column_children, column.lower_column(col, stop_cell, ctx, ctx.selection))
        end

        local children = {
            ui.row {
                key = scope:child("workspace"),
                width = ui.grow(),
                height = ui.grow(),
                gap = 0,
                background = p.surface_panel,
            } {
                ui.column {
                    key = scope:child("scene_rail"),
                    width = ui.fixed(74),
                    height = ui.grow(),
                    gap = 4,
                    padding = { left = 4, top = 0, right = 4, bottom = 4 },
                    background = p.surface_ruler,
                    border = ui.border { right = 1, color = p.border_separator },
                } {
                    ui.row {
                        key = scope:child("scene_spacer"),
                        width = ui.grow(),
                        height = ui.fixed(28),
                        align_y = ui.align_y.center,
                    } {
                        T.quiet_label(ctx, "SCN", {
                            key = scope:child("scene_label"),
                            width = ui.grow(),
                            font_size = 9,
                            text_color = p.text_primary,
                        }),
                    },
                    ui.row {
                        key = scope:child("stop_label_row"),
                        width = ui.grow(),
                        height = ui.fixed(18),
                        align_y = ui.align_y.center,
                    } {
                        T.quiet_label(ctx, "■", {
                            key = scope:child("stop_label"),
                            width = ui.grow(),
                            font_size = 10,
                        }),
                    },
                    ui.column {
                        key = scope:child("scene_buttons"),
                        width = ui.grow(),
                        height = ui.fit(),
                        gap = 4,
                    } (scene_children),
                },
                ui.scroll_region {
                    key = scope:child("columns_scroll"),
                    width = ui.grow(),
                    height = ui.grow(),
                    horizontal = true,
                    vertical = true,
                    background = p.surface_panel,
                } {
                    ui.row {
                        key = scope:child("columns"),
                        width = ui.fit(),
                        height = ui.grow(),
                        gap = 4,
                        padding = { left = 4, top = 4, right = 4, bottom = 4 },
                        align_y = ui.align_y.top,
                    } (column_children),
                },
            },
        }
        P.overlay_children(ctx, scope, self.identity, children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
            background = p.surface_panel,
            border = ui.border { right = 1, color = p.border_separator },
        } (children)
    end, function(err)
        return P.fallback_node(ctx, C.identity_key(self.identity), "view.launcher_view.to_decl", tostring(err))
    end)
end

local to_decl_impl = terralib.memoize(function(self)
    return lower(self, C.new_view_ctx())
end)

M.lower = lower

function V.LauncherView:to_decl()
    return to_decl_impl(self)
end

return M
