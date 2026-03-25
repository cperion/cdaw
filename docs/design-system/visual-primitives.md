# Terra DAW Visual Primitives v0.1

**Status:** Draft  
**Depends on:** `daw-design-system.md`, `design-tokens.md`  
**Purpose:** Define the visual anatomy, dimensions, and composition rules of the first core DAW components

---

## 1. Important Clarification

This document is a **visual specification**, not a rendering contract.

We are **not** saying that Terra DAW must draw its UI with SVG at runtime.

When this document uses vector-style language such as:

- arc
- ring
- stroke
- fill
- outline
- indicator

it is only to describe the intended visual form clearly.

The purpose of this document is to lock down:

- shape language
- proportions
- hierarchy
- state behavior
- visual consistency

Implementation can later use any rendering path that makes sense.

---

## 2. What a Primitive Means Here

A visual primitive is a reusable visual building block with:

- a stable anatomy
- a fixed relationship to tokens
- a known size or size family
- defined interactive states
- clear rules for how it composes into larger DAW patterns

Examples:

- button
- tab
- knob
- fader
- meter
- toggle
- input field
- clip block

---

## 3. Shared Geometry Rules

These rules apply across all primitives.

### 3.1 Base grid

Use a **4 px primary grid** with `2 px` micro-adjustments where dense alignment requires it.

### 3.2 Pixel discipline

- align edges as cleanly as possible
- keep line weights consistent
- avoid accidental half-pixel softness unless intentionally required
- icons and control bodies should sit on repeatable geometry, not optical guesswork

### 3.3 Corner discipline

Use only the shared radii from the token system.

- compact controls: `radius.xs` or `radius.sm`
- panels/tabs: `radius.md`
- overlays/dialogs: `radius.lg`

### 3.4 Contrast discipline

Hierarchy should come from:

1. size
2. value contrast
3. border strength
4. semantic color

in that order.

---

## 4. Shared State Rules

Every interactive primitive should support the same visual state logic.

| State | Visual effect |
|---|---|
| `default` | normal neutral appearance |
| `hover` | slight contrast lift |
| `pressed` | darker or inset feel |
| `selected` | stronger border or accent emphasis |
| `active` | semantic activation if applicable |
| `focusVisible` | explicit ring or outline |
| `disabled` | reduced contrast, preserved silhouette |

### 4.1 State priorities

If multiple states overlap, use this priority order:

1. `disabled`
2. `focusVisible`
3. semantic active state
4. `pressed`
5. `hover`

### 4.2 Focus rule

Focus should be clearly visible but thin and controlled.

Do not solve focus by simply brightening the entire control.

---

## 5. Primitive 1: Button

Buttons are utility controls, transport controls, and action triggers.

### 5.1 Variants

- neutral
- accent
- ghost
- destructive
- transport
- icon-only

### 5.2 Anatomy

A button consists of:

1. body
2. border
3. content area
4. icon and/or label
5. focus ring
6. optional active state overlay

### 5.3 Size table

| Size | Height | Horizontal padding | Radius |
|---|---:|---:|---:|
| `xs` | 20 | 6 | 3 |
| `sm` | 24 | 8 | 4 |
| `md` | 28 | 10 | 4 |
| `lg` | 32 | 12 | 6 |

### 5.4 Layout rules

- icon-only buttons should be square by default
- icon + label buttons should keep a `4-6 px` gap between icon and label
- labels should be vertically centered optically, not just mathematically
- button content should not feel top-heavy

### 5.5 Visual rules

- body should be cleaner than panels but quieter than alerts
- border should remain subtle until selected or pressed
- accent buttons should be used sparingly
- transport buttons may have a stronger identity than neutral buttons

### 5.6 State behavior

#### Neutral button
- default: neutral control body
- hover: slightly lighter body
- pressed: darker or inset body with stronger border
- focusVisible: crisp accent ring
- disabled: muted label and border, body still visible

