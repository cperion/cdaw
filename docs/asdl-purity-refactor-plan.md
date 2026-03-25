# ASDL Purity Refactor Plan

This document records the architectural intent of the refactor that began when
we stopped patching implementations in place and instead corrected the ASDL
surface first.

It is intentionally about **purity of architecture**, not short-term code
convenience.

The refactor will be large. That is acceptable. It is better to do it now,
while the project is still primarily a design/compiler effort, than to let an
impure implementation harden into the public architecture.

---

## 1. Why this refactor exists

We reached a point where the codebase had working audio, tests, and broad phase
coverage, but the architecture still did **not** faithfully implement the Terra
compiler pattern described in `docs/terra-compiler-pattern.md`.

The core mismatch was this:

- the repo had many public phase methods that *looked* local and pure
- but several of them still depended on hidden whole-project context or root
  passes to actually work
- later phases, especially Scheduled → Kernel, still exposed public method
  shapes that were really just quote-emission helpers rather than honest
  reusable compile units

So the implementation was ahead of the architecture in the wrong way: it worked,
but it worked by hiding the real structure.

This refactor exists to reverse that mistake.

---

## 2. The purity we want

The target architecture is the one implied by the Terra compiler pattern:

```lua
terralib.memoize(function(config)
    return { fn = fn, state_t = S }
end)
```

Applied recursively, this means:

1. **ASDL owns meaning.**
   The schema defines the real semantic and compilation units.
2. **Memoize owns reuse.**
   Cache boundaries are explicit, local, and structural.
3. **State ABI is owned locally.**
   Every compiled unit owns its own `state_t`.
4. **Parents compose children.**
   Parents do not silently rebuild or reinterpret children through ambient
   mutable context.
5. **Structural sharing is preserved.**
   Unchanged semantic subtrees remain the same Lua/ASDL objects so memoize hits
   are possible.
6. **Error boundaries are explicit.**
   Each ASDL phase method is one natural degradation boundary, not a hidden
   cross-cutting concern spread across the whole pipeline.
7. **Loading / definition / JIT boundaries are explicit.**
   Schema loading, Terra definition-time emission, typecheck-time exotype
   queries, first-call JIT compilation, and runtime execution each have a clear
   role and must not be blurred together.
8. **Runtime behavior is lazy and composable.**
   Where Terra-side generated behavior needs open-ended lazy dispatch,
   exotype hooks such as `__getmethod` / `__methodmissing` / `__entrymissing`
   are the right tools.

This is the purity we are optimizing for.

---

## 3. Core architectural rules

### Rule A — Public phase methods must be honest

A public ASDL method may take only:

- `self`, or
- explicit semantic typed parameters that are truly required by the method's
  semantics

It must **not** depend on an opaque mutable phase context as part of its public
contract.

Good:

```lua
Authored.TempoMap:resolve(number ticks_per_beat, number sample_rate)
```

Bad:

```lua
Authored.TempoMap:resolve(ResolveCtx ctx)
```

Temporary allocators, intern tables, Terra symbols, and codegen scratch belong
**inside** the memoized implementation, not in the public method signature.

---

### Rule B — False leaf methods must not exist

If a type does not actually contain enough information to compute its next-phase
result independently, then it must not advertise itself as a public phase
boundary.

Examples of previous false-leaf smells:

- `Authored.Node:resolve()` when real flattening depended on graph/root passes
- `Resolved.Track:classify()` when correct bindings depended on larger slices
- `Scheduled.NodeJob:compile() -> TerraQuote` when the real reusable compile
  boundary needed additional owned data and state ABI

If a boundary is not real, remove it from the ASDL or move it to a real slice or
program type.

---

### Rule C — The ASDL must model reusable compilation slices explicitly

Later phases cannot rely only on giant project-global flat tables if the real
architecture wants incremental subtree reuse.

Therefore the ASDL must define intermediate reusable units such as:

- `Resolved.TrackSlice`
- `Resolved.GraphSlice`
- `Classified.TrackSlice`
- `Classified.GraphSlice`
- `Scheduled.TrackProgram`
- `Scheduled.GraphProgram`
- `Kernel.Unit`

These are not convenience wrappers. They are the missing architectural truth of
incremental compilation.

---

### Rule D — `Kernel.Unit` is the atomic compile product

A reusable compiled unit is:

```lua
Kernel.Unit = (TerraFunc fn, TerraType state_t)
```

This is the canonical ABI ownership boundary.

Returning only a function where local state exists is architecturally wrong,
because it encourages hidden dependence on larger parent state layout.

---

### Rule E — Raw jobs are data, not necessarily public compiler units

Structures such as:

- `Scheduled.NodeJob`
- `Scheduled.ClipJob`
- `Scheduled.SendJob`
- `Scheduled.MixJob`
- `Scheduled.OutputJob`
- `Scheduled.Step`

are often best treated as **scheduled data** owned by a larger reusable program.

A raw job should not be exposed as a public compiler boundary unless it truly is
self-contained enough to own a `Kernel.Unit` contract.

