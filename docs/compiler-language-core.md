# Compiler Language Core

Status: exploratory design note

See also:

- `docs/terra-compiler-pattern.md`
- `schema.t` — the implementation (`github.com/cperion/schema.t`)
- `asdl.lua` — the Terra standard ASDL library (ships with Terra)

## 1. Thesis

The new language should not be designed as "a richer ASDL syntax".
Its real semantic foundation is the **Terra Compiler Pattern**:

- ASDL owns the domain model and phase structure
- declared methods are explicit semantic/compiler boundaries
- `terralib.memoize` owns reuse
- exotype hooks own Terra-side lazy specialization
- typed fallbacks own local degradation

So the design goal is:

> expose the smallest API surface that makes those truths explicit, while
> deriving as much boilerplate and tooling as possible.

This means the language is fundamentally a **compiler-boundary language on top
of ASDL**, not a replacement for ASDL itself.

### 1.1 Enforcement-first purpose

`schema.t` should be judged first as an **enforcement front-end** for
`docs/terra-compiler-pattern.md`.

Its job is not to maximize surface cleverness. Its job is to enforce the
compiler pattern:

- earlier
- more explicitly
- with less boilerplate
- with better tooling visibility

So the core design question for any feature is not:

> does this make the syntax fancier?

It is:

> does this enforce the Terra Compiler Pattern more strongly, more clearly, or
> earlier?

That means `schema.t` should maximize:

- explicit public boundaries
- implicit per-method memoization semantics
- typed degraded outputs at those boundaries
- explicit ownership of compile products such as `{ fn, state_t }`
- clear staging boundaries
- preserved metadata for tooling (`line`, `doc`, stripped surface, method inventory, generated markdown)

And it should minimize:

- optionality where the pattern is mandatory
- hidden convention
- syntax that does not correspond to a real semantic law
- duplicate runtime/type architecture above ASDL

In short:

> `schema.t` exists to make `docs/terra-compiler-pattern.md` harder to
> violate.

---

## 2. Why ASDL is the substrate, not the problem

Terra already ships a small ASDL implementation in `/home/cedric/dev/terra/src/asdl.lua`.
That module already provides, essentially for free:

- `asdl.NewContext()`
- `ctx:Extern(name, checker)`
- `ctx:Define(asdl_text)`
- product types
- sum types
- modules / namespaces
- optional fields `?`
- list fields `*`
- `unique` identity canonicalization
- constructor-time field validation
- class reflection via `__fields`, `.kind`, and `:isclassof()`

This is an ideal substrate:

- it is small
- it is already correct
- it already gives us typed construction and uniqueness semantics
- it does **not** impose application architecture above the type layer

Therefore the language lowers to ordinary ASDL contexts plus method
installation/wrapping. It does not invent a second type runtime.

---

## 3. The actual design goal

The language should optimize for:

1. **Minimal semantic surface**
2. **Explicit phase/public boundaries**
3. **Clear staging boundaries**
4. **Derived boilerplate, not hidden semantics**
5. **Lossless metadata for tooling**

Put differently:

- what matters semantically should be visible in the source
- what is repetitive and mechanical should be derived automatically

---

## 4. Core constructs

The core language should have only a small number of first-class concepts.

### 4.1 Schema and types

These are the ASDL-facing constructs:

- `schema`
- `extern`
- `phase`
- `record`
- `enum`
- `flags`
- fields
- `unique`

This layer describes the domain and compiler phases.

### 4.2 Methods as explicit boundaries

A declared method is a real architectural boundary, not just a helper.
It should always visibly declare:

- receiver type
- method name
- explicit semantic arguments
- declared return type

Canonical shape:

```lua
methods
    Track:lower() -> Authored.Track
end
```

This declaration is the source of truth for:

- semantic phase transition
- implementation work unit
- error/degradation boundary
- progress inventory
- test inventory

At the semantic level, this construct belongs to the category:

- **method boundary** — a public, typed, memoized, degradable schema method

### 4.3 Implementation policy on methods

The core language should add only a very small method-policy surface:

- `impl`
- `fallback`
- `status` (optional metadata)
- `doc` (attached documentation text)

Memoization should **not** be a user-level option on declared methods.
Every schema-declared method is, by definition, a memoized public boundary.
If something should not be memoized, it probably should not be a declared schema
method at all; it should be a plain helper outside the boundary DSL.

Attached documentation should be preserved as metadata.

