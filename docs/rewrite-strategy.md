# Rewrite Strategy: schema.t as Center of Gravity

## Why rewrite, not refactor

The old stack was built around accidental friction:

- stock ASDL strips `methods {}` metadata → hand-reinstall methods
- methods metadata lost → hand-scrape schema text for progress
- no doc enforcement → docs drift from declarations
- no fallback contract → hand-write `diag.wrap` + `F.*` per method
- no memoize ownership → hand-wrap `terralib.memoize` per method
- no exotype hooks → ad-hoc metamethod installation
- no test tree derivation → hand-maintain test structure
- no compile-product detection → hand-annotate method semantics
- no runtime type checking → silent type mismatches

`lib/schema.t` solves all of these structurally. Refactoring the old code
toward it would preserve old assumptions under adapters. A clean rewrite
onto the new DSL is the conservative choice because it preserves only
semantic truth, not historical scaffolding.

---

## What survives (semantic truth)

These are the hard-won results from the prototyping phase. They are
non-negotiable inputs to the rewrite, not things to rediscover.

### Phase structure
```
Editor → View → Authored → Resolved → Classified → Scheduled → Kernel
```
Seven phases unchanged. Each is a `phase` block in the new schema.

### Type families
Every ASDL type family (Project, Transport, TempoMap, Track, Graph, Node,
Param, Clip, Slot, Scene, Send, ModSlot, ModRoute, AssetBank, etc.) survives.
They become `record` / `enum` / `flags` declarations in the new DSL.

### Method boundaries
Every public phase-transition method survives as a `methods` item:
- `Editor.*:lower() -> Authored.*`
- `View.*:to_decl() -> TerraUIDecl`
- `Authored.*:resolve(ticks_per_beat: number) -> Resolved.*`
- `Resolved.*:classify() -> Classified.*`
- `Classified.*:schedule(...) -> Scheduled.*`
- `Scheduled.*:compile() -> Kernel.*`
- `Kernel.Project:entry_fn() -> TerraFunc`

### Reusable compilation units
The slice/program/unit hierarchy:
- `Resolved.GraphSlice`, `Resolved.TrackSlice`
- `Classified.GraphSlice`, `Classified.TrackSlice`
- `Scheduled.GraphProgram`, `Scheduled.TrackProgram`
- `Scheduled.NodeProgram`, `Scheduled.ModProgram`
- `Scheduled.ClipProgram`, `Scheduled.SendProgram`
- `Scheduled.MixProgram`, `Scheduled.OutputProgram`
- `Kernel.Unit = { fn: TerraFunc, state_t: TerraType }`

### Memoization invariants
- Every public phase-transition boundary is memoized
- Keys are explicit semantic parameters only
- Structural sharing in editor mutations preserves cache hits
- Leaf-level node/output/mix reuse inside changed graphs/tracks

### Method bodies
The actual lowering/resolve/classify/schedule/compile logic in each
`impl/<phase>/*.t` file. These are the domain semantics — they survive
as the `impl = ...` expressions in the new schema or as external method
bodies attached after schema construction.

### DSP node implementations
The node-kind dispatch table in `impl/scheduled/compiler/node_job.t`
and friends. These are real signal-processing semantics.

### View lowering logic
The View → TerraUI lowering in `impl/view/**/*.t`. Real UI structure.

### Structural sharing helpers
`app/session.t` persistent-update helpers (`update_project_param`,
`update_project_track_volume`, `map_preserve`, etc.).

### Test semantics
The *assertions* in existing tests survive. The *scaffolding* around
them (manual `check()` helpers, manual `diag.status` registration,
manual `F.*` construction) may change.

---

## What gets deleted (scaffolding)

### Immediately deletable
| File/system | Reason |
|---|---|
| `daw-unified.t` | Replaced by new schema DSL file |
| `schema/*.asdl.module.txt` (7 files) | Schema text moves into DSL |
| `impl/_support/diagnostics.t` | `diag.wrap`/`diag.status`/`diag.variant_*` replaced by schema-native status/fallback/inventory |
| `tools/progress.t` | Replaced by `schema.inventory` |
| `tools/asdl_methods.t` | Dead hand-scraping tool |
| `tools/asdl_methods.lua` | Dead hand-scraping tool |
| `impl/*/init.t` (all phase init files) | Method installation is now schema-owned |
| `impl/init.t` | Load tree is now schema-owned |

