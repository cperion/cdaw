-- impl/view/grid_patch_view.t
-- View.GridPatchView:to_decl()
-- Free-patch canvas: positioned modules + cable decorations.


local C = require("src/view/common")
local T = require("src/view/components/text")
local B = require("src/view/components/button")
local P = require("src/view/components/placeholder_panel")

local M = {}

-- ── Helper: lower a single module view ──

local function lower_module(mod, ctx)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local mscope = C.make_scope(ctx, mod.identity, C.identity_key(mod.identity))
    local compile_status = C.compile_status(ctx, mod.module_ref or mod.identity)
    local compile_pending = C.compile_is_pending(compile_status)
    local compile_failed = C.compile_is_failed(compile_status)

    -- Module name from context or ref
    local name = "Module"
    if mod.module_ref and mod.module_ref.module_id then
        name = "Module " .. tostring(mod.module_ref.module_id)
    end

    -- Collect port anchors for display
    local port_children = {}
    if mod.anchors then
        for i = 1, #mod.anchors do
            local a = mod.anchors[i]
            local ak = a.kind and a.kind.kind
            if ak == "ModuleInputPortA" then
                C.push(port_children, ui.row {
                    key = mscope:child("in_" .. tostring(a.port_id or i)),
                    width = ui.grow(),
                    height = ui.fixed(14),
                    align_y = ui.align_y.center,
                } {
                    ui.column {
                        key = mscope:child("in_dot_" .. tostring(a.port_id or i)),
                        width = ui.fixed(6),
                        height = ui.fixed(6),
                        background = p.track_accent,
                    } {},
                    T.quiet_label(ctx, "in " .. tostring(a.port_id or i), {
                        key = mscope:child("in_lbl_" .. tostring(a.port_id or i)),
                        font_size = 9,
                        width = ui.grow(),
                    }),
                })
            elseif ak == "ModuleOutputPortA" then
                C.push(port_children, ui.row {
                    key = mscope:child("out_" .. tostring(a.port_id or i)),
                    width = ui.grow(),
                    height = ui.fixed(14),
                    align_y = ui.align_y.center,
                } {
                    T.quiet_label(ctx, "out " .. tostring(a.port_id or i), {
                        key = mscope:child("out_lbl_" .. tostring(a.port_id or i)),
                        font_size = 9,
                        width = ui.grow(),
                    }),
                    ui.column {
                        key = mscope:child("out_dot_" .. tostring(a.port_id or i)),
                        width = ui.fixed(6),
                        height = ui.fixed(6),
                        background = p.track_accent,
                    } {},
                })
            end
        end
    end

    local card_children = {
        T.strong_label(ctx, name, {
            key = mscope:child("title"),
            width = ui.grow(),
            font_size = 11,
        }),
        ui.column {
            key = mscope:child("ports"),
            width = ui.grow(),
            height = ui.fit(),
            gap = 1,
        } (port_children),
    }

    if compile_failed then
        C.push(card_children, P.surface_overlay(
            ctx,
            mscope:child("failed_overlay"),
            compile_status,
            compile_status.detail or "Module unavailable"
        ))
    elseif compile_pending then
        C.push(card_children, P.surface_overlay(
            ctx,
            mscope:child("pending_overlay"),
            compile_status,
            compile_status.detail or "Compiling…"
        ))
    end

    -- Module card
    return ui.column {
        key = mscope,
        width = ui.fixed(120),
        height = ui.fit(),
        gap = 2,
        padding = { left = 6, top = 6, right = 6, bottom = 6 },
        background = p.surface_device,
        border = C.border(ctx, compile_pending and p.border_pending or (compile_failed and p.border_warning or p.border_authored), 1),
    } (card_children)
end

-- ── Helper: lower cable decoration (visual indicator) ──

