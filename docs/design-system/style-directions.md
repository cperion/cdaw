# Terra DAW Style Directions v0.1

**Status:** Draft  
**Depends on:** `daw-design-system.md`, `design-tokens.md`, `visual-primitives.md`  
**Purpose:** Compare high-level visual personality directions before locking the final design language

---

## 1. Why This Document Exists

At this stage, the system already has:

- a visual foundation
- token logic
- primitive anatomy

What is still open is the **personality layer**.

The layout logic is already strongly informed by Live and Bitwig. That means the product risks feeling too derivative unless we consciously decide:

- how severe or soft the UI should feel
- how much color should appear in the shell
- how much separation should exist between panels and controls
- how technical versus musical the interface should feel

This document defines three candidate style directions:

1. **Discipline Dark** — more Live-leaning
2. **Modular Dark** — more Bitwig-leaning
3. **Terra Pulse** — more original Terra-leaning

The goal is not to pick a perfect final answer immediately.

The goal is to choose a primary direction and maybe borrow selected traits from the others.

---

## 2. Evaluation Criteria

Each direction is evaluated across the same dimensions.

### 2.1 Criteria

- **clarity** — can dense information be parsed quickly?
- **calmness** — does the UI stay workable during long sessions?
- **identity** — does it feel like Terra, not a clone?
- **scalability** — can the system extend cleanly across all DAW surfaces?
- **precision** — does it feel reliable and professional?
- **musicality** — does it feel alive enough for creative work?

---

## 3. Direction A — Discipline Dark

### 3.1 Summary

This direction leans closer to Ableton Live in philosophy.

It is:

- restrained
- utilitarian
- typography-led
- compact
- highly disciplined
- low-ornament

It prioritizes work speed and reduced visual fatigue over expressive personality.

### 3.2 Core visual traits

- very neutral shell
- low-to-medium surface separation
- minimal color usage
- strong dependence on text hierarchy
- compact controls
- very controlled radii
- subtle borders
- almost no decorative light effects

### 3.3 Surface behavior

Panels differ mostly by tone, not by elevation.

- app background and panel surfaces stay close in value
- controls are only slightly brighter than their parent panel
- selected states are visible but not flashy

### 3.4 Color behavior

Color is extremely reserved.

Used mainly for:

- track identity
- recording state
- solo state
- focus
- clipping

Everything else remains mostly grayscale.

### 3.5 Typography feel

- small and dense
- very functional
- low drama
- strong use of alignment and spacing over ornament

### 3.6 Strengths

- excellent for long sessions
- highly professional feeling
- low visual noise
- strong information density
- very scalable across large workflows

### 3.7 Risks

- can feel too austere
- can feel too close to Live if not differentiated carefully
- may under-express modulation, experimentation, and modernity

### 3.8 Best fit areas

This direction works especially well for:

- arranger
- mixer
- browser
- transport
- inspector panels

### 3.9 Primitive implications

#### Buttons
- flatter and quieter
- emphasis through contrast, not glow

#### Knobs
- minimal arc treatment
- strong indicator clarity
- body almost disappears into neutrality

#### Meters
- restrained meter fill with precise clip logic

#### Tabs
- quiet and typographic
- selected state mostly tonal

### 3.10 Keywords

- disciplined
- dry
- precise
- studio
- typographic
- quiet

---

## 4. Direction B — Modular Dark

### 4.1 Summary

This direction leans closer to Bitwig in philosophy.

It is:

- modular
- component-forward
- clearer in panel segmentation
- slightly softer
- more contemporary
- more visually articulated

It still feels professional, but it gives more visual identity to components.

### 4.2 Core visual traits

- stronger panel separation
- slightly more rounded geometry
- controls feel more like discrete modules
- selected and active states are more obvious
- richer accent usage
- moderate visual warmth and softness

### 4.3 Surface behavior

Panels and sub-panels are easier to distinguish.

- shell and panel levels are more clearly tiered
- device sections feel intentionally packaged
- inset/raised surfaces are more legible

### 4.4 Color behavior

Color is still functional, but it is used more generously.

Used for:

- track identity
- modulation
- active devices
- selected regions
- transport states
- meter activity

### 4.5 Typography feel

- still compact
- slightly more spacious than Direction A
- labels and values supported more by surfaces than typography alone