#### Transport button
- play active: green semantic fill or icon emphasis
- record active: red semantic fill or icon emphasis
- stop active: strong neutral/high-contrast state

### 5.7 Red lines

- do not use oversized radii
- do not make hover glowy
- do not make all buttons accent-colored

---

## 6. Primitive 2: Tab

Tabs change context inside a bounded region.

### 6.1 Typical use

- browser category switching
- detail panel switching
- inspector sections
- view mode switching

### 6.2 Anatomy

1. tab body
2. selected treatment
3. label
4. optional icon
5. optional close affordance

### 6.3 Sizing

| Token role | Value |
|---|---:|
| tab height compact | 22 |
| tab height standard | 24 |
| tab min width | 64 |
| tab horizontal padding | 8 |

These tab sizes should stay close to a proven Ableton Live-style compact range.
Do not upscale them casually.

### 6.4 Visual rules

- tabs should sit as a family on a common strip
- unselected tabs should recede slightly
- selected tabs must feel anchored to the content below
- selected treatment can be a fill shift, border reinforcement, or accent edge
- avoid browser-like loud underlines unless the whole system adopts that style consistently

### 6.5 Red lines

- do not make tab rows look like segmented consumer controls
- do not let hover outshine selected state

---

## 7. Primitive 3: Knob

The knob is one of the most important DAW primitives and should become part of the product identity.

### 7.1 Variants

- small
- medium
- large
- unipolar
- bipolar
- stepped
- modulation-enabled

### 7.2 Diameter table

| Size | Diameter | Typical usage |
|---|---:|---|
| `sm` | 20 | dense mixer/device rows |
| `md` | 28 | standard device parameters |
| `lg` | 36 | macros, sends, high-importance controls |
| `xl` | 48 | hero macro or performance control |

The `sm` and `md` ranges should remain the normal default, matching the compact
DAW ergonomics that Live demonstrates well.

### 7.3 Anatomy

1. outer body
2. face/cap
3. indicator notch or line
4. track arc
5. value arc
6. optional modulation arc
7. optional center mark
8. optional focus ring
9. label/value pairing outside the knob

### 7.4 Core proportion rules

- the body should remain visually compact, not bulky
- the indicator should be readable instantly at all sizes
- the track arc should be secondary to the value arc
- the modulation arc must never be confused with the value arc

### 7.5 Arc behavior

#### Unipolar
- sweep should feel continuous and clean
- start and end angles should leave visual breathing room at the bottom

#### Bipolar
- center position must be instantly obvious
- negative and positive directions must mirror cleanly
- the center mark must be stronger than a normal tick

### 7.6 Labeling rules

- labels should sit below by default in dense device rows
- values may appear below or inline depending on the panel pattern
- do not put long text inside the knob body

### 7.7 Visual rules

- the knob body should stay neutral
- color belongs mostly in the arc and semantic overlays
- hover should emphasize indicator readability, not flood the whole knob with light
- selected state should use controlled edge/focus treatment

### 7.8 Red lines

- no glossy 3D knob shading
- no oversized LED-ring aesthetic unless explicitly reserved for one advanced feature family
- no confusing overlap between modulation and value colors

---

## 8. Primitive 4: Fader

Faders communicate linear values and are especially important in mixer contexts.

### 8.1 Variants

- vertical mixer fader
- vertical send fader
- horizontal parameter fader
- bipolar horizontal fader

### 8.2 Anatomy

1. track
2. fill or active region
3. thumb
4. thumb highlight/grip
5. optional center line
6. optional modulation/automation overlay
7. optional scale marks

### 8.3 Suggested dimensions

| Variant | Track thickness | Thumb cross-size |
|---|---:|---:|
| compact | 4 | 10-12 |
| standard | 6 | 12-14 |
| mixer | 8 | 14-16 |

### 8.4 Layout rules

