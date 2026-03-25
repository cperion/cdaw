# Terra DAW Implementation Strategy

See also:

- `docs/asdl-purity-refactor-plan.md` — architectural intent for the ASDL-first purity refactor

## Thesis

This project is implemented as a set of **small, total, phase-local methods**
over the ASDL types.  The consequence:

- the **program exists early** — every method is scaffolded with a valid stub
- the **UI exists early** — View `to_decl` methods are real from the start
- the **project/document model exists early** — Editor→Authored lowering works
- the **audio/runtime compiler completes incrementally** — Kernel stubs produce
  silence, then gain sound one node kind at a time

We do **not** wait for all DSP, all lowering, or all rendering details before the
DAW is usable.  The whole semantic application stands first; compilation depth
increases over time.

---

## What the ASDL is

The ASDL schema is the single generative structure of the entire system.
Everything derives from it.  This is not a metaphor — each derivation is
a concrete mechanism with code behind it.

### Specification

- **The domain model.**  Every musical concept the system knows about is an ASDL
  type: tracks, devices, clips, notes, graphs, nodes, params, modulators.
- **The phase structure.**  Each ASDL module is one compiler phase.  The
  `methods {}` blocks declare the exact transitions between phases.
- **The type contracts.**  ASDL constructors validate fields at construction
  time.  Invalid states are caught immediately, not downstream.
- **The feature list.**  Every Editor command family (AddTrack, MoveDevice,
  SetNoteVelocity, LaunchScene, ...) is declared in the schema comments.  If
  it's not in the ASDL, the user can't do it.
- **The user guide.**  Editor types map 1:1 to what the musician sees.
  `Editor.Track` is a track.  `Editor.Note` is a note.  The schema comments
  describe what each thing means and what constraints it has.

### Architecture

- **The implementation tree.**  Each ASDL type with a `methods {}` block
  produces one implementation file in `impl/<phase>/<type>.t`.
- **The file tree.**  Top-level folders mirror ASDL modules.  Subdirectories
  mirror type families.  The filesystem reads like the schema.
- **The test tree.**  One test per method.  The test structure mirrors the
  implementation structure mirrors the schema structure.
- **The error boundaries.**  Each `methods {}` declaration is exactly one
  `diag.wrap()` boundary.  Failure in one method degrades that subtree;
  everything else survives.
- **The fallback policy.**  Every ASDL target type has a valid empty/silent
  fallback constructor in `F.*`.  This is why stubs work: the type system
  guarantees the fallback is well-formed.

### Project management

- **The progress tracker.**  `tools/progress.t` parses the schema text to
  discover what methods should exist, uses the loaded ASDL runtime to discover
  variant families, and diffs both against runtime registrations. Adding a type
  with `methods {}` to the schema = creating a ticket. No manual checklist.
- **The status declarations.**  `diag.status()` + `diag.wrap()` carry a
  `"stub"` / `"partial"` / `"real"` tag.  Changing one string = moving the
  ticket across the board.
- **The division of work.**  Each method is an atomic, well-typed work unit.
  Different people can work on different methods with minimal conflict because
  the ASDL already defines the boundaries.

### Compilation and memory

- **The compilation boundary.**  Each phase transition is a total function from
  one complete ASDL document to another.  No phase needs to look beyond its
  immediate input.  This is why the seven phases compose cleanly: they are a
  linear pipeline, not a tangle.
- **The memoization boundary.**  `terralib.memoize` caches compiled output by
  structural identity on ASDL values.  Same configuration = same compiled code,
  returned instantly.  Undo is a cache hit.
- **The allocation discipline.**  Phases are pure transformations: ASDL in,
  ASDL out.  There is no persistent mutable application state that accumulates
  across frames.  No incremental mutation tracking, no observer/listener
  subscriptions, no invalidation cascades, no stale references.  The current
  Editor tree IS the application state.  Recompile from it whenever anything
  changes.  The memoize cache makes this fast.
- **The memory layout.**  ASDL values are plain Lua tables at compile time.
  At runtime, the Kernel phase produces monomorphic Terra structs with known
  layouts — no boxing, no vtables, no GC.  The ASDL pipeline is the allocator:
  it decides what memory exists by what it constructs.
