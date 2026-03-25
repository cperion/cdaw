# Terra DAW Screen Patterns v0.1

**Status:** Draft  
**Depends on:** `daw-design-system.md`, `design-tokens.md`, `visual-primitives.md`, `style-directions.md`  
**Purpose:** Define the visual composition rules for the main DAW screen regions

---

## 1. Purpose

This document moves from primitives to composed DAW regions.

It defines how buttons, tabs, knobs, faders, meters, inputs, and clip blocks should combine into stable screen patterns.

This is still a **visual specification**, not a rendering contract.

The purpose is to make the main DAW surfaces feel:

- coherent
- balanced
- dense but readable
- distinctly Terra
- consistent across arranger, mixer, browser, and devices

---

## 2. Global Pattern Rules

### 2.0 Shell baseline

At the macro layout level, Terra should stay close to a Bitwig-style DAW shell.
That means:

- a strong top transport spine
- side-oriented supporting regions
- a central authored workspace
- an attached lower detail editor
- disciplined split boundaries

We should not spend originality budget on replacing a shell grammar that already
works extremely well for this kind of product.

These rules apply to every major DAW region.

### 2.1 Calm shell, expressive active state

At rest, the shell stays quiet.
The shell material should lean flatter and more Ableton-like in texture, while
keeping enough semantic borders to clarify important authored or focused objects.
Selection/focus accents should avoid harsh cyan-blue and prefer softer,
less fatiguing warm emphasis.

Identity appears mainly in:

- selection
- focus
- transport state
- modulation
- clip/track identity
- warning/clipping states

### 2.2 Region hierarchy

Use a stable hierarchy:

1. app shell
2. panel region
3. subsection surface
4. control surface
5. active or selected state

### 2.3 Density rule

Dense is acceptable.
Chaos is not.

Use:

- compact internal spacing
- strict alignment
- stronger spacing between functional groups
- restrained surface changes

Compactness should be benchmarked against Ableton Live's proven density and
sizing grammar. We should not guess at basic DAW control scale when a strong
reference already exists.

### 2.4 Color rule

Default to neutral structure.

Use color only where it adds meaning:

- track identity
- selected focus
- modulation
- transport
- warning/clip

### 2.5 Text rule

Text is informational, not decorative.

- labels stay compact
- numbers stay extremely readable
- browser metadata remains secondary
- arrangement labels must survive reduced height and width

---

## 3. Pattern 1: Transport Bar

The transport bar is the global command and status spine of the application.

### 3.1 Purpose

It should feel:

- immediate
- stable
- high-confidence
- globally legible

### 3.2 Typical content

- play
- stop
- record
- loop
- metronome
- tempo field
- time/position display
- CPU/audio engine indicators
- undo/redo or project utilities
- optional mode toggles

### 3.3 Structural zones

The transport bar should be divided into clear groups:

1. project/navigation utilities
2. core transport controls
3. tempo/time information
4. status and engine indicators
5. optional right-side tools

### 3.4 Visual behavior

- the transport region should sit slightly above the app shell in hierarchy
- transport buttons may be more emphatic than ordinary utility buttons
- record and play states must be unmistakable
- numeric displays should feel instrument-like and exact

### 3.5 Surface guidance

- background: `region.transport.bg`
- controls: standard neutral control language
- active transport controls: semantic emphasis
- separators: subtle and sparse

### 3.6 Key emphasis rules

- play is green
- record is red
- loop and metronome should be visible but secondary to play/record
- tempo and timeline values should be one of the highest-legibility areas in the shell

### 3.7 Risks to avoid

- over-decorated transport icons
- too many equally loud indicators
- weak distinction between transport and utility actions

---

## 4. Pattern 2: Browser Row

The browser is text-heavy and must remain very calm.

### 4.1 Purpose

It should support:

- fast scanning
- hierarchy by text and indentation
- low fatigue over long sessions
- clear hover and selection behavior

### 4.2 Typical row contents

- optional disclosure control
- icon
- primary label
- type/category metadata
- favorite/status marker
- selected/hover state

### 4.3 Row anatomy

1. row background
2. optional indent structure
3. icon zone
4. main label
5. secondary metadata
6. optional trailing badge or indicator

### 4.4 Visual behavior

- default rows should stay visually quiet
- hover should lightly raise contrast
- selected rows should be obvious but not oversaturated
- tree indentation must be easier to parse than background striping alone

### 4.5 Typography rules

- primary label: `text.primary`
- metadata: `text.secondary` or `text.muted`
- disabled/unavailable entries: `text.disabled`

### 4.6 Layout rules

- row height should default to `24`
- icon and text should align on a predictable left rhythm
- metadata should not fight the main label
- long names should truncate cleanly

### 4.7 Risks to avoid

- rows that feel like web list items
- over-contrasted striping
- too many badges competing with names

