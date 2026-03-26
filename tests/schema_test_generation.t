-- tests/schema_test_generation.t
-- Derived test inventory, test markdown, and skeletons should be emitted from schema metadata.

import "lib/schema"

local is_terra_func = terralib.isfunction or function(v)
    return type(v) == "userdata" or type(v) == "cdata" or type(v) == "function"
end

terra unit_nop()
end

local schema TestPlanDemo
    doc = [[Schema used to validate derived test planning outputs.]]

    extern TerraFunc = is_terra_func
    extern TerraType = terralib.types.istype

    phase Scheduled
        doc = [[Scheduled phase.]]

        record GraphProgram
            doc = [[Program scheduled for compilation.]]
            id: number
        end

        methods
            doc = [[Public scheduled-phase boundaries.]]

            GraphProgram:compile() -> Unit
                doc = [[Compile a graph program into an owned kernel unit.]]
                status = "real"
                fallback = function(self, err)
                    return types.Unit(unit_nop, int)
                end
                impl = function(self)
                    return types.Unit(unit_nop, int)
                end

            GraphProgram:label() -> Kernel.Label
                doc = [[Produce a human-readable label.]]
                impl = function(self)
                    return types.Kernel.Label("g" .. tostring(self.id))
                end
        end
    end

    phase Kernel
        doc = [[Kernel phase.]]

        record Label
            doc = [[Display label.]]
            text: string
        end
    end

    hooks Runtime.Grouped
        doc = [[Runtime hooks for a nested target.]]

        getentries
            doc = [[Enumerate runtime entries.]]
            impl = function(self) return {} end

        methodmissing
            doc = [[Resolve missing methods lazily.]]
            macro = function(name, obj, ...)
                return `0
            end
    end
end

assert(TestPlanDemo.tests ~= nil)
assert(#TestPlanDemo.tests.methods == 2)
assert(#TestPlanDemo.tests.hooks == 2)
assert(TestPlanDemo.tests.totals.method_units == 2)
assert(TestPlanDemo.tests.totals.hook_units == 2)
assert(TestPlanDemo.tests.totals.case_count == 10)

local compile_unit = TestPlanDemo.tests.methods[1]
assert(compile_unit.key == "Scheduled.GraphProgram:compile")
assert(compile_unit.path == "tests/scheduled/graphprogram/compile.t")
assert(#compile_unit.cases == 4)
assert(compile_unit.cases[1].kind == "boundary")
assert(compile_unit.cases[2].kind == "fallback")
assert(compile_unit.cases[3].kind == "memoization")
assert(compile_unit.cases[4].kind == "compile_product_ownership")
assert(compile_unit.content:find("Generated skeleton for Scheduled.GraphProgram:compile", 1, true) ~= nil)
assert(compile_unit.content:find("tests/scheduled/graphprogram/compile.t", 1, true) ~= nil)
assert(compile_unit.content:find("construct a valid receiver of type `Scheduled.GraphProgram`", 1, true) ~= nil)

local label_unit = TestPlanDemo.tests.methods[2]
assert(label_unit.key == "Scheduled.GraphProgram:label")
assert(#label_unit.cases == 2)
assert(label_unit.cases[1].kind == "boundary")
assert(label_unit.cases[2].kind == "memoization")

local getentries_unit = TestPlanDemo.tests.hooks[1]
assert(getentries_unit.key == "Runtime.Grouped.getentries")
assert(getentries_unit.path == "tests/hooks/runtime/grouped/getentries.t")
assert(#getentries_unit.cases == 2)
assert(getentries_unit.cases[1].kind == "installation")
assert(getentries_unit.cases[2].kind == "layout_behavior")
assert(getentries_unit.content:find("schema:install_hooks(bindings)", 1, true) ~= nil)
assert(getentries_unit.content:find("target.metamethods.__getentries", 1, true) ~= nil)

local missing_unit = TestPlanDemo.tests.hooks[2]
assert(missing_unit.key == "Runtime.Grouped.methodmissing")
assert(#missing_unit.cases == 2)
assert(missing_unit.cases[2].kind == "dispatch_behavior")

assert(TestPlanDemo.test_markdown:find("# Test plan for TestPlanDemo", 1, true) ~= nil)
assert(TestPlanDemo.test_markdown:find("## Method boundary tests", 1, true) ~= nil)
assert(TestPlanDemo.test_markdown:find("## Hook tests", 1, true) ~= nil)
assert(TestPlanDemo.test_markdown:find("tests/scheduled/graphprogram/compile.t", 1, true) ~= nil)
assert(TestPlanDemo.test_markdown:find("case `compile_product_ownership`", 1, true) ~= nil)
assert(TestPlanDemo.test_markdown:find("Runtime.Grouped.methodmissing", 1, true) ~= nil)

assert(TestPlanDemo.test_skeletons ~= nil)
assert(TestPlanDemo.test_skeletons.methods[1].content == compile_unit.content)
assert(TestPlanDemo.test_skeletons.hooks[1].content == getentries_unit.content)

print("schema test generation test passed")
