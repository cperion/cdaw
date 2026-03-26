-- impl/view/inspector/section_view.t
-- Lowering helper for View.InspectorSectionView.

local C = require("src/view/common")
local F = require("src/view/components/panel_frame")
local field_view = require("src/view/inspector/field_view")
local P = require("src/view/components/placeholder_panel")

local M = {}

function M.lower(section, scope, section_index)
    local field_children = {}
    for k = 1, #section.fields do
        C.push(field_children, field_view.lower(section.fields[k], scope, section_index, k))
    end

    local section_scope = C.make_scope(section.identity, C.identity_key(section.identity))
    local section_node = F.section(
        section_scope:child("frame"),
        section.label,
        {
            padding = { left = 0, top = 4, right = 0, bottom = 4 },
            body_background = C.palette().surface_panel,
            body_border = C.border( C.palette().border_subtle, 1),
        },
        field_children)
    local children = { section_node }
    P.overlay_children(section_scope, section.identity, children)
    return C.ui.column {
        key = section_scope,
        width = C.ui.grow(),
        height = C.ui.fit(),
        gap = 0,
    } (children)
end

return M
