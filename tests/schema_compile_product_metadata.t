-- tests/schema_compile_product_metadata.t
-- Canonical compile products should be recognized in method metadata.

import "lib/schema"

local is_terra_func = terralib.isfunction or function(v)
    return type(v) == "userdata" or type(v) == "cdata" or type(v) == "function"
end

terra unit_nop()
end

local schema CompileMetaDemo
    extern TerraFunc = is_terra_func
    extern TerraType = terralib.types.istype

    phase Scheduled
        record GraphProgram
            id: number
        end

        methods
            GraphProgram:compile() -> Unit
                status = "real"
                fallback = function(self, err)
                    return types.Unit(unit_nop, int)
                end
                impl = function(self)
                    return types.Unit(unit_nop, int)
                end

            GraphProgram:label() -> Kernel.Label
                impl = function(self)
                    return types.Kernel.Label("g" .. tostring(self.id))
                end
        end
    end

    phase Kernel
        record Label
            text: string
        end
    end
end

assert(#CompileMetaDemo.methods == 2)
local compile_m = CompileMetaDemo.methods[1]
local label_m = CompileMetaDemo.methods[2]

assert(compile_m.category == "method_boundary")
assert(compile_m.memoized == true)
assert(compile_m.helper == false)
assert(compile_m.compile_product == true)
assert(compile_m.compile_product_kind == "unit")

assert(label_m.category == "method_boundary")
assert(label_m.memoized == true)
assert(label_m.helper == false)
assert(label_m.compile_product == false)
assert(label_m.compile_product_kind == nil)

local gp = CompileMetaDemo.types.Scheduled.GraphProgram(1)
local u = gp:compile()
assert(CompileMetaDemo.types.Unit:isclassof(u))
assert(u.state_t == int)
assert(u.fn == unit_nop)

print("schema compile product metadata test passed")
