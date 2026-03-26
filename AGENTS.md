# AGENTS.md

## Project Overview

This repo defines **Terra DAW v3** — a DAW (Digital Audio Workstation) compiler IR
modeled as a 7-phase signal-graph pipeline.

The project is written entirely in [Terra](https://terralang.org/), a low-level
statically typed language embedded in and meta-programmed by Lua. There is no
JavaScript, TypeScript, or Node.js tooling of any kind. All source files use the
`.t` extension.

**Core insight:** everything is a signal graph. Device chains, grid patches, layer
containers, selectors, and freq splits are all `Graph` instances distinguished only
by their `layout` field. One type, one compilation path.

**Architectural foundation:** this project implements the **Terra Compiler Pattern**
described in `docs/terra-compiler-pattern.md`. The atomic unit is:

```lua
terralib.memoize(function(config) ... return { fn = fn, state_t = S } end)
```

Applied at every level of the domain hierarchy, this single mechanism provides
incremental compilation, state isolation, code size control, memory/lifetime
management by construction, and live hot-swap — all as emergent properties.

**Schema DSL:** `lib/schema.t` is a Terra language extension that owns the entire
schema surface: types, methods, docs, fallbacks, status, progress, test inventory,
exotype hooks, and markdown generation. It is the single source of truth. The schema
is not documentation about the system — it *is* the system.

### Repository Layout

```
lib/schema.t                       # Terra language extension: the schema DSL
daw.t                              # Schema definition (THE source of truth)
main.t                             # App entrypoint: SDL window + TerraUI shell

impl/                              # Method body modules (pure domain logic)
    editor/                        #   Editor → Authored (lower)
    view/                          #   View → TerraUI (to_decl)
    authored/                      #   Authored → Resolved (resolve)
    resolved/                      #   Resolved → Classified (classify)
    classified/                    #   Classified → Scheduled (schedule)
    scheduled/                     #   Scheduled → Kernel (compile)
        compiler/                  #     Private DSP/codegen helpers
    kernel/                        #   Kernel entry
    support/                       #   Shared helpers

app/                               # Runtime/bootstrap wiring
tests/                             # Tests (derived from schema.tests tree)

docs/                              # Documentation
    terra-compiler-pattern.md      #   The Terra Compiler Pattern (paper draft)
    rewrite-strategy.md            #   Full rewrite plan around schema.t
    implementation-strategy.md     #   Implementation strategy + milestones
    implementation-tree.md         #   End-to-end checkbox roadmap
    terraui-shell-composition.md   #   View → TerraUI shell boundary notes
    design-system/                 #   UI design tokens and visual spec

terraui/                           # Git submodule: TerraUI (separate project)
```

### Key Documentation

- **`docs/terra-compiler-pattern.md`** — the paper draft. Domain-independent
  reference for the full pattern: exotypes, ASDL, metamethods, memoize,
  `{ fn, state_t }` compile products, JIT hot-swap, boundary correctness.
- **`docs/rewrite-strategy.md`** — the rewrite plan from old scaffolding to
  schema.t-owned architecture.
- **`docs/implementation-strategy.md`** — project-specific strategy: phase
  structure, fallback policy, milestones, roadmaps.
- **`lib/schema.t`** — the schema DSL source. Read this to understand what
  the DSL owns and how it works.
- **`daw.t`** — the schema definition. This is the single source of truth
  for types, methods, docs, progress, fallbacks, and test inventory.

### Seven IR Phases

```
Editor → View → Authored → Resolved → Classified → Scheduled → Kernel
```

| Phase | Module | Description |
|---|---|---|
| 0 | `Editor` | User-facing authoring; Bitwig-shaped concepts (tracks, devices, clips) |
| 1 | `View` | DAW-specific projection to TerraUI `Decl`; anchors + command bindings |
| 2 | `Authored` | Canonical semantic graph document; the source of truth after lowering |
| 3 | `Resolved` | IDs fixed, ticks computed, flat tables, zero sum types |
| 4 | `Classified` | Rate classes, bindings `(rate_class, slot)` |
| 5 | `Scheduled` | Buffer slots, reusable programs, leaf compile units |
| 6 | `Kernel` | `TerraFunc` + `TerraType`; native compiled output as `{ fn, state_t }` |

Each phase's types declare methods in the schema for the transformation to the
next phase. The schema DSL installs these as memoized boundaries automatically.

---

## The Schema DSL (`lib/schema.t`)

The schema DSL is a Terra language extension. It replaces raw ASDL definition
strings, manual method installation, hand-scraped progress tooling, and
scattered documentation with a single validated declaration surface.

### What the schema owns

| Concern | Mechanism |
|---|---|
| Type definitions | `record`, `enum`, `flags` blocks |
| Method declarations | `methods` blocks with receiver, args, return type |
| Method installation | Automatic on ASDL classes at schema construction |
| Memoization | Automatic `terralib.memoize` on every method boundary |
| Runtime type checking | Automatic arg/return validation on every call |
| Fallback policy | Declarative `fallback = ...` per method |
| Status tracking | Declarative `status = "real"` per method |
| Documentation | Enforced `doc` / `---` comments at every semantic level |
| Progress inventory | `schema.inventory` — phases, types, methods, hooks |
| Test inventory | `schema.tests` — per-method/hook units with suggested cases |
| Test skeletons | `schema.test_skeletons` — generated skeleton file content |
| Markdown generation | `schema.markdown` — full reference docs |
| Compile product detection | Auto-detects `{ fn: TerraFunc, state_t: TerraType }` |
| Exotype hooks | `hooks` blocks for `__methodmissing`, `__getmethod`, etc. |
| Field defaults | `= [expr]` on field declarations |
| Field constraints | `where` clauses with comparison operators |
| Validation | Type refs, phase ordering, duplicate detection, doc completeness |

### Schema DSL syntax

```terra
import "lib/schema"

local DAW = schema DAW
    doc "Terra DAW v3: 7-phase signal-graph compiler."

    extern TerraType = [function(o) return terralib.types.istype(o) end]
    extern TerraFunc = [terralib.isfunction]

    --- User-facing authoring state.
    phase Editor
        --- The top-level project document.
        record Project
            name: string
            author: string?
            format_version: number
            transport: Transport
            tracks: Track*
            unique
        end

        --- Track input routing.
        enum TrackInput
            NoInput
            AudioInput { device_id: number, channel: number }
            MIDIInput { device_id: number, channel: number }
        end

        --- Phase transition methods.
        methods
            doc "Editor -> Authored lowering."
            Project:lower() -> Authored.Project
                doc "Lower the full editor project to authored semantic form."
                impl = [require("impl/editor/project")]
                fallback = [function(self) return fallbacks.authored_project() end]
                status = "real"
        end
    end
end
```

### Doc enforcement rule

Once any `doc` appears anywhere in the schema, docs become **required** at
every semantic level: schema, phase, record, enum, flags, method, hook.
This is enforced at parse/validation time. Docs cannot drift from declarations
because they are part of the same validated structure.

Two forms are supported:
- Inline: `doc "description"`
- Attached comments: `---` lines immediately above the declaration

### Method body module contract

Each `impl/<phase>/<type>.t` file returns a **bare function**. No boilerplate:

```lua
-- impl/editor/track.t
-- Returns the lower() implementation for Editor.Track.

local function lower(self)
    -- ... domain logic ...
end

return lower
```

No `require("daw-unified")`. No `diag.status()`. No `diag.wrap()`.
No `terralib.memoize()`. No method installation. The schema owns all of that.
Method bodies are **pure domain logic**.

If the method body needs schema types for constructors, use:
```lua
local DAW = require("daw")
local D = DAW.types
```

---

## The Terra Compiler Pattern

The full pattern is documented in `docs/terra-compiler-pattern.md`. This section
summarizes the rules that must be followed in every implementation.

### The atomic unit

```lua
terralib.memoize(function(config) ... return { fn = fn, state_t = S } end)
```

Every compilation boundary in the system follows this shape. The schema DSL
applies `terralib.memoize` automatically on every declared method.

### Compile products

A compile product is `{ fn: TerraFunc, state_t: TerraType }`. The function
owns its ABI. The parent composes child `state_t`s into its own struct and
passes pointers to each child. A cache hit on a child is memory-safe because
the child's state type hasn't changed.

The schema auto-detects compile product types and annotates methods that
return them with `compile_product = true`.

### Boundary correctness collapses infrastructure

From the same correctly modeled boundaries, we get — without separate subsystems:

- **memory management** — `state_t` composition is the ownership graph
- **lifetime management** — child state lives as long as the parent embedding it
- **error handling** — each method boundary is a local degradation boundary
- **loading / JIT ownership** — load, define, typecheck, JIT, runtime are explicit
- **test structure** — the method tree is the test tree
- **implementation structure** — the ASDL tree is the file tree
- **progress tracking** — `methods {}` and variants are the inventory
- **stubs / fallbacks** — each target type defines the shape of valid degradation
- **lazy work** — memoized compilers only do work demanded by the current path
- **incremental compilation** — unchanged subtrees remain cache hits
- **code size control** — memoize boundaries are call boundaries
- **hot swap / undo** — old compiled units remain cached by semantic identity

### Non-negotiable rules

1. **Every public phase-transition boundary must be memoized.** If it is not,
   it is an architectural bug. The schema enforces this automatically.

2. **No opaque semantic context objects.** Public method signatures take only
   explicit semantic parameters (often none beyond `self`). Temporary scratch
   state belongs inside the memoized implementation, not in the public API.

3. **No hidden semantic state.** No underscore-prefixed fields carrying meaning
   that affects codegen but is absent from ASDL and memoize keys. If it matters
   for the result, it must be an explicit parameter or ASDL-owned field.

4. **Explicit parameters only.** `terralib.memoize` keys by Lua equality on
   explicit arguments. If the design fights that, redesign the API, don't hide
   state behind helpers.

5. **Structural sharing preserves cache hits.** Editor/session mutations must
   preserve unchanged subtree references so memoized phase transitions reuse
   cached results for unaffected parts of the tree.

6. **Compile-time and runtime are strictly separated.** Lua + ASDL manipulation
   belongs at compile time. Compiled Terra functions belong at runtime. Never
   mix layers.

7. **`{ fn, state_t }` for reusable compiled units.** Returning only a function
   where local state exists is architecturally wrong. Returning only a quote
   where a reusable boundary should exist is architecturally wrong.

8. **Fail-fast inside, total at boundaries.** Assertions guard programmer errors.
   Phase boundaries return valid degraded output + diagnostics on failure. One
   failing subtree does not tear down the whole session.

### Exotype hooks

The schema DSL supports `hooks` blocks for declaring exotype metamethods:

```terra
hooks Kernel.Unit
    doc "Runtime behavior for compiled units."
    methodmissing
        doc "Lazy Terra-side method generation."
        macro = [function(name, obj, ...) ... end]
end
```

The correct split: **ASDL owns meaning; memoize owns reuse; `__methodmissing`
owns lazy Terra-side behavior.** Exotype hooks are for generated runtime
behavior, not for hiding semantic dependencies that belong in ASDL.

---

## Build & Run

```bash
# Validate the schema (validates all types, methods, docs at load time)
terra daw.t

# Run the app
terra main.t

# Run tests
terra tests/<phase>/<type>/<method>.t

# Check progress (derived from schema.inventory)
terra -e 'import "lib/schema"; local D = require("daw"); for _,m in ipairs(D.inventory.methods) do print(m.receiver..":"..m.name, m.status or "none") end'
```

The `terraui/` submodule has its own build system — see `terraui/AGENTS.md`.

---

## Language & Code Style

### Naming Conventions

| Kind | Convention | Example |
|---|---|---|
| Schema/phase namespaces | `PascalCase` | `Editor`, `Authored`, `Resolved`, `Kernel` |
| Type names | `PascalCase` | `DeviceChain`, `GraphLayout`, `NodeKind` |
| Sum-type variants | `PascalCase` | `AudioInput`, `ManualSelect`, `FreqSplit` |
| Fields | `snake_case` | `sample_rate`, `output_track_id`, `per_voice` |
| Method args | `snake_case` | `ticks_per_beat`, `transport` |
| Lua helper functions | `snake_case` | `parse_name`, `push`, `normalize_id` |
| Lua local tables/modules | short uppercase | `D`, `M`, `C` |

### Formatting

- 4-space indentation. No tabs.
- File header comment identifies the file and its role.
- Comments explain *why*, not *what*. Names and assertions explain what.
- `---` doc comments above declarations in schema files.
- No global pollution. All definitions are `local`.

### Common Utilities

```lua
-- Deterministic iteration over unordered tables:
local keys = {}
for k in pairs(t) do keys[#keys+1] = k end
table.sort(keys)
for _, k in ipairs(keys) do ... end
```

---

## Key Design Axioms

### Editor layer
- Captures semantic authoring state, not transient UI state.
- Commands operate on `Editor.*`, never directly on `Authored.*`.
- Invalid states should be unrepresentable in the type system.
- Structural composition = constructing/transforming Editor trees directly.

### View layer
- References Editor objects; does not duplicate them.
- Semantic IDs come from Editor. TerraUI keys derived during lowering.
- Musical/project truth stays in Editor.
- TerraUI action dispatch routes back to Editor command semantics.

### Authored layer
- The semantic source of truth. Richness belongs here.
- `Graph` is the universal container. One type, one compilation path.
- `NodeKind` is the one sum type carrying all variety.
- No separate container concept. Container-ness = `SubGraph()` kind.

### Resolved/Classified/Scheduled layers
- Zero sum types. All variants collapsed to integer codes.
- Flat tables replace nested trees.
- Reusable compilation slices/programs own their local data.

### Kernel layer
- `Kernel.Unit = { fn: TerraFunc, state_t: TerraType }` — the atomic compiled product.
- Parent programs compose child units and child state types.
- Runtime surface exposes only compiled Terra functions.

---

## Key Invariants

- **One graph type.** All container-like Editor types lower to `Authored.Graph`.
- **One node type.** `Authored.NodeKind` covers everything.
- **Stable IDs.** Editor-level IDs are stable identities across mutations.
- **Schema is authoritative.** Types, methods, docs, fallbacks, progress — all
  live in the schema. If it's not in the schema, it doesn't exist.
- **No speculative generality.** Solve the problem that exists now.
- **Compile-time / runtime separation.** Lua + ASDL at compile time. Terra at runtime.
- **Memoize at every boundary.** Non-memoized phase transition = architectural bug.
- **Structural sharing.** Editor mutations preserve unchanged references.
- **Leaf-level reuse.** Node/output/mix programs reuse inside changed graphs/tracks.
- **The correct thing is the shortest thing to write.** The schema DSL makes the
  architecturally correct implementation the default, not the exception.
