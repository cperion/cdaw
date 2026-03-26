# Rewrite Quality Audit

The rewrite is the right time to fix modeling and implementation problems,
not just translate them into nicer syntax. This document catalogues every
issue found, organized by severity.

---

## ASDL Modeling Issues

### Critical: fix before rewrite

#### 1. `Editor.Project.assets` is typed as `Authored.AssetBank`
**File:** `schema/Editor.asdl.module.txt`

Editor types should not depend on Authored types for fields. The asset bank
is constructed at the Editor level and lowered into Authored. Either:
- create `Editor.AssetBank` with the same shape, or
- keep `Authored.AssetBank` as a shared cross-phase data type (but then it
  should live in a shared module, not in Authored)

The current design leaks the Authored phase into Editor's type surface.

#### 2. `Editor.NativeDeviceBody.kind` is typed as `Authored.NodeKind`
**File:** `schema/Editor.asdl.module.txt`

Same problem: Editor directly references Authored's sum type. This means
Editor depends on Authored's type system, which inverts the phase ordering.
Options:
- create `Editor.DeviceKind` as an Editor-native enum that lowers to `Authored.NodeKind`
- accept `Authored.NodeKind` as a shared type and document that decision explicitly
- keep it but move `NodeKind` to a shared module

The second option is probably fine if documented as a deliberate cross-phase
sharing decision, since NodeKind is genuinely the same algebra at both layers.

#### 3. `Resolved.Track` has dead index fields
**File:** `schema/Resolved.asdl.module.txt`

`first_clip`, `clip_count`, `first_slot`, `slot_count`, `first_send`,
`send_count` — these were designed for a flat project-global table layout.
But with the `TrackSlice` redesign, clips/slots/sends are owned locally by
the slice. These fields are set but never meaningfully consumed downstream.
Either remove them or document what they index into.

#### 4. `Resolved.Track.volume_param_index` / `pan_param_index` are confusing
**File:** `schema/Resolved.asdl.module.txt`

These are indices into the TrackSlice's `mixer_params` list, but that
relationship is implicit. Consider removing them in favor of the TrackSlice
directly owning named volume/pan params (similar to how Editor.Track has
explicit `volume` and `pan` fields).

#### 5. `Scheduled.Step` is defined but unused
**File:** `schema/Scheduled.asdl.module.txt`

`Step` was part of the old job-based execution model. With the leaf program
redesign, execution ordering is now implicit in the program composition.
Remove it unless there's a concrete plan to use it.

#### 6. `Scheduled.GraphPlan` still uses `first_node_job` / `node_job_count`
**File:** `schema/Scheduled.asdl.module.txt`

These were indices into a flat job array. With `NodeProgram` as explicit
leaf programs, they are redundant with `GraphProgram.node_programs` list
length. Either remove them or rename to reflect what they actually index.

#### 7. `Kernel.Buffers` and `Kernel.State` are speculative
**File:** `schema/Kernel.asdl.module.txt`

These carry `TerraType` fields for planned but unimplemented runtime state
decomposition (mono_t, stereo_t, event_t, bus_array_t, transport_t,
control_t, dsp_t, launcher_t, voice_t, render_t). Currently constructed
with `tuple()` everywhere. Either implement them or remove them and add
them back when they're real.

#### 8. `Kernel.API` is speculative
**File:** `schema/Kernel.asdl.module.txt`

17 `TerraFunc` fields for a rich runtime API that doesn't exist yet. All
are constructed as no-op functions. Either design and implement this
properly, or remove it and expose only `entry` on `Kernel.Project` until
the API surface is real.

### Important: should fix during rewrite

#### 9. `Authored.Wire` uses `from_port` / `to_port` as numbers
Port identity is an integer index into the node's input/output lists. This
works but is fragile — reordering ports silently breaks wires. Consider
whether port identity should be by name or by stable id instead.

#### 10. Duplication between Editor and Authored enums
`Quantize`, `InterpMode`, `CombineMode`, `Smoothing`, `FadeCurve`,
`PortHint`, `LaunchMode`, `FollowKind`, `SlotContent`, `SplitKind`,
`NoteExprKind` — all have identical definitions in both Editor and Authored.
The lowering is 1:1 name mapping. Consider:
- shared enums in a common module, or
- Editor using Authored enums directly (like it already does with NodeKind)

The current state requires ~12 mapping functions in `impl/_support/fallbacks.t`
that do nothing but map identical names across phases.

#### 11. `Resolved.Node` carries `x_pos` / `y_pos` and `arg0..arg3`
`x_pos` / `y_pos` are editor/view presentation state that leaked into a
runtime-facing phase. They should be dropped during resolve.

`arg0..arg3` are an opaque grab-bag. They carry node-kind-specific data
but their meaning varies per kind_code with no type safety. This is
acceptable as a runtime encoding if documented, but the doc should state
exactly what each arg means per kind.

#### 12. View schema is very large (~2000 lines) but mostly structural
The View module is the largest schema module. Most of it is legitimate
structural surface, but review whether:
- some types are pure presentation that don't need ASDL modeling
- the anchor/command typed refs are earning their weight
- DetailPanel subtypes justify their complexity

---

## Implementation Issues

### Critical: fix before rewrite

#### 13. `impl/classified/project.t` is 977 lines — too large
This single file handles:
- graph slice scheduling
- track slice scheduling
- project scheduling
- all leaf program builders (node, mod, clip, send, mix, output)
- all ops scheduling (init, block, sample, event, voice)
- param/binding/literal scheduling

It should be split into separate modules per concern. The leaf program
builders alone are ~300 lines and belong in their own files.