### 4.6 Strengths

- strong component readability
- easier onboarding for complex views
- more distinct than a Live-like minimal shell
- good fit for modular and device-heavy workflows

### 4.7 Risks

- can become too busy if not tightly controlled
- stronger component separation may reduce calmness in dense views
- can drift into generic "modern creative app" if over-softened

### 4.8 Best fit areas

This direction works especially well for:

- device chains
- modulation views
- hybrid panel systems
- browser categories
- clip launcher/session surfaces

### 4.9 Primitive implications

#### Buttons
- more obviously componentized
- slightly clearer body layering

#### Knobs
- stronger body/arc distinction
- modulation overlays read very well

#### Meters
- a bit more vivid and visible in peripheral view

#### Tabs
- stronger selected anchoring
- clearer panel connection

### 4.10 Keywords

- modular
- modern
- articulated
- componentized
- clear
- adaptive

---

## 5. Direction C — Terra Pulse

### 5.1 Summary

This is the most original direction.

It should not become futuristic for its own sake. Instead, it should take the discipline of A and the modular clarity of B, then add a distinct Terra identity.

It is:

- precise but alive
- dark but slightly luminous
- modern without trend-chasing
- musically responsive
- restrained but unmistakably authored

### 5.2 Core visual traits

- neutral shell with selective luminous accents
- stronger identity in active and selected states
- very controlled use of warm focus accents and purple modulation language
- blue should be secondary, desaturated, and rare
- subtle sense of signal flow or pulse in certain control families
- cleaner and more authored device presentation

### 5.3 Surface behavior

The shell remains disciplined, but the interaction layer feels more intentional.

- idle surfaces remain calm
- active elements gain more identity than in Direction A
- panel hierarchy remains strict, but focus and musical state feel more alive

### 5.4 Color behavior

Color remains functional, but selected semantic families become signature cues.

Suggested emphasis:

- warm amber or softened neutral accents for selection and focus
- purple for modulation
- green for play and healthy signal
- red reserved for record/clipping
- blue should be reduced and desaturated, not treated as the primary shell accent
- track colors slightly desaturated compared to a raw rainbow palette

### 5.5 Typography feel

- compact and professional
- not overly austere
- values remain exact and tool-like
- labels can feel a touch more breathable than Direction A

### 5.6 Strengths

- strongest product identity potential
- can feel modern without copying competitors directly
- supports device/modulation-heavy workflows well
- gives the DAW a recognizable emotional signature

### 5.7 Risks

- easiest direction to over-design
- identity accents could become gimmicky if too frequent
- requires stricter restraint than the other directions

### 5.8 Best fit areas

This direction works especially well for:

- device chains
- macro systems
- modulation systems
- transport highlights
- selected tracks and focused editing zones

### 5.9 Primitive implications

#### Buttons
- still compact, but active semantic states feel more authored

#### Knobs
- value and modulation arcs become a signature part of the UI
- body stays neutral so the signal language carries the identity

#### Meters
- restrained base with strong, elegant warning/clip states

#### Tabs
- cleaner shell integration, but focused/selected tabs feel more intentional

### 5.10 Keywords

- authored
- alive
- precise
- luminous
- modern
- musical

---

## 6. Comparison Matrix

| Dimension | Discipline Dark | Modular Dark | Terra Pulse |
|---|---|---|---|
| calmness | very high | medium-high | high |
| density performance | very high | high | high |
| originality | low-medium | medium | high |
| modulation friendliness | medium | high | very high |
| shell restraint | very high | medium | high |
| component clarity | high | very high | high |
| product identity potential | medium | medium-high | very high |
| risk of visual noise | low | medium | medium |

---

## 7. Recommended Direction

### 7.1 Recommendation

The best path is **Terra Pulse with Discipline Dark as the control baseline**.

That means:

- use Direction A for density, restraint, and shell discipline
- borrow Direction B for panel clarity and component readability where semantic grouping needs help
- use Direction C to define the actual Terra identity

In other words:

> **Ableton-like flat restraint at rest, Bitwig-like shell composition, and Terra-specific pulse in active states.**

### 7.2 Why this is the best balance

If the product goes too far toward Discipline Dark, it risks feeling overly derivative and emotionally flat.

If it goes too far toward Modular Dark, it risks becoming too segmented and visually busy.