`doc` is the single structured documentation channel meant for:

- stripped surface exports
- generated reference documentation
- inventories and tooling views

For major semantic/compiler nodes, `doc` should be mandatory:

- schema
- phase
- record / enum / flags declarations
- `methods` blocks
- declared method boundaries

In the current implementation, mandatory-doc validation activates once a schema
enters unified-doc mode by using `doc` anywhere in the schema. This preserves
compatibility with older undocumented schemas while making new documented
schemas complete by construction.

Doc authoring sugar should stay shallow and canonicalize back to `doc` metadata:

- `doc = [[...]]` remains the canonical explicit form
- `doc [[...]]` and `doc "..."` are accepted as bare-string sugar
- attached `---` doc comments immediately above a semantic node are accepted as
  source-aware sugar for the same `doc` channel when source text is available
- generated surface/docs should normalize back to canonical `doc = ...`

Canonical block form:

```lua
methods
    doc = [[Track lowering boundaries.]]

    Track:lower() -> Authored.Track
        doc = [[Lower an editor track into authored semantic form.]]
        status = "partial"
        fallback = function(self, err)
            return types.Authored.Track(self.id, self.name)
        end
        impl = function(self)
            return types.Authored.Track(self.id, self.name)
        end
end
```

This is likely the minimal surface that still captures:

- stubs
- partial implementations
- typed degraded outputs
- explicit work status
- explicit compile/cache boundaries

The memoization boundary is implicit in the `methods` declaration itself.

### 4.4 Compile products and the `Unit` intrinsic

The language treats reusable compiled artifacts as a real semantic category.

The canonical compile product is the `Unit` intrinsic — always available, never
declared, reserved name:

```
Unit = { fn: TerraFunc, state_t: TerraType }
```

`fn` is the closed, typed, JIT-compiled Terra function. `state_t` is its
exclusively owned runtime ABI — the struct it reads and writes. Nobody else
reads the state. Nobody else writes it. The mutation is invisible to the outside.

Terminal pipeline transitions must return `Unit`. Non-terminal transitions must
not. This is enforced at schema parse time.

#### `Unit.leaf` and `Unit.compose`

Two factory functions are the only sanctioned paths to a valid `Unit`. Direct
`Unit(fn, state_t)` construction is available but subjects the caller to the
same invariant checks.

**`Unit.leaf(state_t, params, body(state_sym, params)) -> Unit`**

For a node with its own persistent typed state. `state_t` is a Terra struct.
`body` is a Lua function returning a Terra quote; it receives a typed `&state_t`
symbol. The resulting fn signature is `terra(params..., state: &state_t)`. No
`&uint8`. No slot arithmetic. No manual casting.

**`Unit.compose(children, params, body(state_sym, annotated, params)) -> Unit`**

For a node that owns the aggregate of its children's states. The schema
auto-composes a typed `ComposedState` struct from each non-empty child
`state_t`. Each child annotation carries:

- `.fn` — the child's compiled Terra function
- `.state_t` — the child's state type
- `.has_state` — convenience bool
- `.state_expr` — Terra quote `&state.sN` or nil
- `.call(...)` — one-line typed dispatch: `emit(kid.call(buf, frames))`

The resulting fn signature is `terra(params..., state: &ComposedState)`.

#### Invariants enforced by the `Unit` constructor

All three construction paths (leaf, compose, direct) pass through a single
validated constructor that enforces:

1. `fn` must be a `TerraFunc` — not a Lua function, not nil
2. `state_t` must be a `TerraType`
3. If `state_t` is non-empty, `fn` must accept `&state_t` as a parameter —
   ABI ownership enforced structurally. `&uint8` or missing state param → error.
4. `fn:compile()` is called immediately — JIT runs once at Unit creation, not
   lazily on the first audio callback

The `state_t` field is not a hint. It is the full owned ABI boundary. The
function was given this type at compile time. It baked every field offset. It
will never receive anything else.

### 4.5 Unified documentation

Documentation should be attached to the same semantic tree as schema/types/
methods, rather than living only in detached prose files.

The preferred preserved documentation form is:

- `doc` for attached reference documentation

This allows the schema source to derive:

- stripped contract surfaces
- generated Markdown reference docs
- source-aware inventories
- documentation coverage tooling

Without making comments themselves semantic.

### 4.6 Helpers

A helper is any plain Lua/Terra function that does not carry the semantics of a
schema method boundary or an exotype hook.

