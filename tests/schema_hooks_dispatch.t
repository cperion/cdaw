-- tests/schema_hooks_dispatch.t
-- Minimal exotype dispatch-hook DSL support.

import "lib/schema"

local schema HookDemo
    doc = [[Schema with dispatch exotype hooks.]]

    phase Decl
        doc = [[Authoring phase.]]

        record Node
            doc = [[Simple node.]]
            id: string
        end

        methods
            doc = [[Boundary methods.]]
            Node:lower() -> Out.Node
                doc = [[Lower node to output node.]]
                impl = function(self)
                    return types.Out.Node(self.id)
                end
        end
    end

    phase Out
        doc = [[Output phase.]]

        record Node
            doc = [[Output node.]]
            id: string
        end
    end

    hooks LayerRuntime
        doc = [[Lazy Terra-side dispatch hooks for layer runtime.]]

        methodmissing
            doc = [[Resolve open-ended runtime methods lazily.]]
            macro = function(name, obj, ...)
                return `0
            end

        entrymissing
            doc = [[Resolve lazy property access.]]
            macro = function(name, obj)
                return `1
            end

        getmethod
            doc = [[Resolve known methods before methodmissing.]]
            impl = function(self_t, methodname)
                if methodname == "known" then
                    return function() end
                end
                return nil
            end
    end
end

assert(#HookDemo.hooks == 3)
assert(HookDemo.hooks[1].category == "exotype_hook")
assert(HookDemo.hooks[1].family == "dispatch")
assert(HookDemo.hooks[1].implementation_kind == "macro")
assert(HookDemo.hooks[1].target == "LayerRuntime")
assert(HookDemo.hooks[1].key == "__methodmissing")
assert(HookDemo.hooks[2].key == "__entrymissing")
assert(HookDemo.hooks[3].implementation_kind == "lua_function")
assert(HookDemo.hooks[3].key == "__getmethod")

local target = { metamethods = {} }
local installed = HookDemo:install_hooks({ LayerRuntime = target })
assert(#installed == 3)
assert(target.metamethods.__methodmissing ~= nil)
assert(target.metamethods.__entrymissing ~= nil)
assert(target.metamethods.__getmethod ~= nil)

assert(HookDemo.inventory ~= nil)
assert(#HookDemo.inventory.hooks == 3)
assert(#HookDemo.inventory.hook_targets == 1)
assert(HookDemo.inventory.hook_targets[1].target == "LayerRuntime")
assert(HookDemo.surface:find('hooks LayerRuntime', 1, true) ~= nil)
assert(HookDemo.surface:find('methodmissing', 1, true) ~= nil)
assert(HookDemo.surface:find('entrymissing', 1, true) ~= nil)
assert(HookDemo.surface:find('getmethod', 1, true) ~= nil)
assert(HookDemo.surface:find('macro', 1, true) == nil)
assert(HookDemo.markdown:find('## Hook target index', 1, true) ~= nil)
assert(HookDemo.markdown:find('- [LayerRuntime](#hooks-layerruntime)', 1, true) ~= nil)
assert(HookDemo.markdown:find('## Exotype hooks', 1, true) ~= nil)
assert(HookDemo.markdown:find('### Hooks for `LayerRuntime`', 1, true) ~= nil)
assert(HookDemo.markdown:find('implementation_kind: `macro`', 1, true) ~= nil)
assert(HookDemo.markdown:find('target: `LayerRuntime`', 1, true) ~= nil)

print("schema hooks dispatch test passed")
