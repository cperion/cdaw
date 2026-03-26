-- impl/view/components/panel_frame.t
-- Shared framed/panel containers for View lowerings.

local C = require("src/view/common")
local T = require("src/view/components/text")

local M = {}

function M.column(scope, props, children)
    props = C.panel(props)
    props.key = props.key or scope
    props.width = props.width or C.ui.grow()
    props.height = props.height or C.ui.fit()
    return C.ui.column(props)(children)
end

function M.section(scope, title, props, children)
    local ui = C.ui
    props = props or {}
    local gap = props.gap or 2
    local body_props = {
        key = scope:child("body"),
        width = props.body_width or ui.grow(),
        height = props.body_height or ui.fit(),
        gap = props.body_gap or 0,
        background = props.body_background or C.palette().surface_panel,
        border = props.body_border or C.border( C.palette().border_subtle, 1),
    }

    return ui.column {
        key = scope,
        width = props.width or ui.grow(),
        height = props.height or ui.fit(),
        gap = gap,
        padding = props.padding or { left = 0, top = 2, right = 0, bottom = 2 },
    } {
        T.section_title(title, scope:child("title")),
        ui.column(body_props)(children),
    }
end

return M