Helpers are:

- not declared in `methods`
- not public phase/compiler boundaries
- not Terra exotype property hooks
- not part of the method inventory
- not part of the progress/test boundary inventory
- not semantically memoized by the language

This distinction is important for clarity:

- **method boundary** = schema-declared, public, typed, memoized, degradable
- **compile product** = explicit typed reusable compiled artifact
- **exotype hook** = Terra-side compile-time property hook
- **helper** = ordinary support code outside the boundary DSL

### 4.7 Exotype hooks

The language family must acknowledge Terra-side lazy specialization, but this
must remain a **separate semantic category** from schema method boundaries.

Exotype hooks are not phase methods. They are Terra-side compile-time property
functions queried by the Terra typechecker/code generator.

This distinction is critical:

- **method boundary** = public schema-declared semantic/compiler transition
- **exotype hook** = Terra-side lazy specialization hook on a generated type

The relevant semantic hooks are:

- `__getentries`
- `__staticinitialize`
- `__getmethod`
- `__methodmissing`
- `__entrymissing`
- `__cast`
- `__for`
- operator metamethods

These should be treated as part of the compiler language model, but they must
remain separate from `methods`.

Canonical hook surface:

```lua
hooks LayerRuntime
    doc = [[Lazy Terra-side hooks for a generated runtime type.]]

    getentries
        doc = [[Provide layout entries.]]
        impl = function(self_t) ... end

    staticinitialize
        doc = [[Perform post-layout initialization.]]
        impl = function(self_t) ... end

    getmethod
        doc = [[Resolve known methods before methodmissing.]]
        impl = function(self_t, methodname) ... end

    methodmissing
        doc = [[Resolve open-ended runtime methods lazily.]]
        macro = function(methodname, obj, ...) ... end

    entrymissing
        doc = [[Resolve lazy property access.]]
        macro = function(entryname, obj) ... end

    cast
        doc = [[Handle compile-time conversions.]]
        impl = function(from, to, exp) ... end

    for
        doc = [[Provide custom iteration lowering.]]
        impl = function(iter, body) ... end

    add
        doc = [[Operator add implementation.]]
        impl = terra(a: T, b: T) ... end

    band
        doc = [[Operator and implementation.]]
        macro = function(a, b) ... end
end
```

This lowers to ordinary exotype installs such as:

```lua
T.metamethods.__getentries       = function(...) ... end
T.metamethods.__staticinitialize = function(...) ... end
T.metamethods.__getmethod        = function(...) ... end
T.metamethods.__methodmissing    = macro(function(...) ... end)
T.metamethods.__entrymissing     = macro(function(...) ... end)
T.metamethods.__cast             = function(...) ... end
T.metamethods.__for              = function(...) ... end
T.metamethods.__add              = terra(a: T, b: T) ... end
```

The schema object should expose hook metadata and a separate installation step,
for example `schema:install_hooks(bindings)`, rather than pretending hooks are
ordinary ASDL methods.

#### Hook families

The hooks naturally divide into families with different roles.

##### Dispatch hooks

These are the most important hooks for open-ended lazy behavior:

- `__getmethod`
- `__methodmissing`
- `__entrymissing`

`__methodmissing` is especially central. It is the main mechanism for exposing
an unbounded method set whose behavior is decided lazily from semantic data.

##### Layout and lifecycle hooks

These define generated type shape and post-layout setup:

- `__getentries`
- `__staticinitialize`

##### Conversion, iteration, display, and operator hooks

These define specialized behavior for language operations:

- `__cast`
- `__for`
- `__typename`
- operator metamethods
- `__apply` where needed

At the DSL surface, operator hooks use short names such as:

- `add`, `sub`, `mul`, `div`, `mod`
- `lt`, `le`, `gt`, `ge`, `eq`, `ne`
- `xor`, `lshift`, `rshift`, `select`, `apply`

For keyword-colliding operators, the DSL may use aliases such as:

- `band` -> `__and`
- `bor` -> `__or`
- `bnot` -> `__not`

#### Validation rules for hook support

The DSL should enforce:

- hook target blocks are unique
- supported hook names are restricted to the known exotype-hook set
- `methodmissing` and `entrymissing` must declare `macro`
- `getentries`, `staticinitialize`, `getmethod`, `cast`, `for`, and `typename`
  must declare `impl`
- operator hooks must declare exactly one of `impl` or `macro`
- hook blocks and hook items carry mandatory `doc` in unified-doc mode

