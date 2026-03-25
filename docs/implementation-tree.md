# Terra DAW Implementation Tree

This file is the **feature-completion roadmap** for Terra DAW v3.

For the architectural refactor intent behind the recent ASDL redesign, see:

- `docs/asdl-purity-refactor-plan.md`

It complements the ASDL/method progress tooling:

- `tools/progress.t` answers: **do all declared methods exist, and how complete are their variant families?**
- `docs/implementation-tree.md` answers: **is the DAW actually complete as a product/runtime?**

At the moment, method coverage is effectively complete, but several "real"
methods still implement simplified runtime behavior or only cover a subset of
semantic variants. This checklist tracks the remaining work needed to turn the
current compiler/runtime into a complete DAW.

---

## Tight roadmap

This is the shortest practical path from the current state to a real DAW.
Work in this order unless a dependency forces a detour.

### Phase A — make the scheduler honest

Goal: the `Scheduled` phase becomes the real execution plan, not just a partial
intermediate that `Scheduled.Project:compile()` bypasses with special cases.

- [x] Populate real `clip_jobs`, `mod_jobs`, `send_jobs`, `mix_jobs`, and `output_jobs` in `impl/classified/project.t`
- [x] Make `impl/scheduled/project.t` execute scheduled jobs/steps/plans as the authoritative render path
- [x] Remove ad hoc direct track→master render logic as the primary runtime model
- [x] Add one e2e regression test proving final audio comes from scheduled jobs

### Phase B — make bindings and control rates real

Goal: literals are no longer the only runtime control source.

- [x] Implement non-literal `Scheduled.Binding` rate classes in `impl/scheduled/binding.t`
- [x] Execute `init_ops`, `block_ops`, `sample_ops`, `event_ops`, and `voice_ops`
- [x] Add runtime state/control storage needed by those ops
- [x] Add tests showing time-varying control changes output

### Phase C — restore ASDL-first phase boundaries

Goal: every later phase reads the data it needs from ASDL fields, not hidden
Lua side-channel attachments.

- [x] Move flat clip / slot / send tables onto `Resolved.Project`
- [x] Move clip / slot / send tables onto `Classified.Project`
- [x] Move compile-needed literals / params / mod tables onto `Scheduled.Project`
- [x] Make `Kernel.Project` carry its entry function in ASDL instead of `_render_fn`

### Phase D — make clips real

Goal: arrangement and launcher clips play actual content.

- [ ] Add runtime asset lookup from `AssetBank`
- [ ] Replace placeholder `ClipJob` behavior with real audio clip playback
- [ ] Support gain, fades, offset, reverse, and tick/sample timing
- [ ] Add e2e test for real clip playback

### Phase E — make notes/instruments real

Goal: note clips and live note input can drive instruments through a real event/voice path.

- [ ] Lower/schedule note content into runtime event/voice execution
- [ ] Implement voice allocation and note lifecycle state
- [ ] Make instrument nodes respond to pitch/gate/velocity
- [ ] Add e2e test from note clip to audible pitch output

### Phase F — make launcher + transport real

Goal: session workflow behaves like a DAW, not just a static graph renderer.

- [ ] Implement launcher/scene runtime state and quantized triggering
- [ ] Implement runtime transport play/stop/seek/loop/position
- [ ] Fill in the launcher/transport parts of `Kernel.API`
- [ ] Add tests for quantized launch and loop behavior

### Phase G — make the app a DAW, not just a compiler demo

Goal: editing, UI projection, persistence, and runtime control all connect.

- [ ] Expand `app/session.t` to cover the main Editor command families
- [ ] Derive `View.Root` from real `Editor.Project + session state`
- [ ] Route UI actions back into typed Editor commands
- [ ] Implement save/load for `Editor.Project`
- [ ] Fill in the remaining `Kernel.API` control/query functions
- [ ] Add plugin/runtime integration after the core DAW loop is solid

### Immediate next slice

Current immediate focus after the slice/program/unit refactor:

- [x] remove remaining non-schema public helper methods on raw scheduled job/data records where they are no longer needed
- [ ] deepen `Kernel.API` beyond the render entry surface
- [x] rewrite View `to_decl()` boundaries to the same no-opaque-ctx purity rule

---

## 0. Current verified baseline

These are already present and should stay green while deeper work lands.

