-- impl/view/components/text.t
-- Shared text atoms for View lowerings.
-- Font scale from design-tokens.md: xs=10, sm=11, md=12, lg=13.

local C = require("src/view/common")

local M = {}

function M.quiet_label(text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette().text_muted
    props.font_size = props.font_size or 11
    return C.ui.label(props)
end

function M.body_label(text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette().text_secondary
    props.font_size = props.font_size or 11
    return C.ui.label(props)
end

function M.strong_label(text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette().text_primary
    props.font_size = props.font_size or 12
    return C.ui.label(props)
end

function M.mono_label(text, props)
    props = props or {}
    props.text = text
    props.text_color = props.text_color or C.palette().text_primary
    props.font_size = props.font_size or 13
    return C.ui.label(props)
end

function M.section_title(text, scope)
    return C.ui.label {
        key = scope,
        text = text,
        font_size = 10,
        text_color = C.palette().text_muted,
    }
end

return M
