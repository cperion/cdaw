-- tests/schema_hooks_full_family.t
-- Full hook-family coverage: layout, lifecycle, conversion, iteration, display, operator.

import "lib/schema"

terra add_i32(a: int, b: int): int
    return a + b
end

terra apply_i32(a: int): int
    return a
end

local schema HookFullDemo
    doc = [[Schema with full exotype-hook family coverage.]]

    hooks Runtime.Grouped
        doc = [[Full hook family for a nested runtime target.]]

        getentries
            doc = [[Provide layout entries lazily.]]
            impl = function(self_t)
                return terralib.newlist()
            end

        staticinitialize
            doc = [[Perform post-layout installation.]]
            impl = function(self_t)
                return nil
            end

        cast
            doc = [[Handle compile-time conversions.]]
            impl = function(from, to, exp)
                return exp
            end

        for
            doc = [[Provide custom iteration lowering.]]
            impl = function(iter, body)
                return quote end
            end

        typename
            doc = [[Provide a display name.]]
            impl = function(self_t)
                return "Runtime"
            end

        add
            doc = [[Operator add implementation.]]
            impl = add_i32

        band
            doc = [[Operator and implementation as macro.]]
            macro = function(a, b)
                return `0
            end

        bnot
            doc = [[Operator not implementation as macro.]]
            macro = function(a)
                return `0
            end

        apply
            doc = [[Operator apply implementation.]]
            impl = apply_i32
    end
end

assert(#HookFullDemo.hooks == 9)
local by_name = {}
for _, h in ipairs(HookFullDemo.hooks) do by_name[h.name] = h end

assert(by_name.getentries.family == "layout")
assert(by_name.getentries.key == "__getentries")
assert(by_name.staticinitialize.family == "lifecycle")
assert(by_name.staticinitialize.key == "__staticinitialize")
assert(by_name.cast.family == "conversion")
assert(by_name.cast.key == "__cast")
assert(by_name["for"].family == "iteration")
assert(by_name["for"].key == "__for")
assert(by_name.typename.family == "display")
assert(by_name.typename.key == "__typename")
assert(by_name.add.family == "operator")
assert(by_name.add.implementation_kind == "impl")
assert(by_name.band.implementation_kind == "macro")
assert(by_name.band.key == "__and")
assert(by_name.bnot.key == "__not")
assert(by_name.apply.key == "__apply")

assert(HookFullDemo.inventory ~= nil)
assert(#HookFullDemo.inventory.hooks == 9)
assert(#HookFullDemo.inventory.hook_targets == 1)
assert(HookFullDemo.inventory.hook_targets[1].target == "Runtime.Grouped")

local target = { metamethods = {} }
local installed = HookFullDemo:install_hooks({ Runtime = { Grouped = target } })
assert(#installed == 9)
assert(target.metamethods.__getentries ~= nil)
assert(target.metamethods.__staticinitialize ~= nil)
assert(target.metamethods.__cast ~= nil)
assert(target.metamethods.__for ~= nil)
assert(target.metamethods.__typename ~= nil)
assert(target.metamethods.__add == add_i32)
assert(target.metamethods.__and ~= nil)
assert(target.metamethods.__not ~= nil)
assert(target.metamethods.__apply == apply_i32)

assert(HookFullDemo.surface:find('hooks Runtime.Grouped', 1, true) ~= nil)
assert(HookFullDemo.surface:find('getentries', 1, true) ~= nil)
assert(HookFullDemo.surface:find('staticinitialize', 1, true) ~= nil)
assert(HookFullDemo.surface:find('for', 1, true) ~= nil)
assert(HookFullDemo.surface:find('add', 1, true) ~= nil)
assert(HookFullDemo.markdown:find('## Hook target index', 1, true) ~= nil)
assert(HookFullDemo.markdown:find('- [Runtime.Grouped](#hooks-runtime-grouped)', 1, true) ~= nil)
assert(HookFullDemo.markdown:find('## Exotype hooks', 1, true) ~= nil)
assert(HookFullDemo.markdown:find('family: `operator`', 1, true) ~= nil)
assert(HookFullDemo.markdown:find('family: `layout`', 1, true) ~= nil)
assert(HookFullDemo.markdown:find('target: `Runtime.Grouped`', 1, true) ~= nil)

print("schema hooks full-family test passed")