- **The ownership model.**  ASDL trees are value semantics.  There is no shared
  mutable state between phases.  Each phase owns its output completely.  When a
  new output replaces the old one, the old one can be dropped entirely.  With
  `unique` types, structurally identical subtrees share identity automatically.
- **The serialization format.**  `Editor.Project` IS the project file.  The
  ASDL types define exactly what is saved and loaded.  No separate serialization
  schema to maintain.

### Runtime properties

- **The hot-reload boundary.**  Changing one method body and rerunning
  recompiles only the affected path.  Memoize caches the rest.  Undo/redo is
  instant because previous ASDL configurations are already cached.
- **The parallelism boundary.**  Independent subtrees within a phase can be
  processed in parallel because they share no mutable state.  Two tracks
  resolving simultaneously cannot interfere.
- **The debuggability.**  Every intermediate ASDL document is a plain Lua
  table.  You can print it, inspect it, diff two of them, serialize them.
  There are no opaque intermediate states.
- **The migration path.**  Adding a field to an ASDL type is a schema change.
  Every constructor and every method that produces that type gets a clear
  compile-time error until updated.  No silent breakage.

### The core insight

All of these are not separate design decisions.  They are consequences of one
decision: **model the domain as a typed phase pipeline, and make the types
executable**.  The ASDL is not documentation about the system.  It is the system.
Everything else — files, tests, errors, progress, memory, compilation,
serialization — is derived.

---

## The implementation loop

This is the concrete workflow for implementing any feature:

### 1. The ASDL defines what should exist

The `schema/*.asdl.module.txt` files declare every method:

```
Track = (...)
methods {
    lower() -> Authored.Track
}
```

`tools/progress.t` parses these files and produces the canonical method
inventory.  **Adding a type with a `methods {}` block to the ASDL automatically
shows it as unimplemented in the progress report.**  There is no separate
checklist to maintain.

### 2. Every method uses the unified error-boundary wrapper

**Canonical boundary rule:** phase methods take only explicit semantic
parameters — often none beyond `self`. They must not depend on an opaque phase
`ctx` as part of their semantic result. Temporary allocators, interning tables,
and codegen scratch state belong inside the memoized implementation, not in the
public method signature.

```lua
local diag = require("impl/_support/diagnostics")

-- Load-time declaration (visible to progress tracker even before first call)
diag.status("editor.track.lower", "partial")

function D.Editor.Track:lower()
    return diag.wrap(nil, "editor.track.lower", "partial", function()
        -- pure memoized body on explicit args only
        return output
    end, function(err)
        -- fallback: valid degraded output
        return F.authored_track(self.id, self.name, self.channels)
    end)
end
```

`diag.wrap` provides:
- **pcall error boundary** — body failure triggers the fallback, never crashes the pipeline
- **status self-reporting** — `"stub"` / `"partial"` / `"real"` registered at call time
- **call tracking** — successes vs fallbacks counted per method
- **diagnostic recording** — failures logged if a diagnostics sink is explicitly provided

`diag.status` provides:
- **load-time declaration** — visible to the progress tracker before any method is called

### 3. The progress tool diffs ASDL vs implementations

```bash
terra tools/progress.t           # full report
terra tools/progress.t summary   # one-line progress bar
terra tools/progress.t phase     # per-phase breakdown table
terra tools/progress.t runtime   # run fixture, show call stats
```

The report shows every ASDL-declared method and its status:
- `█ REAL` — fully implemented
- `▓ PART` — does real work but incomplete
- `░ STUB` — returns valid fallback only
- `· NONE` — exists in ASDL but no implementation file yet

### 4. Upgrade a method: change the body, change the status string

Moving from stub to real is a one-file change:

```lua
-- was: diag.status("scheduled.track_program.compile", "stub")
diag.status("scheduled.track_program.compile", "real")

function D.Scheduled.TrackProgram:compile()
    return diag.wrap(nil, "scheduled.track_program.compile", "real", function()
        -- real DSP code generation here
        -- any temporary compile scratch belongs inside this implementation,
        -- not in the public method signature
        return kernel_unit
    end, function(err)
        -- fallback: silence / no-op unit
        return F.kernel_unit()
    end)
end
```

No other files change.  No checklist to update.  `tools/progress.t` sees it
automatically.

---

## The unified error-boundary pattern

