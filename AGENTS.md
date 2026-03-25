# AGENTS.md

## Project Overview

This repo defines **Terra DAW v3** — a DAW (Digital Audio Workstation) compiler IR
modeled as a 7-phase signal-graph pipeline. The primary file is `daw-unified.t`.

The project is written entirely in [Terra](https://terralang.org/), a low-level
statically typed language embedded in and meta-programmed by Lua. There is no
JavaScript, TypeScript, or Node.js tooling of any kind. All source files use the
`.t` extension.

**Core insight:** everything is a signal graph. Device chains, grid patches, layer
containers, selectors, and freq splits are all `Graph` instances distinguished only
by their `layout` field. One type, one compilation path.

**Implementation planning insight:** the ASDL is not only the spec surface, it is
also the implementation tree, the test tree, and the progress tracker. The
file/module tree should reflect that same ASDL tree as directly as practical.
From now on, implementation work should be driven primarily by:

- `docs/implementation-strategy.md`
- `tools/progress.t` (run `terra tools/progress.t` for live progress)
- `docs/terraui-shell-composition.md`
- the inline schema comments in `schema/*.asdl.module.txt`

### Repository Layout

```
daw-unified.t                      # Schema loader / entrypoint for all ASDL modules
lib/schema.t                       # Terra language extension: the schema DSL
main.t                             # App entrypoint: SDL window + TerraUI shell

schema/                            # ASDL module definitions (THE source of truth)
    Editor.asdl.module.txt
    View.asdl.module.txt
    Authored.asdl.module.txt
    Resolved.asdl.module.txt
    Classified.asdl.module.txt
    Scheduled.asdl.module.txt
    Kernel.asdl.module.txt

impl/                              # Method implementations (mirrors ASDL tree)
    _support/                      #   shared: diag.wrap, fallbacks, L()
    editor/                        #   Editor → Authored (lower)
    view/                          #   View → TerraUI (to_decl)
    authored/                      #   Authored → Resolved (resolve)
    resolved/                      #   Resolved → Classified (classify)
    classified/                    #   Classified → Scheduled (schedule)
    scheduled/                     #   Scheduled → Kernel (compile)
    kernel/                        #   Kernel entry

app/                               # Runtime/bootstrap wiring
tools/                             # Development tools
    progress.t                     #   ASDL-driven live progress report
    asdl_methods.t                 #   ASDL schema parser (method inventory)
tests/                             # Tests (mirrors ASDL tree)

docs/                              # Documentation
    terra-compiler-pattern.md      #   The Terra Compiler Pattern (paper draft)
    implementation-strategy.md     #   Implementation strategy + milestones
    terraui-shell-composition.md   #   View → TerraUI shell boundary notes
    design-system/                 #   UI design tokens and visual spec

terraui/                           # Git submodule: TerraUI (separate project)
```

### Documentation

- **`docs/terra-compiler-pattern.md`** — the paper draft.  General pattern:
  exotypes, ASDL, metamethods, memoize, and the "ASDL as generative structure"
  thesis.  Domain-independent.
- **`docs/implementation-strategy.md`** — project-specific strategy: the
  `diag.wrap` error-boundary pattern, file structure, fallback policy,
  milestones, roadmaps.
- **`tools/progress.t`** — replaces any manual checklist.  Parses the ASDL,
  diffs against `diag.status()`/`diag.wrap()` registrations, reports progress.
  Run `terra tools/progress.t` for the live report.
- **`schema/*.asdl.module.txt`** — the single source of truth for types,
  phases, methods, features, error boundaries, file tree, and progress.

### Implementation layout rule

- top-level implementation folders mirror the ASDL modules/phases
- subfolders/files mirror ASDL type families
- tests mirror the same tree
- `app/` is for runtime/bootstrap wiring; phase methods belong in `impl/`
- `impl/view/components/` holds shared TerraUI lowering atoms, subordinate
  to the ASDL-shaped View tree

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
| 5 | `Scheduled` | Buffer slots, linear jobs, step sequence |
| 6 | `Kernel` | `TerraType` + `TerraQuote` + `TerraFunc`; native compiled output |

Each phase's types carry `methods` blocks declaring the transformation to the next phase:

```
Editor.Project:lower(LowerCtx)     -> Authored.Project
Authored.Project:resolve(...)      -> Resolved.Project
Resolved.Project:classify(...)     -> Classified.Project
Classified.Project:schedule(...)   -> Scheduled.Project
Scheduled.Project:compile(...)     -> Kernel.Project
View.Root:to_decl(ViewCtx)         -> TerraUIDecl
```

## Build & Run

This project has no Makefile or build system of its own. The file is a pure Terra
module that is `require`d or executed directly.

```bash
# Execute the schema definition (validates ASDL construction at load time)
terra daw-unified.t

# Load as a module from another Terra file:
#   local D = require("daw-unified")
```

The `terraui/` submodule has its own build system — see `terraui/AGENTS.md` for
those commands (`make test`, `make demo`, etc.). The two projects are independent.

Before implementing a new slice, re-read the relevant design and planning docs:

1. the relevant `schema/*.asdl.module.txt` comments and method signatures
2. `tools/progress.t` (live progress: `terra tools/progress.t`)
3. `docs/implementation-strategy.md`
4. `docs/terra-compiler-pattern.md`
5. the design-system docs under `docs/design-system/` when the slice affects UI
   look, hierarchy, primitives, or screen composition

## Language & Code Style

### Module System

```lua
-- Load ASDL library (standard Terra stdlib)
local asdl = require 'asdl'

-- Create a context and register extern types
local D = asdl.NewContext()
D:Extern("TerraType", terralib.types.istype)
D:Extern("PluginHandle", function(o) return type(o) == "userdata" end)

-- Define all phases in one D:Define [[ ... ]] block
D:Define [[
    module Editor { ... }
    module Authored { ... }
    ...
]]

return D
```

All definitions are `local`. No global pollution.

### ASDL Schema Conventions

The schema uses `asdl` (standard Terra ASDL library). Key syntax rules:

```
-- Record type (product):
Transport = (number sample_rate, number buffer_size, boolean looping)

-- Sum type (variants):
TrackInput = NoInput | AudioInput(number device_id, number channel) | MIDIInput(...)

-- Optional field:
string? author

-- List field (zero or more):
Editor.Track* tracks

-- Unique singleton (only one instance allowed):
Project = (...) unique

-- Methods block (declares cross-phase transforms):
methods {
    lower(LowerCtx ctx) -> Authored.Project
}
```

Cross-module references use `Module.TypeName` (e.g. `Authored.NodeKind`,
`Resolved.Graph*`). Within a module, bare names are unqualified.

### Naming Conventions

| Kind | Convention | Example |
|---|---|---|
| ASDL module namespaces | `PascalCase` | `Editor`, `Authored`, `Resolved`, `Kernel` |
| ASDL type names | `PascalCase` | `DeviceChain`, `GraphLayout`, `NodeKind` |
| ASDL sum-type variants | `PascalCase` | `AudioInput`, `ManualSelect`, `FreqSplit` |
| ASDL fields | `snake_case` | `sample_rate`, `output_track_id`, `per_voice` |
| Context parameter names | `PascalCase` suffix | `LowerCtx`, `ResolveCtx`, `CompileCtx` |
| Lua helper functions | `snake_case` | `parse_name`, `push`, `normalize_id` |
| Lua local tables/modules | short uppercase | `D`, `M`, `C` |

### Key Design Axioms (from inline comments)

**Editor layer:**

- Captures semantic authoring state, not transient UI state (no selection, zoom, hover).
- Commands operate on `Editor.*`, never directly on `Authored.*`.
- Invalid states should be unrepresentable in the type system itself.
- Structural composition = constructing/transforming Editor trees directly. No separate macro
  ontology.

**View layer:**

- References Editor objects; does not duplicate them.
- Semantic IDs come from Editor. TerraUI keys are derived during lowering.
- Musical/project truth stays in Editor. View-local state (tabs, scroll, collapse) may live
  in `View.SessionState`.
- TerraUI action dispatch must route back to Editor command semantics.

**Authored layer:**

- The semantic source of truth. Richness belongs here.
- `Graph` is the universal container: serial chain = `Graph(layout=Serial)`,
  free patch = `Graph(layout=Free)`, layer container = `Graph(layout=Parallel)`, etc.
- `NodeKind` is the one sum type carrying all variety — instruments, FX, Grid modules,
  containers, modulators, plugins. One enum, intentionally broad.
- No separate container concept. Container-ness = `SubGraph()` kind + `child_graphs`.

**Resolved/Classified/Scheduled layers:**

- Zero sum types. All variants collapsed to integer codes (`layout_code`, `domain_code`,
  `kind_code`, `rate_class`).
- Flat tables replace nested trees (`all_graphs`, `all_nodes`, `all_params`, etc.).

### Error Handling

Use **fail-fast inside a method**, but **total degraded outputs at phase boundaries**.

That means:

- assertions and `error()` are still correct for impossible internal states,
  broken invariants, and programmer mistakes discovered while implementing a
  method
- however, application/runtime-facing phase methods (`to_decl`, `lower`,
  `resolve`, `classify`, `schedule`, `compile`) should follow the documented
  fallback policy from the schema comments and implementation docs
- so a phase method should normally return either:
  - the intended output, or
  - a valid degraded output of the target phase plus diagnostics
- one failing subtree/device/surface should not normally tear down the whole
  shell/session/runtime compilation path
- this is not incidental: the ASDL tree also defines the natural local error
  boundaries, and lazy memoized compilation should preserve that locality so the
  failing thing degrades where it failed rather than collapsing unrelated parts

```lua
-- Assertions guard programmer errors inside the implementation itself:
assert(condition, "descriptive message: " .. tostring(value))

-- error() is still correct for impossible local states while developing a
-- method, but phase wrappers should catch and degrade at runtime/app level.
error("invalid internal state: " .. tostring(id))

-- Expected runtime conditions may still use nil, err at helper boundaries,
-- but phase entrypoints should convert them into typed fallbacks + diagnostics.
if not valid then return nil, "reason: " .. details end
```

### Common Utilities

-- Deterministic iteration over unordered tables:
local keys = {}
for k in pairs(t) do keys[#keys+1] = k end
table.sort(keys)
for _, k in ipairs(keys) do ... end

```

### Formatting

- 4-space indentation. No tabs.
- File header comment identifies the file and its role:
  ```lua
  -- daw-unified.t
  -- Terra DAW v3: Unified Model. Full 7-phase ASDL schema.
  ```

- Horizontal dividers (`-- ===...===` or `-- ────...────`) separate phases and logical
  sections.
- Comments explain *why*, not *what*. Names and assertions explain what.
- Inline design axioms and lowering contracts live as block comments directly above the
  type they constrain — this is the authoritative specification, not external docs.

## Key Invariants

- **One graph type.** `Editor.DeviceChain`, `Editor.GridPatch`, `Editor.LayerContainer`,
  etc. all lower to `Authored.Graph`. There is no separate container model.
- **One node type.** `Authored.NodeKind` covers instruments, FX, Grid modules, containers,
  modulators, and plugins. No parallel hierarchy.
- **Stable IDs.** Editor-level IDs (`track_id`, `device_id`, `layer_id`, etc.) are stable
  identities. Commands preserve them. View derives TerraUI keys from them deterministically.
- **Lowering contracts are authoritative.** Each type's comment block specifies exactly
  what it lowers to. Implement to match the comment, not the other way around.
- **No speculative generality.** Do not add fields, variants, or extension points for
  hypothetical future use. Solve the problem that exists now.
- **Compile-time and runtime are strictly separated.** Lua + ASDL manipulation belongs at
  compile time. Compiled Terra functions belong at runtime. Never mix layers.
- **The Terra Compiler Pattern is the implementation strategy.** `terralib.memoize` drives
  incremental recompilation. See `docs/terra-compiler-pattern.md` for the full reference.
- **`tools/progress.t` drives execution.** Run `terra tools/progress.t` for
  live ASDL-derived progress tracking. There is no manual checklist to maintain.
- **Each ASDL method is an atomic work unit.** Read its source type, destination
  type, neighboring family types, and inline comments before implementing it.
- **The ASDL is also the test tree.** Method-level tests should mirror the same
  phase/type/method structure as the implementation tree.
