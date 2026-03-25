# Terra DAW Design System v0

**Status:** Draft foundation  
**Scope:** Visual design language, tokens, visual primitives, and first component specs  
**Reference DNA:** Ableton Live layout discipline + Bitwig component clarity  
**Shell baseline:** Bitwig-style overall workspace composition; do not reinvent the macro DAW shell where the existing solution is already excellent.
**Implementation stance:** SVG-informed visual system for design reference only; no requirement that the runtime UI be rendered in SVG

---

## 1. Purpose

This document defines the initial visual design system for Terra DAW.

The goal is to establish a coherent, reusable, and implementation-friendly visual language for a modern DAW interface. The design system must support:

- dense professional workflows
- high readability under long sessions
- clear hierarchy across complex panels
- strong consistency between controls
- themeability
- vector-like component anatomy for precision and reuse

This is not a generic app UI system. It is a DAW-specific system.

### 1.1 Reference baseline

To avoid re-guessing solved DAW UX problems, Terra should use a clear reference blend:

- **shell baseline:** Bitwig-style macro workspace composition
- **texture baseline:** Ableton-style flatter material restraint
- **sizing baseline:** Ableton-style compact control sizing and density
- **identity layer:** Terra-specific modulation, diagnostics, semantic depth, and editor language

This means we should borrow proven macro layout and ergonomic sizing where they already work well, then spend originality on the places where Terra is actually different.

---

## 2. Design Intent

### 2.1 Product feeling

The UI should feel:

- precise
- musical
- calm
- fast
- technical but not sterile
- dense but readable
- modern without being trendy

### 2.2 Visual character

The UI should avoid:

- heavy skeuomorphism
- glossy gradients
- consumer-app softness
- decorative color usage
- oversized controls

The UI should emphasize:

- neutral dark surfaces
- compact, disciplined geometry
- restrained contrast hierarchy
- subtle depth
- color as meaning
- crisp SVG shapes

### 2.3 Style direction

Working style direction: **Precision Dark**

Shell-composition stance:

- the macro shell should remain close to Bitwig's proven DAW workspace grammar
- we should innovate in semantic richness and local interaction language, not by
  discarding a strong existing shell arrangement

Precision Dark means:

- charcoal and steel-gray neutral base
- carefully tiered panel surfaces
- controls brighter than chrome
- vivid accent colors used sparingly
- small radii
- thin separators
- minimal shadowing
- high clarity at compact sizes
- texture and materiality closer to Ableton's flatter restraint than to chunkier card-based modular shells
- stronger borders used selectively where semantic grouping, focus, selection, diagnostics, or authored modular identity need help

---

## 3. System Philosophy

### 3.1 SVG-informed visual language, not an implementation constraint

SVG is a useful reference model for defining the core visual language of the DAW, but it is not a requirement for runtime rendering.

Think in clean vector primitives for:

- icons
- buttons
- knobs
- faders
- meters
- tabs
- toggles
- LEDs
- badges
- clip blocks
- device headers
- small graphs and arcs
- focus/selection rings

The actual runtime implementation may use any appropriate rendering path.

This document uses SVG-style geometric thinking only to keep the visual system:

- precise
- consistent
- scalable
- easy to theme
- easy to specify

### 3.2 Core rule

The design system must read correctly in grayscale before color is added.

This ensures the UI hierarchy is structural, not dependent on decoration.

---

## 4. Design Principles

### P1. Structure first
Panel hierarchy, separators, and control grouping must remain legible without semantic color.

### P2. Color is functional
Color is reserved for state, track identity, modulation, transport status, warnings, and selection.

### P3. Controls over chrome
Panels should recede. Interactive controls and active signals should stand out.

### P3A. Flat by default, bordered where meaning benefits
The default shell material should stay relatively flat and restrained.
Stronger borders should be used selectively at meaningful boundaries:

- focused surfaces
- selected objects
- active tabs
- modular/editor cards where grouping matters
- diagnostics / degraded states
- explicit authored objects such as notes, clips, and grid modules

