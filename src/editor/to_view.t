-- src/editor/to_view.t
-- Editor.Project:to_view() -> View.Root
-- Projects the editor state into a View tree for UI rendering.
-- This is the boundary method for the Editor -> View pipeline edge.

return function(types)
    local V = types.View
    local List = require("terralist")
    local function L() return List() end

    return function(self)
        -- Lazy require to avoid circular dependency during schema construction
        local bootstrap = require("app/bootstrap")
        return bootstrap.bootstrap_root()
    end
end