- [x] Full 7-phase ASDL pipeline exists
- [x] Editor → Authored lowering works end-to-end
- [x] Authored → Resolved flattening works end-to-end
- [x] Resolved → Classified binding/literal classification works for static values
- [x] Classified → Scheduled scheduling works for basic node/track execution
- [x] Scheduled → Kernel compilation produces callable Terra render functions
- [x] Public phase boundaries are pure/no-opaque-ctx through `View → TerraUI` and `Scheduled → Kernel`
- [x] ASDL surface now models reusable late-phase slices/programs (`TrackSlice`, `GraphSlice`, `TrackProgram`, `GraphProgram`, `Kernel.Unit`)
- [x] Core compiler pipeline implementations now match the redesigned slice/program/unit ASDL surface
- [x] View `to_decl()` boundaries now follow the same no-opaque-ctx rule
- [x] First audible output works (`tests/first_sound.t`)
- [x] SDL audio demo plays compiled output (`app/demo_audio.t`)
- [x] Basic session compile / play / undo / redo loop exists (`app/session.t`)
- [x] Broad View → TerraUI lowering exists for shell/workspace surfaces
- [x] Method-level progress tool is green (`tools/progress.t`)
- [x] Variant-level progress axis exists in `tools/progress.t`

---

## 1. Roadmap honesty and completion tracking

The first task is to keep implementation truth visible. The repo already knows
that methods exist; it now needs a durable checklist for feature depth.

- [x] Add `docs/implementation-tree.md`
- [ ] Keep this file updated whenever runtime feature depth changes
- [ ] Add a short note in progress/docs that **method-complete != DAW-complete**
- [ ] Add feature-level milestones to CI/test habit, not just method-level checks
- [ ] Add dedicated regression tests for each major runtime vertical slice below

### 1.1 Runtime depth audit

- [ ] Audit `impl/scheduled/binding.t` against all rate classes
- [ ] Audit `impl/scheduled/mod_job.t` against real modulation requirements
- [ ] Audit `impl/scheduled/clip_job.t` against real clip playback requirements
- [ ] Audit `impl/classified/project.t` job population against Scheduled schema surface
- [ ] Audit `impl/scheduled/project.t` for ad hoc behavior that should move into job compilation
- [ ] Audit `Kernel.API` implementation depth against `schema/Kernel.asdl.module.txt`

---

## 2. Milestone: honest scheduler

Goal: make the **Scheduled** phase the true source of runtime behavior instead
of relying on special-case logic in `Scheduled.Project:compile`.

### 2.1 Classified → Scheduled job population

Target file: `impl/classified/project.t`

- [x] Populate `Scheduled.ClipJob* clip_jobs`
- [x] Populate `Scheduled.ModJob* mod_jobs`
- [x] Populate `Scheduled.SendJob* send_jobs`
- [x] Populate `Scheduled.MixJob* mix_jobs`
- [x] Populate `Scheduled.OutputJob* output_jobs`
- [x] Build `Step` records that reference real clip/mod/send/mix/output jobs
- [x] Schedule per-track output through `OutputJob` rather than ad hoc master writes
- [x] Schedule send routing through `SendJob`
- [x] Schedule intermediate mixes through `MixJob`
- [ ] Preserve graph/node ordering invariants while expanding job coverage
- [ ] Add multi-track scheduling tests with non-trivial job lists

### 2.2 Scheduled → Kernel render execution from jobs

Target file: `impl/scheduled/project.t`

- [x] Remove direct special-case “fill work buffer with DC 1.0” from main render path
- [x] Remove direct special-case track→master mixing from main render path
- [ ] Remove direct special-case master copy logic as the primary execution model
- [x] Execute `Step:compile()` / `GraphPlan:compile()` as the authoritative runtime path
- [x] Route track output via scheduled `OutputJob`
- [ ] Ensure render body stays a structural interpreter of scheduled jobs only
- [ ] Keep degraded fallbacks local when a job type is missing/fails
- [x] Add e2e test proving scheduled jobs, not ad hoc render code, produce final output

### 2.3 Track scheduling cleanup

Target files:
- `impl/classified/track.t`
- `impl/scheduled/step.t`
- related tests

- [ ] Make `Classified.Track:schedule()` carry real track plan information needed by job population
- [ ] Ensure step construction mirrors the actual track execution model
- [ ] Add tests for tracks with clips + devices + sends + output jobs together

---

## 3. Milestone: real runtime bindings and control rates

Goal: make non-literal parameter/control flow actually work.

### 3.1 Scheduled bindings

Target file: `impl/scheduled/binding.t`

- [x] Implement `rate_class = init`
- [x] Implement `rate_class = block`
- [x] Implement `rate_class = sample`
- [x] Implement `rate_class = event`
- [x] Implement `rate_class = voice`
- [x] Stop returning hardcoded `0.0f` for all non-literal bindings
- [x] Add per-rate-class tests for scheduled binding value lowering helpers