---

## 5. Pattern 3: Track Header

The track header is a critical identity and control zone.

### 5.1 Purpose

It should communicate:

- track identity
- record/solo/mute state
- selection state
- device/clip context at a glance

### 5.2 Typical contents

- track color indicator
- track name
- input/output or routing summary
- arm / solo / mute toggles
- monitoring mode
- level meter summary or mini meter
- optional collapse/fold control

### 5.3 Visual structure

A track header should usually have:

1. background surface
2. identity accent region
3. name area
4. state toggle cluster
5. optional compact meter or status strip

### 5.4 Color rules

- track color should appear as a controlled accent, not a full flood
- selected track should use a stronger selected ring or border treatment
- arm/solo/mute remain semantic and should not be confused with track identity color

### 5.5 Layout rules

- controls should cluster tightly
- name area should stay legible even in narrow widths
- mini meter should not dominate the header
- selected state should remain visible even if track color is muted or dark

### 5.6 Risks to avoid

- track headers becoming too colorful
- semantic toggles getting lost in the identity color
- selected state disappearing against bright track tints

---

## 6. Pattern 4: Mixer Strip

The mixer strip is one of the densest vertical patterns and must be extremely disciplined.

### 6.1 Purpose

It should support:

- level reading in peripheral vision
- rapid target acquisition
- consistency across many repeated channels
- strong semantic state clarity

### 6.2 Typical contents

- track label
- meter
- insert/send section
- pan control
- fader
- mute/solo/arm toggles
- numerical value readout optional

### 6.3 Vertical rhythm

The strip should read as repeated aligned zones:

1. header identity
2. signal readout
3. processing zone
4. balance/parameter zone
5. main level control
6. track-state controls

### 6.4 Visual behavior

- strip surfaces should remain calm and repetitive
- meters provide the main continuous motion language
- faders provide the main control focus
- state toggles should remain compact but unmistakable

### 6.5 Surface guidance

- strip background: `region.mixer.strip`
- repeated lane rhythm is more important than decorative separation
- channel boundaries should be clear but subtle

### 6.6 Color rules

- track identity may appear in the header area or small accent elements
- meter colors should remain semantically consistent
- fader fill should not clash with meter color

### 6.7 Risks to avoid

- every strip becoming too visually unique
- faders and meters competing equally for attention
- overusing color on repeated vertical controls

---

## 7. Pattern 5: Device Module Card

This is one of the most important Terra identity opportunities.

### 7.1 Purpose

The device module should feel:

- modular
- precise
- inspectable
- patchable in spirit even when not literally patching
- more authored than plain shell chrome

### 7.2 Typical contents

- device header
- enable/bypass state
- title and type
- parameter controls
- modulation indicators
- macro mappings
- optional fold/collapse affordance

### 7.3 Structure

1. module shell
2. device header
3. parameter grid or rows
4. secondary details or modulation layer
5. footer/meta actions optional

### 7.4 Visual behavior

- device boundaries should be clearer here than in arranger or browser regions
- active devices can have slightly stronger emphasis
- modulation overlays should feel especially readable in this pattern
- modulation route rows and target highlights should read as authored signal relationships
- selected/focused parameter groups can show more Terra Pulse identity than the global shell

### 7.5 Color rules

- device shells stay mostly neutral
- modulation uses purple consistently
- modulation scaling should stay within the purple modulation family rather than introducing extra cyan
- selected/focused areas should prefer soft warm accents over cyan/blue
- active bypass/power states must remain semantically clear
- modulation colors must never be confused with warning/error colors

### 7.6 Layout rules

- parameter groupings should be obvious even under density
- labels should not drift from their controls
- macro rows may be slightly more spacious than dense utility rows

### 7.7 Risks to avoid

- turning device cards into generic app cards
- over-framing every parameter group
- using too many simultaneous accent colors

---

## 8. Pattern 6: Arrangement Clip Lane

The arrangement area is one of the longest-duration viewing surfaces in the DAW.

### 8.1 Purpose

It must support:

- long-session readability
- fast structural scanning
- accurate clip selection and editing
- clear playhead and timing reference

### 8.2 Typical contents

- lane background
- time grid
- clip blocks
- automation overlays
- selection region
- playhead
- loop markers
- muted/disabled states

### 8.3 Visual hierarchy

The arrangement should prioritize:

1. timing/grid structure
2. clip placement
3. playhead and current edit focus
4. automation or secondary overlays

### 8.4 Grid rules

- minor grid lines should stay quiet
- major grid lines should be readable but not heavy
- selected time regions should not obscure clip identity

### 8.5 Clip rules

- clip blocks carry most local color identity
- selected clips need a strong and crisp distinction
- muted clips should remain placeable and readable
- text labels must survive reduced track heights

### 8.6 Playhead rules

