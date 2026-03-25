-- impl/view/inspector/field_view.t
-- Lowering helper for View.InspectorFieldView.

local D = require("daw-unified")
local V = D.View

local C = require("impl/view/_support/common")
local T = require("impl/view/components/text")
local R = require("impl/view/components/list_row")

local M = {}

function M.lower(field, ctx, scope, section_index, field_index)
    local field_cmd = C.find_command(field.commands, V.ICCSetValue)
        or C.find_command(field.commands, V.ICCToggleFlag)

    if field.kind.kind == "ActionField" then
        return R.action_value(ctx,
            C.make_scope(ctx, field.identity, C.identity_key(field.identity)),
            field.label,
            field_cmd and field_cmd.action_id or nil,
            { button_text = "Edit" })
    end

    local value_text = field.kind.kind == "ToggleField" and "On" or "Value"
    return R.value_row(ctx,
        C.make_scope(ctx, field.identity, C.identity_key(field.identity)),
        field.label,
        T.strong_label(ctx, value_text, {
            key = scope:child("field_value_" .. tostring(section_index) .. "_" .. tostring(field_index)),
            font_size = 12,
        }))
end

return M