### 3.2 Runtime state / control storage

Target files:
- `impl/scheduled/project.t`
- `impl/kernel/project.t`
- possibly support modules under `impl/_support/`

- [x] Introduce real runtime storage for control/state slots
- [x] Thread state symbols through compile context cleanly
- [x] Distinguish literal table from mutable runtime control/state memory
- [x] Verify state layout is stable and testable

### 3.3 Scheduled ops execution

Target schema surface:
- `InitOp`
- `BlockOp`
- `SampleOp`
- `EventOp`
- `VoiceOp`

- [x] Compile and execute `init_ops`
- [x] Compile and execute `block_ops`
- [x] Compile and execute `sample_ops`
- [x] Compile and execute `event_ops`
- [x] Compile and execute `voice_ops`
- [x] Add tests where changing ops changes audible/control output over time

---

## 4. Milestone: real modulation engine

Goal: modulation becomes a runtime signal path, not a constant bake-in path.

### 4.1 Mod jobs and output state

Target file: `impl/scheduled/mod_job.t`

- [ ] Allocate/use real modulator output state slots
- [ ] Evaluate modulator outputs at the correct rate
- [ ] Distinguish global modulation from per-voice modulation
- [x] Stop treating modulation as constant-only behavior
- [x] Add tests for time-varying modulation output

### 4.2 Mod routes applied to params

Target files:
- `impl/resolved/mod_slot.t`
- `impl/classified/project.t`
- `impl/scheduled/project.t`
- relevant node compilers

- [x] Apply mod route depth to target params at runtime
- [x] Implement bipolar/unipolar route behavior
- [ ] Implement scale-mod-slot / scale-param behavior
- [x] Ensure base param + modulation composition matches schema intent
- [ ] Add tests for one modulator driving multiple params

### 4.3 First-class modulators

- [x] Make LFO modulation audible on a target param
- [ ] Make ADSR-style modulation affect a target param over time
- [ ] Add regression tests for per-block and per-sample modulation correctness

---

## 5. Milestone: real clip and asset playback

Goal: `ClipJob` reads actual clip/asset content instead of placeholder behavior.

### 5.1 Asset access

Target surfaces:
- `Authored.AssetBank`
- session/runtime asset loading path
- `impl/scheduled/clip_job.t`

- [ ] Define runtime path from `AssetBank` to audio sample access
- [ ] Add asset lookup by `asset_id`
- [ ] Handle missing assets with degraded but valid silence + diagnostics
- [ ] Add tests for asset lookup success/failure boundaries

### 5.2 Audio clip playback

Target file: `impl/scheduled/clip_job.t`

- [ ] Read actual audio content from assets
- [ ] Apply `start_tick` / `end_tick`
- [ ] Apply `source_offset_tick`
- [ ] Apply `reversed`
- [ ] Apply `gain`
- [ ] Apply fade-in shape
- [ ] Apply fade-out shape
- [ ] Integrate playback timing with tempo map / tick→sample conversion
- [ ] Remove placeholder-only behavior from clip job body
- [ ] Add e2e test: arrangement audio clip produces expected samples

### 5.3 Launcher clip playback

- [ ] Make launched slot clips feed `ClipJob` scheduling/runtime
- [ ] Add tests for clip launch starting/stopping real playback

---

## 6. Milestone: note/event/voice engine

Goal: instrument and note-clip workflows become real DAW behavior.

### 6.1 Note content lowering and scheduling

- [ ] Verify note clips lower all necessary note/event information into Authored/Resolved/Classified
- [ ] Schedule note/event work into `event_ops` / `voice_ops`
- [ ] Add tests from piano-roll style note content to runtime event generation

### 6.2 Voice allocation/runtime

- [ ] Implement voice allocation strategy
- [ ] Track note-on / note-off lifecycle
- [ ] Support polyphony limits / stealing policy
- [ ] Keep voice state in runtime/kernel state
- [ ] Add tests for overlapping notes and voice reuse/steal behavior

### 6.3 Instrument runtime behavior

- [ ] Make synth/instrument nodes respond to pitch/gate rather than only static params
- [ ] Make note velocity available to runtime behavior
- [ ] Add regression tests proving note clips change audible pitch and gate

---

## 7. Milestone: launcher and scene runtime

Goal: launcher/session view becomes functionally real.

### 7.1 Kernel launcher API

Target surface: `Kernel.API`

- [ ] Implement `queue_launch_fn`
- [ ] Implement `queue_scene_fn`
- [ ] Implement `stop_track_fn`
- [ ] Thread launcher commands into runtime state changes