### P4. Density without chaos
Use compact internal spacing, but preserve breathing room between functional groups.

### P5. One geometry system
Radii, spacing, strokes, and control heights should come from a strict shared scale.

### P5A. Use Ableton Live compactness as the baseline sizing reference
For compactness and control sizing, we should bias toward what already works in
Ableton Live rather than guessing from scratch.

That means:

- default control heights should stay in the same compact family as Live
- toolbar, browser, tab, and dense editor sizing should begin from Live-like proportions
- deviations should be intentional and justified by semantic needs, not novelty
- density should feel proven and ergonomic, not experimentally cramped or oversized

### P6. One interaction language
Hover, pressed, selected, focus, disabled, and semantic states should behave consistently everywhere.

### P7. No ornamental complexity
Visual forms should be geometric, minimal, and easy to theme.

### P8. Native surfaces deserve native visual language
Mature DAW surfaces should not be treated as generic panels with controls dropped in.
Arrangement, launcher, mixer, device editing, grid patching, piano roll, browser,
inspector, and diagnostics should each have a distinct but system-aligned visual grammar.

### P9. Degraded states are part of the product
The product is intentionally designed to support partial implementation and local
fallbacks. Error badges, placeholder panels, and degraded-but-valid views are part of
the design system, not accidental temporary artifacts.

---

## 5. Foundations

### 5.1 Grid and spacing

Use a **4 px base grid** with small intermediate values for dense controls.

| Token | Value |
|---|---:|
| `space.0` | 0 |
| `space.1` | 2 |
| `space.2` | 4 |
| `space.3` | 6 |
| `space.4` | 8 |
| `space.5` | 12 |
| `space.6` | 16 |
| `space.7` | 20 |
| `space.8` | 24 |

#### Usage guidance

- `2-4 px`: micro gaps inside dense controls
- `6-8 px`: standard control padding
- `12 px`: spacing between related control groups
- `16-24 px`: spacing between major zones or sections

### 5.2 Control sizes

| Token | Value |
|---|---:|
| `control.xs` | 20 |
| `control.sm` | 24 |
| `control.md` | 28 |
| `control.lg` | 32 |

#### Typical applications

- `20`: compact icon buttons, LEDs, tab rows in dense contexts
- `24`: standard toolbar buttons, browser rows
- `28`: device controls, parameter inputs
- `32`: transport controls, primary action buttons

#### Baseline sizing note

This scale is intentionally close to an Ableton Live-style compact baseline.
Treat it as the default starting point for implementation so we do not have to
re-discover basic DAW ergonomics unnecessarily.

### 5.3 Radius scale

The radius system should remain tight and disciplined.

| Token | Value |
|---|---:|
| `radius.xs` | 3 |
| `radius.sm` | 4 |
| `radius.md` | 6 |
| `radius.lg` | 8 |
| `radius.pill` | 999 |

#### Usage guidance

- `3-4`: dense controls and buttons
- `6`: panels and tab bodies
- `8`: dialogs and overlay surfaces
- pill: badges, capsules, segmented state chips

### 5.4 Stroke scale

| Token | Value |
|---|---:|
| `stroke.hairline` | 1 |
| `stroke.strong` | 1.5 |
| `stroke.heavy` | 2 |

#### Rendering rule

Whenever possible, align strokes and edges to the pixel grid for maximum sharpness.

---

## 6. Color Architecture

Color is organized into three layers:

1. neutral structural tokens
2. semantic state tokens
3. track and clip identity tokens

### 6.1 Neutral surfaces

These tokens define the core tonal hierarchy of the DAW.

| Token | Value | Purpose |
|---|---|---|
| `surface.app` | `#111315` | global application background |
| `surface.panel` | `#171A1E` | standard panel background |
| `surface.panelRaised` | `#1C2126` | slightly lifted panel or active section |
| `surface.panelInset` | `#14171A` | recessed zones |
| `surface.control` | `#232930` | idle control body |
| `surface.controlHover` | `#2A3138` | hover control body |
| `surface.controlPressed` | `#313942` | pressed/active control body |
| `surface.overlay` | `#20252B` | popovers, menus, dialogs |