### Dramatically simplified
| File/system | Change |
|---|---|
| `impl/_support/fallbacks.t` | Most fallbacks become declarative `fallback = ...` in schema; only complex multi-field fallbacks may remain as helper functions |
| `app/session.t` | Structural sharing helpers survive; `require("impl/init")` replaced by schema import |
| `app/bootstrap.t` | Schema import replaces `require("daw-unified")` + `require("impl/init")` |
| `main.t` | Same |

### Reorganized
| Current | New |
|---|---|
| `impl/editor/*.t` | Method bodies become `impl = function(self) ... end` in schema or external requires |
| `impl/authored/*.t` | Same |
| `impl/resolved/*.t` | Same |
| `impl/classified/*.t` | Same |
| `impl/scheduled/*.t` | Same |
| `impl/kernel/*.t` | Same |
| `impl/view/*.t` | Same |
| `impl/scheduled/compiler/*.t` | Private helpers, unchanged, required by method impls |

---

## New file structure

```
lib/schema.t                    # The language extension (already exists)
daw.t                           # The schema definition (replaces daw-unified.t)
impl/                           # Method body modules (simplified, no init/diag boilerplate)
  editor/                       # Editor -> Authored lowering bodies
  view/                         # View -> TerraUI lowering bodies
  authored/                     # Authored -> Resolved resolve bodies
  resolved/                     # Resolved -> Classified classify bodies
  classified/                   # Classified -> Scheduled schedule bodies
  scheduled/                    # Scheduled -> Kernel compile bodies
    compiler/                   # Private DSP/codegen helpers
  kernel/                       # Kernel accessor bodies
  support/                      # Shared helpers (fallback helpers if any remain)
app/                            # Runtime/session (mostly unchanged)
tests/                          # Reorganized to match schema.tests tree
docs/                           # Generated from schema.markdown + hand-written strategy docs
```

---

## The new schema file (`daw.t`)

This is the single source of truth. Rough shape:

```terra
import "lib/schema"

local DAW = schema DAW
    doc "Terra DAW v3: 7-phase signal-graph compiler for music production."

    extern TerraType = [function(o) return terralib.types.istype(o) end]
    extern TerraQuote = [terralib.isquote]
    extern TerraFunc = [terralib.isfunction]
    extern PluginHandle = [function(o) return type(o) == "userdata" end]
    extern TerraUIDecl = [function(o) return type(o) == "table" end]

    --- User-facing authoring state. Bitwig-shaped concepts.
    phase Editor
        --- The top-level project document.
        record Project
            name: string
            author: string?
            format_version: number
            transport: Transport
            tracks: Track*
            scenes: Scene*
            tempo_map: TempoMap
            assets: Authored.AssetBank
            unique
        end

        -- ... all Editor types ...

        methods
            doc "Editor -> Authored lowering."
            Project:lower() -> Authored.Project
                doc "Lower the full editor project to authored semantic form."
                impl = [require("impl/editor/project")]
                fallback = [require("impl/support/fallbacks").authored_project]
                status = "real"
            -- ... all Editor methods ...
        end
    end

    --- DAW-specific projection to TerraUI declarations.
    phase View
        -- ... View types and methods ...
    end

    --- Canonical semantic graph document.
    phase Authored
        -- ... Authored types and methods ...
    end

    -- ... Resolved, Classified, Scheduled, Kernel phases ...

    --- Exotype hooks for Kernel runtime types.
    hooks Kernel.Unit
        doc "Runtime behavior for compiled units."
        -- ... if needed ...
    end
end
```

### Key properties of this shape

1. **One file defines the entire schema** — types, methods, docs, fallbacks, status, hooks
2. **Method bodies are external requires** — `impl = [require("impl/editor/project")]` returns a function
3. **Fallbacks are declarative** — `fallback = [function(self) return ... end]` or `fallback = [require("impl/support/fallbacks").authored_project]`
4. **Status is declarative** — `status = "real"` lives next to the method
5. **Docs are enforced** — `---` comments or `doc "..."` at every level
6. **Memoize is automatic** — schema installs `terralib.memoize` on every boundary
7. **Runtime type checking is automatic** — schema validates args and return types
8. **Progress is derived** — `DAW.inventory` replaces `tools/progress.t`
9. **Test tree is derived** — `DAW.tests` replaces hand-maintained test structure
10. **Markdown docs are derived** — `DAW.markdown` replaces hand-maintained docs

---