### 7.2 Runtime launcher state

- [ ] Track active slot per track
- [ ] Track queued launch state
- [ ] Apply launch quantization at runtime
- [ ] Apply scene launch behavior across tracks
- [ ] Add tests for scene launch changing active clip set

### 7.3 Advanced launcher behavior

- [ ] Implement legato handling
- [ ] Implement retrigger handling
- [ ] Implement follow actions
- [ ] Implement tempo override behavior where specified
- [ ] Add regression tests for these behaviors

---

## 8. Milestone: transport runtime

Goal: transport becomes a real runtime state machine rather than just static metadata.

### 8.1 Runtime transport state

- [ ] Track play/stop state in runtime
- [ ] Track block/sample position
- [ ] Track tick position
- [ ] Implement seek/reposition behavior
- [ ] Expose current position via Kernel API

### 8.2 Looping and tempo

- [ ] Implement loop enable/disable behavior
- [ ] Implement loop start/end handling
- [ ] Ensure tempo map drives tick/sample conversion at runtime
- [ ] Add tests for playback through loop boundaries

### 8.3 Transport kernel API

- [ ] Implement `get_position_fn`
- [ ] Ensure transport-facing commands in app/session can reach runtime cleanly

---

## 9. Milestone: mixer, routing, buses

Goal: mixing/routing becomes DAW-grade rather than minimal stereo summing.

### 9.1 Track routing

- [ ] Implement track→track routing
- [ ] Implement group track routing
- [ ] Implement master track constraints and runtime behavior
- [ ] Add tests for explicit routing topologies

### 9.2 Sends and aux paths

- [ ] Implement pre-fader send behavior
- [ ] Implement post-fader send behavior
- [ ] Support send target track/bus behavior
- [ ] Add tests for send level affecting target path only

### 9.3 Output and metering

- [ ] Implement proper multichannel output behavior where schema requires it
- [ ] Implement `get_peak_fn`
- [ ] Add tests for peak reporting

---

## 10. Milestone: full Kernel API surface

Goal: the runtime is controllable and inspectable as a DAW engine.

### 10.1 Parameter/runtime control API

- [ ] Implement `set_param_fn`
- [ ] Implement `get_param_fn`
- [ ] Implement `get_mod_fn`
- [ ] Define how runtime parameter changes interact with recompilation vs mutable state

### 10.2 Performance/control input API

- [ ] Implement `note_on_fn`
- [ ] Implement `note_off_fn`
- [ ] Implement `poly_pressure_fn`
- [ ] Implement `cc_fn`
- [ ] Implement `pitch_bend_fn`
- [ ] Implement `timbre_fn`
- [ ] Add tests driving runtime via API instead of only static project setup

### 10.3 Lifecycle API

- [ ] Implement `init_fn`
- [ ] Implement `destroy_fn`
- [ ] Ensure runtime state alloc/free boundaries are explicit and testable

---

## 11. Milestone: application command layer

Goal: app/session becomes the semantic command hub for the whole Editor layer.

### 11.1 Session command coverage

Target file: `app/session.t`

- [ ] Add track commands
  - [ ] AddTrack
  - [ ] RemoveTrack
  - [ ] MoveTrack
  - [ ] SetTrackOutput / flags
- [ ] Add device commands
  - [ ] AddDevice
  - [ ] RemoveDevice
  - [ ] MoveDevice
  - [ ] ReplaceDevice
  - [ ] ToggleDeviceEnabled
- [ ] Add container commands
  - [ ] layer container editing
  - [ ] selector container editing
  - [ ] split container editing
  - [ ] grid conversion/editing
- [ ] Add modulation commands
  - [ ] AddModulator
  - [ ] RemoveModulator
  - [ ] SetModulationDepth / scale
- [ ] Add clip/launcher commands
  - [ ] AddClip / RemoveClip / MoveClip / ResizeClip
  - [ ] SetClipGain / fade
  - [ ] SetSlotContent / behavior
  - [ ] AddScene / RemoveScene / SetSceneProperties
- [ ] Add routing commands
  - [ ] AddSend / RemoveSend
  - [ ] SetSendTarget / level / mode
- [ ] Add note/piano-roll commands
  - [ ] AddNote / RemoveNote / MoveNote
  - [ ] ResizeNoteStart / ResizeNoteEnd
  - [ ] SetNoteVelocity / mute
  - [ ] Add/Move/Remove note expression points
  - [ ] Transpose / Quantize notes

### 11.2 Undo/redo semantics

- [ ] Ensure all new commands participate cleanly in undo/redo
- [ ] Add tests for command→undo→redo stability with stable ids preserved