- the thumb must remain easy to see against the track
- the active value should be recognizable from medium zoom distance
- mixer faders can tolerate slightly stronger contrast than device sliders

### 8.5 Bipolar fader rules

- zero position must be explicit
- negative and positive sides should feel symmetric
- modulation bands should not erase the center reference

### 8.6 Red lines

- do not make the whole track bright
- do not make the thumb too flat to target
- do not rely only on color to show zero vs non-zero state

---

## 9. Primitive 5: Meter

Meters are high-tempo readouts and need immediate legibility.

### 9.1 Variants

- mono vertical
- stereo vertical
- mono horizontal
- compact slot meter

### 9.2 Anatomy

1. meter well/background
2. live level fill
3. peak hold marker
4. clip indicator
5. optional scale marks
6. optional stereo separation line

### 9.3 Size guidance

| Variant | Min width |
|---|---:|
| compact vertical mono | 6 |
| standard vertical mono | 8 |
| stereo pair total | 16-20 |
| compact horizontal | 32 |

### 9.4 Visual rules

- meters should feel active even in peripheral vision
- clip indication must be unmistakable
- peak hold should be visible but not louder than the live fill
- stereo pairs should read as a matched unit

### 9.5 Preferred color logic

For this DAW, prefer a restrained meter style:

- most of the range uses a controlled base fill
- warning region shifts to yellow/orange
- clip region shifts to red

### 9.6 Red lines

- avoid excessive rainbow ramps unless a classic console style is intentionally chosen
- do not let decorative glow reduce precision

---

## 10. Primitive 6: Toggle

Toggles cover DAW semantic states such as solo, mute, arm, bypass, and power.

### 10.1 Variants

- text toggle
- icon toggle
- compact state toggle
- semantic state button-toggle hybrid

### 10.2 Anatomy

1. body
2. border
3. label or icon
4. semantic active treatment
5. focus ring

### 10.3 Visual rules

- off state should remain clearly interactive
- on state should be stronger in both contrast and semantic meaning
- arm, solo, and mute should be distinguishable by more than color alone
- bypass should feel different from destructive or warning states

### 10.4 Red lines

- do not make all semantic toggles share the same active color
- do not hide inactive toggles too aggressively

---

## 11. Primitive 7: LED / Status Light

LEDs are secondary indicators, not primary interaction surfaces.

### 11.1 Uses

- device enabled state
- signal present
- clip warning
- record-ready detail indicators
- sync or clock status

### 11.2 Anatomy

1. small indicator body
2. off state fill
3. on state fill
4. optional glow halo

### 11.3 Rules

- LEDs should be small and information-dense
- halo should be restrained
- a clipping LED may be stronger than a normal active LED

### 11.4 Red lines

- do not use LEDs where a real toggle/button is needed
- do not make the whole UI sparkle with decorative dots

---

## 12. Primitive 8: Input / Numeric Field

This primitive is critical in music software because exact values matter.

### 12.1 Uses

- BPM
- dB
- Hz
- ms
- percentages
- transport location
- parameter entry

### 12.2 Anatomy

1. field body
2. border
3. value text
4. caret or edit state
5. optional suffix/prefix
6. optional stepper affordance
7. focus ring

### 12.3 Sizing guidance

| Variant | Height | Typical width |
|---|---:|---:|
| compact | 20 | 48-56 |
| standard | 24 | 56-72 |
| parameter | 28 | 64-84 |

### 12.4 Rules

- numbers should be very easy to scan
- suffixes should be secondary but readable
- edit mode should not radically restyle the control
- focus state should be explicit and clean

### 12.5 Red lines

- do not make inputs look like generic web forms
- do not use placeholder-like contrast for actual values

---

## 13. Primitive 9: Clip Block

The clip block is one of the most DAW-specific visuals and must balance identity with readability.

### 13.1 Anatomy

1. clip body
2. track-derived tint
3. label area
4. border
5. selected outline
6. muted overlay
7. loop indicator
8. resize handles