Terra Pulse allows the DAW to remain professional while still feeling like its own instrument.

---

## 8. Recommended Final Personality Mix

A practical mix could look like this:

### 8.1 Shell

Use **Discipline Dark** with flatter Ableton-like texture.

- dark neutral shell
- restrained panel separation
- quiet browser and inspector surfaces
- compact typography
- flatter materiality by default
- stronger borders only where grouping, focus, diagnostics, or authored-object clarity benefit

### 8.2 Devices and modulation

Use **Modular Dark + Terra Pulse**

- clearer device grouping
- stronger parameter readability
- strong modulation identity
- slightly more authored active states

### 8.3 Selection and focus

Use **Terra Pulse**

- softer warm focus treatment rather than crisp cyan/blue
- controlled but recognizable selected states
- strong distinction between selection and semantic alert states
- prioritize eye comfort over flashy accent contrast

### 8.4 Transport and music states

Use **Terra Pulse**

- green play
- red record
- strong but disciplined transport emphasis

### 8.5 Arrangement and mixer

Lean back toward **Discipline Dark**

- keep long-session surfaces quieter
- protect readability under density
- do not over-accent clip blocks and channel strips

---

## 9. Style Rules if We Choose Terra Pulse

If Terra Pulse becomes the main direction, the following rules should keep it under control.

### 9.1 Rule: quiet shell, expressive state

The shell must stay calm.

Identity should emerge mostly through:

- focus
- selection
- modulation
- transport
- active device emphasis

### 9.2 Rule: purple belongs to modulation

Purple should remain one of the most protected semantic colors.

This gives the system a strong and instantly legible modulation identity.

### 9.3 Rule: no decorative gradients

Any luminosity should come from:

- value contrast
- thin accent edges
- restrained glow
- intentional semantic color

not from generic shiny gradients.

### 9.4 Rule: track color remains secondary to structure

Track color should support navigation and clip identity, not repaint the whole application.

### 9.5 Rule: active controls can be slightly more authored than idle controls

At rest, controls remain calm.

When active, selected, modulated, or focused, they can show more personality.

This gives the interface a musical sense of response without becoming noisy.

---

## 10. Visual Cues by Direction

### 10.1 Surfaces

| Cue | Discipline Dark | Modular Dark | Terra Pulse |
|---|---|---|---|
| panel separation | subtle | moderate | subtle-moderate |
| inset regions | quiet | clear | clear but restrained |
| overlay separation | controlled | clearer | controlled |

### 10.2 Controls

| Cue | Discipline Dark | Modular Dark | Terra Pulse |
|---|---|---|---|
| button identity | quiet | medium | quiet at rest, stronger when active |
| knob expression | minimal | clear | signature-worthy |
| toggle emphasis | semantic but restrained | clearer modules | semantic with authored active state |

### 10.3 Color

| Cue | Discipline Dark | Modular Dark | Terra Pulse |
|---|---|---|---|
| track color intensity | low | medium | low-medium |
| modulation visibility | medium | high | very high |
| selection visibility | medium | high | high |

---

## 11. Concrete Decision Proposal

### Proposed decision

Adopt:

- **primary direction:** Terra Pulse
- **structural baseline:** Discipline Dark
- **component clarity influence:** Modular Dark

### In plain language

The DAW should feel:

- calmer than Bitwig
- more authored than Live
- more precise than a generic modern creative tool
- more musical in active states than either reference

---

## 12. What to Lock Next

Once this direction is accepted, the next useful docs should lock the style into concrete screen patterns:

1. `daw-patterns.md`
   - transport bar
   - browser row
   - track header
   - mixer strip
   - device module card
   - arrangement clip lane

2. `color-behavior.md`
   - track color rules
   - modulation overlays
   - selected state logic
   - meter and clipping logic

3. `control-gallery.md`
   - button families
   - knob families
   - fader families
   - meter families
   - toggle families

---

## 13. Summary

Three strong style paths exist:

- **Discipline Dark** for restraint and density
- **Modular Dark** for component clarity
- **Terra Pulse** for product identity

The strongest recommendation is not to choose only one in pure form.

The best result is a controlled hybrid:

- calm shell
- clear components
- distinctive active-state language

That combination gives Terra DAW the best chance of feeling:

- professional
- original
- precise
- musically alive
