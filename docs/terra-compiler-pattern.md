# The Terra Compiler Pattern

## What it is

A method for building domain-specific compilers in Terra using four facilities: ASDL for domain types, struct metamethods and macros for compile-time code generation hooks, `terralib.memoize` for caching compiled output, and an optional schema DSL that validates ASDL definitions as a Terra language extension. The pattern produces monomorphic native code from high-level domain descriptions, with zero infrastructure code written by the user.

The atomic unit of the pattern is one line:

```lua
terralib.memoize(function(config) ... return { fn = fn, state_t = S } end)
```

A memoized function that takes a domain configuration (ASDL node), generates a Terra function and the state type it needs, and returns both. Applied at every level of the domain hierarchy, this single mechanism provides incremental compilation, state isolation, code size control, and live hot-swap — all as emergent properties. Everything else in this document — ASDL, metamethods, the schema DSL — is structure around this core.

This document describes the pattern precisely, grounded in the Terra API and the original exotypes paper (DeVito et al., PLDI 2014).


## Exotypes: the foundation

Everything in this pattern rests on one concept from the Terra paper: **exotypes** — user-defined types whose behavior and memory layout are defined *external* to Terra, using Lua property functions queried during typechecking.

Formally, an exotype is a tuple of functions:

```
(() → MemoryLayout) × (Op₀ → Quote) × ... × (Opₙ → Quote)
```

The first function computes the in-memory layout. The remaining functions describe the semantics when the type appears in a primitive operation (method invocation, binary operator, cast, field access, function application). Given an operation, the corresponding function returns a Quote — a concrete Terra expression implementing the operation. These functions are evaluated by the typechecker whenever it encounters an operation on the exotype.

This is not a dynamic dispatch mechanism. The property functions run **once during compilation**, not at runtime. The generated quotes are spliced into the compiled code. By the time the code executes, the property functions are gone. What remains is monomorphic machine code — the same code a C programmer would write by hand.

### Why exotypes matter for our pattern

The paper identifies the key insight: "Rather than define an object's behavior as a function that is evaluated at runtime, an exotype describes the behavior with a function that is evaluated once during a staged compilation step. These functions generate the code that implements the behavior of the object in the next stage rather than implementing the behavior directly."

This is exactly what we do with ASDL + metamethods. The ASDL tree describes the domain. The metamethods (which are exotype property functions) generate the implementation code. The quotes they return become the compiled output. The staging boundary is explicit: Lua decides, Terra executes.

### Lazy property evaluation and composability

The paper proves that exotype properties must be **lazily evaluated** for composability. Consider `Array(Tree)` where `Tree` contains an `Array(Tree)`. The layout of `Tree` depends on the layout of `Array(Tree)`. The methods of `Array(Tree)` depend on the methods of `Tree`. If we eagerly compute all properties of one type before the other, we create a false cycle.

Terra solves this by querying each property **only when needed** during typechecking. Properties are individual functions, evaluated independently. The compiler interleaves queries across types automatically. From the paper: "Lazily queried properties also make it possible to create types that have an unbounded number of behaviors" — which is why `__methodmissing` can respond to any method name, and why types built with `__methodmissing` compose with other exotype constructors like `Array(T)`.

This lazy evaluation is what makes `terralib.memoize` work as a type constructor. `Array = terralib.memoize(function(T) ... end)` returns a new exotype for each `T`. The exotype's properties (layout, methods) are defined as functions, not eagerly computed tables. When the compiler needs `Array(Tree).print`, it queries `Array(Tree).__getmethod("print")`, which queries `Tree.methods.print`, which is already defined. No cycle.

### Termination guarantee

The paper proves that property evaluation terminates if two conditions hold:

1. **Individual termination**: each property function, assuming its sub-queries return values, itself returns a value.
2. **Closed universe**: there are a finite number of unique properties that can be queried.

Under these conditions, the set of active property queries grows monotonically with each nested query. Since the universe is finite, either evaluation completes or a cycle is detected. Terra tracks active queries and throws an error on cycles.

In practice, `__methodmissing` can create an unbounded universe (infinite possible method names), so Terra caps the depth of property lookup and reports the query trace when the limit is reached. For our pattern, this rarely matters: ASDL types have a known set of methods, and `terralib.memoize` ensures each type constructor is called once per unique argument.

### `__methodmissing` is the central mechanism

The paper uses `__methodmissing` in every major example. It is not one metamethod among many — it is the primary mechanism through which exotypes achieve their expressiveness:

**Student2**: `__methodmissing` generates setter methods (`setname`, `setyear`) dynamically from the field list. The methods don't exist in the methods table — they are generated on first call during typechecking.

```lua
Student2.metamethods.__methodmissing = macro(function(name,self,arg)
    local field = string.match(name,"set(.*)")
    if field then return quote self.[field] = arg end end
    error("unknown method: "..name)
end)
```

**Objective-C wrapper**: `__methodmissing` forwards ANY method call to the Objective-C runtime. The type has an unbounded method set — every possible Objective-C selector is a valid method. Each is compiled on demand with the selector pre-computed at compile time.

```lua
ObjC.metamethods.__methodmissing = macro(function(sel,obj,...)
    local arguments = {...}
    local sel = C.sel_registerName(sanitizeSelector(sel,#arguments))
    return `ObjC { C.objc_msgSend([obj].handle,[sel],[arguments]) }
end)
```

**Array(T)**: `__methodmissing` implements the proxy pattern generically. For any method called on `Array(T)`, it generates a loop forwarding the call to each element. It does NOT need to know T's methods ahead of time.

```lua
ArrayImpl.metamethods.__methodmissing =
    macro(function(methodname,selfexp,...)
        local args = terralib.newlist{...}
        return quote
            var self = selfexp
            for i = 0,self.N do
                self.data[i]:[methodname]([args])
            end
        end
    end)
```

**Dynamic x86 assembler**: `__methodmissing` compiles assembly instructions on demand. `A:movlpd(RegR, addr)` triggers the generation of the encoding function for `movlpd` from the instruction table. Only instructions actually used are compiled. Furthermore, each call site gets a specialized version: constant arguments become part of a template, dynamic arguments are patched at runtime. This achieved 3–20× faster assembly than Google Chrome's hand-written assembler.

**Probabilistic programming**: `__apply` (the same concept applied to function application) wraps every function call with address stack management code. Each call site gets a unique ID at compile time — impossible without staging.

The composability proof in the paper depends on `__methodmissing` creating an unbounded method set that is resolved lazily. `Array(ObjC)` works because calling `windows:makeKeyAndOrderFront(nil)` triggers `Array.__methodmissing`, which generates a loop that calls `element:makeKeyAndOrderFront(nil)` on each element, which triggers `ObjC.__methodmissing`, which generates the Objective-C message send. Each query happens only when needed. If `Array` required all methods up front, the composition would fail because ObjC's method set is infinite.

This is the same mechanism we use throughout our pattern. In the MapLibre compiler, `__methodmissing` on `LayerRuntime` dispatches `layer:get_fill_color()` to either an inlined constant or a compiled zoom expression based on classification. In the UI library, `__methodmissing` could resolve property accessors by binding type (static vs. dynamic). In the BEM solver, `__methodmissing` on a surface struct could dispatch to the appropriate boundary condition evaluation. The mechanism is always the same: a macro that receives the method name as a string, inspects domain data (ASDL nodes, classification tables, spec metadata), and returns a quote.


### Properties should be functional

From the paper: "Since the writer of a property does not control when it is queried, it is a good idea to write property functions so that they will produce the same result regardless of when they are evaluated." Terra memoizes property queries to guarantee the same result on repeated calls. This means:

- Don't depend on mutable global state in property functions
- Don't depend on evaluation order between properties
- Don't query properties you don't need (to avoid creating false cycles)

These constraints align naturally with our pattern: ASDL methods are pure functions from ASDL nodes to Terra quotes. Metamethods are pure functions from type-checker queries to quotes. `terralib.memoize` is a pure cache. The only state is the ASDL tree itself, which is immutable once constructed.


## The four facilities

### ASDL

Ships with Terra as `require 'asdl'`. Creates Lua classes (metatables) from algebraic type definitions. Types are created inside a context via `context:Define(string)`. The string supports:

- **Product types** (records): `Point = (number x, number y)`
- **Sum types** (tagged unions): `Expr = Lit(number v) | BinOp(Expr l, string op, Expr r)`
- **Singletons**: `BinOp = Plus | Minus` — values, not classes
- **Field modifiers**: `*` for List, `?` for optional
- **Modules** (namespaces): `module Foo { Bar = (number a) }`
- **Unique types**: `Id(string name) unique` — memoized construction, same arguments yield same Lua object, enables identity comparison with `==`
- **External types**: registered via `context:Extern(name, predicate_fn)`, e.g. `Types:Extern("TerraType", terralib.types.istype)`

ASDL values are plain Lua objects. They have:
- Fields set by the constructor: `expr.v`, `expr.lhs`
- A `.kind` string on sum type instances: `expr.kind == "Lit"`
- Class identity via `Types.Lit:isclassof(expr)`
- The class as metatable: `getmetatable(expr) == Types.Lit`

**Methods** are added by assigning functions to the class table:

```lua
function Types.Lit:eval(env)
    return self.v
end
```

**Critical ordering rule** (from the docs): parent methods are copied to children at definition time, not via chained metatables. Therefore you must define parent methods BEFORE child methods, or the parent will clobber the child.

ASDL operates entirely in Lua. It knows nothing about Terra. The connection between them is explicit — through quotes, escapes, macros, and metamethods.


### Struct metamethods

Every Terra struct has a `metamethods` table. These are the **exotype property functions** from the paper — Lua functions queried by Terra's type checker when it encounters operations it cannot resolve. Each property function receives the operation context and returns either a value (for layout queries) or a quote (for behavior queries).

The metamethods are (from the docs):

**`__getentries(self) → entries`**
A Lua function. Called once when the compiler first needs the struct layout. Returns a List of `{field = name, type = terratype}` tables. Since the type is not yet complete during this call, anything requiring the type to be complete will error.

**`__staticinitialize(self)`**
A Lua function. Called after the type is complete (layout is known) but before the compiler returns to user code. Can examine offsets with `terralib.offsetof`, create vtables, install additional methods. Runs once per type.

**`__getmethod(self, methodname) → method`**
A Lua function. Called for every static invocation of `methodname` on this type. May return a Terra function, a Lua function, or a macro. Since it can be called multiple times for the same name, expensive operations should be memoized. By default returns `self.methods[methodname]`, falling through to `__methodmissing` if not found.

**`__methodmissing(methodname, obj, arg1, ..., argN)`**
A **macro**. The most important exotype property. Called when `__getmethod` fails (method not in the methods table). Receives quotes as arguments. Must return a quote to splice in place of the method call. The paper uses this in every major example: generating setters from field names, forwarding to Objective-C, implementing the proxy pattern in `Array(T)`, compiling x86 instructions on demand, wrapping probabilistic function calls. It enables unbounded method sets resolved lazily — the foundation of exotype composability.

**`__entrymissing(entryname, obj)`**
A **macro**. Called when `obj.entryname` is not a known field. Receives quotes. Must return a quote.

**`__cast(from, to, exp) → castedexp`**
A Lua function. Called when either `from` or `to` is this struct type (or pointer to it). If a valid conversion exists, returns a Terra expression (quote) converting `exp` from `from` to `to`. If not, calls `error()`. The compiler tries applicable `__cast` methods until one succeeds.

**`__for(iterable, body) → quote`**
A Lua function (marked experimental). Generates the loop body for `for x in myobj do`. `iterable` is an expression yielding a value of this type. `body` is a Lua function that, when called with the loop variable, returns one iteration's code. Both `iterable` and the body argument must be protected from multiple evaluation. Returns a quote.

**Operator metamethods**: `__add`, `__sub`, `__mul`, `__div`, `__mod`, `__lt`, `__le`, `__gt`, `__ge`, `__eq`, `__ne`, `__and`, `__or`, `__not`, `__xor`, `__lshift`, `__rshift`, `__select`, `__apply`. Can be either Terra methods or macros.

**`__typename(self) → string`**
A Lua function. Provides the display name for error messages.

The key distinction: `__methodmissing` and `__entrymissing` are **macros** — they receive quotes and return quotes. `__cast`, `__for`, `__getentries`, `__staticinitialize` are **Lua functions** — they receive types/values and return entries, quotes, or nothing. Operator metamethods can be either.

In the exotype formalism, all of these are property functions `(Opᵢ → Quote)`. The difference between macros and Lua functions is when they access their arguments: macros receive arguments as unevaluated AST fragments (quotes), while Lua functions receive evaluated values (types, expressions). Both are queried lazily by the type checker and both run at compile time — not at runtime.


### Macros

Created with `macro(function(arg0, arg1, ...) ... end)`. The function is invoked **at compile time** (during type-checking) for each call in Terra code. Each argument is a Terra quote representing the argument expression. The macro must return a value that converts to Terra via the compile-time conversion rules — typically a quote.

Macros are how Lua logic runs inside Terra code without escape blocks. When Terra code calls a macro, the macro receives the arguments as AST fragments (quotes), performs arbitrary Lua computation, and returns an AST fragment (quote) that is spliced into the call site. The compiler then type-checks the result.

From the docs: "Escapes are evaluated when the surrounding Terra code is **defined**." Macros run when the code is **compiled** (type-checked). This is a subtle but important difference for nested/deferred compilation. In practice, for our pattern both happen during `terralib.memoize`'d function generation, so the distinction rarely matters.

### `terralib.memoize`

From the docs: "Memoize the result of a function. The first time a function is called with a particular set of arguments, it calls the function to calculate the return value and caches it. Subsequent calls with the same arguments (using Lua equality) will return that value."

This is a Terra built-in. We do not write cache code. We wrap our compiler function:

```lua
local compile_thing = terralib.memoize(function(config)
    -- ... inspect config, generate Terra function, build state type ...
    return { fn = fn, state_t = S }
end)
```

That's the core pattern. One line repeated at every level of the hierarchy. The function takes a domain configuration (an ASDL node), generates a Terra function and the state type that function needs, and returns both. `terralib.memoize` caches the result by Lua equality on `config`.

Combined with ASDL's `unique` types (which memoize construction so structurally identical objects are `==`), this gives us structural caching: same domain configuration → same `{ fn, state_t }` pair returned instantly.

**Hard rule: no hidden semantic state.** Because `terralib.memoize` keys by **Lua equality on the explicit argument list only**, every semantic dependency of a memoized compiler must appear in that explicit argument list (often just `self`, sometimes `self, transport, tempo_map`, etc.). Do **not** smuggle semantic inputs through hidden Lua fields, side tables, `rawset`, ambient globals, mutable contexts, or ad hoc attached metadata. If a compiler's behavior depends on something, that something must either:

1. be structurally owned by `self` in the ASDL value itself, or
2. be passed as an explicit semantic parameter.

If you hide semantic inputs off-schema, memoize can return a stale cached function even though the real meaning changed. So the practical rule is simple:

- **no hidden state**
- **explicit semantic parameters only**
- **trust memoize only on explicit Lua-equality keys**

A corollary for this repo: every **public phase-transition boundary** should be implemented as a memoized body over those explicit parameters. If a public lowering/resolve/classify/schedule/compile boundary is not memoized, treat that as an architectural bug unless it is intentionally not a compilation boundary at all (for example, a trivial runtime accessor like `Kernel.Project:entry_fn()`).

**Corollary: no explicit key fields in compile products.** A compile product is `{ fn, state_t }`. Not `{ fn, state_t, key }`. The identity of the product is the identity of its input — the ASDL node that was compiled. If that node is `unique`, then `terralib.memoize` already keys on it by Lua equality. Adding an explicit `key` field to the output is redundant at best and misleading at worst: it suggests the identity is a value you must carry and compare, when in fact it's structural and free.

If you need to correlate a compiled product back to its source, you already have the source — it's the ASDL node you passed to the memoized compiler. The memoize cache IS the correlation. `compile_component(plan)` → `{ fn, state_t }`. Given the same `plan`, you get the same product. The plan is the key. Storing the key inside the product is like storing the dictionary key inside the dictionary value — it's either redundant (the dictionary already maps key → value) or wrong (the stored key can drift from the actual key).

This also applies to context objects. A context object passed through the tree is a bag of implicit keys that `terralib.memoize` can't see. If the context affects the output, its contents must be in the explicit argument list. If it doesn't affect the output, it shouldn't exist. Either way, the context is the wrong abstraction — the right abstraction is explicit parameters that memoize keys on, or ASDL fields that `unique` hashes.

**Why `{ fn, state_t }` and not just `fn`:** The state type must be as granular as the function. If a level returns only `fn`, the function must take a pointer to some external state struct — and that struct's layout can change when OTHER parts of the project change, invalidating the cached function silently. Returning `{ fn, state_t }` means the function owns its ABI. The parent composes child `state_t`s into its own struct and passes pointers to each child. A cache hit on a child is memory-safe because the child's state type hasn't changed — even if the parent's layout has. This is explained fully in the JIT hot-swap section.

**State is compiled, not managed.** This is the strongest consequence of the pattern and it should shape the whole architecture. A memoized compiler does not merely generate code that happens to need some state; it generates the code **and** the exact state ABI that code owns. The pair `{ fn, state_t }` is a closed unit. The function only makes sense with that `state_t`; the `state_t` only makes sense for that function. They are born together, cached together, published together, and retired together.

In the schema DSL, this pair is enforced as a **language intrinsic**. `Unit` is a built-in type provided by `schema.t` itself — not declared by any phase, not owned by any module. It is always available, always canonical, always `{ fn: TerraFunc, state_t: TerraType }`. Compile transitions (`phase X to Y via compile`) are validated to return either the builtin `Unit` or a custom `unit` type (which auto-injects the same canonical fields). This means the architecture is not a convention that can drift — it is structurally enforced by the schema language.

That is why this pattern largely deletes hand-written state-management and memory-management subsystems. There is no separate phase where a human invents a parallel ownership graph, offset table, buffer pool, or lifetime protocol for DSP state. Each memoized unit declares the exact state layout it needs; the parent embeds that layout as a field; Terra's normal value/layout rules determine offsets; the parent passes a pointer to the embedded child state. Ownership, lifetime, and access paths all fall out of the same structure. The model is the memory plan.

A useful mental model for this repo:

- compilation produces **code + state ABI**
- edit-time instantiation allocates **one root state value** for the active compiled product
- playback does **zero allocations and zero frees** in the hot path
- recompilation publishes a new `{ fn, state_t }` pair; the old pair remains valid for the old state image until retirement

So alloc/free are not part of the audio algorithm. They are edit-time publication events. The audio thread should not know how to allocate, free, resize, or reconcile state. It should only receive a pointer to the state image that was already compiled for the currently published function.

The pattern applied at three levels:

```lua
compile_effect  = terralib.memoize(function(effect)  return { fn, state_t } end)
compile_track   = terralib.memoize(function(track)   return { fn, state_t } end)
compile_session = terralib.memoize(function(session) return { fn, state_t } end)
```

From this, four properties emerge simultaneously: incremental compilation (only the changed path recompiles), state isolation (each function owns its ABI), code size control (each memoize boundary is a call boundary keeping functions small for LLVM and I-cache), and hot-swap (the top-level function is a Lua variable that you reassign or publish through a stable callback/engine image). See the JIT hot-swap section for the complete explanation.


### The schema DSL: validated ASDL as a language extension

Raw ASDL is a string passed to `context:Define()`. It's unchecked beyond basic syntax. You can define a sum type with one variant, a record that recurses without indirection, a phase that widens instead of narrows. These are design errors that produce confusing failures downstream — a method that returns nil, an infinite loop at construction, generated code that branches where it shouldn't.

The schema DSL fixes this by hooking into Terra's **language extension API** — the same mechanism used to define `terra` functions and `struct` declarations. It registers the keyword `schema`, uses Terra's **Pratt parser** (shipped as `tests/lib/parsing.t`) for constraint expressions, and emits errors through Terra's own error reporting. An ASDL structural error becomes a Terra error — same format, same file, same line number.

From the API docs, a language extension is a Lua table with:

- `name`: identifier for the extension
- `entrypoints`: keywords that trigger the parser (e.g. `{"schema"}`)
- `keywords`: additional reserved words (e.g. `{"enum", "flags", "record", "phase", "methods", "extern", "unique"}`)
- `expression` / `statement` / `localstatement`: parser functions that receive the `lexer` and return constructor functions

The `lexer` provides `lexer:next()`, `lexer:expect(type)`, `lexer:matches(type)`, `lexer:luaexpr()`, `lexer:terraexpr()`, `lexer:error(msg)`. The Pratt parser library wraps these with precedence-aware expression parsing.

The schema DSL uses `statement` to parse the entire schema block, validate it, generate the ASDL definition string, and return the compiled context:

```lua
local schema_lang = {
    name = "schema",
    entrypoints = {"schema"},
    keywords = {"enum", "flags", "record", "phase",
                "methods", "extern", "unique"},

    statement = function(self, lex)
        lex:expect("schema")
        local name = lex:expect(lex.name).value

        -- Parse the body using the lexer
        local decl = parse_schema_body(lex)

        -- Validate ALL structural rules
        local errors = validate(decl)
        if #errors > 0 then
            -- Errors go through Terra's error system
            -- with correct file and line numbers
            lex:error(errors[1].message)
        end

        -- Generate the ASDL definition string
        local asdl_string = emit_asdl(decl)

        -- Return the constructor
        return function(env)
            local ctx = asdl.NewContext()
            for _, ext in ipairs(decl.externs) do
                ctx:Extern(ext.name, ext.checker)
            end
            ctx:Define(asdl_string)
            install_constraints(ctx, decl)
            install_method_traps(ctx, decl)
            return {
                types = ctx,
                phases = decl.phase_names,
                methods = decl.method_sigs,
            }
        end, {name}  -- bind to local variable `name`
    end,
}
```

#### Syntax

The user writes:

```lua
import "schema"