### 13.2 Rules

- track tint should carry identity, not overwhelm text
- selected clips should be easy to spot in dense arrangements
- muted clips should remain visible and placeable
- handles should appear when relevant but not add constant noise

### 13.3 Label rules

- clip name is primary
- optional metadata should remain secondary
- text truncation should preserve readability under dense zoom

### 13.4 Red lines

- do not use fully saturated fills for all clips
- do not rely only on opacity to indicate selection

---

## 13A. Primitive 10: Piano Key

The piano key is not just a list row or button. It is the left-side pitch anchor of
piano-roll editing and must feel precise, repeatable, and readable at many vertical
densities.

### 13A.1 Anatomy

1. key body
2. white/black fill variant
3. hover/pressed overlay
4. active pitch highlight optional
5. label zone optional in expanded scales

### 13A.2 Rules

- white and black keys must remain distinguishable primarily by value, not glow
- octave rhythm must be easy to read quickly
- active or played pitch should be obvious without turning the keyboard into a toy
- narrow heights must still preserve the pitch rhythm

### 13A.3 Red lines

- do not make black keys glossy or beveled
- do not use bright per-key outlines at rest

---

## 13B. Primitive 11: Note Block

The note block is the core piano-roll authored object. It should feel editable,
precise, and musically stable.

### 13B.1 Anatomy

1. note body
2. border
3. selected outline
4. muted/de-emphasized overlay
5. left and right trim affordances
6. optional velocity/expression relation highlight

### 13B.2 Rules

- note length must be visually exact
- selected notes should step forward crisply
- muted notes should remain placeable and editable
- note blocks must remain readable against dense time/pitch grids

### 13B.3 Red lines

- do not make every note heavily saturated
- do not rely on opacity alone for selection

---

## 13C. Primitive 12: Module Port and Cable

Ports and cables define the legibility of the grid patch surface.

### 13C.1 Port anatomy

1. port marker
2. port state fill
3. optional hover/selection ring
4. optional direction cue

### 13C.2 Cable anatomy

1. cable stroke
2. selection emphasis
3. optional modulation/source distinction
4. optional drag-preview state

### 13C.3 Rules

- ports must be targetable without becoming cartoonishly large
- cables must remain readable over dense module arrangements
- selected cables should be more visible through stroke treatment, not glow spam
- source/modulation distinctions should be semantic and consistent

### 13C.4 Red lines

- do not use overly decorative bezier styling
- do not make idle cables brighter than selected modules

---

## 13D. Primitive 13: Modulation Overlay / Route Row

Modulation is one of the main Terra identity opportunities and must have a stable,
non-confusable visual grammar across knobs, faders, rows, and targets.

### 13D.1 Overlay anatomy

1. base value display
2. modulation overlay band/arc
3. target highlight ring or edge
4. optional depth direction cue
5. optional scale relation cue

### 13D.2 Route row anatomy

1. row background
2. modulator identity
3. target identity
4. depth display
5. optional scale indicator
6. selected/hover treatment

### 13D.3 Rules

- modulation must always be visually distinct from the base value layer
- target highlighting should feel precise, not glowy or decorative
- depth should communicate signed or directional meaning when relevant
- route rows should read as signal relationships, not generic list items

### 13D.4 Red lines

- do not reuse the ordinary selection accent for modulation itself
- do not let modulation overlays fully hide the base value control

---

## 13E. Primitive 14: Diagnostic Badge / Placeholder Panel

Diagnostics are part of the product language and need stable visual primitives.

### 13E.1 Diagnostic badge anatomy

1. badge body
2. semantic icon or glyph
3. optional count or compact label

### 13E.2 Placeholder panel anatomy

1. panel shell
2. title
3. explanatory body text
4. optional semantic object label
5. optional action/retry area

### 13E.3 Rules