## Method body module contract

Each `impl/<phase>/<type>.t` file becomes simpler. It returns a function,
not a side-effecting module that installs methods on `D`:

### Old shape (current)
```lua
local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("editor.track.lower", "real")

local lower_track = terralib.memoize(function(self)
    -- ... 80 lines of lowering logic ...
end)

function D.Editor.Track:lower()
    return diag.wrap(nil, "editor.track.lower", "real", function()
        return lower_track(self)
    end, function()
        return F.authored_track(self.id, self.name, self.channels)
    end)
end

return true
```

### New shape (after rewrite)
```lua
-- impl/editor/track.t
-- Returns the lower() implementation for Editor.Track.

local function lower(self)
    -- ... 80 lines of lowering logic (same semantics) ...
end

return lower
```

That's it. No `require("daw-unified")`. No `diag.*`. No `F.*`. No
`terralib.memoize`. No method installation. The schema owns all of that.

The method body is **pure domain logic**.

---

## Rewrite phases

### Phase 0: Freeze and validate `schema.t`
- [ ] All existing schema.t tests pass
- [ ] Write a small end-to-end proof: define a toy 2-phase schema in the DSL,
      attach impl/fallback/status, verify inventory/markdown/tests/memoize
- [ ] Confirm `attached_doc_comment` works reliably with Terra's lexer
- [ ] Confirm hooks installation works for exotype use cases
- [ ] Fix any bugs found

### Phase 1: Write the new schema file (`daw.t`)
- [ ] Translate all 7 `schema/*.asdl.module.txt` files into DSL syntax
- [ ] Add `doc` at every required level (schema, phase, record, enum, field, method)
- [ ] Add `fallback = ...` for every method where fallbacks exist
- [ ] Add `status = "real"` for every currently-real method
- [ ] Add `impl = [require("impl/...")]` for every method with an implementation
- [ ] Validate: `terra daw.t` succeeds, `DAW.inventory` matches old progress numbers
- [ ] Validate: `DAW.markdown` produces useful docs
- [ ] Validate: `DAW.tests` produces correct test tree

### Phase 2: Simplify method body modules
- [ ] Strip each `impl/<phase>/*.t` file to return a bare function
- [ ] Remove all `require("daw-unified")` — method bodies receive `self` which
      carries ASDL type information; if they need the schema context for
      constructors, it can be passed through the schema env or closure
- [ ] Remove all `diag.status()` / `diag.wrap()` / `diag.variant_*()` calls
- [ ] Remove all `terralib.memoize()` wrappers (schema does this)
- [ ] Remove all method installation (`function D.Foo.Bar:method()`)
- [ ] Keep `require("impl/scheduled/compiler/...")` for private helpers
- [ ] Validate: all tests pass after each file conversion

### Phase 3: Port tests
- [ ] Create test runner that uses `DAW.tests` structure
- [ ] Port each existing test to use schema-provided constructors and types
- [ ] Replace `require("daw-unified")` + `require("impl/init")` with schema import
- [ ] Add schema-derived test cases (boundary, fallback, memoization, compile_product)
- [ ] Validate: test count >= old test count

### Phase 4: Port app layer
- [ ] `app/session.t` uses schema import instead of `require("daw-unified")` + `require("impl/init")`
- [ ] `app/bootstrap.t` same
- [ ] `main.t` same
- [ ] `app/demo_audio.t` same
- [ ] Validate: `main.t` and `app/demo_audio.t` still work

### Phase 5: Delete old scaffolding
- [ ] Delete `daw-unified.t`
- [ ] Delete `schema/*.asdl.module.txt` (7 files)
- [ ] Delete `impl/_support/diagnostics.t`
- [ ] Delete `impl/*/init.t` (all phase init files)
- [ ] Delete `impl/init.t`
- [ ] Delete `tools/progress.t`
- [ ] Delete `tools/asdl_methods.t`
- [ ] Delete `tools/asdl_methods.lua` (if exists)
- [ ] Simplify or delete `impl/_support/fallbacks.t`
- [ ] Validate: no dangling requires, all tests pass

### Phase 6: Generate and verify derived outputs
- [ ] Write `DAW.markdown` to `docs/schema-reference.md`
- [ ] Write `DAW.test_markdown` to `docs/test-plan.md`
- [ ] Verify `DAW.inventory` matches expected method/type/hook counts
- [ ] Update `docs/implementation-strategy.md` to reference schema DSL
- [ ] Update `AGENTS.md` to reference new file structure