local function lower_cable(cable, ctx, index)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local cscope = C.make_scope(ctx, cable.identity, C.identity_key(cable.identity))

    local from_label = "?"
    if cable.from_module_ref and cable.from_module_ref.module_id then
        from_label = tostring(cable.from_module_ref.module_id) .. ":" .. tostring(cable.from_port)
    end
    local to_label = "?"
    if cable.to_module_ref and cable.to_module_ref.module_id then
        to_label = tostring(cable.to_module_ref.module_id) .. ":" .. tostring(cable.to_port)
    end

    local row = ui.row {
        key = cscope:child("base"),
        width = ui.grow(),
        height = ui.fixed(16),
        gap = 4,
        align_y = ui.align_y.center,
        padding = { left = 6, top = 0, right = 6, bottom = 0 },
    } {
        T.quiet_label(ctx, from_label, {
            key = cscope:child("from"),
            font_size = 9,
            width = ui.fit(),
            text_color = p.track_accent,
        }),
        T.quiet_label(ctx, "→", {
            key = cscope:child("arrow"),
            font_size = 9,
            width = ui.fit(),
        }),
        T.quiet_label(ctx, to_label, {
            key = cscope:child("to"),
            font_size = 9,
            width = ui.fit(),
            text_color = p.track_accent,
        }),
    }
    return P.wrap_node(ctx, cscope, cable.identity, row, {
        width = ui.grow(),
        height = ui.fixed(16),
    })
end


-- ═══════════════════════════════════════════════════════════════════════
-- GridPatchView:to_decl
-- ═══════════════════════════════════════════════════════════════════════

local function lower(self, ctx)
        local ui = ctx.ui
        local p = C.palette(ctx)
        local scope = C.make_scope(ctx, self.identity, C.identity_key(self.identity))

        -- Module cards
        local module_children = {}
        for i = 1, #self.modules do
            C.push(module_children, lower_module(self.modules[i], ctx))
        end

        -- Cable indicators
        local cable_children = {}
        for i = 1, #self.cables do
            C.push(cable_children, lower_cable(self.cables[i], ctx, i))
        end

        -- Add module button
        local add_cmd = C.find_command(self.commands, "GPCCAddModule")

        local patch_children = {
            -- Header
            ui.row {
                key = scope:child("header"),
                width = ui.grow(),
                height = ui.fixed(22),
                align_y = ui.align_y.center,
            } {
                T.section_title(ctx, "GRID PATCH", scope:child("title")),
                ui.spacer { key = scope:child("hgap"), width = ui.grow(), height = ui.fixed(0) },
                B.flat_button(ctx, "+ Module", add_cmd and add_cmd.action_id or nil, {
                    key = scope:child("add"),
                    width = ui.fixed(80),
                    height = ui.fixed(20),
                    font_size = 10,
                    background = p.surface_accent_soft,
                    border = C.border(ctx, p.border_focus, 1),
                }),
            },
            -- Scrollable canvas with modules
            ui.scroll_region {
                key = scope:child("canvas"),
                width = ui.grow(),
                height = ui.grow(),
                horizontal = true,
                vertical = true,
            } {
                ui.column {
                    key = scope:child("canvas_inner"),
                    width = ui.fit(),
                    height = ui.fit(),
                    gap = 8,
                } {
                    -- Module grid (wrapped row)
                    ui.row {
                        key = scope:child("modules"),
                        width = ui.fit(),
                        height = ui.fit(),
                        gap = 12,
                        align_y = ui.align_y.top,
                    } (module_children),
                    -- Cable list (structural representation)
                    (#cable_children > 0) and ui.column {
                        key = scope:child("cables"),
                        width = ui.grow(),
                        height = ui.fit(),
                        gap = 1,
                        background = p.surface_inset,
                        border = C.border(ctx, p.border_subtle, 1),
                        padding = { left = 4, top = 4, right = 4, bottom = 4 },
                    } (cable_children) or ui.spacer {
                        key = scope:child("no_cables"),
                        width = ui.fixed(0),
                        height = ui.fixed(0),
                    },
                },
            },
        }

        P.overlay_children(ctx, scope, self.device_ref or self.identity, patch_children)

        return ui.column {
            key = scope,
            width = ui.grow(),
            height = ui.grow(),
            gap = 6,
            background = p.surface_detail,
            border = ui.border { top = 1, color = p.border_separator },
            padding = { left = 8, top = 8, right = 8, bottom = 8 },
        } (patch_children)

end


M.lower = lower


return M