### 6.2 Borders and separators

| Token | Value | Purpose |
|---|---|---|
| `border.subtle` | `rgba(255,255,255,0.06)` | light panel definition |
| `border.default` | `rgba(255,255,255,0.10)` | standard control border |
| `border.strong` | `rgba(255,255,255,0.16)` | selected or emphasized structure |
| `border.focus` | `#D6A35A` | focus ring or focus stroke |
| `border.separator` | `rgba(255,255,255,0.08)` | section dividers |

### 6.3 Text tokens

| Token | Value | Purpose |
|---|---|---|
| `text.primary` | `#E8EDF2` | primary UI text |
| `text.secondary` | `#AAB4BE` | secondary labels |
| `text.muted` | `#7D8791` | subdued information |
| `text.disabled` | `#5C6670` | disabled labels and values |
| `text.inverse` | `#0E1114` | text on bright semantic fills |

### 6.4 Semantic tokens

| Token | Value | Purpose |
|---|---|---|
| `accent.primary` | `#D6A35A` | selection, focus, and warm active accent |
| `accent.secondary` | `#78B26A` | secondary active accent |
| `state.play` | `#57D17A` | play state |
| `state.record` | `#FF5D5D` | recording state |
| `state.warning` | `#F0B64A` | warning or caution |
| `state.solo` | `#FFD84D` | solo state |
| `state.mute` | `#7F8891` | mute state |
| `state.arm` | `#FF6B6B` | record arm |
| `state.modulation` | `#B184FF` | modulation overlays and assignment |
| `state.clipping` | `#FF3B30` | peak clip warning |

### 6.5 Semantic color usage rules

- red is reserved for record, arm, clipping, and severe error states
- yellow is reserved for solo and warnings
- green is reserved for play and safe signal activity
- purple is reserved for modulation
- warm amber accents are preferred for focus and selection
- blue should be reduced and kept secondary or desaturated when used at all
- large neutral surfaces should remain neutral
- modulation must remain visually distinct from track identity and from ordinary value state
- diagnostics must remain visually distinct from modulation and transport semantics

---

## 7. Track and Clip Color System

Track color is important in a DAW but must remain controlled.

### 7.1 Rule

Track colors should tint local identity surfaces, not dominate the full application background.

### 7.2 Derived track roles

Each track color should generate the following semantic variants:

| Token role | Meaning |
|---|---|
| `track.fillSoft` | low-intensity background tint |
| `track.fillStrong` | stronger clip or header fill |
| `track.border` | border/accent stroke |
| `track.textOn` | readable text color on the track fill |
| `track.dimmed` | muted or de-emphasized track variant |
| `track.selectedRing` | selected state outline or glow |

### 7.3 Typical usage

Track color may appear in:

- track header accent areas
- clip fills or clip headers
- selected device accents
- active lane highlights
- small status or identity strips

Track color should not fill:

- the entire app shell
- all controls within a track
- menus or global chrome

---

## 8. Typography

Typography should feel practical, compact, and extremely legible.

### 8.1 Font size scale

| Token | Value |
|---|---:|
| `font.xs` | 10 |
| `font.sm` | 11 |
| `font.md` | 12 |
| `font.lg` | 13 |

### 8.2 Text roles

| Role | Intended usage |
|---|---|
| `label.xs` | tiny labels in dense controls |
| `label.sm` | standard labels for knobs, tabs, toggles |
| `body.sm` | browser rows, mixer labels |
| `body.md` | dialogs, settings, larger information views |
| `mono.sm` | BPM, dB, Hz, ms, percentages, timecode |

### 8.3 Typography rules