The schema object should expose:

- `schema.hooks` metadata
- `schema:install_hooks(bindings)`
- `schema.tests`, `schema.test_markdown`, and `schema.test_skeletons` as derived test-planning outputs

so hook installation remains an explicit step distinct from ASDL method
installation.

#### Macro vs Lua-function distinction

Not all exotype hooks are the same kind of authoring surface.

- `__methodmissing` and `__entrymissing` are **macros** receiving quotes and
  returning quotes
- `__getentries`, `__staticinitialize`, `__cast`, and `__for` are **Lua
  functions** queried by Terra during compilation
- operator hooks may be either Terra methods or macros depending on the case

Any future DSL support for hooks must preserve this distinction clearly. The DSL
must not blur quote-producing macro hooks with ordinary ASDL phase methods.

#### Staging rule for hooks

Exotype hooks belong to Terra's compile-time property-query stage, not to the
ASDL phase-transition stage.

So a future hook DSL must keep explicit:

- ASDL method boundaries
- Terra typecheck/codegen hooks
- runtime compiled artifacts

If a surface design mixes those categories, it is architecturally wrong.

---

## 5. What is core and what is derived

The language stays minimal only if it separates **semantic primitives** from
**derived tooling**.

### 5.1 Core

The following must exist in the semantic model:

- phases and types
- explicit method signatures
- `impl`
- `fallback`
- optional `status`
- required attached `doc` on major semantic nodes
- implicit per-method memoization semantics
- a separate semantic category for Terra-side exotype hooks

### 5.2 Derived

The following should be generated or derived from the core:

- progress reports
- stub inventories
- stripped schema export
- arg/return contract wrappers
- parent-before-child method installation ordering
- method inventory for tooling
- test skeletons
- docs/summaries

These are important, but they should not enlarge the user-visible core API
unless experience proves they need first-class surface syntax.

---

## 6. Core semantic rules

These rules come from `docs/terra-compiler-pattern.md` and are the real meaning
of the language.

### Rule A — ASDL owns meaning

The type/phase tree is the semantic source of truth.
The language should lower to ASDL, not replace it.

### Rule B — Public methods must be honest

A public method may depend only on:

- `self`
- explicit semantic typed arguments

It must not hide semantic dependencies in ambient mutable context.

Arguments typed `table` are a **parse error**. `table` is a ctx bag — it hides
arbitrary semantic dependencies from the memoize key. The memoize key is only
as complete as the explicit argument list. If something is in a `table` but not
in the key, the cache is wrong. Not a style issue — a correctness bug.

The hierarchy:

```
WORST:  void*          → "I know nothing about this memory"
BAD:    ctx: &Context  → "I'm a bag of maybe-relevant state"
ERROR:  arg: table     → parse error in schema.t; banned
OK:     self + args    → every dependency named and typed
BEST:   self only      → everything needed is in the ASDL node
```

### Rule C — Phase direction is explicit

Methods may return only same-phase or later-phase types unless a construct is
explicitly not a phase-lowering boundary.

### Rule D — Fallbacks are typed

If a public boundary degrades, it must return a valid value of its declared
return type.

### Rule E — Declared methods are memoized boundaries

Every schema-declared method is a memoized public boundary. This is not an
optimization toggle; it is part of what `methods` means in the compiler
language.

That implies:

- cache keys are the explicit semantic inputs only
- unchanged structural subtrees can reuse compiled results deeply
- the author does not manually write per-method memoize boilerplate

If a function should not have this meaning, it should remain a plain helper
outside the schema method surface.

### Rule F — Compile products own their ABI

When a method returns a reusable compiled artifact with local runtime state, its
return type should expose both:

- the executable function
- the owned state ABI

Canonical shape:

```lua
Kernel.Unit = (TerraFunc fn, TerraType state_t)
```

Returning a naked function where local state exists is architecturally weaker,
because ownership of the runtime ABI becomes implicit in some larger parent.

### Rule G — Terra-side laziness belongs to exotype hooks

Open-ended lazy Terra behavior belongs in exotype/metamethod hooks, not hidden
inside ASDL phase semantics.

This includes especially:

- `__methodmissing`
- `__entrymissing`
- `__getmethod`

These are not degraded phase boundaries. They are compile-time property hooks.
A future DSL must preserve that distinction.

### Rule H — Staging remains explicit

The language must preserve the distinction between:

- schema/module load time
- Terra definition time
- Terra typecheck/codegen time
- first-call JIT time
- runtime

A smaller syntax is good only if these stages remain easier to reason about, not
more blurred.

---

## 6.1 Enforcement gaps closed in `schema.t`

These rules are not merely documented — they are enforced structurally at schema
parse or construction time. A violation produces a Terra error with file name and
line number, not a silent bug or runtime crash.

| Gap | What is caught | When |
|-----|---------------|------|
| **`table` arg** | Method argument typed `table` — ctx bag hides memoize deps | Parse time |
| **`Unit` ABI ownership** | `fn` does not accept `&state_t` as parameter | `Unit()` call |
| **`Unit` fn type** | `fn` is not a TerraFunc | `Unit()` call |
| **`Unit` state type** | `state_t` is not a TerraType | `Unit()` call |
| **Forced JIT** | `fn:compile()` called at Unit creation, not on first audio callback | `Unit()` call |
| **Non-terminal Unit (direct)** | Phase not adjacent to terminal returns `Unit` | Parse time |
| **Non-terminal Unit (schema unit type)** | Intermediate transition returns an `is_unit` type | Parse time |
| **Compose struct identity** | `terralib.memoize` on Terra type identity, not `tostring` — no collision | `Unit.compose` |

These are not aspirational. Every item in the table fires today. The remaining
violation vector is Lua functions closing over ambient state not in the memoize
key — Lua cannot prevent this statically, but the `table` arg ban removes the
most common mechanism for it.

---

## 7. Minimal canonical surface

At the user level, the canonical core surface should be approximately this:

```lua
schema Demo
    extern TerraType = terralib.types.istype

    phase Editor
        record Track
            id: number
            name: string
        end

        methods
            Track:lower() -> Authored.Track
                status = "partial"
                fallback = function(self, err)
                    return types.Authored.Track(self.id, self.name)
                end
                impl = function(self)
                    return types.Authored.Track(self.id, self.name)
                end
        end
    end

    phase Authored
        record Track
            id: number
            name: string
        end
    end
end
```

And for a real compile unit:

```lua
phase Kernel
    record Unit
        fn: TerraFunc
        state_t: TerraType
    end
end

methods
    GraphProgram:compile() -> Kernel.Unit
        status = "real"
        fallback = function(self, err)
            return silent_kernel_unit()
        end
        impl = function(self)
            return compile_graph_program(self)
        end
end
```

This is intentionally small.

---

## 8. Desugaring model

The language should remain inspectable by lowering every richer surface form to
an explicit small core.

### 8.1 Shorthand implementation

```lua
Foo:bar() -> X = function(self) ... end
```

Desugars to:

```lua
Foo:bar() -> X
    impl = function(self) ... end
end
```

### 8.2 Stub shorthand

A future shorthand such as:

```lua
Foo:bar() -> X
    stub = function(self) ... end
end
```

should lower to:

```lua
Foo:bar() -> X
    status = "stub"
    fallback = function(self, err) ... end
end
```

### 8.3 Parent/child method families

For sum types, installation must preserve ASDL's real semantics:

- install parent method first
- install variant overrides second

This should be automatic runtime behavior, not author burden.

---

## 9. Minimal internal IR

The surface syntax should lower to a small internal representation that is more
fundamental than any one parser.

Illustrative shape:

```lua
Schema {
    name = "Demo",
    externs = {...},
    phases = {
        Phase {
            name = "Editor",
            decls = {...},
            methods = {
                Method {
                    receiver = "Editor.Track",
                    name = "lower",
                    args = {},
                    return_type = "Authored.Track",
                    status = "partial",
                    memoized = true,
                    impl = <lua expr>,
                    fallback = <lua expr>,
                }
            }
        }
    }
}
```

This IR should be rich enough to drive:

- ASDL emission
- method installation
- diagnostics wrappers
- progress tooling
- stripped-schema export
- generated Markdown reference docs
- test skeleton generation
- source-location-aware tooling via stored line metadata

---

## 10. Runtime installation model

The implementation backend should stay simple.

### 10.1 Type layer

1. evaluate extern checkers
2. emit plain ASDL text
3. call `ctx:Define(asdl_text)`

### 10.2 Method layer

1. collect declared method metadata
2. install parent methods before child overrides
3. wrap bodies with arg/return contract checks
4. wrap `impl` with `fallback` degradation behavior
5. attach metadata for tooling