- warning and error must be distinguishable in grayscale and color
- placeholders should feel calm and structural, not like crashing dialogs
- diagnostics should layer onto a surface without erasing object identity

### 13E.4 Red lines

- do not make every diagnostic state bright red
- do not use placeholders that look like unrelated empty-state marketing cards

---

## 14. Composition Rules

Primitives should compose consistently into higher-order DAW patterns.

### 14.1 Device row

Typical composition:

- section label
- parameter label
- knob or input
- small toggle or button
- status LED if needed

Rule: density is acceptable, but alignment must remain strict.

### 14.2 Mixer strip

Typical composition:

- meter
- inserts/sends
- pan control
- fader
- mute/solo/arm toggles
- track label

Rule: vertical rhythm must stay consistent across all strips.

### 14.3 Transport cluster

Typical composition:

- play/stop/record buttons
- tempo input
- position display
- loop toggle
- metronome toggle

Rule: transport controls may have slightly stronger semantic emphasis than the rest of the shell.

### 14.4 Browser row

Typical composition:

- row background
- icon
- label
- metadata
- hover/selected state

Rule: browser density should not collapse text hierarchy.

### 14.5 Piano-roll lane

Typical composition:

- piano key column
- time/pitch grid
- note blocks
- selection overlay
- velocity or expression lane below

Rule: note objects and timing structure should stay primary; expression remains
secondary until selected.

### 14.6 Grid patch

Typical composition:

- patch background
- module cards
- ports
- cables
- diagnostics / selection overlays

Rule: modular structure should be clear before semantic color is added.

### 14.7 Diagnostic surface

Typical composition:

- host surface
- local badge/strip
- optional placeholder subpanel

Rule: degraded state should remain local and must not visually collapse the rest
of the region.

---

## 15. Alignment Rules by Primitive Family

### 15.1 Circular controls

For knobs and LEDs:

- center precisely
- preserve optical balance between label and control body
- do not let labels drift relative to the center line

### 15.2 Linear controls

For faders and meters:

- use repeatable vertical/horizontal rhythms
- align tracks and labels to a shared strip system
- align clip marks and peak marks consistently across families

### 15.3 Text-bearing controls

For buttons, tabs, and inputs:

- cap height matters more than box math
- text should feel optically centered
- dense labels must not be crushed vertically

---

## 16. Visual QA Checklist

A primitive is ready only if all of the following are true.

### 16.1 Structural QA

- does it read clearly in grayscale?
- does it preserve hierarchy at compact sizes?
- does the selected state remain distinct from hover?
- does disabled preserve silhouette?

### 16.2 Semantic QA

- do record/solo/mute/play states remain unambiguous?
- is modulation distinct from value?
- is clipping unmistakable?

### 16.3 Density QA

- does it still work inside a crowded mixer or device panel?
- does the text remain legible beside neighboring controls?
- does the control add unnecessary visual noise?

### 16.4 Consistency QA

- are radius and border rules respected?
- is focus treatment consistent with the rest of the system?
- is the component using semantic tokens rather than ad hoc styling?

---

## 17. Immediate Next Step

With this document in place, the next useful work is final consistency review of
the primitive set against the real View ontology:

1. **pattern specs**
   - transport bar
   - mixer strip
   - track header
   - browser row
   - device module card
   - piano roll
   - grid patch
   - detail panel
   - diagnostic / placeholder states

2. **style explorations**
   - more Ableton-like
   - more Bitwig-like
   - more original Terra-like

3. **visual boards**
   - sample control families
   - surface hierarchy boards
   - track color behavior boards
   - modulation behavior boards
   - diagnostic state boards

---

## 18. Summary

This document defines the first visual primitives for Terra DAW as a design reference.

It is intentionally implementation-agnostic.

The goal is to make the UI system feel:

- coherent
- precise
- reusable
- dense but readable
- distinctly DAW-native

The key outcome is not "SVG components in code".

The key outcome is a stable visual grammar that can later be implemented with confidence.
