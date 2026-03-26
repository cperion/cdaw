-- impl/view/components/text.t
-- Shared text atoms for View lowerings.
-- Font scale from design-tokens.md: xs=10, sm=11, md=12, lg=13.

local C = require("src/view/common")

local M = {}

function M.quiet_label(ctx, text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette(ctx).text_muted
    props.font_size = props.font_size or 11
    return ctx.ui.label(props)
end

function M.body_label(ctx, text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette(ctx).text_secondary
    props.font_size = props.font_size or 11
    return ctx.ui.label(props)
end

function M.strong_label(ctx, text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette(ctx).text_primary
    props.font_size = props.font_size or 12
    return ctx.ui.label(props)
end

function M.mono_label(ctx, text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette(ctx).text_primary
    props.font_size = props.font_size or 13
    return ctx.ui.label(props)
end

function M.section_title(ctx, text, scope)
    return ctx.ui.label {
        key = scope,
        text = text,
        font_size = 10,
        text_color = C.palette(ctx).text_muted,
    }
end

return M