---

## 12. Milestone: live View derivation from Editor + session state

Goal: the View tree becomes live application state projection, not mostly bootstrap/demo content.

### 12.1 View derivation

- [ ] Add a real `Editor.Project + SessionState -> View.Root` derivation path
- [ ] Reduce hardcoded/demo-only bootstrap data in `app/bootstrap.t`
- [ ] Derive names/refs/selection/detail surfaces from actual project contents
- [ ] Add tests that changing Editor state changes View projection deterministically

### 12.2 View command dispatch

- [ ] Route TerraUI actions back into typed View commands
- [ ] Route typed View commands into Editor command mutations in `app/session.t`
- [ ] Add tests for command roundtrip: UI action → Editor mutation → recompile → updated view/audio

### 12.3 Session/UI-local state

- [ ] Persist/use `View.SessionState` for split ratios, tabs, scroll, collapse where needed
- [ ] Keep project semantics out of `View.SessionState`

---

## 13. Milestone: persistence and project I/O

Goal: `Editor.Project` becomes an actual save/load surface.

### 13.1 Project serialization

- [ ] Define serialization format for `Editor.Project`
- [ ] Implement save path
- [ ] Implement load path
- [ ] Ensure stable ids survive roundtrip
- [ ] Add roundtrip tests for representative projects

### 13.2 Asset persistence

- [ ] Persist asset references cleanly
- [ ] Handle missing/moved assets with diagnostics + degraded outputs
- [ ] Add tests for asset reference recovery/failure behavior

### 13.3 Session/workspace persistence

- [ ] Decide what `View.SessionState` is persisted and where
- [ ] Implement workspace/session-state save/load if desired

---

## 14. Milestone: plugin/runtime integration

Goal: hosted plugins become part of the real runtime, not just the schema/model.

### 14.1 Plugin host integration

- [ ] Implement plugin loading/runtime handle management
- [ ] Map plugin params into the parameter/binding system
- [ ] Handle plugin audio I/O in scheduling/compilation
- [ ] Handle plugin failure with local degradation, not whole-engine collapse

### 14.2 Plugin state/presets

- [ ] Persist plugin state where needed
- [ ] Wire preset references to actual load behavior
- [ ] Add tests for plugin presence/absence boundaries

---

## 15. Cross-cutting quality gates

These should be checked continuously while landing the milestones above.

### 15.1 Tests

- [ ] Every new runtime vertical slice gets a focused method-level test
- [ ] Every new runtime vertical slice gets an end-to-end audible/behavioral test
- [ ] Add regression tests for local degraded fallback behavior
- [ ] Add tests for multi-track, multi-job, non-trivial routing graphs

### 15.2 Diagnostics and degraded outputs

- [ ] Ensure failures stay local at method boundaries
- [ ] Ensure missing assets/plugins/modulators degrade to valid outputs + diagnostics
- [ ] Ensure View remains visible via placeholder panels when a subtree fails

### 15.3 Architectural consistency

- [ ] Keep top-level implementation folders mirroring ASDL phases/modules
- [ ] Keep tests mirroring the same phase/type/method structure where practical
- [ ] Avoid adding speculative runtime concepts outside the ASDL model
- [ ] Keep compile-time vs runtime boundaries explicit

---

## 16. Recommended next slice

This is the best immediate next milestone because it unlocks the rest of the runtime cleanly.

- [ ] Make `impl/classified/project.t` populate real `clip_jobs`, `mod_jobs`, `send_jobs`, `mix_jobs`, and `output_jobs`
- [ ] Make `impl/scheduled/project.t` execute those scheduled jobs as the authoritative runtime path
- [ ] Add an end-to-end test proving final audio comes from scheduled jobs rather than direct special-case render logic

Once that is done, move immediately to:

- [ ] real non-literal bindings
- [ ] real modulation
- [ ] real clip playback

---

## Definition of “whole DAW complete enough”

The project should be considered functionally complete when all of the following are true:

- [ ] Arrangement clips can play real audio assets
- [ ] Launcher slots/scenes can launch real content at quantized times
- [ ] Piano-roll/note clips can drive instruments through a real event/voice engine
- [ ] Modulation affects parameters at runtime
- [ ] Sends, routing, grouping, and output mixing behave correctly
- [ ] Transport/play/stop/loop/position are runtime-real
- [ ] Kernel API is callable for performance/control use cases
- [ ] View is derived from real project/session state
- [ ] Editor commands cover normal DAW authoring workflows
- [ ] Projects can be saved and loaded
- [ ] The engine remains locally degradable under failure