---

### Rule F — `Kernel` is runtime surface, not AST surface

`Kernel` types must describe monomorphic runtime artifacts.

This means `Kernel.API` fields must be `TerraFunc`, not `TerraQuote`.

Quotes are compile-time intermediates. `Kernel` is the compiled result.

---

### Rule G — Error boundaries must coincide with type/method boundaries

If a failure should degrade locally, there should be a corresponding explicit
ASDL method boundary there.

This means:

- one public phase method = one local degradation boundary
- fallback output must be a valid value of the target ASDL type
- one failing subtree should not force unrelated sibling recompilation or
  unrelated pipeline failure

We do not want a second hidden error-handling architecture layered around the
compiler. The type/method boundary is the error boundary.

---

### Rule H — Loading and JIT boundaries must stay explicit

The architecture must preserve the distinction between:

- module/schema load time
- Terra function definition time (`escape`, emitted quotes)
- Terra typecheck/codegen time (`__getmethod`, `__methodmissing`, etc.)
- first-call JIT compilation time
- runtime execution time

If these stages blur together in the implementation, architectural reasoning
collapses: it becomes unclear where validation belongs, where code generation
belongs, where caching belongs, and where runtime mutation is actually allowed.

The pure architecture names these stages explicitly and assigns work to the
correct one.

---

### Rule I — `__methodmissing` is for lazy behavior, not for hiding semantics

`__methodmissing` is architecturally valuable, but it has a specific role.

Use it for:

- lazily generated Terra-side methods
- open-ended method sets
- exotype-style runtime wrappers
- compile-time dispatch over generated Terra types

Do **not** use it to smuggle hidden semantic dependencies that should be modeled
in ASDL.

The pure split is:

- ASDL methods define semantic phase transitions
- `terralib.memoize` defines cached compiled units
- exotype hooks (`__methodmissing`, etc.) define lazy Terra-side behavior

---

## 4. What we changed in the ASDL surface

The ASDL redesign corrected several architectural lies.

### 4.1 Authored → Resolved

We changed resolve signatures to use explicit semantic parameters where needed,
most notably timing data such as `ticks_per_beat` and `sample_rate`.

We also stopped pretending that certain local objects were standalone public
resolve boundaries when they were not.

Most importantly, we introduced:

- `Resolved.TrackSlice`
- `Resolved.GraphSlice`

so that later phases can classify reusable local slices rather than depending on
one giant hidden root flattening pass.

### 4.2 Resolved → Classified

We introduced:

- `Classified.TrackSlice`
- `Classified.GraphSlice`

so classification can remain local to real reusable slices.

### 4.3 Classified → Scheduled

We introduced:

- `Scheduled.TrackProgram`
- `Scheduled.GraphProgram`

so scheduling produces real reusable programs instead of only raw tables plus a
monolithic project compiler.

### 4.4 Scheduled → Kernel

We introduced:

- `Kernel.Unit = (TerraFunc fn, TerraType state_t)`

and stopped modeling raw `TerraQuote` emission as the public meaning of compile.

This is the biggest architectural correction in the whole redesign.

---

## 5. What the new ASDL does and does not guarantee

### It does guarantee:

- the public surface is now much more honest
- late-phase reusable units are explicitly modeled
- explicit semantic parameters are present where needed
- the compiler pattern now has a place to live in the schema

### It does **not** by itself guarantee:

- memoize is applied at every real boundary
- implementation truly composes cached children instead of rebuilding too much
- structural sharing is preserved by editor/session mutations
- incremental recompilation is already achieved in practice

That work still belongs to the implementation refactor.

So the ASDL is now a **necessary foundation**, not the finished result.

---

## 6. How this applies to the codebase

### 6.1 `app/session.t`

This file must preserve structural sharing aggressively.

If an edit changes only one track, then:

- unchanged track objects must be reused
- unchanged device chains must be reused
- unchanged devices must be reused
- unchanged clip/slot/send lists must be reused

If session mutation rebuilds sibling trees broadly, it destroys memoize hits and
violates the compiler-pattern intent even if later phases are pure.

### 6.2 `impl/authored/*`

Implementations must now produce:

- `Resolved.TrackSlice`
- `Resolved.GraphSlice`

rather than reconstructing whole-project flattening through hidden root-only
logic.

### 6.3 `impl/resolved/*`

Implementations must classify local slices:

- `Resolved.TrackSlice -> Classified.TrackSlice`
- `Resolved.GraphSlice -> Classified.GraphSlice`

They must not silently depend on giant root-owned mutable classification context
for their semantic correctness.

### 6.4 `impl/classified/*`

Implementations must schedule reusable programs:

- `Classified.TrackSlice -> Scheduled.TrackProgram`
- `Classified.GraphSlice -> Scheduled.GraphProgram`

Raw jobs remain data; the reusable program owns scheduling semantics.

### 6.5 `impl/scheduled/*`

Implementations must compile reusable units:

- `Scheduled.GraphProgram:compile() -> Kernel.Unit`
- `Scheduled.TrackProgram:compile() -> Kernel.Unit`
- `Scheduled.Project:compile() -> Kernel.Project`

Compilation should be structured as memoized composition of units, not as one
monolithic root quote-emitter with hidden scratch threaded through everything.

### 6.6 `impl/kernel/*`

`Kernel` code must treat `Kernel.Unit` as the atomic product.

`Kernel.API` must be treated as runtime function surface, not quote storage.

---

## 7. The role of `__methodmissing` in the pure architecture

The Terra compiler pattern makes `__methodmissing` central for exotype purity.

In this codebase, the right place to introduce it is **after** semantic units
and compile units are honest.

Probable future use:

- Terra-side wrappers around `Kernel.Unit`
- lazily synthesized runtime/control/query APIs
- generated forwarding behavior for composed runtime units
- exotype-based ergonomic Terra runtime surfaces over compiled DAW programs

This is a future architectural enhancement, not a substitute for ASDL honesty.

The guiding principle:

- use ASDL to define semantic truth
- use memoized unit compilers to define reuse and ABI ownership
- use `__methodmissing` to define lazy Terra-side behavior over those units

---

## 8. Refactor order

This is the recommended order for aligning implementation to the purified ASDL
surface.

### Phase 1 — preserve structural sharing

Refactor `app/session.t` first.

Goal: unchanged editor subtrees keep object identity.

Without this, even a perfect later-phase architecture will miss cache hits.

### Phase 2 — implement slice-based resolve

Rewrite `impl/authored/*` to produce:

- `Resolved.TrackSlice`
- `Resolved.GraphSlice`

with explicit semantic params.

### Phase 3 — implement slice-based classify

Rewrite `impl/resolved/*` to produce:

- `Classified.TrackSlice`
- `Classified.GraphSlice`

### Phase 4 — implement program-based schedule

Rewrite `impl/classified/*` to produce:

- `Scheduled.TrackProgram`
- `Scheduled.GraphProgram`

### Phase 5 — implement unit-based compile

Rewrite `impl/scheduled/*` to produce:

- `Kernel.Unit`
- `Kernel.Project`

with true `{ fn, state_t }` ownership.

### Phase 6 — introduce exotype runtime wrappers where they add purity

Only after the above is stable should we add `__methodmissing`-driven runtime
wrappers to clean up Terra-side behavior composition.

---

## 9. How to judge each future change

A proposed change is good if it makes more of the following true:

- the public ASDL boundary becomes more honest
- a reusable compilation unit becomes explicit rather than hidden
- a compiled unit owns its own ABI/state
- a parent composes children rather than reinterpreting them globally
- structural sharing is preserved
- memoize boundaries become more local and meaningful
- exotype hooks are used to expose lazy runtime behavior cleanly

A proposed change is bad if it does any of the following:

- reintroduces opaque phase contexts as semantic dependencies
- adds false leaf methods
- hides real compilation units inside helper tables rather than ASDL
- returns raw quotes where a runtime unit should be returned
- broadens root passes when a local unit should exist
- sacrifices structural sharing for mutation convenience

---

## 10. Boundary correctness collapses infrastructure

This is the principle we want the refactor to realize in practice.

If the semantic, ownership, compilation, error, and staging boundaries are
modeled correctly, then a large amount of engineering "infrastructure" is no
longer designed separately.  It is derived from the same architecture.

For this codebase, that means:

- **memory management** should fall out of `Kernel.Unit` / `state_t` ownership
  and parent state embedding
- **lifetime management** should fall out of normal value lifetime of composed
  parent state values
- **error handling** should fall out of explicit ASDL phase method boundaries
  and typed local fallbacks
- **loading / JIT behavior** should fall out of explicit stage boundaries:
  schema load, Terra definition, Terra typecheck/codegen, first-call JIT,
  runtime execution
- **test organization** should fall out of the ASDL method tree
- **implementation organization** should fall out of the ASDL type tree
- **progress tracking** should fall out of `methods {}` and variant families
- **stubs / degraded execution** should fall out of typed fallback constructors
- **lazy work** should fall out of memoized units and exotype lazy queries
- **incremental recompilation** should fall out of structural sharing plus
  memoized unit composition

If we find ourselves inventing large parallel subsystems for these concerns,
that is usually evidence that the core boundaries are still wrong.

The purpose of the refactor is therefore not only to make the implementation
cleaner.  It is to make the boundary structure so correct that these other
concerns stop requiring ad hoc architecture.

## 11. Final statement of intent

The goal of this refactor is **not** merely to make the code prettier.

The goal is to make the codebase **architecturally truthful**:

- the ASDL says what the real units are
- the implementations obey those units
- memoization happens at the right boundaries
- state ownership is local and safe
- runtime behavior is generated lazily and compositionally through the correct
  Terra mechanisms

This will be a large refactor.
That is fine.
It is better to align the codebase with the correct patterns now than to keep
adding implementation depth on top of an impure architecture.
