-- impl/view/inspector/section_view.t
-- Lowering helper for View.InspectorSectionView.

local C = require("impl/view/_support/common")
local F = require("impl/view/components/panel_frame")
local field_view = require("impl/view/inspector/field_view")
local P = require("impl/view/components/placeholder_panel")

local M = {}

function M.lower(section, ctx, scope, section_index)
    local field_children = {}
    for k = 1, #section.fields do
        C.push(field_children, field_view.lower(section.fields[k], ctx, scope, section_index, k))
    end

    local section_scope = C.make_scope(ctx, section.identity, C.identity_key(section.identity))
    local section_node = F.section(ctx,
        section_scope:child("frame"),
        section.label,
        {
            padding = { left = 0, top = 4, right = 0, bottom = 4 },
            body_background = C.palette(ctx).surface_panel,
            body_border = C.border(ctx, C.palette(ctx).border_subtle, 1),
        },
        field_children)
    local children = { section_node }
    P.overlay_children(ctx, section_scope, section.identity, children)
    return ctx.ui.column {
        key = section_scope,
        width = ctx.ui.grow(),
        height = ctx.ui.fit(),
        gap = 0,
    } (children)
end

return M
