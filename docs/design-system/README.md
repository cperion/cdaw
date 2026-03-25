# Terra DAW Design System Docs

This folder contains the visual design-system documentation for Terra DAW.

These docs are about **visual language and product design**, not runtime rendering requirements.

## Reference baseline

The current design-system baseline is:

- **shell baseline:** Bitwig-style macro workspace composition
- **texture baseline:** Ableton-style flatter material restraint
- **sizing baseline:** Ableton-style compact density and control sizing
- **identity layer:** Terra-specific modulation, diagnostics, and semantic editor language

In particular:

- they may use vector/SVG-style terminology to describe shapes clearly
- they do **not** require the UI implementation to render SVG
- they exist to define visual consistency, hierarchy, tokens, and component behavior

---

## Reading Order

### 1. Foundation
- `daw-design-system.md`
  - overall design intent
  - principles
  - foundations
  - state model
  - first component categories

### 2. Tokens
- `design-tokens.md`
  - base tokens
  - semantic tokens
  - component token families
  - modulation / diagnostics / detail-panel tokens
  - track color derivation

### 3. Primitive anatomy
- `visual-primitives.md`
  - button
  - tab
  - knob
  - fader
  - meter
  - toggle
  - input
  - clip block
  - piano key / note block
  - module port / cable
  - modulation overlay / route row
  - diagnostic badge / placeholder panel

### 4. Visual personality
- `style-directions.md`
  - Discipline Dark
  - Modular Dark
  - Terra Pulse
  - recommended hybrid direction

### 5. Screen patterns
- `daw-patterns.md`
  - transport bar
  - browser row
  - track header
  - mixer strip
  - device module card
  - arrangement clip lane
  - piano roll
  - grid patch
  - detail panel
  - diagnostics / placeholder states
  - modulation language

---

## Recommended Working Flow

When evolving the design system, update docs in this order:

1. `daw-design-system.md`
2. `design-tokens.md`
3. `visual-primitives.md`
4. `style-directions.md`
5. `daw-patterns.md`

This keeps the system coherent:

- principles first
- tokens second
- primitives third
- personality fourth
- screen composition last

---

## Current Direction

Current recommended direction:

- **primary personality:** Terra Pulse
- **structural baseline:** Discipline Dark
- **component clarity influence:** Modular Dark

In short:

- calm shell
- clear modular controls
- distinctive active-state language

---

## Scope Reminder

These documents define:

- visual hierarchy
- color behavior
- geometry systems
- component anatomy
- DAW-specific screen patterns

They do not yet define:

- implementation APIs
- rendering architecture
- runtime widget code
- TerraUI integration details
- overall implementation plan: `../implementation-strategy.md`

Those can come later once the visual system is stable.
