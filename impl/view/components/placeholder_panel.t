-- impl/view/components/placeholder_panel.t
-- Shared degraded/error placeholder subtree for View lowerings.
--
-- fallback_node() builds a visible error placeholder panel.

local C = require("impl/view/_support/common")

local M = {}

local function as_scope(ctx, key)
    if type(key) == "string" then return ctx.ui.scope(key) end
    return key
end

local function as_status(ctx, target_or_status)
    if target_or_status == nil then return { state = "ready" } end
    if type(target_or_status) == "string" then
        if target_or_status == "ready" or target_or_status == "pending" or target_or_status == "queued"
            or target_or_status == "compiling" or target_or_status == "failed"
            or target_or_status == "error" or target_or_status == "degraded" then
            return { state = target_or_status }
        end
        return C.compile_status(ctx, target_or_status)
    end
    if type(target_or_status) == "table" and (target_or_status.state ~= nil or target_or_status.detail ~= nil or target_or_status.label ~= nil) then
        return target_or_status
    end
    return C.compile_status(ctx, target_or_status)
end

function M.overlay_children(ctx, scope, target_or_status, children, text)
    local status = as_status(ctx, target_or_status)
    if not C.compile_is_pending(status) and not C.compile_is_failed(status) then
        return children
    end
    C.push(children, M.surface_overlay(
        ctx,
        as_scope(ctx, scope):child("compile_overlay"),
        status,
        text or status.detail
    ))
    return children
end

function M.wrap_node(ctx, scope, target_or_status, child, opts, text)
    opts = opts or {}
    local ui = ctx.ui
    local children = { child }
    M.overlay_children(ctx, scope, target_or_status, children, text)
    return ui.stack {
        key = as_scope(ctx, scope),
        width = opts.width or ui.grow(),
        height = opts.height or ui.fit(),
        background = opts.background,
        border = opts.border,
        visible_when = opts.visible_when,
    } (children)
end

function M.surface_overlay(ctx, key, status, text)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = as_scope(ctx, key)
    local s = type(status) == "table" and status.state or status
    local label = text or C.compile_label(status)
    local bg = ui.rgba(0.149, 0.129, 0.094, 0.84)
    local border = p.border_pending
    local text_color = p.text_pending

    if s == "failed" or s == "error" or s == "degraded" then
        bg = ui.rgba(0.120, 0.090, 0.070, 0.90)
        border = p.border_warning
        text_color = p.text_warning
    elseif s == "queued" then
        bg = ui.rgba(0.078, 0.090, 0.102, 0.80)
        border = p.border_subtle
        text_color = p.text_secondary
    end

    return ui.tooltip {
        key = scope,
        target = ui.float.parent,
        parent_point = ui.attach.left_top,
        element_point = ui.attach.left_top,
        width = ui.grow(),
        height = ui.grow(),
        z_index = 20,
        padding = { left = 0, top = 0, right = 0, bottom = 0 },
        background = bg,
        border = C.border(ctx, border, 1),
        pointer_capture = ui.pointer_capture.passthrough,
    } {
        ui.column {
            key = scope:child("body"),
            width = ui.grow(),
            height = ui.grow(),
            gap = 0,
        } {
            ui.spacer { key = scope:child("top"), width = ui.fixed(0), height = ui.grow() },
            ui.row {
                key = scope:child("center"),
                width = ui.grow(),
                height = ui.fit(),
                align_y = ui.align_y.center,
            } {
                ui.spacer { key = scope:child("left"), width = ui.grow(), height = ui.fixed(0) },
                ui.label {
                    key = scope:child("text"),
                    text = label,
                    text_color = text_color,
                    font_size = 11,
                },
                ui.spacer { key = scope:child("right"), width = ui.grow(), height = ui.fixed(0) },
            },
            ui.spacer { key = scope:child("bottom"), width = ui.fixed(0), height = ui.grow() },
        },
    }
end

function M.fallback_node(ctx, key, title, detail)
    local ui = ctx.ui
    local p = C.palette(ctx)
    local scope = ui.scope(key)
    return ui.column {
        key = scope,
        width = ui.grow(),
        height = ui.grow(),
        background = p.surface_panel,
        border = C.border(ctx, p.border_warning, 1),
        padding = { left = 10, top = 10, right = 10, bottom = 10 },
        gap = 6,
    } {
        ui.label {
            key = scope:child("title"),
            text = title,
            text_color = p.text_warning,
            font_size = 13,
        },
        ui.label {
            key = scope:child("detail"),
            text = detail,
            text_color = p.text_muted,
            font_size = 12,
            wrap = ui.wrap.words,
            width = ui.grow(),
        },
    }
end

return M