schema MyDomain

    extern terra_type = terralib.types.istype
    extern terra_quote = terralib.isquote

    flags Dir
        Row
        Col
    end

    enum Sizing
        Fit     { min: number, max: number }
        Grow    { weight: number, min: number, max: number }
        Fixed   { value: number }
        Percent { fraction: number, 0 <= fraction <= 1 }
    end

    record Color
        r: number
        g: number
        b: number
        a: number = 1.0
    end

    phase Source
        enum Expr
            Lit   { value: number }
            BinOp { op: string, lhs: Expr, rhs: Expr }
            Get   { property: string }
            Zoom  {}
        end

        methods
            Expr:compile(sample_rate: number) -> terra_quote
        end
    end

    phase Classified
        flags Dep
            Const
            Zoom
            Feature
        end
    end

    phase Compiled
        record VertexField
            name: string
            components: number, 1 <= components <= 4
        end

        record VertexFormat
            fields: VertexField*
        unique
        end
    end

end
```

This parses to an internal representation, validates, then generates:

```lua
M:Define [[
    Dir = Row | Col

    Sizing = Fit(number min, number max)
           | Grow(number weight, number min, number max)
           | Fixed(number value)
           | Percent(number fraction)

    Color = (number r, number g, number b, number a)

    module Source {
        Expr = Lit(number value)
             | BinOp(string op, Source.Expr lhs, Source.Expr rhs)
             | Get(string property)
             | Zoom()
    }

    module Classified {
        Dep = Const | Zoom | Feature
    }

    module Compiled {
        VertexField = (string name, number components)
        VertexFormat = (Compiled.VertexField* fields) unique
    }
]]
```

Plus constructor wrappers that check constraints at construction time:

```lua
-- Fraction must be 0..1
local original = M.Sizing.Percent
M.Sizing.Percent = function(fraction)
    assert(fraction >= 0 and fraction <= 1,
        "Percent.fraction must be in [0,1], got " .. fraction)
    return original(fraction)
end

-- Components must be 1..4
local original_vf = M.Compiled.VertexField
M.Compiled.VertexField = function(name, components)
    assert(components >= 1 and components <= 4,
        "components must be 1-4, got " .. components)
    return original_vf(name, components)
end
```

Plus method exhaustiveness traps via the ASDL ordering rule — the parent method is installed first as an error-reporting fallback. Any variant that doesn't override it fires a clear error at first call naming the missing variant and method.

#### What the validator checks

Every rule is checked at parse time and reported through `lex:error()` as a standard Terra error:

**Sum types (enum)**:
- At least 2 variants. One variant = use a record instead.
- No two variants have identical field sets. Identical fields = merge or differentiate.
- Every variant has at least one distinguishing field from its siblings.

**Records**:
- All referenced types exist in the schema or are registered externs.
- No direct recursion without `*` or `?` indirection (infinite struct).
- Warning if more than 3 mutually exclusive optional fields (suggests a sum type).
- Default values type-check against the field type.
- Constraint expressions are valid (bounds are numeric, min < max).

**Phases**:
- Declaration order = phase order.
- Later phases have fewer or equal sum types than earlier phases.
- Final phase has zero sum types (the monomorphic guarantee) — warning if violated.
- Types reference only types from their own phase or earlier phases.

**Methods**:
- Return type's phase ≥ receiver type's phase (no backward lowering).
- Exhaustiveness: at first call, every variant of the sum type must have an implementation.
- Arguments typed `table` are a **parse error** — `table` is a ctx bag; it hides semantic dependencies from the memoize key. Every argument must be explicitly typed.
- Methods in non-terminal pipeline phases that return `Unit` are a **parse error** — `Unit` may only be returned from the phase immediately preceding the terminal (the compilation boundary). Intermediate phases must return ASDL data types.

**Pipeline**:
- Declared stages must exist as phases.
- Each pipeline edge must have at least one transition method.
- No skipping — a method may only return a type from the directly next phase.
- Terminal transitions must return `Unit` (or a schema-declared unit type).
- Non-terminal transitions must not return `Unit`.
- Transition verb must be consistent across all types on the same edge.

**`Unit` constructor**:
- `fn` must be a `TerraFunc`.
- `state_t` must be a `TerraType`.
- If `state_t` is non-empty, `fn` must accept `&state_t` as a parameter — ABI ownership enforced structurally. A function that takes `&uint8` or omits the state parameter entirely fails immediately.
- `fn:compile()` is forced at construction time — JIT runs once here, not lazily on the first audio callback.
- The canonical construction paths are `Unit.leaf` and `Unit.compose`. Direct `Unit(fn, state_t)` construction is available but subject to the same checks.

**Unique**:
- Only on types that will benefit from identity comparison.

#### How errors look

Because `lex:error()` uses Terra's error infrastructure, errors have file names and line numbers:

```
schema.t:14: sum type 'Format' has only one variant.
    A sum type must have at least 2 variants. Use a record instead.

schema.t:28: field 'target' references type 'Waypoint'
    which is not defined in this schema.

schema.t:45: method 'decompile' on Typed.TypedExpr returns Source.Expr,
    which is an earlier phase. Methods must produce types from
    the same or later phase.

schema.t:52: record 'Tree' contains field 'left' of type 'Tree'
    which creates infinite recursion. Use Tree* or Tree?.
```

These are identical in format to any other Terra compilation error. The user's editor shows them in the same way. The schema DSL is invisible except when you get it wrong — then it tells you exactly what's wrong and where.

#### The Pratt parser for constraints

Constraint expressions like `0 <= fraction <= 1` and `1 <= components <= 4` are parsed using Terra's shipped Pratt parser library. The Pratt parser handles operator precedence naturally. We define:

- Prefix rules for identifiers (field names) and numbers
- Infix rules for `<=`, `>=`, `<`, `>`, `==` at appropriate precedence levels

The parsed constraint becomes a Lua predicate function wrapped around the ASDL constructor. The Pratt parser is also used for default value expressions (`a: number = 1.0`).

#### Relationship to the rest of the pattern

The schema DSL is **optional**. You can always write raw `context:Define()` strings. The DSL is for projects where humans author ASDL definitions — UI libraries, game engines, DSLs you're inventing. Projects where a spec JSON generates ASDL programmatically (like the MapLibre compiler) don't need it.

The schema DSL is a **separate project** — a reusable Terra language extension hosted at `github.com/cperion/schema.t`. It produces the same ASDL contexts and types that `context:Define()` produces. Everything downstream (ASDL methods, metamethods, `terralib.memoize`, the compilation pattern) works identically whether the ASDL came from the schema DSL or from a raw string. Consumers reference it as a git submodule and import the single file: `import "path/to/schema"`.

The schema DSL is itself an example of the exotype pattern: it uses Terra's language extension API (a form of `__methodmissing` at the parser level — the `expression`/`statement` functions are invoked when the keyword is encountered), it generates ASDL types (domain modeling), and it installs exotype properties (constraint checkers, method traps) on the generated types. The tool is built with the same tools it validates.

#### `Unit`, `Unit.leaf`, and `Unit.compose`

The schema DSL installs a `Unit` intrinsic — the canonical compile product — and two factory functions that are the only sanctioned ways to construct one.

`Unit` is `{ fn: TerraFunc, state_t: TerraType }`. Every compile-boundary method returns it. The `fn` is a closed, typed Terra function. The `state_t` is the full owned runtime ABI — the struct that `fn` reads and writes exclusively.

```lua
-- Unit.leaf: a node with its own persistent typed state.
-- fn signature: terra(params..., state: &state_t)
Unit.leaf(state_t, params, function(state_sym, params)
    return quote
        -- state_sym is &state_t, typed, no casting
        state_sym.phase = state_sym.phase + freq / sample_rate
        buf[i] = sinf(2 * PI * state_sym.phase)
    end
end)

-- Unit.compose: a node that owns the aggregate of its children's states.
-- The schema auto-builds a ComposedState struct from each child's state_t.
-- fn signature: terra(params..., state: &ComposedState)
Unit.compose(children, params, function(state_sym, annotated, params)
    return quote
        escape
            for _, kid in ipairs(annotated) do
                -- kid.call(...) dispatches correctly whether child has state or not.
                -- One line. No manual has_state/state_expr boilerplate.
                emit(kid.call(buf, frames))
            end
        end
    end
end)
```

`Unit.leaf` and `Unit.compose` both route through the validated `Unit(fn, state_t)` constructor, so the ABI ownership check and forced JIT apply automatically. There is no way to build a `Unit` that passes `&uint8` instead of `&state_t`. The struct type is declared, composed, and baked at compile time — not cast at runtime.


## The pattern

### Step 1: Define the domain in ASDL

ASDL modules correspond to compiler phases. Types in each module represent the data at that phase. Later modules have fewer sum types — decisions are resolved as you progress through phases.

```lua
local asdl = require 'asdl'
local M = asdl.NewContext()

M:Extern("TerraType", terralib.types.istype)
M:Extern("TerraQuote", terralib.isquote)

M:Define [[
    module Source {
        Expr = Lit(number v)
             | BinOp(string op, Source.Expr lhs, Source.Expr rhs)
             | Get(string property)
             | Zoom()
             | Interpolate(Source.Expr input, Source.Stop* stops)

        Stop = (number at, number val)
    }
]]
```

This is pure Lua. No Terra yet. The types are Lua metatables with validated constructors.


### Step 2: Install methods on ASDL types

ASDL methods are Lua functions. For methods that produce Terra code, they return quotes:

```lua
-- PARENT methods FIRST (ASDL ordering rule)
function M.Source.Expr:compile(ctx)
    error("compile not implemented for " .. self.kind)
end

-- Then child methods
function M.Source.Expr.Lit:compile(ctx)
    return `[float](self.v)
end

function M.Source.Expr.BinOp:compile(ctx)
    local l = self.lhs:compile(ctx)
    local r = self.rhs:compile(ctx)
    local ops = {
        ["+"] = function(a, b) return `a + b end,
        ["-"] = function(a, b) return `a - b end,
        ["*"] = function(a, b) return `a * b end,
        ["/"] = function(a, b) return `a / b end,
    }
    return ops[self.op](l, r)
end

function M.Source.Expr.Get:compile(ctx)
    local key = self.property
    return `ctx.feature.[key]
end