- default text should be compact and crisp
- parameter values should prefer tabular or monospaced numerals when possible
- uppercase labels should be used sparingly and only where hierarchy benefits
- text contrast should communicate role without becoming noisy

---

## 9. State Model

Every interactive component should support a shared state language.

### 9.1 Core states

- `default`
- `hover`
- `pressed`
- `selected`
- `active`
- `focusVisible`
- `disabled`

### 9.2 DAW-specific semantic states

- `armed`
- `muted`
- `soloed`
- `recording`
- `playing`
- `bypassed`
- `modulated`
- `clipping`
- `diagnosticWarning`
- `diagnosticError`
- `activeSurface`
- `multiSelected`

### 9.3 State behavior rules

| State | Visual behavior |
|---|---|
| `hover` | small tonal lift; no dramatic glow |
| `pressed` | darker or inset appearance; immediate response |
| `selected` | border/accent emphasis plus tonal distinction |
| `active` | semantic color or stronger fill depending on control meaning |
| `focusVisible` | explicit crisp ring; never rely on fill alone |
| `disabled` | lower contrast but preserve silhouette and layout |
| `modulated` | show a distinct secondary modulation layer, never confused with the base value display |
| `diagnosticWarning` | local warning marker or strip without collapsing the host surface |
| `diagnosticError` | stronger local warning/error marker while preserving the host surface silhouette |

---

## 10. Depth and Elevation

Depth should be subtle and functional.

### 10.1 Elevation levels

| Token | Meaning |
|---|---|
| `elevation.0` | flat base surface |
| `elevation.1` | panel separation |
| `elevation.2` | overlay or popover |
| `elevation.3` | modal dialog |

### 10.2 Shadow rules

Allowed:

- subtle inset shadow for recessed areas
- very light outer shadow for overlays
- small glow for focus or active semantic emphasis

Avoid:

- large soft card shadows
- heavy depth stacks
- decorative glows
- fake depth used where a crisp semantic border would communicate structure better

---

## 11. Motion

Motion should support precision, not spectacle.

### 11.1 Recommended timing

| Interaction | Timing |
|---|---|
| hover transition | `80-120ms` |
| toggle transition | `100-140ms` |
| modal entry | `140-180ms` |
| press feedback | immediate |

### 11.2 Motion rules

- meters should feel responsive and informative
- transport controls should feel immediate
- easing should remain restrained
- no playful overshoot or bounce

---

## 12. Visual Drawing Rules

### 12.1 Preferred geometry

Use mostly:

- rounded rectangles
- circles
- lines
- arcs
- masks
- clipped fills
- simple path icons

### 12.2 Avoid

- glossy layered gradients
- path-heavy decorative illustration
- neumorphic softness
- inconsistent stroke widths

### 12.3 Shading approach

Prefer:

- flat fills
- subtle tonal steps
- restrained highlights
- minimal gradients only when necessary

### 12.4 Icon rules

Icons should be:

- geometric
- simple
- readable at 16 px
- based on 1.5-2 px visual strokes
- aligned to a shared icon grid

Recommended icon sizes:

- `16 x 16`
- `20 x 20`
- `24 x 24`

---

## 13. Primitive Library

This section defines the core visual primitives from which larger components are built.

### 13.1 Surface primitives

- `Panel`
- `PanelInset`
- `PanelRaised`
- `SectionDivider`
- `StripBackground`

### 13.2 Control primitives

- `ButtonBase`
- `IconButtonBase`
- `ToggleBase`
- `TabBase`
- `InputBase`
- `StepperBase`

### 13.3 Audio-control primitives

- `KnobBase`
- `KnobArc`
- `KnobIndicator`
- `FaderTrack`
- `FaderThumb`
- `MeterBar`
- `PeakMarker`
- `PanDial`

### 13.4 Indicator primitives

- `LED`
- `Badge`
- `StatusDot`
- `FocusRing`
- `SelectionOutline`
- `ClipLight`

### 13.5 Arrangement and clip primitives