All phases — View, Editor, Authored, Resolved, Classified, Scheduled, Kernel —
use the same `diag.wrap()` mechanism.  The only difference is what the fallback
produces:

| Phase | Body returns | Fallback returns |
|---|---|---|
| View → TerraUI | TerraUI subtree | `P.fallback_node()` — visible error placeholder panel |
| Editor → Authored | Authored ASDL value | `F.authored_*()` — valid empty/silent semantic node |
| Authored → Resolved | Resolved ASDL value | `F.resolved_*()` — valid flattened form |
| Resolved → Classified | Classified ASDL value | `F.classified_*()` — valid with zero bindings |
| Classified → Scheduled | Scheduled ASDL value | `F.scheduled_*()` — valid with no jobs |
| Scheduled → Kernel | `Kernel.Unit` or `Kernel.Project` | `F.kernel_unit()` / `F.kernel_project()` — silence / zero / passthrough |

Fallback constructors live in `impl/_support/fallbacks.t`.  They are shared by
all stubs and by real implementations when a child fails.

### Composite methods compose children safely

```lua
function D.Editor.Project:lower()
    return diag.wrap(nil, "editor.project.lower", "partial", function()
        local transport = self.transport:lower()     -- has its own wrap
        local tracks = diag.map(nil, "editor.project.lower.tracks",
            self.tracks, function(t) return t:lower() end)  -- per-item protection
        return D.Authored.Project(self.name, ..., transport, tracks, ...)
    end, function(err)
        return F.authored_project(self.name)
    end)
end
```

If `Transport:lower` throws → its own wrap catches it, returns
`F.authored_transport()`. If one track throws → `diag.map` drops it. If the
whole body throws → the outer wrap catches, returns an empty project. The
pipeline never crashes.

### List mapping with per-item protection

`diag.map(ctx, code, items, fn)` calls `fn` on each item under pcall.
Failed items are dropped with a diagnostic.  Returns a proper ASDL-compatible
`List`.

---

## Infrastructure

### File structure

```text
impl/
    _support/
        diagnostics.t     -- diag.wrap, diag.status, diag.map, diag.record, L()
        fallbacks.t        -- F.authored_*, F.resolved_*, ..., F.noop_quote, enum mappers
    editor/
        init.t             -- load order
        project.t          -- Editor.Project:lower
        transport.t        -- Editor.Transport:lower, TempoMap:lower
        track.t            -- Editor.Track:lower
        device.t           -- Editor.Device:lower (sum type parent → all variants)
        device_chain.t     -- Editor.DeviceChain:lower
        grid_patch.t       -- Editor.GridPatch:lower
        modulator.t        -- Editor.Modulator:lower
        param_value.t      -- Editor.ParamValue:lower
        clip.t             -- Editor.Clip:lower, NoteRegion:lower
        slot.t, scene.t, send.t
    view/
        init.t
        root.t, shell.t, transport_bar.t, status_bar.t, detail_panel.t
        arrangement/, launcher/, mixer/, piano_roll/
        device_chain/, browser/, inspector/
        components/        -- shared TerraUI lowering atoms
        _support/common.t  -- palette, identity encoding, selection helpers
    authored/
        init.t
        project.t, transport.t, track.t, graph.t, node.t
        node_kind.t, param.t, mod_slot.t, asset_bank.t
        clip.t, slot.t, scene.t, send.t
    resolved/
        init.t
        project.t, transport.t, track.t, graph.t, node.t, param.t, mod_slot.t
    classified/
        init.t
        project.t, transport.t, track.t, graph.t, node.t, binding.t
    scheduled/
        init.t
        project.t, tempo_map.t, step.t, graph_plan.t
        node_job.t, clip_job.t, mod_job.t
        send_job.t, mix_job.t, output_job.t, binding.t
    kernel/
        init.t
        project.t
tools/
    progress.t             -- ASDL-driven progress report
    asdl_methods.t         -- ASDL schema parser (extracts method inventory)
tests/
    pipeline_e2e.t         -- full 7-phase end-to-end test
```

### Load order

`impl/init.t` loads phases in dependency order:

```lua
require("impl/view/init")        -- independent (references Editor, lowers to TerraUI)
require("impl/editor/init")      -- Editor → Authored
require("impl/authored/init")    -- Authored → Resolved
require("impl/resolved/init")    -- Resolved → Classified
require("impl/classified/init")  -- Classified → Scheduled
require("impl/scheduled/init")   -- Scheduled → Kernel
require("impl/kernel/init")      -- Kernel entry
```

