-- tests/schema_inline_status_fallback.t
-- Block-form inline method clauses: status, fallback, impl.

import "lib/schema"

local schema InlineStatusDemo
    phase Decl
        record Node
            id: string
        end

        methods
            Node:lower(tag: string) -> Out.Node
                status = "partial"
                fallback = function(self, err, tag)
                    local suffix = err and ":fallback" or ":stub"
                    return types.Out.Node(self.id .. tag .. suffix)
                end
                impl = function(self, tag)
                    return types.Out.Node(self.id .. tag .. ":real")
                end

            Node:stub(tag: string) -> Out.Node
                status = "stub"
                fallback = function(self, err, tag)
                    return types.Out.Node(self.id .. tag .. ":stub")
                end

            Node:flaky(tag: string) -> Out.Node
                status = "partial"
                fallback = function(self, err, tag)
                    assert(type(err) == "string")
                    return types.Out.Node(self.id .. tag .. ":recovered")
                end
                impl = function(self, tag)
                    error("boom:" .. tag)
                end
        end
    end

    phase Out
        record Node
            id: string
        end
    end
end

assert(#InlineStatusDemo.methods == 3)
assert(InlineStatusDemo.methods[1].status == "partial")
assert(InlineStatusDemo.methods[1].has_impl == true)
assert(InlineStatusDemo.methods[1].has_fallback == true)
assert(InlineStatusDemo.methods[1].installed_inline == true)
assert(InlineStatusDemo.methods[2].status == "stub")
assert(InlineStatusDemo.methods[2].has_impl == false)
assert(InlineStatusDemo.methods[2].has_fallback == true)
assert(InlineStatusDemo.methods[2].installed_inline == true)

local n = InlineStatusDemo.types.Decl.Node("root")
assert(n:lower("-a").id == "root-a:real")
assert(n:stub("-b").id == "root-b:stub")
assert(n:flaky("-c").id == "root-c:recovered")

print("schema inline status/fallback test passed")