- `GridLine`
- `Playhead`
- `LoopBrace`
- `ClipBlock`
- `ResizeHandle`
- `AutomationNode`

### 13.6 Device primitives

- `DeviceHeader`
- `Slot`
- `ModRing`
- `MacroBadge`
- `ModRouteRow`
- `ModTargetHighlight`
- `ModDepthBand`

### 13.7 Piano-roll primitives

- `PianoKey`
- `NoteBlock`
- `VelocityBar`
- `ExprPoint`
- `SelectionRect`

### 13.8 Grid-patch primitives

- `ModuleCard`
- `PortDot`
- `CableStroke`
- `PatchDropMarker`
- `ModuleSelectionOutline`

### 13.9 Diagnostic primitives

- `DiagnosticBadge`
- `DiagnosticStrip`
- `PlaceholderPanel`
- `DegradedStateMarker`

---

## 14. Component Specs

The first version of the design system should fully specify the following components:

1. button
2. tab
3. knob
4. fader
5. meter
6. toggle / LED
7. clip block
8. input field

The subsections below provide v0 implementation guidance for the most important controls.

---

## 15. Button Spec

### 15.1 Variants

- `neutral`
- `accent`
- `ghost`
- `destructive`
- `transport`
- `iconOnly`

### 15.2 Anatomy

- background
- border
- icon and/or label
- focus ring
- optional active indicator

### 15.3 Sizing

| Size | Height | Radius |
|---|---:|---:|
| `xs` | 20 | 3 |
| `sm` | 24 | 4 |
| `md` | 28 | 4 |
| `lg` | 32 | 6 |

### 15.4 State behavior

| State | Fill | Border | Content |
|---|---|---|---|
| default | `surface.control` | `border.default` | `text.primary` |
| hover | `surface.controlHover` | `border.default` | `text.primary` |
| pressed | `surface.controlPressed` | `border.strong` | `text.primary` |
| disabled | subdued | subdued | `text.disabled` |
| focusVisible | unchanged fill | `border.focus` ring | unchanged |

### 15.5 Variant rules

#### Neutral
Standard utility buttons throughout the interface.

#### Accent
Use for selected or emphasized actions, not for every primary action everywhere.

#### Ghost
Low-emphasis control with transparent or near-transparent fill; used inside already-raised surfaces.

#### Destructive
Reserved for delete, clear, or dangerous operations.

#### Transport
Supports semantic play/stop/record states and stronger iconic clarity.

### 15.6 Button rules

- labels should remain short
- icon-only buttons must preserve strong focus visibility
- transport buttons should be visually distinct from utility buttons
- avoid large brightness jumps on hover

---

## 16. Tab Spec

### 16.1 Usage

Tabs are used for:

- browser sections
- editor/detail panel views
- mixer/arranger context switches
- inspector pages

### 16.2 Anatomy

- tab body
- selected body or underline treatment
- label
- optional icon
- optional close badge

### 16.3 State rules

- unselected tabs should recede slightly into the panel
- selected tabs should feel anchored and active
- hover should increase clarity without competing with selection
- selected state may use tonal fill, border emphasis, or accent edge

### 16.4 Layout rules

- minimum width should preserve label readability
- tabs should align to a shared row baseline
- the selected tab should visually connect to the panel it controls

---

## 17. Knob Spec

The knob is one of the signature controls of the DAW.

### 17.1 Variants

- `small`
- `medium`
- `large`
- `bipolar`
- `unipolar`
- `stepped`
- `modulated`

### 17.2 Suggested sizes

| Size | Diameter |
|---|---:|
| `sm` | 20 |
| `md` | 28 |
| `lg` | 36 |
| `xl` | 48 |

### 17.3 Anatomy

- outer body
- inner cap or face
- indicator line or notch
- track arc
- value arc
- optional modulation arc
- optional focus ring
- optional value label

### 17.4 Visual rules

- the body should remain mostly neutral
- value should be communicated by the indicator and arc
- modulation should always be visually distinct from value
- bipolar knobs should have a visible center reference
- stepped knobs should communicate discrete positions clearly