function M.Source.Expr.Zoom:compile(ctx)
    return `ctx.zoom
end

function M.Source.Expr.Interpolate:compile(ctx)
    local input = self.input:compile(ctx)
    local stops = self.stops
    local result = symbol(float, "interp_result")

    local stmts = terralib.newlist()
    stmts:insert(quote var [result] = [float](stops[1].val) end)

    for i = 2, #stops do
        local lo, hi = stops[i-1].at, stops[i].at
        local lo_v, hi_v = stops[i-1].val, stops[i].val
        stmts:insert(quote
            if [input] >= [lo] and [input] < [hi] then
                var t = ([input] - [lo]) / ([hi] - [lo])
                [result] = [lo_v] + t * ([hi_v] - [lo_v])
            end
        end)
    end

    stmts:insert(quote
        if [input] >= [stops[#stops].at] then
            [result] = [float](stops[#stops].val)
        end
    end)

    return quote [stmts] in [result] end
end
```

Each method takes an ASDL node (`self`) plus a context, and returns a Terra quote. The quote is not yet inside a function — it is a code fragment waiting to be spliced.

Note: `Interpolate:compile` unrolls the stop array. The `for i = 2, #stops` is a Lua loop that runs at code-generation time. Each iteration emits a quote. The stops are compile-time constants baked into the generated code. At runtime there is no loop and no stop array — just a sequence of comparisons against constant values.


### Step 3: Install metamethods on Terra structs

Metamethods bridge from Terra's type checker to our ASDL-based code generators.

**`__getentries`** derives struct layout from ASDL data:

```lua
local make_vertex_struct = terralib.memoize(function(format)
    local S = terralib.types.newstruct("Vertex")

    S.metamethods.__getentries = function(self)
        return format.fields:map(function(f)
            return {field = f.name, type = components_to_type(f.components)}
        end)
    end

    return S
end)
```

`format` is an ASDL value describing the vertex layout. `__getentries` reads it and returns the field list. Terra calls this once when the struct is first completed. The resulting struct has exactly the fields the ASDL format specifies — no more, no less.

**`__staticinitialize`** generates derived code after layout is known:

```lua
S.metamethods.__staticinitialize = function(self)
    local stride = terralib.sizeof(self)
    self.methods.bind = terra(prog: uint32)
        escape
            local offset = 0
            for _, f in ipairs(format.fields) do
                emit quote
                    var loc = gl.GetAttribLocation(prog, [f.name])
                    gl.VertexAttribPointer(loc, [f.components],
                        gl.FLOAT, 0, [stride],
                        [&uint8](nil) + [offset])
                    gl.EnableVertexAttribArray(loc)
                end
                offset = offset + f.components * 4
            end
        end
    end
end
```

This runs once per struct type, after the layout is determined. It installs a `bind` method that knows the exact offsets (computed from the real layout) and generates one `glVertexAttribPointer` call per field. The `escape/emit` block iterates the ASDL field list at method-definition time.

**`__entrymissing`** as a macro dispatches field access:

```lua
S.metamethods.__entrymissing = macro(function(entryname, obj)
    local name = entryname:asvalue()
    if known_fields[name] then
        return `obj.[name]
    else
        return `dynamic_get(obj._extra, [hash(name)])
    end
end)
```

When Terra code accesses `feature.population`, and `population` is not a declared field, this macro fires. It checks (at compile time) whether `population` is in the known schema. If yes: direct field access. If no: hash table fallback. The decision is made once at compile time. The compiled code has one path.

**`__methodmissing`** as a macro dispatches method calls:

```lua
Layer.metamethods.__methodmissing = macro(function(name, obj, ...)
    local method_name = name:asvalue()
    local prop_name = method_to_prop(method_name)
    local dep = classifications[prop_name]
    if dep == DEP_CONST then
        return `[value_to_terra(constant_values[prop_name])]
    elseif dep == DEP_ZOOM then
        local expr = zoom_exprs[prop_name]
        return `[expr:compile({zoom = `obj.zoom})]
    end
end)
```

When Terra code calls `layer:get_fill_color()`, and the method doesn't exist in the methods table, this macro fires. It looks up the classification (a Lua value from our ASDL analysis), then returns either an inlined constant or a compiled zoom expression. The call site compiles to either a constant or an arithmetic expression — no dispatch at runtime.

**`__cast`** as a Lua function handles type conversions:

```lua
MapColor.metamethods.__cast = function(from, to, exp)
    if from == float and to == MapColor then
        return `MapColor {exp, exp, exp, 1.0f}
    elseif from == MapColor and to == float then
        return `(exp.r + exp.g + exp.b) / 3.0f
    else
        error("invalid cast")
    end
