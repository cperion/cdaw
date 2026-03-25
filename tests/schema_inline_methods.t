-- tests/schema_inline_methods.t
-- Smoke test for inline method bodies in the schema DSL.

import "lib/schema"

local suffix = "!"

local schema InlineDemo
    phase Decl
        record Node
            id: string
        end

        enum Expr
            Lit { value: number }
            Neg { inner: Expr }
        end

        methods
            Node:lower(tag: string) -> Out.Node = function(self, tag)
                return types.Out.Node(self.id .. tag .. suffix)
            end

            Lit:eval() -> number = function(self)
                return self.value
            end

            Neg:eval() -> number = function(self)
                return -self.inner:eval()
            end

            Expr:eval() -> number = function(self)
                error("missing eval for " .. tostring(self.kind))
            end

            Node:broken() -> Out.Node = function(self)
                return self.id
            end
        end
    end

    phase Out
        record Node
            id: string
        end
    end
end

assert(#InlineDemo.methods == 5)
assert(InlineDemo.methods[1].inline == true)

local lowered = InlineDemo.types.Decl.Node("root"):lower("-x")
assert(InlineDemo.types.Out.Node:isclassof(lowered))
assert(lowered.id == "root-x!")

local lit = InlineDemo.types.Decl.Lit(3)
local neg = InlineDemo.types.Decl.Neg(lit)
assert(lit:eval() == 3)
assert(neg:eval() == -3)

local ok_arg, err_arg = pcall(function()
    InlineDemo.types.Decl.Node("root"):lower(42)
end)
assert(not ok_arg)
assert(err_arg:match("argument 'tag' expected string"))

local ok_ret, err_ret = pcall(function()
    InlineDemo.types.Decl.Node("root"):broken()
end)
assert(not ok_ret)
assert(err_ret:match("returned string, expected Out%.Node"))

print("schema inline methods test passed")