### 17.5 Arc conventions

#### Unipolar
- start around lower-left
- end around lower-right
- value arc sweeps in one direction

#### Bipolar
- center reference at top or top-center
- negative and positive sides should mirror cleanly
- zero position must be instantly readable

### 17.6 Color rules

- arc track: subdued neutral
- value arc: accent or control-specific semantic color
- modulation arc: `state.modulation`
- disabled knob: preserve form but remove emphasis

### 17.7 Interaction rules

- hover may brighten indicator and arc slightly
- focus ring should not obscure the arc
- selected state should not turn the whole knob into a glowing disk

---

## 18. Fader Spec

### 18.1 Variants

- vertical volume fader
- vertical send fader
- horizontal parameter fader
- bipolar horizontal fader

### 18.2 Anatomy

- track
- filled value region
- thumb
- thumb highlight or grip
- optional scale line
- optional automation/mod overlay

### 18.3 Suggested dimensions

| Variant | Track thickness | Thumb size |
|---|---:|---:|
| compact | 4 | 10-12 |
| standard | 6 | 12-14 |
| mixer | 8 | 14-16 |

### 18.4 Visual rules

- the track should stay visually quiet
- the thumb must be easy to target and read
- the current value should be clear even at a glance
- selection should be communicated by thumb/border/focus treatment rather than excessive glow

### 18.5 Semantic overlays

Possible overlays:

- automation lane relation
- modulation amount band
- current touch/write state
- clip or warning state for mixer controls

---

## 19. Meter Spec

Meters are high-frequency readouts and need strong visual hierarchy.

### 19.1 Variants

- mono vertical
- stereo vertical
- mono horizontal
- compact slot meter

### 19.2 Anatomy

- meter background track
- live level fill
- peak hold marker
- clip indicator cap
- optional ruler marks

### 19.3 Color strategies

Two valid styles are supported.

#### Strategy A: classic semantic ramp
- low-mid range: green
- upper range: yellow
- clip range: red

#### Strategy B: modern restrained ramp
- most of the range: neutral or accent-tinted fill
- warning zone: yellow
- clip zone: red

For Precision Dark, Strategy B is preferred unless a more traditional mixer style is desired.

### 19.4 Meter rules

- peak hold must remain readable but not overpower live level
- clipping must be unmistakable
- stereo pairs should read as a unit
- compact meters should preserve clip indication even at small sizes

---

## 20. Toggle and LED Spec

### 20.1 Usage

Used for:

- arm
- mute
- solo
- bypass
- power
- monitoring mode
- engagement indicators

### 20.2 Toggle anatomy

- body
- border
- icon/label
- semantic state fill
- focus ring

### 20.3 LED anatomy

- small circular or rounded indicator
- off fill
- on fill
- optional glow

### 20.4 Rules

- LEDs should be used sparingly
- mute, solo, and arm must remain distinguishable by both color and label/icon context
- semantic color alone should never be the only cue

---

## 21. Clip Block Spec

### 21.1 Anatomy

- block fill
- label region
- border
- selected outline
- muted overlay
- loop indicator
- resize handles

### 21.2 Rules

- clip fill should be a controlled track-derived tint
- text must remain readable on the clip fill
- selected clips should be easy to distinguish without overwhelming neighboring clips
- muted clips should remain visible but clearly subdued

---

## 22. Input and Numeric Field Spec

### 22.1 Usage

Used for:

- BPM
- dB
- Hz
- ms
- percentages
- transport positions
- numerical device parameters

### 22.2 Anatomy

- background
- border
- value text
- optional prefix/suffix
- optional stepper affordance
- focus ring

### 22.3 Rules

- values should prefer tabular numerals
- editing and display states should remain visually consistent
- suffixes like `dB`, `Hz`, `%`, `ms` should be legible but secondary

---

## 23. Region Surface Roles