end
```

When Terra's type checker needs to convert between `float` and `MapColor`, it calls this. If conversion is valid, it returns the expression. If not, it calls `error()` and the compiler tries other `__cast` methods. This is a Lua function, not a macro — it receives type objects and a quote, not just quotes.

**`__for`** as a Lua function generates custom iteration:

```lua
TileLayer.metamethods.__for = function(iter, body)
    return quote
        var layer = iter
        var cursor = 0
        for i = 0, layer.feature_count do
            var feature : Feature
            cursor = decode_feature(layer.data, cursor, &feature)
            [body(`feature)]
        end
    end
end
```

When Terra code writes `for feature in tile_layer do`, this generates the decoding loop. `iter` is the expression producing the tile layer. `body` is a function that, given the loop variable, returns one iteration's code. The result is a quote containing the complete loop.

**Operator metamethods** for domain arithmetic:

```lua
MapColor.metamethods.__add = terra(a: MapColor, b: MapColor): MapColor
    return MapColor {a.r+b.r, a.g+b.g, a.b+b.b, a.a+b.a}
end
MapColor.metamethods.__mul = terra(a: MapColor, b: float): MapColor
    return MapColor {a.r*b, a.g*b, a.b*b, a.a*b}
end
```

These are Terra methods (not macros). They define what `+` and `*` mean for colors. The expression compiler can write `lo + t * (hi - lo)` and it works for both `float` (scalar arithmetic) and `MapColor` (component-wise), with the correct code generated for each. No type-dispatch in the expression compiler.


### Step 4: Generate Terra functions

The ASDL tree, the methods that return quotes, and the metamethods on the structs all come together in the core pattern: a memoized function that takes a domain configuration and returns `{ fn, state_t }` — a compiled Terra function and the state type it operates on. In this repo, treat that pair as **canonical at every compile boundary**. The schema DSL enforces this: `Unit` is a built-in intrinsic type with `{ fn, state_t }` — no declaration needed. If no persistent state is needed, return `state_t = tuple()`. Do not collapse the compile product to just `fn`; the whole point is that the function owns its ABI, even when that ABI is empty. Custom compile products with extra fields use `unit Name ... end` in the schema; the canonical fields are auto-injected.

```lua
local compile_processor = terralib.memoize(function(plan_key)
    local plan = plan_registry[plan_key]
    local VStruct = make_vertex_struct(plan.format)
    local filter = plan.filter      -- an ASDL Expr node
    local exprs = plan.exprs        -- table: field_name → ASDL Expr node

    return terra(
        tile: TileLayer,
        vertices: &VStruct,
        vertex_cap: int,
        zoom: float
    ) : int
        var count = 0
        var ctx : CompileCtx
        ctx.zoom = zoom

        -- __for metamethod on TileLayer generates the decoding loop
        for feature in tile do
            ctx.feature = feature

            -- filter:compile(ctx) is a Lua call at definition time.
            -- It returns a quote. The [...] escape splices it in.
            if [filter:compile(ctx)] then
                var v : VStruct
                -- __getentries determined VStruct's layout from plan.format

                escape
                    for name, expr in pairs(exprs) do
                        -- Each expr:compile(ctx) returns a quote.
                        -- __cast on the result type handles conversion
                        -- to the vertex field type automatically.
                        emit quote v.[name] = [expr:compile(ctx)] end
                    end
                end

                vertices[count] = v
                count = count + 1
            end
        end
        return count
    end
end)
```

Reading this function:

1. `for feature in tile do` — Terra sees `TileLayer`, calls `__for`, gets the decoding loop inlined.

2. `[filter:compile(ctx)]` — At function definition time, `filter` is an ASDL node. `:compile(ctx)` is a Lua method call that walks the ASDL tree and returns a quote. The `[...]` escape splices that quote into the `if` condition. The compiled code has the filter as a flat boolean expression.

3. `var v : VStruct` — Terra completes the struct, calling `__getentries`, which reads the ASDL format descriptor and returns the field list. The struct has exactly the fields this specific plan requires.

4. `escape ... for name, expr in pairs(exprs) ... emit ... end` — Lua iterates the ASDL expression table at definition time. For each data-driven property, it calls `expr:compile(ctx)` to get a quote, and emits an assignment statement. If the quote's type doesn't match the field's type, `__cast` fires to generate the conversion.

5. `terralib.memoize` wraps the whole generator. Same plan key → same compiled function. We don't write cache code.

The result is a Terra function with no ASDL dispatch, no type checking, no optional field handling. The tree walk happened in Lua at definition time. The compiled function is a tight loop of arithmetic and memory writes.


### Step 5: Call it

```lua
-- terralib.memoize returns the generated Terra function (may not be compiled yet)
local fn = compile_processor(plan_key)

-- First call: Terra automatically typechecks and JIT-compiles via LLVM
-- Subsequent calls: direct native function call
local count = fn(tile_data, vertex_buffer, capacity, zoom)
```

There is no explicit `:compile()` step. From the docs: "When a Terra function is first called, it is typechecked and compiled, producing machine code." We just call the function. Terra handles compilation automatically on first invocation. `terralib.memoize` handles caching the generated function. We manage nothing.


## Where each thing runs

| What | When | Produces |
|---|---|---|
| `asdl.NewContext():Define(...)` | Lua execution time | Lua metatables (ASDL types) |
| ASDL constructor: `M.Lit(42)` | Lua execution time | Lua table (ASDL instance) |
| ASDL method: `expr:compile(ctx)` | Terra function definition time (inside escape) | Terra quote |
| `__getentries(self)` | Type completion time (once per struct) | List of field entries |
| `__staticinitialize(self)` | After type completion (once per struct) | Side effects (install methods) |
| `__cast(from, to, exp)` | Terra type-checking time | Terra quote (conversion) |
| `__for(iterable, body)` | Terra type-checking time | Terra quote (loop) |
| `__methodmissing(name, ...)` | Terra type-checking time (macro) | Terra quote |
| `__entrymissing(name, obj)` | Terra type-checking time (macro) | Terra quote |
| Operator metamethods | Terra type-checking time | Terra function or macro expansion |
| `escape ... emit ... end` | Terra function definition time | Spliced quotes |
| `[luaexpr]` (backtick escape) | Terra function definition time | Spliced value/quote |
| `terralib.memoize(fn)` | First call with new args | Cached return value (Terra function) |
| `fn(args...)` | First call: LLVM JIT + execute. After: native execution | Return values |

This table is more than an execution summary. It is the boundary map of the
whole architecture. Once these stages are kept explicit, a large amount of
system complexity disappears:

- **loading boundaries** are explicit — ASDL construction happens in Lua when
  the module/schema loads
- **definition boundaries** are explicit — escapes run when Terra functions are
  defined
- **typecheck/codegen boundaries** are explicit — metamethods/macros run when
  Terra queries behavior during compilation
- **JIT boundaries** are explicit — native code appears on first call
- **runtime boundaries** are explicit — after that, only machine code remains

This matters for the same reason granular `state_t` matters: when the boundary is
explicit, ownership and responsibility become obvious. You do not need a second
implicit subsystem to answer "when does this happen?", "who owns this failure?",
or "what stage is allowed to allocate/inspect/emit this?" The architecture is
just the composition of these named boundaries.

## The role of escape vs. macro

Both are mechanisms for Lua code to produce Terra code. The difference:

**Escapes** (`[...]` and `escape ... emit ... end`) run when the surrounding Terra function is **defined**. They evaluate a Lua expression and splice the result into the function's AST. They're the mechanism for iterating over ASDL lists and splicing quotes.

**Macros** run when the function is **type-checked** (compiled). They receive their arguments as quotes (AST fragments) and return a quote. They're the mechanism for `__methodmissing` and `__entrymissing` — compile-time dispatch that looks like a normal method call or field access in Terra code.

In practice, for our pattern, both happen during the `terralib.memoize`'d function generation. The practical rule:

- **Use escapes** when you need to iterate an ASDL list and emit code for each element. This is Lua controlling the structure of the generated code.
- **Use macros** (via metamethods) when you want Terra code to look like normal code while hiding compile-time dispatch. `feature.population` looks like a field access but is actually `__entrymissing` dispatching to either direct access or a hash lookup.

The cleanest code minimizes escapes. Ideally there is one escape block per ASDL list traversal. Inside each emission, the code is either a direct quote or a macro call. Everything else — field access, method calls, operators, iteration, casts — is handled by metamethods, which Terra invokes automatically.


## What makes it work

The pattern works because of the exotype architecture described in DeVito et al.:

**ASDL types exist in Lua.** They are Lua tables with metatables. Lua code can walk them, analyze them, transform them, and make decisions based on their structure — all at function-generation time. They are the domain model that the exotype property functions inspect.

**Terra quotes exist in Lua.** A backtick expression `` `a + b `` is a Lua object representing a fragment of Terra code. Quotes compose: you can build larger quotes from smaller ones. They are the currency exchanged between ASDL methods and exotype property functions. In the formal model, every property function returns a Quote.

**Exotype properties run at compile time, not runtime.** From the paper: "Rather than define an object's behavior as a function that is evaluated at runtime, an exotype describes the behavior with a function that is evaluated once during a staged compilation step." The metamethods are these property functions. They inspect ASDL data, make decisions, and return quotes. The decision is made once, during typechecking. The generated code has no trace of the decision.

**Properties are lazily evaluated and composable.** From the paper: properties are queried individually, only when needed. This prevents false cycles and allows independently-defined type constructors (like `Array(T)`) to compose with arbitrary exotypes. In our pattern, `terralib.memoize` wraps type constructors, and ASDL `unique` ensures structural identity. Together they give us composable, cached type generation.

**`terralib.memoize` caches by Lua equality.** ASDL's `unique` types ensure that structurally identical values are `==`. Combined with `terralib.memoize`, this means: same domain configuration → same compiled function. The first call pays the compilation cost. Every subsequent call with the same configuration returns the cached function instantly.

The net effect: domain complexity lives in ASDL (Lua). Generated code is monomorphic (Terra). The gap between them is bridged by quotes flowing through ASDL methods and exotype property functions. LLVM optimizes the final code aggressively because it sees only concrete types, constant values, and straight-line arithmetic — no virtual dispatch, no tagged unions, no optional field checks.

The paper demonstrated this in four domains: serialization (11× faster than Kryo), dynamic x86 assembly (3–20× faster than Chrome's assembler), automatic differentiation (comparable to Stan C++ with 25% less memory), and probabilistic programming (10× faster than V8 JavaScript PPL). Our pattern generalizes their approach: ASDL replaces hand-built type hierarchies, and the metamethods + macros are the exotype property functions. The result is the same — high-level expressiveness with low-level performance — but with a structured methodology that applies to any domain.


## JIT hot-swap: live-recompiling with function pointers and memoize

The pattern naturally produces a live-recompilation system. No framework, no hot-reload infrastructure, no message queues. Just three Terra primitives: `terralib.memoize`, function pointers, and first-call compilation.

### The mechanism

Terra functions are Lua objects. They compile to native code on first call. They have function pointer addresses. You can store a Terra function in a Lua variable, and you can change what that variable points to at any time. That's the entire mechanism.

```lua
-- The memoized compiler: ASDL config → Terra function
local compile_session = terralib.memoize(function(session)
    -- Walk the ASDL tree, generate quotes, build the terra function
    local terra render(output: &float, n: int, time: double, state: &State)
        escape
            for _, track in ipairs(session.tracks) do
                if not track.muted then
                    emit(track:compile(ctx))
                end
            end
        end
    end
    return render
end)

-- The live pointer: whatever the runtime calls
local current_render = compile_session(initial_session)
```

That's it. `current_render` is a Terra function. It compiles on first call. The audio thread (or render loop, or network handler, or whatever the hot path is) calls it:

```lua
-- The hot loop calls whatever current_render points to
current_render(output_buf, buffer_size, time, state)
```

### What happens on edit

When the domain configuration changes — user adds an effect, resizes a widget tree, changes a map style, edits a simulation parameter — the new configuration produces a new ASDL tree. The compiler runs again:

```lua
-- User adds a reverb to track 3.
-- This produces a new session ASDL tree (new Lua table).
local new_session = apply_edit(old_session, edit)

-- Compile the new session.
-- terralib.memoize checks: have we seen this exact session before?
--   YES → return the cached Terra function instantly. Zero cost.
--   NO  → run the generator, produce a new Terra function, cache it.
current_render = compile_session(new_session)

-- Next time the hot loop runs, it calls the new function.
-- No lock. No synchronization. Just a pointer that changed.
```

The hot loop doesn't know anything changed. It calls `current_render`. If the pointer changed between calls, it calls the new function. If not, it calls the old one. The transition is invisible.

### Why this is safe

The old function is still in memory. `terralib.memoize` holds a reference to every function it has ever produced. The old function's machine code lives in the JIT memory pool until the process exits (or until the memoize cache is explicitly cleared, which we never do). So even if the hot loop is mid-call when the pointer changes, it finishes the old call normally. The next call picks up the new pointer.

For audio threads where even a single-sample glitch matters, you can use an atomic pointer swap. But in most cases, Lua's single-threaded execution model means the pointer update and the function call can't race — they happen in the same thread, or the calling thread reads a consistent pointer value.

### What memoize gives you for free

`terralib.memoize` turns the configuration space into a cache. Every unique configuration you visit produces a compiled function. Every revisit is a cache hit. This means:

**Undo is instant.** The user undoes "add reverb." The session reverts to the previous ASDL tree. `compile_session(old_session)` hits the memoize cache. The old function pointer is returned. Zero compilation. The function pointer swaps back to the previous native code.

**A/B comparison is instant.** Toggle between two configurations (e.g. with/without an EQ, two different map styles, two different particle system configs). Each toggle is a memoize hit after the first compilation. The cost is one pointer assignment.

**Toggle operations are instant.** Mute a track. Unmute it. Mute it again. Each state is a distinct session → a distinct cached function. After the first two compilations (muted and unmuted), every subsequent toggle is a cache hit. The compiled function for the muted state has literally zero code for that track — it was compiled without it.

**The system gets faster with use.** Over an editing session, the user explores maybe 20-50 distinct configurations. After a few minutes, almost every edit maps to a configuration that's already been compiled. The DAW (or map renderer, or UI, or simulation) becomes more responsive over time, not less.

### Granular memoization: only what changed recompiles

The examples above show memoization at the session level. But `terralib.memoize` is composable. You memoize at EVERY level of the hierarchy: per-effect, per-track, per-session. When one thing changes, only the functions that depend on it recompile. Everything else is a cache hit.

**Critical rule: state structs must be as granular as the memoized functions.** Each level returns both a compiled function AND the state type it needs. The child function takes a pointer to its OWN state type, never the parent's. The parent composes child state types into its own struct by embedding them as fields. This guarantees that a cache hit on track 2 is memory-safe even when track 1's layout changes — track 2's function was compiled against `TrackState_2`, which hasn't changed.

If you break this rule — if `compile_track` returns a function that takes `&GlobalSessionState` — then a cache hit is a lie. The cached function was compiled against the old struct layout. If another track's edit changes the global struct (e.g. adds a biquad state slot), the field offsets shift, and the cached function reads garbage. Cache hit, silent memory corruption.

The fix is structural: each memoized function owns its ABI.

```lua
-- ── Level 1: Effect ──
-- Returns { fn = terra_function, state_t = terra_struct_type }
-- The function takes a pointer to its OWN state type.
local compile_effect = terralib.memoize(function(effect)
    if effect.kind == "Gain" then
        local factor = math.pow(10, effect.db / 20.0)
        -- Gain has no state. Empty struct.
        local S = terralib.types.newstruct("GainState")
        S.entries = {}
        local fn = terra(buf: &float, n: int, state: &S)
            for i = 0, n do buf[i] = buf[i] * [float](factor) end
        end
        return { fn = fn, state_t = S }

    elseif effect.kind == "Biquad" then
        local b0, b1, b2, a1, a2 = compute_biquad(effect.freq, effect.q)
        -- Biquad needs 4 floats of filter history.
        local S = terralib.types.newstruct("BiquadState")
        S.entries = {
            {field = "x1", type = float}, {field = "x2", type = float},
            {field = "y1", type = float}, {field = "y2", type = float},
        }
        local fn = terra(buf: &float, n: int, state: &S)
            for i = 0, n do
                var x = buf[i]
                var y = [float](b0)*x + [float](b1)*state.x1
                      + [float](b2)*state.x2
                      - [float](a1)*state.y1 - [float](a2)*state.y2
                state.x2 = state.x1; state.x1 = x
                state.y2 = state.y1; state.y1 = y
                buf[i] = y
            end
        end
        return { fn = fn, state_t = S }
    end
end)

-- ── Level 2: Track ──
-- Compiles each effect, collects their state types,
-- composes them into a TrackState struct.
-- Returns { fn = terra_function, state_t = TrackState }
-- The function takes &TrackState, never &SessionState.
local compile_track = terralib.memoize(function(track)
    -- Compile effects. Unchanged effects are cache hits.
    local compiled_fx = track.effects:map(function(fx)
        return compile_effect(fx)
    end)

    -- Build the TrackState struct from child state types.
    local TrackState = terralib.types.newstruct("TrackState")
    local entries = terralib.newlist()
    entries:insert({field = "track_buf", type = float[1024]})
    for i, cfx in ipairs(compiled_fx) do
        entries:insert({field = "fx_" .. i, type = cfx.state_t})
    end
    TrackState.entries = entries

    local fader = math.pow(10, track.fader_db / 20.0)

    local fn = terra(out_L: &float, out_R: &float, n: int, state: &TrackState)
        -- Zero track working buffer
        C.memset(&state.track_buf, 0, n * [terralib.sizeof(float)])

        -- ... clip reading into state.track_buf ...

        -- Apply effects in order. Each gets its own state slice.
        escape
            for i, cfx in ipairs(compiled_fx) do
                emit quote
                    [cfx.fn](&state.track_buf[0], n, &state.["fx_" .. i])
                end
            end
        end

        -- Fader gain (baked constant) and sum into output
        for i = 0, n do
            var s = state.track_buf[i] * [float](fader)
            out_L[i] = out_L[i] + s
            out_R[i] = out_R[i] + s
        end
    end

    return { fn = fn, state_t = TrackState }
end)

-- ── Level 3: Session ──
-- Compiles each track, collects their state types,
-- composes them into a SessionState struct.
-- Returns the top-level render function.
local compile_session = terralib.memoize(function(session)
    -- Compile tracks. Unchanged tracks are cache hits.
    local compiled_tracks = terralib.newlist()
    for _, track in ipairs(session.tracks) do
        if not track.muted then
            compiled_tracks:insert(compile_track(track))
        end
    end

    -- Build SessionState from child TrackStates.
    local SessionState = terralib.types.newstruct("SessionState")
    local entries = terralib.newlist()
    for i, ct in ipairs(compiled_tracks) do
        entries:insert({field = "track_" .. i, type = ct.state_t})
    end
    SessionState.entries = entries

    local render = terra(
        out_L: &float, out_R: &float,
        n: int, time: double,
        state: &SessionState
    )
        C.memset(out_L, 0, n * [terralib.sizeof(float)])
        C.memset(out_R, 0, n * [terralib.sizeof(float)])
        escape
            for i, ct in ipairs(compiled_tracks) do
                emit quote
                    [ct.fn](out_L, out_R, n, &state.["track_" .. i])
                end
            end
        end
    end

    return render
end)
```

### Why this is memory-safe

The key is the ABI boundary. Each memoized function is compiled against its own struct type:

- `compile_effect(biquad_1)` returns a function taking `&BiquadState`. This struct has exactly 4 floats: `x1, x2, y1, y2`. The field offsets are 0, 4, 8, 12. These offsets are baked into the compiled machine code.

- `compile_track(track_2)` returns a function taking `&TrackState_2`. This struct embeds `BiquadState` at a known offset inside its own layout. The track function passes `&state.fx_1` to the effect function — a pointer to the embedded `BiquadState`.

- `compile_session(session)` returns a function taking `&SessionState`. This struct embeds `TrackState_2` at a known offset. The session function passes `&state.track_2` to the track function.

Now the critical scenario: the user adds an effect to track 1. What happens?

```
Track 1 changed → compile_track(track_1) cache miss
    → new TrackState_1 (bigger, has one more effect state)
    → new track 1 function compiled against new TrackState_1

Track 2 unchanged → compile_track(track_2) CACHE HIT
    → same TrackState_2 as before
    → same track 2 function as before
    → this function reads state.fx_1 at offset 4096 (or wherever)
    → THAT OFFSET IS STILL CORRECT because TrackState_2 hasn't changed

Session changed → compile_session(new_session) cache miss
    → new SessionState with new TrackState_1 + old TrackState_2
    → TrackState_2 is now at a DIFFERENT offset in SessionState
       (because TrackState_1 grew)
    → BUT the session function passes &state.track_2 to the track function
    → the track function receives a pointer to its own TrackState_2
    → it doesn't know or care where that pointer came from
    → all internal offsets are relative to the pointer base, which is correct
```

The session-level function regenerates (cache miss), so it correctly computes the new offset of `track_2` inside the new `SessionState`. It passes the right pointer. The track-level function is a cache hit — it doesn't regenerate. But it doesn't need to, because its ABI (pointer to `TrackState_2`) hasn't changed. The pointer it receives is valid. The struct behind the pointer is the same type it was compiled for.

This is the same principle as dynamic linking: a library function takes a pointer to a struct it knows about. The caller is responsible for placing that struct at the right address. The function doesn't know where the struct lives in the caller's memory — only what it looks like. Changing another library's struct doesn't invalidate this library's code.

### The persistent data structure pattern

For the cache hits to be correct, unchanged subtrees must be reused by REFERENCE, not by copy. When the user edits track 3:

```lua
-- WRONG: deep-copying the session and mutating
local new_session = deep_copy(old_session)
new_session.tracks[3].effects[2].freq = 2000

-- The deep copy creates new Lua tables for ALL tracks.
-- compile_track(new_track_1) misses — different Lua object.
-- Even though track_1 is structurally identical to before.
-- All tracks recompile. Granular memoization is defeated.
```

```lua
-- RIGHT: structural sharing
local new_biquad = M.Biquad(2, 2000, 0.707)  -- new node
local new_effects = List {
    old_track_3.effects[1],  -- SAME Lua reference
    new_biquad,              -- new object
    old_track_3.effects[3],  -- SAME Lua reference
}
local new_track_3 = M.Track(
    old_track_3.name, new_effects, old_track_3.fader_db, false
)
local new_tracks = List {
    old_session.tracks[1],  -- SAME Lua reference → cache hit
    old_session.tracks[2],  -- SAME Lua reference → cache hit
    new_track_3,            -- new object → cache miss
    old_session.tracks[4],  -- SAME Lua reference → cache hit
    -- ...
}
local new_session = M.Session(new_tracks, old_session.sample_rate)
```

The old tracks are not copied — they're reused by reference. `terralib.memoize` checks arguments by Lua `==`. Same reference → same object → cache hit. This is a persistent data structure: new versions share unchanged subtrees with old versions. Both versions coexist in memory. The old session's tracks are the same Lua tables that the new session's `tracks[1]`, `tracks[2]`, `tracks[4]`... point to.

With ASDL `unique`, this sharing happens automatically for types declared `unique`: the constructor memoizes, so `M.Track("bass", same_effects, -6, false)` returns the exact same Lua table every time. For non-unique types, you must preserve references manually through structural sharing.

Now trace what happens when the user changes the EQ frequency on track 3:

```
User drags EQ freq on track 3
    ↓
new Biquad ASDL node (freq changed)
    ↓
new Track ASDL node for track 3 (effects list changed, shares other effects)
    ↓
new Session ASDL node (tracks list changed, shares other tracks)
    ↓
compile_session(new_session)
    ↓ cache miss — new session object
    compile_track(track_1)  → CACHE HIT (same Lua reference)
        → returns cached { fn, state_t = TrackState_1 }
    compile_track(track_2)  → CACHE HIT (same Lua reference)
        → returns cached { fn, state_t = TrackState_2 }
    compile_track(track_3)  → cache miss — new Lua object
        compile_effect(gain_on_track_3)    → CACHE HIT (same reference)
            → returns cached { fn, state_t = GainState }
        compile_effect(new_biquad)         → cache miss — new object
            → computes new biquad coefficients
            → generates new BiquadState (same layout, new constants)
            → generates new biquad function (~0.5ms)
        compile_effect(reverb_on_track_3)  → CACHE HIT (same reference)
            → returns cached { fn, state_t = ReverbState }
        → assembles new TrackState_3 from cached + new effect states
        → generates new track function (~1ms)
    compile_track(track_4)  → CACHE HIT (same Lua reference)
    ...
    compile_track(track_20) → CACHE HIT (same Lua reference)
    → assembles new SessionState from cached + new track states
       (TrackState_1 at offset 0, TrackState_2 at offset N, 
        NEW TrackState_3 at offset M, TrackState_4 at offset P...)
    → generates new session function (~2ms)
    → session function passes correct pointers to each track's state
    → ALL cached track functions receive pointers to their
       unchanged state types. Memory-safe.
```

Total recompilation: one biquad + one track + one session shell = ~3.5ms. NOT 20 tracks × 3 effects = 60 effects recompiled. Just the three functions on the path from the changed leaf to the root.

The cost is proportional to the DEPTH of the change (leaf → root), not the WIDTH of the session (number of tracks and effects). A 100-track session with one EQ change recompiles exactly the same amount as a 2-track session with one EQ change: one effect function, one track function, one session function.

The session-level function does still regenerate because it must compose the new `SessionState` struct (even though most `TrackState` types are unchanged, the embedding offsets may shift). But its generation is fast — it's just an `escape`/`emit` loop passing pointers to embedded substates. The expensive part (computing biquad coefficients, generating per-sample DSP code) only happens for the one changed effect.

This is why ASDL `unique` matters at every level, not just the top. ASDL `unique` guarantees that structurally identical values are the same Lua object (`==`). Combined with structural sharing in the edit path, unchanged subtrees trigger instant memoize hits. Combined with granular state types, those cache hits are memory-safe. The three pieces — `unique` identity, structural sharing, granular state — form a complete incremental compilation system.

### Why this largely eliminates manual state/lifetime management

A useful way to read the pattern is that **state management is not a separate engineering problem once the units are modeled correctly**. We do not first invent a global runtime state arena, then separately invent caches, then separately track which offsets belong to which child. Instead:

1. each memoized compiler returns its own `state_t`
2. the parent embeds child `state_t`s as fields in its own state struct
3. the parent passes `&state.child_i` to the child function
4. Terra's normal struct layout rules determine offsets and lifetime

That means the same hierarchy that gives us incremental compilation also gives us correct memory ownership:

- **ownership**: parent owns child state by embedding it
- **lifetime**: child state lives exactly as long as the parent state value that contains it
- **addressing**: the parent computes the correct child pointer by field access, not by hand-maintained offset tables
- **stability**: unchanged child units keep the same ABI and therefore remain valid cache hits

So when the model is correct, we get memory management "for free" in the precise sense that there is no additional conceptual subsystem needed for most stateful compilation problems. The semantic tree, the memoized compile units, and the composed state structs are already the ownership graph.

### Memoize boundaries as natural code size limits

There is a hidden problem with the pattern that granular memoization solves for free: **code explosion.**

Without memoize boundaries, everything inlines. The `escape`/`emit` loop in `compile_session` stitches quotes from every track, which stitch quotes from every effect. A 50-track session with 5 effects each produces ONE Terra function containing 250 inlined effect processors — thousands of instructions in a single function body. This causes two problems:

**LLVM compilation time goes superlinear with function size.** Register allocation is the bottleneck. LLVM's register allocator is roughly O(n²) in the number of live ranges. A 10,000-instruction function takes dramatically longer to compile than ten 1,000-instruction functions. The difference can be 100ms vs 5ms for the same total code.

**Instruction cache pressure at runtime.** A massive inlined function spreads across many cache lines. On each audio callback, the CPU fetches the entire function into I-cache. A 50-track inlined function might be 50KB of machine code — far exceeding the L1 I-cache of most CPUs (32-64KB). Cache misses on instruction fetch cause stalls in a context where every microsecond matters.

Granular memoization solves both problems because **each memoize boundary is a call boundary.** The memoized function at each level is a SEPARATE Terra function, not an inlined quote:

```
Without granular memoize (everything inlines into one function):

session_render:
    ┌─────────────────────────────────────────────────┐
    │ track_1_gain: mul loop                          │
    │ track_1_biquad: biquad loop                     │
    │ track_1_reverb: reverb loop (hundreds of ops)   │
    │ track_1_fader: mul loop                         │
    │ track_1_sum: add loop                           │
    │ track_2_gain: mul loop                          │
    │ track_2_biquad: biquad loop                     │
    │ ...                                             │
    │ track_50_fader: mul loop                        │
    │ track_50_sum: add loop                          │
    └─────────────────────────────────────────────────┘
    One function. ~50KB of machine code. LLVM spends 100ms+
    on register allocation. I-cache thrashes at runtime.

With granular memoize (each level is a separate function):

session_render:          (~500 bytes)
    call track_1_render
    call track_2_render
    ...
    call track_50_render

track_3_render:          (~200 bytes)
    call effect_1_fn     (gain)
    call effect_2_fn     (biquad)
    call effect_3_fn     (reverb)
    fader mul loop
    sum into output

effect_2_fn:             (~150 bytes)
    biquad loop with baked coefficients

    50 track functions × ~200 bytes + 150 effect functions × ~150 bytes
    = ~32KB total. But each individual function is 150-500 bytes.
    LLVM compiles each in <1ms. I-cache only needs the currently
    executing function (~1-2 cache lines).
```

The effect function is small — one sample loop with baked coefficients. LLVM optimizes it perfectly: loop vectorization, constant folding, register allocation takes microseconds. The track function is small — a few calls plus a fader multiply and sum. The session function is tiny — just calls.

At runtime, the CPU executes one effect function at a time. It's 150 bytes — fits in 3 cache lines. The next effect function probably shares the same cache lines (they have similar structure). The track function is a few calls and a loop — trivially fits in cache. There's no I-cache pressure because no single function is large.

The function call overhead is negligible. A `call` instruction on x86 is 1 cycle for the call itself, plus 1-2 cycles for the return prediction. In a 256-sample audio buffer, you're doing 256 iterations of the sample loop inside each effect. The call/return overhead is < 0.01% of the total work.

**The memoize boundaries are doing three jobs simultaneously:**

1. **Incremental compilation** — only recompile what changed
2. **Code size control** — each function is small enough for LLVM to optimize efficiently
3. **I-cache friendliness** — each function fits in L1 I-cache

None of these were designed. They're all the same mechanism — a `terralib.memoize` call that returns a separate Terra function — observed from three different angles.

This also means the granularity of memoization is a tuning knob. If you memoize too coarsely (session-level only), you get one huge function, slow compilation, and I-cache thrashing. If you memoize too finely (per-sample-operation), you get thousands of tiny functions with call overhead dominating. The right granularity matches the domain's natural hierarchy: per-effect, per-track, per-session. Each level corresponds to a meaningful DSP boundary where the function size is 100-500 bytes of machine code — the sweet spot for both LLVM and the CPU.

### The compilation cost

With granular memoization, cache misses only recompile the changed path. The cost depends on the depth of the change, not the size of the project:

| Edit type | What recompiles | Typical cost |
|---|---|---|
| Change one knob value on one effect | 1 effect + 1 track + 1 session shell | ~2-4ms |
| Add/remove an effect on one track | 1 track + 1 session shell | ~3-5ms |
| Add/remove a track | 1 session shell | ~2-5ms |
| Mute/unmute a track | 1 session shell (track fn cached from before) | ~1-2ms |
| Undo any of the above | All levels hit cache | <0.1ms |
| Change a global parameter (BPM, sample rate) | Everything — new session config invalidates all | ~10-20ms |

Only the last case — a global parameter change — recompiles the entire tree. Every other edit touches only the path from the changed leaf to the root. A 100-track session and a 5-track session have the same recompilation cost for a single-effect edit.

The key: during compilation, the OLD function keeps running. The hot loop never stalls. It calls whatever `current_render` pointed to when it last read the pointer. When compilation finishes and the pointer updates, the next iteration calls the new function. The transition is seamless.

For low-latency audio systems, the stronger form is: keep a **stable callback** and publish a coherent **engine image** containing the function pointer plus the root state pointer it was compiled for. The callback itself never changes. It just reads the current engine image and calls through it. Compilation happens on the edit path; playback only sees already-compiled native code plus the matching state image.

For domains where even 1-buffer latency matters, you can pre-warm: force LLVM compilation before publication (`fn:compile()` or an equivalent warm-up call) and then swap the engine image pointer. Then the swap is instantaneous — the function is already compiled.

### Complete example: hot-swappable audio engine

This example uses session-level memoization (one compiled function for the entire session). For production use with large projects, apply the granular pattern from the section above: memoize at each level with isolated state types, and publish a coherent engine image `{ fn_ptr, state_ptr }` through a stable callback. The session-level version here is simpler to read and demonstrates the hot-swap mechanism.

```lua
local asdl = require 'asdl'
local C = terralib.includecstring [[
    #include <math.h>
    #include <string.h>
    #include <stdatomic.h>
]]

-- Domain types
local M = asdl.NewContext()
M:Define [[
    Effect = Gain(number db)
           | Biquad(number type, number freq, number q)

    Track = (string name, Effect* effects, number fader_db, boolean muted)

    Session = (Track* tracks, number sample_rate) unique
]]

-- State struct generated from session
local make_state = terralib.memoize(function(session)
    local S = terralib.types.newstruct("State")
    local entries = terralib.newlist()
    -- One biquad state (4 floats) per biquad effect in the session
    local biquad_count = 0
    for _, track in ipairs(session.tracks) do
        for _, fx in ipairs(track.effects) do
            if fx.kind == "Biquad" then
                biquad_count = biquad_count + 1
            end
        end
    end
    entries:insert({field = "biquad_state", type = float[biquad_count * 4]})
    entries:insert({field = "track_buf", type = float[1024]})
    S.entries = entries
    return S
end)

-- Compile one effect to inline code
function M.Effect.Gain:compile(buf, n)
    local factor = math.pow(10, self.db / 20.0)
    return quote
        for i = 0, n do buf[i] = buf[i] * [float](factor) end
    end
end

function M.Effect.Biquad:compile(buf, n, state_ptr, biquad_idx)
    -- Compute biquad coefficients at compile time from self.freq, self.q
    local b0, b1, b2, a1, a2 = compute_biquad(self.type, self.freq, self.q, 44100)
    local base = biquad_idx * 4
    return quote
        for i = 0, n do
            var x = buf[i]
            var y = [float](b0)*x + [float](b1)*state_ptr[base]
                  + [float](b2)*state_ptr[base+1]
                  - [float](a1)*state_ptr[base+2]
                  - [float](a2)*state_ptr[base+3]
            state_ptr[base+1] = state_ptr[base]; state_ptr[base] = x
            state_ptr[base+3] = state_ptr[base+2]; state_ptr[base+2] = y
            buf[i] = y
        end
    end
end

-- THE MEMOIZED COMPILER
local compile_session = terralib.memoize(function(session)
    local StateT = make_state(session)

    local terra render(
        output_L: &float, output_R: &float,
        n: int, time: double,
        state: &StateT
    )
        -- Zero output
        C.memset(output_L, 0, n * [terralib.sizeof(float)])
        C.memset(output_R, 0, n * [terralib.sizeof(float)])

        escape
            local biquad_idx = 0
            for _, track in ipairs(session.tracks) do
                if not track.muted then
                    -- Zero track buffer
                    emit quote C.memset(
                        state.track_buf, 0,
                        n * [terralib.sizeof(float)]
                    ) end

                    -- ... (clip reading code would go here) ...

                    -- Apply effects (inlined, no dispatch)
                    for _, fx in ipairs(track.effects) do
                        if fx.kind == "Biquad" then
                            emit(fx:compile(
                                `state.track_buf, `n,
                                `&state.biquad_state[0], biquad_idx
                            ))
                            biquad_idx = biquad_idx + 1
                        else
                            emit(fx:compile(`state.track_buf, `n))
                        end
                    end

                    -- Fader gain (baked as constant)
                    var fader = [float](math.pow(10, track.fader_db / 20.0))
                    emit quote
                        for i = 0, n do
                            output_L[i] = output_L[i]
                                + state.track_buf[i] * fader
                            output_R[i] = output_R[i]
                                + state.track_buf[i] * fader
                        end
                    end
                end
                -- muted tracks: no code emitted. literally nothing.
            end
        end
    end

    return render
end)

-- ╔══════════════════════════════════════════════════╗
-- ║  THE RUNTIME: three lines                       ║
-- ╚══════════════════════════════════════════════════╝

-- Initial compilation
local session = build_session_from_project_file()
local current_fn = compile_session(session)

-- The audio callback (called by the audio driver)
-- Calls whatever current_fn points to. That's it.
local function audio_callback(output_L, output_R, n, time, state)
    current_fn(output_L, output_R, n, time, state)
end

-- On user edit (called by the UI thread)
local function on_edit(edit)
    local new_session = apply_edit(session, edit)
    session = new_session

    -- This is THE hot-swap.
    -- Cache hit? Instant. Cache miss? ~10ms, old function keeps running.
    current_fn = compile_session(new_session)
end

-- On undo
local function on_undo()
    session = undo_stack:pop()
    -- Almost always a cache hit. The previous session was compiled before.
    current_fn = compile_session(session)
end
```

### What this replaces

In a traditional system, live-reloading requires:

| Traditional approach | Lines of code | What can go wrong |
|---|---|---|
| Thread-safe message queue between UI and audio thread | ~200-500 | Priority inversion, queue overflow, ordering bugs |
| Lock-free ring buffer for parameter updates | ~300-500 | ABA problem, memory ordering, platform-specific atomics |
| Double-buffered state with swap flag | ~100-300 | Torn reads, state inconsistency during swap |
| Dynamic dispatch table for effect chain | ~200-400 | Cache misses, virtual call overhead, registration boilerplate |
| Hot-reload framework (dlopen/dlsym or equivalent) | ~500-1000 | Symbol resolution, ABI compatibility, state migration |
| Cache invalidation system | ~200-500 | Stale cache, over-invalidation, cache key design |

Total: 1500-3200 lines of infrastructure code.

In our pattern: zero. `terralib.memoize` is the cache. The function pointer is the swap. Terra's first-call compilation is the JIT. We wrote none of it.

### The insight

The entire live-recompilation system — JIT compilation, caching, incremental recompilation, state isolation, code size control, hot-swap, and most of what would traditionally be called state/memory management — is not a feature we built. It's an emergent property of one design decision applied at every level: `terralib.memoize` on functions that return `{ fn, state_t }`.

From that single decision, five properties emerge simultaneously:

1. **Incremental compilation.** Only the changed path from leaf to root recompiles. Unchanged subtrees are cache hits. Cost is O(depth), not O(total).

2. **State isolation.** Each function owns its own state type. The parent composes child states by embedding them. Cache hits are memory-safe because the cached function's ABI never changes.

3. **Memory/lifetime management by construction.** Child state is owned by the parent that embeds it. Lifetime follows normal value lifetime. Pointer correctness comes from field access into composed structs, not from a parallel manual offset/arena system.

4. **Code size control.** Each memoize boundary is a call boundary. Each function is 100-500 bytes of machine code — small enough for LLVM to optimize in <1ms, small enough to fit in L1 I-cache.

5. **Hot-swap.** Terra functions are Lua values. Reassigning the variable changes the function pointer. The hot loop calls whatever it points to. Old functions stay cached. Undo is a cache hit.

We didn't design four separate systems. We called `terralib.memoize` at three levels of the hierarchy and returned granular state types. Everything else followed.

No framework. No protocol. No infrastructure. Just Terra being Terra.


## Examples

Seven complete examples, each demonstrating specific facilities. They build in complexity: the first uses only ASDL + quotes, the last uses everything.


### Example 1: Expression compiler

Demonstrates: ASDL sum types, method dispatch by variant, quotes composing recursively, escape to splice, `terralib.memoize`.

```lua
local asdl = require 'asdl'
local List = require 'terralist'
local C = terralib.includecstring [[
    #include <math.h>
    #include <stdio.h>
]]

local M = asdl.NewContext()
M:Define [[
    Expr = Lit(number v)
         | Var(string name)
         | BinOp(string op, Expr lhs, Expr rhs)
         | UnaryOp(string op, Expr arg)
         | Call(string fn, Expr* args)
         | Cond(Expr test, Expr yes, Expr no)
]]

-- Parent fallback FIRST (ASDL ordering rule)
function M.Expr:compile(env)
    error("compile not implemented for " .. self.kind)
end

-- Child methods
function M.Expr.Lit:compile(env)
    return `[double](self.v)
end

function M.Expr.Var:compile(env)
    local sym = env[self.name]
    if not sym then error("undefined: " .. self.name) end
    return `sym
end

function M.Expr.BinOp:compile(env)
    local l = self.lhs:compile(env)
    local r = self.rhs:compile(env)
    local ops = {
        ["+"] = function(a,b) return `a + b end,
        ["-"] = function(a,b) return `a - b end,
        ["*"] = function(a,b) return `a * b end,
        ["/"] = function(a,b) return `a / b end,
        ["%"] = function(a,b) return `a % b end,
        ["^"] = function(a,b) return `C.pow(a, b) end,
    }
    return ops[self.op](l, r)
end

function M.Expr.UnaryOp:compile(env)
    local a = self.arg:compile(env)
    if self.op == "-" then return `-a
    elseif self.op == "abs" then return `C.fabs(a)
    elseif self.op == "sqrt" then return `C.sqrt(a)
    elseif self.op == "sin" then return `C.sin(a)
    elseif self.op == "cos" then return `C.cos(a)
    elseif self.op == "log" then return `C.log(a)
    elseif self.op == "exp" then return `C.exp(a)
    end
end

function M.Expr.Call:compile(env)
    local compiled_args = self.args:map(function(a) return a:compile(env) end)
    local fn_sym = env[self.fn]
    return `fn_sym([compiled_args])
end

function M.Expr.Cond:compile(env)
    local t = self.test:compile(env)
    local y = self.yes:compile(env)
    local n = self.no:compile(env)
    return `terralib.select(t > 0.0, y, n)
end

-- Compile an expression tree into a Terra function.
-- terralib.memoize: same tree → same function.
local compile_expr = terralib.memoize(function(expr, param_names)
    local param_syms = param_names:map(function(n)
        return symbol(double, n)
    end)
    local env = {}
    for i, n in ipairs(param_names) do
        env[n] = param_syms[i]
    end
    local body = expr:compile(env)

    local fn = terra([param_syms]) : double
        return [body]
    end
    return fn
end)

-- Usage:
-- Build the AST: sin(x) * cos(y) + 0.5
local tree = M.BinOp("+",
    M.BinOp("*",
        M.UnaryOp("sin", M.Var("x")),
        M.UnaryOp("cos", M.Var("y"))),
    M.Lit(0.5))

local fn = compile_expr(tree, List {"x", "y"})

-- Just call it. Terra compiles on first invocation automatically.
print(fn(3.14, 0))  -- sin(pi)*cos(0) + 0.5 ≈ 0.5
fn:disas()           -- see the LLVM-optimized assembly
```

The generated function is pure arithmetic — `sin`, `cos`, `mul`, `add`, no branches, no dispatch. LLVM can inline the math intrinsics and vectorize if called in a loop.


### Example 2: Struct from ASDL schema

Demonstrates: `__getentries`, `__staticinitialize`, `terralib.memoize`, ASDL driving struct layout, generated methods.

```lua
local asdl = require 'asdl'
local List = require 'terralist'
local C = terralib.includecstring [[
    #include <stdio.h>
    #include <string.h>
]]

local S = asdl.NewContext()
S:Define [[
    Field = (string name, string type, number size)
    Schema = (Field* fields, string name) unique
]]

-- Map schema type names to Terra types
local type_map = {
    f32 = float, f64 = double,
    i32 = int32, i64 = int64,
    u8 = uint8, u32 = uint32,
    bool = bool,
}

-- Generate a Terra struct from an ASDL schema
local make_struct = terralib.memoize(function(schema)
    local T = terralib.types.newstruct(schema.name)

    T.metamethods.__getentries = function(self)
        return schema.fields:map(function(f)
            local terra_type = type_map[f.type]
            if f.size > 1 then
                terra_type = terra_type[f.size]
            end
            return {field = f.name, type = terra_type}
        end)
    end

    T.metamethods.__staticinitialize = function(self)
        -- Generate a print method that knows every field
        self.methods.dump = terra(self_ptr: &self)
            C.printf("[%s]\n", [schema.name])
            escape
                for _, f in ipairs(schema.fields) do
                    if f.type == "f32" or f.type == "f64" then
                        if f.size == 1 then
                            emit quote
                                C.printf("  %s = %f\n",
                                    [f.name], [double](self_ptr.[f.name]))
                            end
                        else
                            emit quote
                                C.printf("  %s = [", [f.name])
                                for i = 0, [f.size] do
                                    C.printf("%f ", [double](self_ptr.[f.name][i]))
                                end
                                C.printf("]\n")
                            end
                        end
                    elseif f.type == "i32" or f.type == "u32" or f.type == "i64" then
                        emit quote
                            C.printf("  %s = %d\n",
                                [f.name], [int](self_ptr.[f.name]))
                        end
                    elseif f.type == "bool" then
                        emit quote
                            C.printf("  %s = %s\n",
                                [f.name],
                                terralib.select(self_ptr.[f.name],
                                    "true", "false"))
                        end
                    end
                end
            end
        end

        -- Generate a zero method
        self.methods.zero = terra(self_ptr: &self)
            C.memset(self_ptr, 0, [terralib.sizeof(self)])
        end

        -- Generate a size query
        self.methods.byte_size = terra() : int
            return [terralib.sizeof(self)]
        end
    end

    return T
end)

-- Usage:
local vec3_schema = S.Schema(List {
    S.Field("x", "f32", 1),
    S.Field("y", "f32", 1),
    S.Field("z", "f32", 1),
}, "Vec3")

local particle_schema = S.Schema(List {
    S.Field("pos", "f32", 3),
    S.Field("vel", "f32", 3),
    S.Field("mass", "f32", 1),
    S.Field("alive", "bool", 1),
}, "Particle")

local Vec3 = make_struct(vec3_schema)
local Particle = make_struct(particle_schema)

terra test()
    var v : Vec3
    v.x = 1.0f; v.y = 2.0f; v.z = 3.0f
    v:dump()

    var p : Particle
    p:zero()
    p.pos = array(1.0f, 2.0f, 3.0f)
    p.mass = 0.5f
    p.alive = true
    p:dump()

    C.printf("Particle size: %d bytes\n", Particle.methods.byte_size())
end

test()
```

The struct layout, the `dump` method, the `zero` method — all generated from the ASDL schema. Change the schema, rerun, get a new struct with new methods. No hand-written serialization.


### Example 3: Custom iteration with `__for`

Demonstrates: `__for` metamethod, ASDL describing a data format, compiled decoding inlined into iteration.

```lua
local asdl = require 'asdl'
local List = require 'terralist'
local C = terralib.includecstring [[
    #include <stdio.h>
    #include <string.h>
]]

local D = asdl.NewContext()
D:Define [[
    ColumnDef = (string name, string type)
    TableDef = (string name, ColumnDef* columns) unique
]]

-- A row-store table: header + packed rows
struct TableStore {
    data: &uint8
    row_count: int32
    row_stride: int32
}

-- Generate a Row struct and iteration from a table definition
local make_table_api = terralib.memoize(function(table_def)
    local type_map = {f64 = double, i32 = int32, bool = bool}

    -- Row struct via __getentries
    local Row = terralib.types.newstruct("Row_" .. table_def.name)
    Row.metamethods.__getentries = function(self)
        return table_def.columns:map(function(c)
            return {field = c.name, type = type_map[c.type]}
        end)
    end

    -- __for on TableStore: iterate rows with compiled decoding
    -- Each column read is at a known offset (baked at compile time)
    TableStore.metamethods.__for = function(iter, body)
        return quote
            var store = iter
            for i = 0, store.row_count do
                var row : Row
                var base = store.data + i * store.row_stride
                escape
                    local offset = 0
                    for _, col in ipairs(table_def.columns) do
                        local tt = type_map[col.type]
                        local sz = terralib.sizeof(tt)
                        emit quote
                            C.memcpy(&row.[col.name], base + [offset], [sz])
                        end
                        offset = offset + sz
                    end
                end
                [body(`row)]
            end
        end
    end

    return {Row = Row, stride = terralib.sizeof(Row)}
end)

-- Usage: define a table, get compiled iteration

local people_def = D.TableDef("people", List {
    D.ColumnDef("age", "i32"),
    D.ColumnDef("salary", "f64"),
    D.ColumnDef("active", "bool"),
})

local api = make_table_api(people_def)

-- This terra function uses __for — the decoding is inlined
terra sum_salary_of_active(store: TableStore) : double
    var total = 0.0
    for row in store do
        if row.active then
            total = total + row.salary
        end
    end
    return total
end

-- The compiled function reads specific bytes at specific offsets.
-- No column name lookup. No type dispatch. Just loads.
sum_salary_of_active:disas()
```

The `for row in store do` expands to a loop where each column is read from a known byte offset. The generated code is equivalent to hand-written C with hardcoded struct offsets.


### Example 4: Type conversions with `__cast`

Demonstrates: `__cast` for automatic conversions, operator metamethods for domain arithmetic, quotes composing through operators.

```lua
local C = terralib.includecstring [[ #include <math.h> ]]

struct Color { r: float; g: float; b: float; a: float }

-- Construct from hex integer
Color.metamethods.__cast = function(from, to, exp)
    if from:isintegral() and to == Color then
        return quote
            var v = [uint32](exp)
            in Color {
                [float]((v >> 24) and 0xFF) / 255.0f,
                [float]((v >> 16) and 0xFF) / 255.0f,
                [float]((v >> 8) and 0xFF) / 255.0f,
                [float](v and 0xFF) / 255.0f
            }
        end
    elseif from == float and to == Color then
        -- Grayscale
        return `Color { exp, exp, exp, 1.0f }
    elseif from == Color and to == float then
        -- Luminance
        return `0.2126f * exp.r + 0.7152f * exp.g + 0.0722f * exp.b
    else
        error("invalid Color cast")
    end
end

-- Arithmetic: component-wise
Color.metamethods.__add = terra(a: Color, b: Color): Color
    return Color { a.r+b.r, a.g+b.g, a.b+b.b, a.a+b.a }
end
Color.metamethods.__sub = terra(a: Color, b: Color): Color
    return Color { a.r-b.r, a.g-b.g, a.b-b.b, a.a-b.a }
end
Color.metamethods.__mul = terra(a: Color, b: float): Color
    return Color { a.r*b, a.g*b, a.b*b, a.a*b }
end

-- Now lerp is generic — works for float AND Color
-- with no type dispatch
local function make_lerp(T)
    return terra(a: T, b: T, t: float): T
        return a + (b - a) * t
    end
end

local lerp_float = make_lerp(float)
local lerp_color = make_lerp(Color)

terra demo()
    -- __cast from int: hex color literal
    var bg : Color = [Color](0xFF8800FF)

    -- __cast from float: grayscale
    var gray : Color = [Color](0.5f)

    -- __cast to float: luminance
    var lum : float = [float](bg)

    -- Operator metamethods: lerp works on Color
    var sunrise = lerp_color(
        [Color](0x1a0533FF),   -- deep purple
        [Color](0xFF6B35FF),   -- orange
        0.5f)

    -- And on float
    var mid = lerp_float(10.0f, 20.0f, 0.5f)
end
```

The `make_lerp` function generates a Terra function using `+`, `-`, `*`. For `float`, these are native operators. For `Color`, they dispatch to our metamethods. The generated code is component-wise arithmetic — no runtime type check.

This is the pattern that makes expression compilers work on both scalar and color properties with one codepath.


### Example 5: Compile-time dispatch with `__methodmissing` and `__entrymissing`

Demonstrates: macros as metamethods, compile-time decision making, ASDL classification data driving code generation.

```lua
local asdl = require 'asdl'
local List = require 'terralist'
local C = terralib.includecstring [[ #include <stdio.h> ]]

local M = asdl.NewContext()
M:Define [[
    PropDef = (string name, string type, boolean dynamic)
]]

-- Simulate a "classified style" — some properties are constant,
-- some vary per-element

local schema = List {
    M.PropDef("width",  "f32", false),    -- constant
    M.PropDef("height", "f32", false),    -- constant
    M.PropDef("color",  "f32", true),     -- dynamic (per element)
    M.PropDef("opacity","f32", true),     -- dynamic (per element)
    M.PropDef("label",  "str", false),    -- constant
}

-- Build a struct where constant props are baked in,
-- dynamic props are stored as fields
local make_element = terralib.memoize(function(schema, constants)
    local T = terralib.types.newstruct("Element")

    -- Only dynamic fields get struct entries
    T.metamethods.__getentries = function(self)
        return schema:filter(function(p) return p.dynamic end)
            :map(function(p)
                if p.type == "f32" then
                    return {field = p.name, type = float}
                elseif p.type == "str" then
                    return {field = p.name, type = rawstring}
                end
            end)
    end

    -- __entrymissing: constant props return inlined values,
    -- dynamic props should never miss (they're real fields)
    T.metamethods.__entrymissing = macro(function(entryname, obj)
        local name = entryname:asvalue()
        -- Look up in constants table
        if constants[name] ~= nil then
            local val = constants[name]
            if type(val) == "number" then
                return `[float](val)
            elseif type(val) == "string" then
                return `[rawstring](val)
            end
        end
        error("unknown property: " .. name)
    end)

    -- __methodmissing: get_X() returns the value regardless
    -- of whether it's constant or dynamic.
    -- The caller doesn't know which it is.
    T.metamethods.__methodmissing = macro(function(name, obj)
        local method_name = name:asvalue()
        local prop_name = method_name:sub(5)  -- strip "get_"
        if not method_name:match("^get_") then
            error("unknown method: " .. method_name)
        end

        -- Check if it's a dynamic field
        for _, p in ipairs(schema) do
            if p.name == prop_name and p.dynamic then
                return `obj.[prop_name]  -- real field access
            end
        end
        -- Must be constant — check entrymissing will handle it
        if constants[prop_name] ~= nil then
            local val = constants[prop_name]
            return `[float](val)
        end
        error("unknown property: " .. prop_name)
    end)

    return T
end)

-- Create an element type with specific constant values
local Elem = make_element(schema, {
    width = 100,
    height = 50,
    label = "hello",
})

-- This function uses __entrymissing and __methodmissing.
-- Constant props are inlined. Dynamic props are field reads.
-- The generated code has NO dispatch.
terra process(elems: &Elem, count: int) : float
    var total : float = 0.0f
    for i = 0, count do
        var e = elems[i]

        -- e.width → __entrymissing → `100.0f (constant, inlined)
        -- e.color → real field access (dynamic)
        -- e:get_opacity() → __methodmissing → real field access
        -- e:get_width() → __methodmissing → `100.0f (constant)

        total = total + e.color * e.opacity * e.width * e.height
    end
    return total
end

process:disas()
-- The disassembly shows: load color, load opacity,
-- multiply by 100.0 * 50.0 = 5000.0 (constant-folded by LLVM),
-- accumulate. No property lookup, no string comparison.
```

This is the core of the MapLibre pattern: properties classified as constant become inlined values via `__entrymissing`. Properties classified as dynamic become field reads. The user code (`e.width`, `e.color`, `e:get_opacity()`) looks uniform. The generated code is specialized.


### Example 6: Full pipeline with modules, phases, and lowering

Demonstrates: ASDL modules as compiler phases, methods on each phase that lower to the next, progressive resolution of sum types, `unique` for structural identity, the complete flow from source to machine code.

```lua
local asdl = require 'asdl'
local List = require 'terralist'
local C = terralib.includecstring [[
    #include <stdio.h>
    #include <math.h>
]]

local T = asdl.NewContext()
T:Extern("TerraType", terralib.types.istype)

T:Define [[
    -- Phase 1: Source — the parsed representation
    -- Sum types everywhere: types unresolved, ops as strings
    module Src {
        Type = IntType | FloatType | BoolType
             | ArrayType(Src.Type elem, number size)

        Expr = Lit(number v)
             | Var(string name)
             | BinOp(string op, Src.Expr lhs, Src.Expr rhs)
             | ArrayNew(Src.Expr* elems)
             | ArrayGet(Src.Expr arr, Src.Expr idx)
             | Let(string name, Src.Expr value, Src.Expr body)
             | If(Src.Expr cond, Src.Expr then_e, Src.Expr else_e)

        Decl = FnDecl(string name, Src.Param* params,
                       Src.Type ret, Src.Expr body)
        Param = (string name, Src.Type type)
    }

    -- Phase 2: Typed — types resolved, every node annotated
    -- Fewer sum types: Type is concrete
    module Typed {
        Expr = Lit(number v, TerraType type)
             | Var(string name, TerraType type)
             | BinOp(string op, Typed.Expr lhs, Typed.Expr rhs,
                     TerraType type)
             | ArrayNew(Typed.Expr* elems, TerraType type)
             | ArrayGet(Typed.Expr arr, Typed.Expr idx, TerraType type)
             | Let(string name, Typed.Expr value, Typed.Expr body,
                   TerraType type)
             | If(Typed.Expr cond, Typed.Expr then_e,
                  Typed.Expr else_e, TerraType type)
    }
]]

-- === Phase 1 → Phase 2: Type checking ===
-- Methods on Src types that produce Typed types

function T.Src.Type.IntType:to_terra()   return int end
function T.Src.Type.FloatType:to_terra() return double end
function T.Src.Type.BoolType:to_terra()  return bool end
function T.Src.Type.ArrayType:to_terra()
    return self.elem:to_terra()[self.size]
end

-- Type check: Src.Expr → Typed.Expr
function T.Src.Expr:check(env)
    error("check not implemented for " .. self.kind)
end

function T.Src.Expr.Lit:check(env)
    local t = (math.floor(self.v) == self.v) and int or double
    return T.Typed.Expr.Lit(self.v, t)
end

function T.Src.Expr.Var:check(env)
    local entry = env[self.name]
    if not entry then error("undefined: " .. self.name) end
    return T.Typed.Expr.Var(self.name, entry.type)
end

function T.Src.Expr.BinOp:check(env)
    local l = self.lhs:check(env)
    local r = self.rhs:check(env)
    -- Simple: both must be same type
    assert(l.type == r.type,
        "type mismatch in " .. self.op)
    return T.Typed.Expr.BinOp(self.op, l, r, l.type)
end

function T.Src.Expr.If:check(env)
    local c = self.cond:check(env)
    local t = self.then_e:check(env)
    local e = self.else_e:check(env)
    assert(t.type == e.type, "if branches must match")
    return T.Typed.Expr.If(c, t, e, t.type)
end

function T.Src.Expr.Let:check(env)
    local v = self.value:check(env)
    local new_env = {}
    for k, val in pairs(env) do new_env[k] = val end
    new_env[self.name] = {type = v.type}
    local b = self.body:check(new_env)
    return T.Typed.Expr.Let(self.name, v, b, b.type)
end

function T.Src.Expr.ArrayNew:check(env)
    local checked = self.elems:map(function(e) return e:check(env) end)
    local elem_type = checked[1].type
    for _, c in ipairs(checked) do
        assert(c.type == elem_type, "array elements must match")
    end
    return T.Typed.Expr.ArrayNew(checked, elem_type[#checked])
end

function T.Src.Expr.ArrayGet:check(env)
    local arr = self.arr:check(env)
    local idx = self.idx:check(env)
    assert(arr.type:isarray(), "not an array")
    return T.Typed.Expr.ArrayGet(arr, idx, arr.type.type)
end


-- === Phase 2 → Terra: Code generation ===
-- Methods on Typed types that produce Terra quotes

function T.Typed.Expr:compile(env)
    error("compile not implemented for " .. self.kind)
end

function T.Typed.Expr.Lit:compile(env)
    return `[self.type](self.v)
end

function T.Typed.Expr.Var:compile(env)
    return `[env[self.name]]
end

function T.Typed.Expr.BinOp:compile(env)
    local l = self.lhs:compile(env)
    local r = self.rhs:compile(env)
    local ops = {
        ["+"]  = function(a,b) return `a + b end,
        ["-"]  = function(a,b) return `a - b end,
        ["*"]  = function(a,b) return `a * b end,
        ["/"]  = function(a,b) return `a / b end,
        ["<"]  = function(a,b) return `[int](a < b) end,
        [">"]  = function(a,b) return `[int](a > b) end,
        ["=="] = function(a,b) return `[int](a == b) end,
    }
    return ops[self.op](l, r)
end

function T.Typed.Expr.If:compile(env)
    local c = self.cond:compile(env)
    local t = self.then_e:compile(env)
    local e = self.else_e:compile(env)
    return `terralib.select(c ~= 0, t, e)
end

function T.Typed.Expr.Let:compile(env)
    local v = self.value:compile(env)
    local s = symbol(self.value.type, self.name)
    local new_env = {}
    for k, val in pairs(env) do new_env[k] = val end
    new_env[self.name] = s
    local b = self.body:compile(new_env)
    return quote var [s] = [v] in [b] end
end

function T.Typed.Expr.ArrayNew:compile(env)
    local compiled = self.elems:map(function(e) return e:compile(env) end)
    return `arrayof([self.type.type], [compiled])
end

function T.Typed.Expr.ArrayGet:compile(env)
    local arr = self.arr:compile(env)
    local idx = self.idx:compile(env)
    return `arr[idx]
end

-- === Compile a function declaration ===
local compile_fn = terralib.memoize(function(fn_decl)
    -- Type-check
    local env = {}
    local param_syms = List()
    for _, p in ipairs(fn_decl.params) do
        local tt = p.type:to_terra()
        local s = symbol(tt, p.name)
        env[p.name] = {type = tt}
        param_syms:insert(s)
    end

    local typed_body = fn_decl.body:check(env)

    -- Compile to Terra
    local compile_env = {}
    for _, p in ipairs(fn_decl.params) do
        for i, s in ipairs(param_syms) do
            if fn_decl.params[i].name == p.name then
                compile_env[p.name] = s
            end
        end
    end

    local body_quote = typed_body:compile(compile_env)
    local ret_type = fn_decl.ret:to_terra()

    local fn = terra([param_syms]) : ret_type
        return [body_quote]
    end
    fn:setname(fn_decl.name)
    return fn
end)

-- Usage: a tiny language compiled through two phases
local Src = T.Src

local program = Src.FnDecl(
    "quadratic", List {
        Src.Param("a", Src.FloatType),
        Src.Param("b", Src.FloatType),
        Src.Param("x", Src.FloatType),
    },
    Src.FloatType,
    -- a*x*x + b*x + 1.0
    Src.BinOp("+",
        Src.BinOp("+",
            Src.BinOp("*", Src.Var("a"),
                Src.BinOp("*", Src.Var("x"), Src.Var("x"))),
            Src.BinOp("*", Src.Var("b"), Src.Var("x"))),
        Src.Lit(1.0))
)

local fn = compile_fn(program)
print(fn(2.0, 3.0, 4.0))  -- 2*16 + 3*4 + 1 = 45.0
fn:disas()  -- two multiplies, two adds. LLVM optimizes beautifully.
```

This is the full pipeline: `Src.Expr` → (type check) → `Typed.Expr` → (compile) → Terra quote → (JIT) → native code. Two ASDL modules, two phases, each with methods that produce the next phase's output.


### Example 7: Everything together — a compiled particle system

Demonstrates: every facility in concert. ASDL for the domain, `__getentries` for the particle struct, `__for` for iteration, `__cast` for color conversion, operator metamethods for vector math, `__entrymissing` for force field access, `__staticinitialize` for buffer helpers, `terralib.memoize` for caching by system configuration, ASDL methods returning quotes for force evaluation.

```lua
local asdl = require 'asdl'
local List = require 'terralist'
local C = terralib.includecstring [[
    #include <math.h>
    #include <stdlib.h>
]]

-- ============================================================
-- ASDL: the particle system domain
-- ============================================================

local P = asdl.NewContext()
P:Define [[
    -- Forces
    Force = Gravity(number gx, number gy)
          | Drag(number coefficient)
          | Turbulence(number strength, number frequency)
          | Attractor(number x, number y, number strength, number radius)
          | Vortex(number x, number y, number strength)

    -- Color over lifetime
    ColorKey = (number t, number r, number g, number b, number a)

    -- Size over lifetime
    SizeKey = (number t, number size)

    -- A complete particle system config
    SystemConfig = (
        Force* forces,
        ColorKey* color_keys,
        SizeKey* size_keys,
        number emit_rate,
        number lifetime,
        number speed_min,
        number speed_max,
        number spread_angle
    ) unique
]]


-- ============================================================
-- Vec2 with operator metamethods
-- ============================================================

struct Vec2 { x: float; y: float }

Vec2.metamethods.__add = terra(a: Vec2, b: Vec2): Vec2
    return Vec2 { a.x+b.x, a.y+b.y }
end
Vec2.metamethods.__sub = terra(a: Vec2, b: Vec2): Vec2
    return Vec2 { a.x-b.x, a.y-b.y }
end
Vec2.metamethods.__mul = terra(a: Vec2, b: float): Vec2
    return Vec2 { a.x*b, a.y*b }
end

terra Vec2.methods.length(self: &Vec2): float
    return C.sqrtf(self.x*self.x + self.y*self.y)
end


-- ============================================================
-- Color struct with __cast
-- ============================================================

struct RGBA { r: float; g: float; b: float; a: float }

RGBA.metamethods.__add = terra(a: RGBA, b: RGBA): RGBA
    return RGBA { a.r+b.r, a.g+b.g, a.b+b.b, a.a+b.a }
end
RGBA.metamethods.__sub = terra(a: RGBA, b: RGBA): RGBA
    return RGBA { a.r-b.r, a.g-b.g, a.b-b.b, a.a-b.a }
end
RGBA.metamethods.__mul = terra(a: RGBA, b: float): RGBA
    return RGBA { a.r*b, a.g*b, a.b*b, a.a*b }
end


-- ============================================================
-- Particle struct from config (__getentries)
-- ============================================================

struct Particle {
    pos: Vec2
    vel: Vec2
    age: float
    lifetime: float
}


-- ============================================================
-- ParticleBuffer with __for
-- ============================================================

struct ParticleBuffer {
    data: &Particle
    count: int
    capacity: int
}

ParticleBuffer.metamethods.__for = function(iter, body)
    return quote
        var buf = iter
        for i = 0, buf.count do
            [body(`buf.data[i])]
        end
    end
end


-- ============================================================
-- Force compilation: ASDL methods → Terra quotes
-- ============================================================

-- Parent method FIRST
function P.Force:apply(pos, vel, dt)
    error("apply not implemented for " .. self.kind)
end

function P.Force.Gravity:apply(pos, vel, dt)
    return quote
        vel.x = vel.x + [float](self.gx) * dt
        vel.y = vel.y + [float](self.gy) * dt
    end
end

function P.Force.Drag:apply(pos, vel, dt)
    local coeff = self.coefficient
    return quote
        var factor = 1.0f - [float](coeff) * dt
        if factor < 0.0f then factor = 0.0f end
        vel.x = vel.x * factor
        vel.y = vel.y * factor
    end
end

function P.Force.Turbulence:apply(pos, vel, dt)
    local str = self.strength
    local freq = self.frequency
    return quote
        -- Simple noise: sin-based pseudo-turbulence
        -- Frequency and strength are compile-time constants
        var nx = C.sinf(pos.x * [float](freq) + pos.y * [float](freq) * 1.3f)
        var ny = C.cosf(pos.y * [float](freq) + pos.x * [float](freq) * 0.7f)
        vel.x = vel.x + nx * [float](str) * dt
        vel.y = vel.y + ny * [float](str) * dt
    end
end

function P.Force.Attractor:apply(pos, vel, dt)
    local ax, ay = self.x, self.y
    local str, rad = self.strength, self.radius
    return quote
        var dx = [float](ax) - pos.x
        var dy = [float](ay) - pos.y
        var dist = C.sqrtf(dx*dx + dy*dy) + 0.001f
        if dist < [float](rad) then
            var force = [float](str) / (dist * dist)
            vel.x = vel.x + (dx / dist) * force * dt
            vel.y = vel.y + (dy / dist) * force * dt
        end
    end
end

function P.Force.Vortex:apply(pos, vel, dt)
    local vx, vy, str = self.x, self.y, self.strength
    return quote
        var dx = pos.x - [float](vx)
        var dy = pos.y - [float](vy)
        var dist = C.sqrtf(dx*dx + dy*dy) + 0.001f
        -- Tangential force
        vel.x = vel.x + (-dy / dist) * [float](str) * dt / dist
        vel.y = vel.y + ( dx / dist) * [float](str) * dt / dist
    end
end


-- ============================================================
-- Color interpolation: compiled from color keys
-- ============================================================

local function compile_color_lookup(color_keys)
    -- Returns a macro that takes a `t` quote and returns an RGBA quote
    -- All keys are compile-time constants. Unrolled, no loop.
    return macro(function(t_quote)
        local result = symbol(RGBA, "color")
        local stmts = terralib.newlist()

        -- Default: first key's color
        local ck = color_keys[1]
        stmts:insert(quote
            var [result] = RGBA {
                [float](ck.r), [float](ck.g),
                [float](ck.b), [float](ck.a) }
        end)

        for i = 2, #color_keys do
            local lo = color_keys[i-1]
            local hi = color_keys[i]
            stmts:insert(quote
                if [t_quote] >= [float](lo.t) and [t_quote] < [float](hi.t) then
                    var frac = ([t_quote] - [float](lo.t))
                             / ([float](hi.t) - [float](lo.t))
                    -- __sub and __mul on RGBA handle component-wise math
                    var lo_c = RGBA { [float](lo.r), [float](lo.g),
                                      [float](lo.b), [float](lo.a) }
                    var hi_c = RGBA { [float](hi.r), [float](hi.g),
                                      [float](hi.b), [float](hi.a) }
                    [result] = lo_c + (hi_c - lo_c) * frac
                end
            end)
        end

        return quote [stmts] in [result] end
    end)
end


-- ============================================================
-- The compiler: config → monomorphic update function
-- ============================================================

local compile_updater = terralib.memoize(function(config)
    local forces = config.forces
    local color_lookup = compile_color_lookup(config.color_keys)

    -- The update function: specialized for this exact config.
    -- Forces are inlined. Color keys are unrolled.
    -- No dispatch on force type at runtime.
    return terra(buf: ParticleBuffer, dt: float,
                 out_pos: &Vec2, out_color: &RGBA, out_size: &float) : int
        var alive_count = 0

        -- __for on ParticleBuffer handles iteration
        for p in buf do
            p.age = p.age + dt

            -- Skip dead particles
            if p.age >= p.lifetime then goto continue end

            var t = p.age / p.lifetime  -- 0..1 normalized age

            -- Apply ALL forces — each is inlined, not dispatched
            escape
                for _, force in ipairs(forces) do
                    emit(force:apply(`p.pos, `p.vel, `dt))
                end
            end

            -- Integrate position
            p.pos = p.pos + p.vel * dt

            -- Color lookup — compiled, unrolled, no loop
            out_color[alive_count] = color_lookup(t)

            -- Size lookup — similarly unrolled
            escape
                local sizes = config.size_keys
                local result = symbol(float, "size")
                local stmts = terralib.newlist()
                stmts:insert(quote var [result] = [float](sizes[1].size) end)
                for i = 2, #sizes do
                    local lo, hi = sizes[i-1], sizes[i]
                    stmts:insert(quote
                        if t >= [float](lo.t) and t < [float](hi.t) then
                            var frac = (t - [float](lo.t))
                                     / ([float](hi.t) - [float](lo.t))
                            [result] = [float](lo.size)
                                     + frac * ([float](hi.size) - [float](lo.size))
                        end
                    end)
                end
                emit quote [stmts]; out_size[alive_count] = [result] end
            end

            out_pos[alive_count] = p.pos
            alive_count = alive_count + 1
            ::continue::
        end

        return alive_count
    end
end)


-- ============================================================
-- Usage
-- ============================================================

-- Define a fire particle system
local fire = P.SystemConfig(
    -- Forces: gravity pulls up, drag slows, turbulence adds life
    List {
        P.Gravity(0, -50),
        P.Drag(0.5),
        P.Turbulence(30, 2.0),
    },
    -- Color: white → yellow → orange → red → black
    List {
        P.ColorKey(0.0,  1.0, 1.0, 0.9, 1.0),
        P.ColorKey(0.2,  1.0, 0.8, 0.2, 0.9),
        P.ColorKey(0.5,  0.9, 0.3, 0.1, 0.7),
        P.ColorKey(0.8,  0.3, 0.1, 0.05, 0.3),
        P.ColorKey(1.0,  0.0, 0.0, 0.0, 0.0),
    },
    -- Size: grow then shrink
    List {
        P.SizeKey(0.0, 2.0),
        P.SizeKey(0.3, 5.0),
        P.SizeKey(1.0, 0.0),
    },
    -- Emit: 200 particles/sec, 1.5s lifetime, 50-100 speed, 30° spread
    200, 1.5, 50, 100, 30
)

-- terralib.memoize: same SystemConfig (unique) → same function.
local update_fire = compile_updater(fire)

-- Just call it or disassemble it.
-- Terra compiles on first invocation automatically.
-- The compiled function has:
-- - Gravity: vel.y -= 50*dt (constant folded)
-- - Drag: vel *= (1 - 0.5*dt) (coefficient baked in)
-- - Turbulence: sin/cos with freq=2.0, str=30 baked in
-- - Color: 5 keys, 4 lerps, unrolled
-- - Size: 3 keys, 2 lerps, unrolled
-- - No force-type dispatch, no color key array, no runtime config
update_fire:disas()

-- Changing to a snow system: different forces, different colors.
-- A completely different compiled function.
local snow = P.SystemConfig(
    List { P.Gravity(0, 20), P.Turbulence(15, 0.5) },
    List {
        P.ColorKey(0.0, 1,1,1, 0.0),
        P.ColorKey(0.1, 1,1,1, 0.8),
        P.ColorKey(0.9, 1,1,1, 0.8),
        P.ColorKey(1.0, 1,1,1, 0.0),
    },
    List { P.SizeKey(0.0, 3.0), P.SizeKey(1.0, 3.0) },
    100, 4.0, 10, 30, 180
)

local update_snow = compile_updater(snow)
-- Different config → different terralib.memoize key → new function.
-- But if we call compile_updater(fire) again, we get the cached one.
```

What this example demonstrates:

- **ASDL types** (`Force`, `ColorKey`, `SizeKey`, `SystemConfig`) model the domain
- **`unique` on `SystemConfig`** means structurally identical configs are `==`, enabling `terralib.memoize`
- **ASDL methods** (`Force:apply`) return Terra quotes — each force variant produces different code
- **`escape/emit`** iterates the force list — the only place Lua loops over ASDL children
- **`__for` on `ParticleBuffer`** generates the particle iteration loop
- **`__add`, `__sub`, `__mul` on `Vec2` and `RGBA`** make arithmetic read naturally
- **`macro()`** for `color_lookup` — a macro that receives a quote (`t`) and returns a quote (interpolated color)
- **`terralib.memoize`** caches by `SystemConfig` identity — same particle system config → same compiled function
- **Compile-time constant folding**: force parameters, color keys, and size keys are all Lua numbers that become constants in the generated code. LLVM folds `0 - 50*dt` to `-50*dt`, etc.

The fire updater and snow updater are completely different compiled functions. Each contains only the forces, colors, and sizes for that specific system. No runtime dispatch on force type, no array of color keys, no config struct to read. Just arithmetic.


## The ASDL as generative structure

The preceding sections describe the *mechanism*: how ASDL, metamethods, macros, and memoize combine to produce compiled code.  But when applied to a real multi-phase domain compiler, a deeper property emerges.  The ASDL schema stops being one component among many and becomes **the single generative structure from which the entire system derives**.

This is not a metaphor.  Each derivation below is a concrete, mechanically enforced consequence of modeling the domain as typed phases with methods.

### Specification

The ASDL types are the domain model.  They define what the system knows about — every concept, every relationship, every constraint.  The ASDL modules are the compiler phases.  The `methods {}` blocks declare the exact transitions between phases.  The schema comments document what each type means and what invariants it carries.  There is no separate spec document that can drift from the code, because the spec IS the code.

If the domain has user-facing concepts, the early-phase types map 1:1 to them.  The command families declared in the schema are the feature list.  If a concept is not in the ASDL, the system cannot represent it.

### Architecture

The ASDL modules define the **directory structure** — one top-level folder per phase.  The type families define the **file structure** — one file per type or tight sibling group.  The `methods {}` blocks define the **implementation units** — one function per method, independently implementable, independently testable.  The file tree reads like the schema tree because it IS the schema tree.

No secondary module architecture needs to be invented.  The schema has already decomposed the problem.

### Error boundaries

Each ASDL method boundary is exactly one error boundary.  Every method can be wrapped:

```lua
wrap(ctx, code, status, function()
    return body()          -- the real implementation
end, function(err)
    return fallback()      -- valid degraded output for the target type
end)
```

If the body throws, the fallback fires.  The error is local: one subtree failing does not destroy the whole document.  This works because every ASDL target type admits a valid empty/neutral fallback — silence for audio, passthrough for effects, a placeholder panel for UI, an empty document for project-level types.  The type system guarantees the fallback is well-formed.

The error boundary and the type boundary are the same thing.  No additional error-handling architecture is needed.

### Compilation boundaries

Each phase transition is a total function from one complete typed document to another.  No phase needs to look beyond its immediate input.  In a pipeline of N phases, there is no coupling between non-adjacent phases.  Phase 1 and phase N can be worked on by different people who have never spoken to each other, because the intermediate types define the contract completely.

### Memory and allocation

The phase pipeline eliminates entire categories of state management complexity:

- **No persistent mutable application state.**  The current phase-0 tree IS the application state.  Recompile from it whenever anything changes.  The memoize cache makes this fast.
- **No incremental mutation tracking.**  No observer/listener subscriptions, no invalidation cascades, no dirty flags.  Phases are pure functions: ASDL in, ASDL out.
- **No stale references.**  ASDL trees have value semantics.  Each phase owns its output completely.  When a new output replaces the old one, the old one can be dropped.  There is nothing to "unsubscribe" from.
- **No complex ownership.**  With `unique` types, structurally identical subtrees share identity automatically.  The memoize cache holds references to previous compilations.  Undo is a cache hit, not a state-restoration operation.
- **No runtime boxing.**  The final phase produces monomorphic Terra structs with known layouts.  The ASDL pipeline is effectively the allocator: it decides what runtime memory exists by what it constructs.  Nothing is allocated that wasn't declared in the schema.

The conventional approach to interactive applications — mutable state plus incremental updates plus change notification — is replaced by immutable typed documents plus recompilation plus structural caching.  The result is the same interactivity with none of the accidental complexity.

### Progress tracking

The ASDL schema is a machine-readable inventory of what the system should be able to do.  Each `methods {}` block declares a work unit.  A tool that parses the schema and diffs against runtime status declarations produces a live progress report with zero manual bookkeeping.

Adding a type with `methods {}` to the schema creates a work item.  Implementing the method and tagging it with a maturity level (`"stub"` / `"partial"` / `"real"`) at the call site updates the status.  The schema is the backlog, the code is the board, the parser is the dashboard.  No separate project management artifact is needed.

### Stubs and incremental construction

Because every target type has a valid fallback constructor, every method can be stubbed from day one.  A stub is not fake success — it is a real, well-typed, degraded output that the rest of the pipeline consumes normally.  The system compiles and runs end-to-end with all stubs.  Progress is then purely incremental: replace one stub body with a real implementation, change one status string, run the tests.  No other files change.  No plumbing, no wiring, no glue code.

This means the entire application exists — structurally complete, end-to-end runnable, with correct error boundaries — before any real domain logic is written.  Implementation depth increases monotonically.  The shape never changes.

### Serialization

The early-phase ASDL types are the persistence format.  There is no separate serialization schema to maintain.  What is saved is exactly what the ASDL defines.  Schema migration is adding or removing a field, which produces clear constructor errors until every producer and consumer is updated.

### Testing

The test tree mirrors the implementation tree mirrors the schema tree.  One test per method.  Each test constructs a minimal input node, calls the method, and asserts the output shape.  Fallback behavior is tested by forcing the body to throw and verifying the degraded output.  Integration tests compose a small typed document and push it through all phases.

### The core insight

All of these properties — specification, architecture, file structure, error boundaries, compilation boundaries, memory discipline, progress tracking, stubs, serialization, testing — are not separate design decisions made independently.  They are consequences of one decision:

> **Model the domain as a typed phase pipeline, and make the types executable.**

The ASDL schema is not documentation about the system.  It is the system.  Everything else — files, tests, errors, fallbacks, progress, memory, compilation, serialization — is derived.

### Boundary correctness collapses infrastructure

This is the deeper payoff of the pattern.  When the boundaries are modeled correctly, large categories of "infrastructure" stop being separate infrastructure and become derived consequences of the same structure.

From the same correctly modeled phase/type/unit boundaries, we get:

- **memory management** — because `state_t` composition is already the ownership graph
- **lifetime management** — because child state lives exactly as long as the parent state value embedding it
- **error handling** — because each typed method boundary is already a local degradation boundary
- **loading / JIT ownership** — because load-time, definition-time, typecheck-time, first-call JIT, and runtime are explicit stages
- **test structure** — because the ASDL/method tree is already the test tree
- **implementation structure** — because the ASDL tree is already the file tree
- **progress tracking** — because `methods {}` and variant families are already the inventory
- **stubs / fallbacks** — because each target type already defines the shape of a valid degraded output
- **lazy work** — because exotype queries and memoized compilers only do the work demanded by the current path
- **incremental compilation** — because unchanged semantic subtrees remain cache hits
- **code size control** — because memoize boundaries are also call boundaries
- **hot swap / undo** — because old compiled units remain cached by semantic identity

This is why the pattern gives more than it first appears to give.  It is not just a code-generation technique.  It is a way of arranging the architecture so that multiple hard problems collapse into the same boundary structure instead of requiring separate subsystems.

## Summary

The pattern rests on **exotypes** (DeVito et al., PLDI 2014): user-defined types whose behavior and layout are defined by Lua property functions queried lazily during Terra's typechecking. We structure these property functions using four facilities:

1. **`require 'asdl'`** — define domain types with modules, sum types, product types, unique, external types. Methods on types return Terra quotes. ASDL is the domain model that exotype property functions inspect.

2. **Struct metamethods + macros** — these ARE the exotype property functions. `__getentries` computes layout. `__entrymissing` and `__methodmissing` (macros) dispatch at compile time. `__cast` handles conversions. `__for` generates iteration. `__staticinitialize` generates post-layout code. Operators define domain arithmetic. Each returns a quote that implements the operation — the `(Opᵢ → Quote)` from the formal model.

3. **`terralib.memoize`** — same configuration → same compiled function. Combined with ASDL `unique`, gives structural caching. Combined with lazy property evaluation, gives composable type constructors. Applied at every level of the hierarchy with granular state types, gives an incremental compilation system where only the changed path recompiles, each function is small enough for LLVM to optimize efficiently, and I-cache pressure stays bounded regardless of project size.

4. **The schema DSL** (optional, separate project) — a Terra language extension that replaces raw ASDL definition strings with validated syntax. Uses Terra's language extension API and Pratt parser to make ASDL structural errors into standard Terra errors with file names and line numbers. Checks variant count, field uniqueness, phase ordering, method direction, type resolution, recursion safety, and value constraints. Produces the same ASDL contexts as `context:Define()`. Everything downstream works identically.

The developer's job: define the domain in ASDL (via the schema DSL or raw strings). Write methods that return the next semantic product or compiled unit. Install exotype properties (metamethods) on the output structs where lazy Terra-side behavior is needed. Wrap the generator in `terralib.memoize`. Everything else — typechecking, property evaluation, cycle detection, caching, code generation, LLVM optimization, JIT compilation, function pointer hot-swap — is Terra.

The same is true of error handling and stage ownership. If each ASDL method boundary is explicit, then each method is also a natural **error boundary**: body fails here, degrade here, continue everywhere else. If each loading/definition/typecheck/JIT/runtime boundary is explicit, then there is no hidden ambiguity about where work belongs. Loading validates and constructs schema/types. Definition walks ASDL and emits quotes. Typechecking queries exotype behavior lazily. First call JIT-compiles. Runtime executes only machine code. These are not separate frameworks layered on top of the system. They are the system's natural joints.

The hot-swap capability is not a feature we build. It's an emergent property: Terra functions are values in Lua variables or published engine-image pointers. `terralib.memoize` caches them by configuration. Changing the configuration changes the published pair. The hot loop calls whatever the current publication points to. Old functions stay cached. Undo is a cache hit. Applied at every level with granular state types, `terralib.memoize` simultaneously provides incremental compilation (only the changed path recompiles), state isolation (each function owns its ABI), memory/lifetime management by construction (ownership follows embedded state layout), code size control (each function is a call boundary, keeping LLVM and I-cache happy), and hot-swap (reassign the pointer or publish a new engine image). Multiple architectural wins from one correctly modeled set of boundaries.

The strongest phrasing for this repo is: **state is compiled, not managed**. A compile product is not "some code plus some metadata"; it is a closed runtime artifact `{ fn, state_t }`. The function and its state ABI are one thing. Edit-time code is allowed to instantiate a new root state image and publish it. Playback code should do no allocation, no free, no resizing, no offset bookkeeping, no ownership reconciliation. In a well-formed design, the audio/render thread only reads the already-published function/state pair and executes arithmetic.

Everything in this document — the exotype theory, the ASDL phase design, the metamethods, the schema DSL, the seven examples, the JIT section — is context for one line:

```lua
terralib.memoize(function(config) ... return { fn = fn, state_t = S } end)
```

Write this at every level of your domain hierarchy. Put your ASDL-driven code generation in the `...`. That's the pattern.


## Purity, Closure, and the Two Levels

### Every compiler function is pure. Every compiled function is closed.

There are two levels in this architecture, and they have different contracts:

```
COMPILATION LEVEL (Lua):
    compile_effect(effect)   → { fn, state_t }
    compile_track(track)     → { fn, state_t }
    compile_session(session) → { fn, state_t }

    Pure? YES. Absolutely.
    Same input → same output. Enforced by terralib.memoize.
    No side effects. No hidden state. No mutation.
    ASDL in, { fn, state_t } out. Always.

EXECUTION LEVEL (Terra):
    fn(out_L, out_R, n, state)

    Pure? No. It mutates.
    It writes to out_L, out_R (output buffers).
    It writes to state (filter history, phase accumulators).
```

But look at *what* the compiled function mutates and *how*:

```
The compiled function:
    ✓ reads only from its explicit parameters
    ✓ writes only to its explicit parameters
    ✓ touches no globals
    ✓ allocates nothing
    ✓ frees nothing
    ✓ calls no external systems
    ✓ has no hidden inputs
    ✓ has no hidden outputs
    ✓ its behavior is ENTIRELY determined by its arguments
```

That is not purity in the Haskell sense. But it is something stronger than what any traditional DAW provides. It is **closed mutation** — the function mutates, but only things it was given explicitly, and only things it owns exclusively. Nobody else reads the state. Nobody else writes the state. The mutation is invisible to the outside world.

The real statement is:

```
Every COMPILER function is pure.
    config → { fn, state_t }
    Enforced by memoize. Guaranteed.

Every COMPILED function is closed.
    All inputs explicit. All outputs explicit.
    All mutation confined to owned state.
    No hidden effects. No shared state. No allocation.
```

All the *reasoning* happens at the pure level. Caching? Pure level — memoize checks equality on pure inputs. Incremental recompilation? Pure level — unchanged inputs return cached outputs. Hot-swap? Pure level — swap one pure product for another. State isolation? Pure level — each pure compilation produces its own state type. Correctness? Pure level — same config always produces the same function.

The impure part — the actual sample processing — is *below* the reasoning level. The pattern does not think about it. It generates it and moves on. The generated code mutates, yes, but it mutates inside a box that the pure level constructed. The box walls are the `state_t`. Nobody reaches in. Nobody reaches out.

```
Traditional DAW:
    Impure code managing impure state
    with impure infrastructure
    all reasoning is about mutation

This pattern:
    Pure compilers producing closed functions
    with owned state
    all reasoning is about compilation
    mutation exists but is not reasoned about —
    it is generated, contained, and forgotten
```

So can you say every function is pure? Not strictly. But you can say something better: **every function you reason about is pure, and every function you do not reason about is closed.** The architecture splits cleanly at the compilation boundary. Above it: pure, cacheable, composable, correct by construction. Below it: fast, mutating, but confined to a box that the pure level built.

The purity is where the thinking is. The mutation is where the arithmetic is. They never mix. That is why the pattern works.

---

### Every ctx, void pointer, and indirection is a smell. Every single one.

A `ctx` in the compiled output means **knowledge leaked to runtime**. Something was known at compile time but was not consumed. It was passed through as a runtime value instead of being baked as a constant or resolved into a struct field.

```
void pointer:     "I don't know what this points to"
                  → the COMPILER knew. Why doesn't the code?

ctx parameter:    "I need runtime context to do my job"
                  → the compiler HAD the context. Why didn't it
                    compile it away?

virtual dispatch: "I don't know what function to call"
                  → the compiler knew the type. Why is there
                    a table lookup at runtime?

config struct:    "I read my settings at runtime"
                  → the settings were known at edit time.
                    They should be constants in the instruction stream.

hash table:       "I look up a value by name at runtime"
                  → the name was known at compile time.
                    It should be a direct field access.
```

Every indirection is a question being asked at runtime that was already answered at compile time. The compiler had the answer. It failed to consume it. The answer leaked through to runtime as a pointer, a ctx, a table, a dispatch.

```
COMPILED FUNCTION (Terra):

    ✗ fn(buf, n, ctx)             ← what is ctx? A bag of unknowns.
                                     LLVM can't see through it.
                                     The function isn't closed.
                                     Something is hiding.

    ✓ fn(buf, n, state)           ← state is &MySpecificState.
                                     Every field known at compile time.
                                     Every offset baked. Nothing hidden.
```

This applies at the compilation level too. Rule B from this document:

> "A public method may depend only on `self` and explicit semantic typed arguments. It must not hide semantic dependencies in ambient mutable context."

```lua
-- SMELL: ctx is a bag. Anything could be in it.
-- Memoize keys on self, but what if ctx changed?
-- Silent cache bug.
function NodeKind.Biquad:compile(ctx)
    local sr    = ctx.sample_rate
    local bs    = ctx.buffer_size
    local tempo = ctx.tempo_map
    -- ...
end

-- CLEAN: every dependency is explicit and in the memoize key.
-- Nothing hidden. Nothing ambient.
function NodeKind.Biquad:compile(sample_rate, buffer_size)
    local b0, b1, b2, a1, a2 = compute_biquad(
        self.freq, self.q, sample_rate)
    -- ...
end
```

The smell hierarchy:

```
WORST:  void*          → "I know nothing about this memory"
BAD:    ctx: &Context  → "I'm a bag of maybe-relevant state"
MEH:    config: table  → "I'm a Lua table, at least it's typed"
OK:     self + args    → "every dependency is named and typed"
BEST:   self only      → "everything I need is in the ASDL node"
```

The test: if you cannot memoize purely on the explicit arguments, you have hidden state. The memoize key **is** the purity proof. If the function depends on something not in the key, the cache is wrong. If the function depends only on what is in the key, the cache is correct by construction.

```lua
terralib.memoize(function(effect, sample_rate)
    -- These two arguments ARE the cache key.
    -- If the function touches ANYTHING ELSE, it is a bug.
    -- Not a style issue. A correctness bug.
    -- The memoize cache will return stale results.
end)
```

The rule is absolute: in the compiled output, there must be zero indirection. No `ctx`. No void pointers. No dispatch tables. No config reads at runtime. Only explicit typed parameters and constants baked at compile time. At the compilation level, every dependency must be in the explicit argument list — because `terralib.memoize` is the purity enforcer, and it only sees the arguments.

Every `ctx` is a confession that the compiler did not finish its job.

