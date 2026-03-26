-- impl/view/launcher/view.t
-- View.LauncherView:to_decl()


local C = require("src/view/common")
local T = require("src/view/components/text")
local P = require("src/view/components/placeholder_panel")
local column = require("src/view/launcher/column")

local M = {}

local function lower(self, ctx)
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

end


M.lower = lower


return M