The DAW uses a Bitwig/Live-inspired layout and needs clear surface role assignment.

### 23.1 Primary regions

- top transport bar
- browser panel
- track header column
- arrangement area
- launcher area
- mixer panel
- detail panel
  - device chain detail
  - focused device detail
  - grid patch detail
  - piano-roll detail
- inspector panel
- overlays and dialogs

### 23.2 Hierarchy rules

- app background is darkest
- large panels sit one step above the app background
- inset regions sit one step below their parent where needed
- controls sit brighter than their parent panel
- overlays use the strongest separation
- the detail panel should read as an attached editor region, not a floating card
- active surfaces should be distinguishable by focus treatment, not by loud shell recoloring
- diagnostics should layer on top of region identity without destroying the base structure

---

## 24. Token Naming Conventions

The system should use layered token naming.

### 24.1 Base tokens

Examples:

- `space.4`
- `radius.sm`
- `font.sm`
- `stroke.hairline`

### 24.2 Semantic tokens

Examples:

- `surface.panel`
- `surface.control.hover`
- `text.primary`
- `border.subtle`
- `focus.ring`

### 24.3 Component tokens

Examples:

- `button.neutral.bg.default`
- `button.neutral.bg.hover`
- `button.transport.play.active`
- `knob.arc.track`
- `knob.arc.value`
- `knob.arc.modulation`
- `meter.fill.clip`
- `clip.selected.border`

This structure supports theme overrides without losing semantic clarity.

---

## 25. Accessibility and Readability Notes

Even in a dense pro interface, accessibility still matters.

### Requirements

- focused controls must have a clear visible focus state
- text hierarchy must not depend on color alone
- arm, mute, solo, and clip states should not rely on color alone
- disabled state should remain structurally readable
- selected elements should remain discernible under alternate themes

---

## 26. Implementation Guidance

### 26.1 Suggested layering

1. raw/base tokens
2. semantic tokens
3. component tokens
4. visual primitives
5. composite controls
6. screen patterns

### 26.2 Good first implementation targets

Build and validate these components first:

1. `ButtonBase`
2. `TabBase`
3. `KnobBase`
4. `FaderTrack` + `FaderThumb`
5. `MeterBar`
6. `ToggleBase`
7. `NoteBlock`
8. `PianoKey`
9. `ModuleCard` / `PortDot` / `CableStroke`
10. `DiagnosticBadge` / `PlaceholderPanel`
11. `ModRouteRow` / target highlight primitives

Once these look coherent, the rest of the DAW will inherit that quality.

---

## 27. Immediate Next Steps

The foundational design pass is now broad enough that the next step is not more
foundational invention but consistency checking against the real product ontology.

### Phase A: token and primitive consistency

Verify and refine:

- surface tokens
- border tokens
- text tokens
- semantic state tokens
- modulation and diagnostic tokens
- track color derivation rules
- component token mappings

### Phase B: primitive gallery validation

Validate the primitive families as one coherent system:

- button
- tab
- knob
- fader
- meter
- toggle / LED
- note block / piano key
- module card / port / cable
- modulation overlay / route row
- diagnostic badge / placeholder panel

### Phase C: DAW pattern assembly

Build pattern specs for:

- transport cluster
- track header
- mixer strip
- device module card
- browser row
- clip block
- piano roll
- grid patch
- detail panel
- diagnostics / placeholder states

---

## 28. Summary

Terra DAW should use a vector-informed design system built around:

- disciplined dark neutral surfaces
- compact professional geometry
- functional color semantics
- minimal but clear state changes
- reusable primitives for DAW-specific controls

The immediate objective is not merely to style a few controls. It is to lock the visual grammar for the real semantic product surfaces:

- tokens
- geometry
- states
- primitive anatomy
- color meaning
- detail-panel hierarchy
- piano-roll language
- grid-patch language
- diagnostics / degraded-state language

Once those are stable, full DAW surfaces can be implemented with far less friction and much stronger consistency.