---

## Critical constraints during rewrite

### Keep the repo green
- Every phase ends with all tests passing
- Never have both old and new schema active simultaneously
- Phase 1 can coexist with old code if `daw.t` is not yet `require`d by anything
- Phase 2-4 are the critical switchover — do per-file, test after each

### No hybrid period
- Do not create bridge/adapter code between old `D` and new `DAW`
- Do not maintain two method installation paths
- Do not keep old progress tooling "just in case"
- Cut over decisively per phase

### Preserve memoize correctness
- Verify that schema-installed memoize behaves identically to hand-installed
- Run `tests/memoize_incremental.t` after each phase
- The memoize wrapper in schema.t wraps `boundary` (which includes fallback),
  so the memoize key is `(self, ...args)` — same as current

### Method body access to schema types
Method bodies need to construct ASDL values (e.g., `D.Authored.Track(...)`).
Options:
1. **Closure over schema env** — schema passes `types` table to impl factories
2. **Global/module-level require** — method body requires the schema module
3. **Self-discovery** — method body discovers types from `self`'s metatable

Option 1 is cleanest: `impl = [function(env) return function(self) ... end end]`
where `env` contains the schema types. But this changes the method body signature.

Option 2 is simplest for porting: `local DAW = require("daw")` at top of each
impl file. Method bodies look almost identical to current code but use `DAW.types`
instead of `D`.

Recommend **option 2** for the rewrite, with option 1 available for small inline
methods.

---

## Risk assessment

### Low risk
- Type declarations: mechanical translation, validated by schema parser
- Doc enforcement: existing inline comments provide most of the content
- Progress replacement: `schema.inventory` is strictly more powerful
- Test structure: `schema.tests` generates paths, content is ported

### Medium risk
- Method body porting: 50+ methods, each needs manual touch
- Memoize equivalence: schema wraps differently than hand-written
- Fallback equivalence: schema catches errors differently than `diag.wrap`
- Constructor access: method bodies need schema types available

### High risk
- Nothing identified. The schema DSL is already tested and the method
  bodies are pure domain logic that doesn't depend on the installation
  mechanism.

---

## Success criteria

The rewrite is done when:

1. `terra daw.t` loads the full 7-phase schema with all types, methods, docs
2. All method bodies are attached via `impl = ...` in the schema
3. All fallbacks are declared via `fallback = ...` in the schema
4. `DAW.inventory` shows the same method/variant coverage as current
5. All existing tests pass (ported to new imports)
6. `tests/memoize_incremental.t` passes with identical reuse behavior
7. `tests/first_sound.t` produces identical audio output
8. `app/demo_audio.t` plays sound
9. No file in the repo contains `require("daw-unified")`
10. No file in the repo contains `diag.status` or `diag.wrap`
11. No file in the repo contains `require("impl/init")`
12. `DAW.markdown` is written to `docs/schema-reference.md` and is useful
13. `docs/implementation-strategy.md` references the schema DSL, not the old stack

---

## Estimated effort

| Phase | Files touched | Effort |
|---|---|---|
| 0: Validate schema.t | ~5 | Small |
| 1: Write daw.t | 1 new + 7 source files | Medium (mechanical but large) |
| 2: Simplify impl bodies | ~50 files | Medium (repetitive but safe) |
| 3: Port tests | ~25 files | Medium |
| 4: Port app layer | ~5 files | Small |
| 5: Delete scaffolding | ~15 deletions | Small |
| 6: Generate outputs | ~3 files | Small |

Total: significant but bounded. Each phase is independently testable.
The hardest part is Phase 1 (writing the schema) and Phase 2 (simplifying
method bodies). Both are mechanical — the semantics don't change.

---

## What this buys

After the rewrite:

- **One file** defines the entire schema, docs, methods, fallbacks, progress
- **Method bodies** are pure domain logic with zero boilerplate
- **Progress** is `DAW.inventory` — no scraping, no manual registration
- **Docs** are generated from the schema — no drift possible
- **Tests** have a derived structure — no manual tree maintenance
- **Memoize** is automatic at every boundary — no hand-wrapping
- **Type checking** is automatic at every boundary — no silent mismatches
- **Fallbacks** are declarative — no repetitive `diag.wrap` ceremony
- **Hooks** are declarative — no ad-hoc metamethod installation
- **The correct thing is the shortest thing to write**
