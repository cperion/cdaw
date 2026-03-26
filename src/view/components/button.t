-- impl/view/components/button.t
-- Shared compact button atom for View lowerings.
-- Sizing follows design-tokens.md: xs=20, sm=24, md=28, lg=32.

local C = require("src/view/common")

local M = {}

-- Standard utility button (design system "neutral" variant).
function M.flat_button(ctx, text, action, props)
    props = props or {}
    local ui = ctx.ui
    local p = C.palette(ctx)
    props.text = text
    props.action = action
    props.height = props.height or ui.fixed(24)
    props.padding = props.padding or { left = 8, top = 0, right = 8, bottom = 0 }
    props.background = props.background or p.surface_control
    props.border = props.border or C.border(ctx, p.border_control, 1)
    props.radius = props.radius or ui.radius(3)
    props.text_color = props.text_color or p.text_primary
    props.font_size = props.font_size or 11
    return ui.button(props)
end

-- Ghost/minimal button — transparent bg, secondary text.
function M.ghost_button(ctx, text, action, props)
    props = props or {}
    local ui = ctx.ui
    local p = C.palette(ctx)
    props.text = text
    props.action = action
    props.height = props.height or ui.fixed(24)
    props.padding = props.padding or { left = 6, top = 0, right = 6, bottom = 0 }
    props.background = props.background or nil
    props.border = props.border or nil
    props.radius = props.radius or ui.radius(3)
    props.text_color = props.text_color or p.text_secondary
    props.font_size = props.font_size or 11
    return ui.button(props)
end

-- Transport-sized button (slightly taller, icon-friendly).
function M.transport_button(ctx, text, action, props)
    props = props or {}
    local ui = ctx.ui
    local p = C.palette(ctx)
    props.text = text
    props.action = action
    props.height = props.height or ui.fixed(28)
    props.padding = props.padding or { left = 6, top = 0, right = 6, bottom = 0 }
    props.background = props.background or p.surface_control
    props.border = props.border or C.border(ctx, p.border_control, 1)
    props.radius = props.radius or ui.radius(3)
    props.text_color = props.text_color or p.text_primary
    props.font_size = props.font_size or 12
    return ui.button(props)
end

return M
