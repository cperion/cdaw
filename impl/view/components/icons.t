-- impl/view/components/icons.t
-- Semantic icon library for Terra DAW.
--
-- Icons use ui.custom nodes drawn by the GPU via draw_custom callback.
-- Each icon maps to an ASDL semantic concept from the View module.
-- The `kind` string identifies the icon shape; `payload` carries the color.
--
-- Icon kinds follow the pattern "icon.<name>" so the draw_custom
-- dispatcher can route them with a simple strcmp prefix check.

local C = require("impl/view/_support/common")

local M = {}

-- ── Helpers ──

local function defaults(ctx, size, color)
    size = size or 12
    color = color or C.palette(ctx).text_primary
    return size, color
end

-- Create a ui.custom icon node with the given kind, size, and color.
local function icon_node(ctx, scope, kind, size, color)
    local ui = ctx.ui
    return ui.custom {
        key = scope,
        kind = kind,
        payload = color,
        width = ui.fixed(size),
        height = ui.fixed(size),
    }
end

-- ═══════════════════════════════════════════════════════════════════════
-- Transport icons — TCCPlay, TCCStop, TCCToggleRecord, TCCToggleLoop
-- ═══════════════════════════════════════════════════════════════════════

function M.play(ctx, scope, size, color)
    size, color = defaults(ctx, size, color)
    return icon_node(ctx, scope, "icon.play", size, color)
end

function M.stop(ctx, scope, size, color)
    size, color = defaults(ctx, size, color)
    return icon_node(ctx, scope, "icon.stop", size, color)
end

function M.record(ctx, scope, size, color)
    size = size or 12
    color = color or C.palette(ctx).state_record
    return icon_node(ctx, scope, "icon.record", size, color)
end

function M.loop(ctx, scope, size, color)
    size, color = defaults(ctx, size, color)
    return icon_node(ctx, scope, "icon.loop", size, color)
end

-- ═══════════════════════════════════════════════════════════════════════
-- Track state icons — TrackArmedF, TrackSoloedF, TrackMutedF
-- ═══════════════════════════════════════════════════════════════════════

function M.arm(ctx, scope, size, color)
    size = size or 12
    color = color or C.palette(ctx).state_record
    return icon_node(ctx, scope, "icon.record", size, color)
end

function M.solo(ctx, scope, size, color)
    size, color = defaults(ctx, size, color)
    return icon_node(ctx, scope, "icon.solo", size, color)
end

function M.mute(ctx, scope, size, color)
    size, color = defaults(ctx, size, color)
    return icon_node(ctx, scope, "icon.mute", size, color)
end

-- ═══════════════════════════════════════════════════════════════════════
-- Action icons
-- ═══════════════════════════════════════════════════════════════════════

function M.plus(ctx, scope, size, color)
    size, color = defaults(ctx, size, color)
    return icon_node(ctx, scope, "icon.plus", size, color)
end

function M.meter(ctx, scope, size, color)
    size, color = defaults(ctx, size, color)
    return icon_node(ctx, scope, "icon.meter", size, color)
end

-- ═══════════════════════════════════════════════════════════════════════
-- Icon button: interactive row containing a centered icon.
-- The row has hover/press/action input — the icon is a child, not
-- an overlay, so it renders on top of the row background naturally.
-- ═══════════════════════════════════════════════════════════════════════

function M.icon_button(ctx, scope, icon_fn, action, props)
    props = props or {}
    local ui = ctx.ui
    local p = C.palette(ctx)
    local size = props.size or 20
    local icon_size = props.icon_size or math.max(6, math.floor(size * 0.55))
    local icon_color = props.icon_color or p.text_primary

    return ui.row {
        key = scope,
        width = ui.fixed(size),
        height = ui.fixed(size),
        gap = 0,
        align_y = ui.align_y.center,
        background = props.background or p.surface_control,
        border = props.border or C.border(ctx, p.border_control, 1),
        radius = props.radius or ui.radius(3),
        hover = true,
        press = true,
        action = action,
    } {
        ui.spacer { key = scope:child("_l"), width = ui.grow(), height = ui.fixed(0) },
        icon_fn(ctx, scope:child("ic"), icon_size, icon_color),
        ui.spacer { key = scope:child("_r"), width = ui.grow(), height = ui.fixed(0) },
    }
end

return M