#### 14. `impl/scheduled/project.t` is 542 lines — graph and track compile are coupled
`compile_graph_program` and `compile_track_program` and `compile_project`
are all in one file. They share some helpers (`emit_runtime_ops`,
`eval_tick_to_sample`, slot counting) but the compile logic per level is
independent. Split into separate files per compile boundary.

#### 15. `impl/resolved/project.t` handles both classify and its own phase
497 lines mixing classify_graph_slice, classify_track_slice,
classify_project, and all the internal classification helpers. Despite
the filename suggesting "resolved", it installs methods on
`Resolved.GraphSlice:classify()` etc. The file is misnamed and overloaded.

#### 16. Leaf program compile functions have identical boilerplate
All six leaf program compilers (`node_program.t`, `mod_program.t`,
`clip_program.t`, `send_program.t`, `mix_program.t`, `output_program.t`)
follow the exact same pattern:
1. Create symbols for bufs, frames, and 5 slot arrays
2. Build a ctx table
3. Call the private compiler helper
4. Wrap in a terra function
5. Return `Kernel.Unit(fn, tuple())`

This should be a shared helper that takes the compiler function and self,
not 6 copies of the same 60-line template.

#### 17. `state_t` still needs deeper application at leaf granularity
Historical audit note: at the time of this review, every `Kernel.Unit`
returned `tuple()` as `state_t`. That meant the function did not yet own a
real state ABI and all runtime state effectively lived in local scratch
arrays inside the generated function.

This is being corrected by moving toward canonical `{ fn, state_t }`
products throughout the runtime. The remaining architectural gap is at
leaf granularity: stateful leaf units should return real `state_t`s of
their own, and parent programs should compose those child state types
structurally. The end state is: state is compiled, not managed.

### Important: should fix during rewrite

#### 18. `impl/authored/graph.t` resolve rebuilds everything from scratch
The resolve function allocates fresh state tables and walks the entire graph.
No per-node memoization. If one node's params change, the entire graph
slice is recomputed. This is mitigated by the later leaf-level memoize we
added, but the resolve phase itself could benefit from finer granularity.

#### 19. All 5 rate-slot arrays passed to every leaf function
Every leaf compile function signature is:
```
fn(bufs, frames, init_slots, block_slots, sample_slots, event_slots, voice_slots)
```
Most leaves use at most 1-2 of these. The others are dead arguments.
Consider whether leaf functions should declare which slot arrays they
actually need, or whether the 7-argument convention is acceptable overhead.

#### 20. `build_node_program_impl` uses massive varargs
The memoize-keyed builder uses `unpack(args)` with potentially dozens of
primitive arguments. This is correct for memoize correctness, but the
readability and maintainability is poor. Consider whether a hash-based key
or a structured key object would be clearer.

#### 21. Fallback constructors are 800+ lines of repetitive code
`impl/_support/fallbacks.t` has one function per type across all phases.
Many are identical patterns (empty lists, zero ids, default values).
The schema DSL could potentially generate most of these from field defaults
and type structure.

#### 22. `impl/editor/device.t` has deeply nested container lowering
255 lines of device lowering with 5 device kinds, each with its own
container layout. The pattern is repetitive but not identical.
Consider whether a table-driven approach would be cleaner.

### Minor: fix if convenient

#### 23. `impl/editor/clip.t` note asset extraction is duplicated
The clip lower extracts note assets, and `impl/editor/project.t` also
collects note assets separately. The extraction logic exists in two places.

#### 24. Several `impl/` files still reference `D` directly
After the rewrite, method bodies should access schema types through
a clean import, not through a module-level `require("daw-unified")`.
This is a mechanical cleanup but needs to happen everywhere.

---

## Naming Issues

#### 25. Phase numbering inconsistency
Comments say View is "Phase 1" but the pipeline ordering in various docs
is inconsistent about whether View is phase 1 or sits alongside phase 0.
Clarify: is View a numbered phase in the pipeline, or a parallel
projection? The schema should be definitive.

#### 26. `Classified.Binding:schedule()` is a confusing method name
A `Binding` "scheduling" itself sounds wrong. It's really just converting
a classified binding into a scheduled binding (same data, different module).
Consider renaming to something like `to_scheduled()` or just making it
a shared type.

#### 27. `GraphPlan` / `TrackPlan` naming
These are really just "the flat metadata header for a scheduled graph/track."
The "Plan" suffix implies planning/intent, but they're data records.
Consider `GraphHeader` or `GraphMeta` or just folding these fields into
the parent program.

---

## Architectural Gaps

#### 28. No real voice/polyphony model
The schema has voice-related fields (`per_voice`, `voice_ops`, `voice_slots`)
but no actual voice allocation, note assignment, or per-voice state.
This is the biggest semantic gap for a real DAW.

#### 29. No real clip playback
Clips are modeled but clip compilation produces silence or trivial output.
The whole clip→note→voice→DSP path is unimplemented.

#### 30. No real plugin hosting
`VSTPlugin` / `CLAPPlugin` variants exist but `PluginHandle` is opaque
with no loading, parameter discovery, or audio processing implementation.

#### 31. No real audio I/O routing
Track input routing is modeled but not compiled. Sends are modeled but
send routing between tracks is not implemented in the compile phase.

---

## Recommendation

**For the rewrite, fix items 1-8 and 13-16 at minimum.** These are modeling
errors and structural problems that will be cheaper to fix now than after
the new schema is written.

Items 10 and 21 may partially solve themselves through schema DSL features
(shared types, generated fallbacks from field defaults).

Items 17 and 28-31 are real architectural gaps but represent future work,
not rewrite prerequisites. Document them clearly in the new schema docs
so they're visible as known gaps, not hidden assumptions.

Items 9, 11-12, 18-20, 22-27 are quality improvements worth making during
the rewrite but not blockers.