Within each phase, `init.t` loads leaf methods before composite methods, and
sum-type parent methods before potential child overrides.

### ASDL list fields

ASDL `*` fields require `terralist.List`, not plain Lua tables.  Use `L()`:

```lua
local L = F.L  -- or diag.L — same function

D.Authored.Track(id, name, 2, D.Authored.NoInput, vol, pan,
    F.authored_graph(0),
    L(), L(), L(),           -- clips, slots, sends
    nil, nil, false, false, false, false, false)
```

`diag.map()` returns a proper List automatically.

---

## How to implement one method

### Before writing code

Read these in order:

1. **The method signature** in `schema/*.asdl.module.txt` — phase boundary
2. **The input type fields and comments** — what's available
3. **The surrounding family types** — siblings, parents, repeated subviews
4. **The destination type** — what shape must be emitted
5. **The fallback/diagnostic notes** — how to degrade safely

### The implementation recipe

1. Create the file in the ASDL-mirrored location
2. Add `diag.status("code", "stub")` at load time
3. Add `diag.wrap(ctx, "code", "stub", body_fn, fallback_fn)`
4. Implement the smallest correct body (or just call `F.*` for a pure stub)
5. Write the fallback function (valid degraded output)
6. Run `terra tools/progress.t summary` to verify it shows up
7. Add a test in `tests/`
8. Upgrade status to `"partial"` or `"real"` as the body matures

### Sum type methods

For sum types like `Editor.Device` or `Authored.NodeKind`, define the method on
the **parent type**.  ASDL's `__newindex` propagation copies it to all variants:

```lua
-- Parent method — automatically inherited by NativeDevice, LayerDevice, etc.
function D.Editor.Device:lower()
    return diag.wrap(nil, "editor.device.lower", "partial", function()
        if self.kind == "NativeDevice" then return lower_native(self.body)
        elseif self.kind == "LayerDevice" then return lower_layer(self.body)
        -- ...
        end
    end, function(err)
        return F.authored_node(0, "device_fallback")
    end)
end
```

Later, individual variants can be overridden by assigning directly to the
variant's class table.

---

## Fallback policy by phase

### View → TerraUI
- stable keyed placeholder subtree via `P.fallback_node(ctx, key, title, detail)`
- visible error panel with title + detail text
- shell remains intact

### Editor → Authored
- valid canonical semantic node/graph/asset via `F.authored_*()`
- preserve ids, names, channels where possible
- use empty/silent/passthrough authored forms

### Authored → Resolved
- valid flattened form via `F.resolved_*()`
- empty event streams, zero control sources
- preserve track/node ids

### Resolved → Classified
- valid classified form via `F.classified_*()`
- zero bindings, no signal allocation

### Classified → Scheduled
- valid plan forms via `F.scheduled_*()`
- no jobs, no buffer allocation

### Scheduled → Kernel
- silence for generators via `F.noop_quote()`
- passthrough for effects
- zero output for modulators
- no-op Terra functions for Kernel API

---

## Progress tracking

The system is **self-tracking**.  There is no manual checklist to maintain.

The ASDL schema is the single source of truth for what methods should exist.
Each implementation file self-reports its status via `diag.status()` and
`diag.wrap()`.  The progress tool diffs them.

```
$ terra tools/progress.t summary

Terra DAW: 46/68 methods implemented  │   34% real   34% partial   32% stub    0% none
  █████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░  █ 23  ▓ 23  ░ 22  · 0
```

**To add a feature:**

1. Add the type + `methods {}` to the ASDL schema
2. Run `terra tools/progress.t` → it appears as `· NONE`
3. Create the impl file with `diag.status` + `diag.wrap`
4. Run again → it appears as `░ STUB`
5. Implement the real body → update status to `"real"`
6. Run again → it appears as `█ REAL`

No other bookkeeping required.

---

## Test strategy

### End-to-end pipeline test

`tests/pipeline_e2e.t` constructs a representative Editor.Project and pushes it
through all 7 phases.  It verifies:

- every phase transition succeeds
- identity is preserved (track ids, names, counts)
- container devices produce child graphs
- grid patches produce nodes and wires
- the full pipeline produces a callable Kernel entry function

### Per-method tests

Each important method should have:

- one happy-path fixture
- one edge-case fixture
- one forced-failure/fallback fixture
- one identity-preservation assertion

Tests mirror the ASDL tree:

```text
tests/editor/track_lower.t
tests/authored/param_resolve.t
tests/scheduled/node_job_compile.t
```

---

## Milestones

### A — Schema / architecture  ✓

Schema split into modules, loader operational, View ontology specified, piano
roll designed, unified error boundaries (`diag.wrap`), full 7-phase stub
pipeline operational, ASDL-driven progress tracking.

### B — Shell in a window  ✓

SDL/OpenGL window, TerraUI component tree rendering, keyboard/mouse input, text
rendering, DAW shell with transport/sidebar/main/detail/status, mode switching.

### C — Interactive editor shell

Command actions fire from UI.  Editor mutations update shell state.
Arrangement, mixer, launcher, piano roll, browser, inspector all usable as
interactive editors (even if audio is silent).

### D — Semantic lowering breadth

Major Editor families lower completely.  Note regions, devices, containers,
grid, scenes, sends lower.  Authored/resolve/classify/schedule paths produce
structurally complete output.

### E — First sound

Transport runtime active.  Clip playback.  Gain/pan.  One instrument source.
Modulation affects audible parameters.

### F — Incremental device growth

First effects bank, first synth bank, robust modulation runtime.  Sessions
remain forward-compatible as compilers deepen.

---

## DSP / device compile roadmap

This is intentionally incremental.  The UI/editor work before any of this.

**Fallback behaviors** (already scaffolded via `F.noop_quote()`):
generators → silence, effects → passthrough, note FX → passthrough,
modulators → zero control, analyzers → no-op.

**First audible path**: transport timing → track gain/pan → clip playback →
note event playback.

**First node kinds**: GainNode, PanNode, basic EQ, basic synth, ADSR, LFO,
delay, compressor — each implemented inside reusable scheduled compilation
units (e.g. `Scheduled.GraphProgram:compile()` / `Scheduled.TrackProgram:compile()`)
by specializing on `kind_code` payloads carried by scheduled node jobs.

**Modulation runtime**: evaluate mod slot output → apply routes to target params
→ bipolar mapping → scale modulation.

**Piano-roll/runtime bridge**: note-region lowering preserves ids through
Authored → Resolved flattens to events → runtime consumes events → expression
playback maps to control paths.

---

## Command dispatch roadmap

Commands are already specified as typed `View.*Command` families in the ASDL.
Implementation = wiring action dispatch from TerraUI back to Editor mutations.

**Global**: transport play/stop/record/loop, shell focus, sidebar, detail panel.

**Arrangement**: playhead, loop range, time selection, clip add/move/resize,
automation points.

**Launcher**: slot/scene launch, stop track, slot behavior, selection.

**Mixer**: track flags/output/volume/pan, send level/mode/add/remove.

**Device chain**: add/move/remove/replace/toggle device, wrap in
layer/selector/split, convert to grid.

**Containers**: layer/selector-branch/split-band add/move/remove + mix/mode/crossover.

**Grid**: module add/move/remove, cable connect/disconnect, source bind/unbind.

**Modulation**: modulator add/remove/move/enable/voice, mapping add/remove/depth/scale.

**Piano roll**: note add/remove/move/resize, velocity/mute/transpose/quantize,
expr points.

---

## Practical summary

1. **ASDL is the spec, the implementation tree, the test tree, and the progress tracker**
2. **`diag.wrap()` is the universal error boundary** — same mechanism for all 7 phases
3. **`diag.status()` + `diag.wrap()` are the status declarations** — no separate registry
4. **`tools/progress.t` diffs ASDL vs implementations** — no manual checklist
5. **Fallback constructors in `F.*` make stubs trivial** — one line per fallback
6. **The tree stands first; compilation depth increases over time**

See also:

- `docs/terra-compiler-pattern.md` — the foundational Terra compilation methodology
- `docs/terraui-shell-composition.md` — View → TerraUI shell-boundary notes
- `tools/progress.t` — live progress report
- `tests/pipeline_e2e.t` — full pipeline validation