- playhead must be unmistakable
- it should cut through arrangement density cleanly
- it should not be confused with selection bounds or loop markers

### 8.7 Automation rules

- automation should be visible but secondary to clip structure by default
- selected automation can step forward in emphasis
- modulation-like colors should not collide with track identity unnecessarily

### 8.8 Risks to avoid

- arrangement backgrounds becoming too contrasty
- clip colors overpowering the timing structure
- automation making lanes visually tangled

---

## 9. Pattern 7: Inspector / Detail Panel

This region supports focused editing and should feel more intimate than the main shell.

### 9.1 Purpose

It should support:

- exact value work
- contextual editing
- readable grouping
- low confusion while multitasking

### 9.2 Typical contents

- section titles
- labeled inputs
- toggles
- small knobs/sliders
- metadata and contextual help

### 9.3 Visual behavior

- calmer than device cards
- more structured than browser rows
- supports dense control clusters without looking cramped

### 9.4 Rules

- section headers should be visible but not loud
- fields and toggles should align rigidly
- spacing between groups matters more than decorative dividers

---

## 10. Pattern 8: Dialog / Overlay

Dialogs and overlays are infrequent but need strong clarity.

### 10.1 Purpose

They should feel:

- elevated
- focused
- temporary
- readable immediately

### 10.2 Typical contents

- title
- explanatory text
- inputs or settings
- primary/secondary actions

### 10.3 Rules

- overlays can use stronger separation from the background than ordinary panels
- action hierarchy should be obvious
- destructive actions must not blend with passive actions

### 10.4 Risks to avoid

- making overlays feel like a different product
- overusing modal depth and glow

---

## 10A. Pattern 9: Piano Roll

The piano roll is a first-class native note-region editor, not a generic grid.

### 10A.1 Purpose

It should support:

- precise note editing
- very fast pitch/time scanning
- confident selection and manipulation
- clear distinction between notes, velocity, and other expression

### 10A.2 Typical contents

- piano keyboard
- time/pitch grid
- note blocks
- selected-note outlines
- playhead
- loop region
- velocity lane
- expression lanes
- marquee selection rectangle

### 10A.3 Visual hierarchy

The piano roll should prioritize:

1. pitch/time scaffold
2. note objects
3. current selection and editing affordances
4. velocity / expression lanes
5. secondary overlays

### 10A.4 Rules

- notes must read as stable authored objects, not as decorative blocks
- the keyboard should support fast octave recognition
- velocity should feel closely related to notes but clearly secondary
- expression lanes should be quieter than notes until selected or edited
- multi-selection should be crisp and unmistakable

### 10A.5 Risks to avoid

- grids that overpower note readability
- overly playful keyboard visuals
- expression lanes visually competing with note editing by default

---

## 10B. Pattern 10: Grid Patch

The grid patch is the most explicitly modular surface and should feel technical,
legible, and spatially authored.

### 10B.1 Purpose

It should support:

- spatial reasoning
- patch tracing
- target acquisition on modules and ports
- confident cable editing

### 10B.2 Typical contents

- patch background
- module cards
- ports
- cables
- selected modules/cables
- source-binding markers
- drag/drop or insertion markers
- local diagnostics

### 10B.3 Visual hierarchy

The grid patch should prioritize:

1. module bodies and titles
2. cable topology
3. port endpoints
4. selection/drag state
5. background grid scaffold

### 10B.4 Rules

- modules must remain readable before cables are considered
- idle cables should stay quieter than selected modules
- source/modulation distinctions should be semantic and stable
- the background grid should aid alignment, not dominate the patch
- diagnostics should attach locally to modules or cables

### 10B.5 Risks to avoid

- decorative patch backgrounds
- ports too small to read or target
- too many equally loud cable colors

---

## 10C. Pattern 11: Detail Panel

The detail panel is the lower attached editor region of the application. It must
handle multiple editor metaphors without feeling like a disconnected secondary app.

### 10C.1 Purpose

It should support:

- focused secondary editing
- continuity with the main surface above
- clear mode switching between device, chain, grid, and piano roll detail

### 10C.2 Typical contents

- mode/tab row optional
- header strip or contextual summary
- one focused detail editor
- splitters or resize affordances
- local diagnostics where relevant

### 10C.3 Rules

- the detail panel should feel attached to the main workspace, not floating
- switching detail modes should preserve shell calmness
- panel headers should be quieter than transport but clearer than ordinary subsections
- each detail editor keeps its own visual grammar inside a shared structural frame

### 10C.4 Risks to avoid

- making the lower panel look like a stack of generic cards
- giving every detail mode a totally different shell language

---

## 10D. Pattern 12: Diagnostics / Placeholder States

Diagnostics and degraded states are intentional product behavior.

### 10D.1 Purpose

They should support:

- local failure visibility
- confidence that the session still stands
- readable distinction between warning, degraded, and error states

### 10D.2 Typical contents

- compact badge on the affected object
- inline diagnostic strip or footer
- placeholder panel for locally unavailable surfaces
- concise explanation text

### 10D.3 Rules

- diagnostics should remain local whenever possible
- placeholders should preserve the host surface identity and layout slot
- warning vs error should differ structurally, not only by hue
- degraded state should look intentional and calm, not catastrophic

### 10D.4 Risks to avoid

- modalizing every local issue
- replacing large regions with aggressive crash-like treatment
- using the same loud red state for all problems

---

## 10E. Pattern 13: Modulation Language

Modulation is one of the key identity layers of Terra DAW and should feel authored,
precise, and system-wide rather than like a one-off highlight effect.

### 10E.1 Purpose

It should support:

- fast recognition of modulated targets
- readable distinction between base value and modulation influence
- clear route relationships between modulators and params
- signed or directional depth reading where relevant

### 10E.2 Typical appearances

- knob arcs with modulation overlay
- fader modulation bands
- parameter target rings/highlights
- route rows in device/modulator sections
- scale relationships shown as secondary linked cues

### 10E.3 Rules

- modulation must remain a secondary semantic layer on top of value, not a replacement for value
- target highlights should be local and precise
- route rows should look like signal relationships, not ordinary browser/inspector rows
- modulation scaling should be visually distinct from both depth and target identity

### 10E.4 Risks to avoid

- making modulation look like generic selection
- making modulation look like warning/error state
- saturating every modulated control until the whole device becomes noisy

---

## 11. Pattern Interactions

This section describes how patterns should relate to one another.

### 11.1 Browser to device flow

The browser is quiet and list-based.
The device area is more modular and authored.

That transition should feel intentional, not jarring.

### 11.1A Device to modulation flow

Device parameter editing and modulation editing should belong to the same family.
Modulation should feel like a precise secondary authored layer on top of base value
editing, not like an unrelated neon overlay system.

### 11.2 Arrangement to mixer flow

Arrangement is horizontally analytical.
Mixer is vertically repetitive.

They should share the same token logic and control family language even though their rhythms differ.

### 11.3 Transport to everything else

Transport is globally important.

It may be slightly more emphatic than surrounding chrome, but it must still belong to the same system.

---

## 12. Pattern Priority by Style Direction

If the chosen overall direction is Terra Pulse with Discipline Dark baseline, use this emphasis map:

| Pattern | Style weighting |
|---|---|
| transport bar | Terra Pulse + Discipline Dark |
| browser row | Discipline Dark |
| track header | Discipline Dark + Terra Pulse |
| mixer strip | Discipline Dark |
| device module card | Terra Pulse + Modular Dark |
| arrangement clip lane | Discipline Dark + Terra Pulse |
| piano roll | Discipline Dark + Terra Pulse |
| grid patch | Terra Pulse + Modular Dark |
| detail panel | Discipline Dark |
| diagnostics / placeholder | Discipline Dark with explicit semantic contrast |
| inspector/detail | Discipline Dark |
| dialog/overlay | Discipline Dark with stronger clarity |

---

## 13. Review Checklist

Before a pattern is considered stable, check:

### 13.1 Hierarchy
- does the pattern read clearly in grayscale?
- are the active zones obvious?
- are repeated structures consistent?

### 13.2 Density
- does the pattern still work when packed tightly?
- does spacing distinguish groups from individual controls?

### 13.3 Semantics
- are semantic states unambiguous?
- is track identity distinct from selection and warning states?
- is modulation distinct from value and track identity?

### 13.4 System fit
- does it still look like Terra?
- does it still belong to the same family as the other patterns?
- is it using the same token and primitive logic?

---

## 14. Recommended Next Docs

If we want to continue from here without exploding the documentation set, the best next artifacts are more focused reference sheets rather than many new large documents.

Recommended compact follow-ups:

1. `color-behavior.md`
   - track color rules
   - modulation color behavior
   - selected/focus logic
   - meter/clip warning logic
   - diagnostics and placeholder color rules

2. `control-gallery.md`
   - button family snapshots
   - knob family snapshots
   - toggle family snapshots
   - meter/fader variants
   - piano-roll note/key variants
   - grid module/port/cable variants

3. `screen-review-checklist.md`
   - a short QA list for future screens

---

## 15. Summary

This document defines the first major composed screen patterns for Terra DAW.

It translates the primitive system into actual DAW regions:

- transport
- browser
- track headers
- mixer
- devices
- arrangement
- piano roll
- grid patch
- detail panel
- diagnostics / placeholder states
- inspector
- overlays

The key design goal remains consistent:

- calm shell
- precise controls
- meaningful color
- strong active-state language
- dense but readable professional workflows
