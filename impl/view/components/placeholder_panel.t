-- impl/view/components/placeholder_panel.t
-- Shared degraded/error placeholder subtree for View lowerings.
--
-- fallback_node() builds a visible error placeholder panel.
-- safe_node() is DEPRECATED — use diag.wrap() with a fallback that
-- calls fallback_node() instead.  Kept temporarily for compatibility.

local C = require("impl/view/_support/common")
local diag = require("impl/_support/diagnostics")

local M = {}

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

-- DEPRECATED: use diag.wrap() instead.
-- Kept for backward compatibility during migration.
function M.safe_node(ctx, key, code, f)
    local ok, out = pcall(f)
    if ok then return out end
    C.record_diag(ctx, "error", code, out)
    return M.fallback_node(ctx, key, code, tostring(out))
end

return M
