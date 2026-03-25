-- tests/schema_inline_memoized.t
-- Schema-declared inline methods should memoize by explicit semantic inputs.

import "lib/schema"

local counts = {
    lower = 0,
    flaky_impl = 0,
    flaky_fallback = 0,
}

local schema MemoDemo
    phase Decl
        record Node
            id: string
        unique
        end

        methods
            Node:lower(tag: string) -> Out.Node
                status = "real"
                impl = function(self, tag)
                    counts.lower = counts.lower + 1
                    return types.Out.Node(self.id .. tag)
                end

            Node:flaky(tag: string) -> Out.Node
                status = "partial"
                fallback = function(self, err, tag)
                    counts.flaky_fallback = counts.flaky_fallback + 1
                    return types.Out.Node(self.id .. tag .. ":fallback")
                end
                impl = function(self, tag)
                    counts.flaky_impl = counts.flaky_impl + 1
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

assert(#MemoDemo.methods == 2)
assert(MemoDemo.methods[1].memoized == true)
assert(MemoDemo.methods[1].installed_memoized == true)
assert(MemoDemo.methods[2].memoized == true)
assert(MemoDemo.methods[2].installed_memoized == true)

local n1 = MemoDemo.types.Decl.Node("root")
local n2 = MemoDemo.types.Decl.Node("root")
assert(n1 == n2)

local a1 = n1:lower("-x")
local a2 = n1:lower("-x")
local a3 = n2:lower("-x")
local b1 = n1:lower("-y")

assert(a1 == a2)
assert(a1 == a3)
assert(a1.id == "root-x")
assert(b1.id == "root-y")
assert(counts.lower == 2)

local f1 = n1:flaky("-z")
local f2 = n1:flaky("-z")
local f3 = n2:flaky("-z")
assert(f1 == f2)
assert(f1 == f3)
assert(f1.id == "root-z:fallback")
assert(counts.flaky_impl == 1)
assert(counts.flaky_fallback == 1)

print("schema inline memoized test passed")