### 10.3 Compile-unit layer

Every declared method installs as a memoized boundary over explicit semantic
inputs only.

For methods returning reusable compiled artifacts, the installer should preserve
owned compile-product structure such as `Kernel.Unit = (TerraFunc fn, TerraType
state_t)`.

### 10.4 Terra specialization layer

Install exotype hooks on Terra structs/types only where Terra-side lazy behavior
is actually required.

---

## 11. Non-goals for the core

The core language should **not** initially try to solve:

- all tests syntax
- diagnostics sink plumbing
- backend-specific Terra helper APIs
- every possible boilerplate family
- every exotype pattern as a special syntax form
- premature compile-product sugar
- project-specific file-tree conventions

These may become separate layers or tooling, but they should not bloat the core
before the core itself is stable.

---

## 12. Immediate next layers above the core

Once the core is stable, the most natural derived layers are:

### 12.1 Tooling layer

Derived from method metadata:

- progress views
- stub/partial/real summaries
- stripped schema output
- implementation coverage maps

### 12.2 Test DSL layer

Derived from declared method boundaries and hook metadata:

- one test skeleton per method
- one hook-installation skeleton per hook
- fallback behavior tests
- variant-family coverage tests
- memoization/ownership tests
- compile-product ownership tests

Current derived outputs should include:

- `schema.tests` structured test inventory
- `schema.test_markdown` readable test plan
- `schema.test_skeletons` per-unit skeleton snippets with suggested file paths

### 12.3 Optional exotype helper layer

Only if repeated patterns justify it:

- hook declarations
- quote-returning helper combinators
- Terra struct layout helpers

---

## 13. The shortest possible statement of the language

The compiler language is:

> ASDL phases and types, plus explicit memoized method boundaries, plus typed
> fallback semantics, plus compile products that own their runtime ABI, with
> Terra exotype hooks for lazy compile-time specialization.

Everything else should be derived.

---

## 14. Feature admission test for `schema.t`

A proposed feature belongs in `schema.t` only if it passes all of the
following tests.

### 14.1 Pattern enforcement test

It must enforce `docs/terra-compiler-pattern.md` more strongly, more clearly, or
earlier.

If the feature is merely convenient or shorter, that is not enough.

### 14.2 Semantic reality test

It must correspond to a real semantic/compiler-pattern primitive, such as:

- a typed phase/type declaration
- a public method boundary
- a typed fallback boundary
- compile-product ownership
- preserved metadata required for tooling

If it does not correspond to a real architectural fact, it should not become
core syntax.

### 14.3 Non-redundancy test

It must not expose a user-level option for something the compiler pattern treats
as mandatory.

Examples:

- per-method memoization should not be optional syntax if all declared methods
  are memoized by definition
- compile-product ownership should not be hidden behind naming conventions

### 14.4 Clarity test

It must make one or more of the following clearer:

- phase boundaries
- ownership boundaries
- degradation boundaries
- staging boundaries
- compile-product boundaries

If it makes the surface shorter but semantically fuzzier, it fails.

### 14.5 Minimality test

It must not be cleanly derivable from a smaller construct that already exists.

If it can be implemented as:

- desugaring
- metadata derivation
- tooling
- library helper code

then it should usually stay out of the core surface.

### 14.6 Inspectability test

It must lower to a small inspectable core form.

The language should always preserve the ability to inspect:

- emitted ASDL
- stripped schema surface
- generated Markdown docs
- method inventory
- line/doc metadata
- compile-product classification

### 14.7 Runtime-substrate test

It must not create a second runtime/type architecture above stock ASDL unless
there is a compelling compiler-pattern reason.

The preferred design is:

- ASDL for typed values
- schema DSL for boundary enforcement and metadata
- Terra hooks for compile-time specialization

not a replacement runtime.

### 14.8 Tooling value test

If a feature introduces syntax, it should ideally improve at least one of:

- diagnostics
- progress visibility
- stripped contract export
- test derivation
- source-aware tooling

A feature that adds syntax but gives no tooling leverage should face a very high
bar.

## 15. Practical acceptance rule

A feature should enter `schema.t` only if:

1. it enforces the compiler pattern
2. it expresses a real semantic fact
3. it is not redundant with mandatory semantics
4. it improves clarity more than it increases surface area
5. it lowers cleanly to the existing ASDL-centered substrate

If it fails that rule, it should be:

- sugar
- tooling
- a library helper
- or rejected entirely
