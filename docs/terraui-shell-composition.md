# Terra DAW TerraUI Shell Composition Pass

## Purpose

This document defines the **View -> TerraUI boundary** for the DAW shell before implementation begins.

Practical product-direction note:

- for the overall shell composition, we should not reinvent what Bitwig already
  gets right
- the macro shell/workspace baseline should stay recognizably Bitwig-like:
  transport on top, authored workspace in the center, attached lower detail
  editor, browser/inspector side regions, and disciplined dark panel hierarchy
- originality should come primarily from our semantic depth, modulation language,
  diagnostics, grid/piano-roll quality, and implementation architecture — not
  from forcing a novel shell layout for its own sake

It exists because this boundary is one of the most important structural seams in the project:

- `View` defines semantic DAW surfaces
- `TerraUI Decl` defines the concrete authored UI tree
- the shell is where nearly every major surface first meets TerraUI layout, identity, input, clipping, scrolling, and theming semantics

This is a design/implementation-planning document, not code.

---

## Canonical boundary statement

The DAW shell should be authored as:

> one TerraUI component whose internal tree is lowered from `View.Root`

That means:

- the top-level application shell is one TerraUI component specialization
- `View.Root:to_decl(ViewCtx)` is the semantic entry point
- all major DAW surfaces lower to TerraUI subtrees inside that one component tree
- `View.Identity` is the source of stable TerraUI keyed identity
- `View.*Anchor` and `View.*Command.action_id` become TerraUI-local target and input wiring

This keeps the boundary clean:

- `View` stays semantic
- `TerraUI` stays structural/presentational
- no ad hoc UI tree is invented outside the schema

---

## TerraUI concepts that matter most for shell composition

From the TerraUI docs, the shell pass should center on these authored concepts:

- `Decl.Component`
- `Decl.Node`
- `Decl.Id`
- `Decl.Layout`
- `Decl.Clip`
- `Decl.Scroll`
- `Decl.Floating`
- `Decl.Input`
- `Decl.ThemeScope`
- widget definitions / widget calls only where they genuinely reduce repetition

The most important TerraUI rules for us are:

1. **structure is authored in `Decl`**
2. **widget sugar elaborates away during bind**
3. **stable ids matter for targeting and specialization**
4. **scroll is first-class and runtime-backed**
5. **floating attaches to stable ids**
6. **layout is row/column/fit/grow/fixed/percent based**

---

## Shell composition principles

## 1. One semantic shell, many keyed subtrees

`View.Root` lowers to one TerraUI root subtree.
Inside that subtree, each major semantic surface becomes a keyed child subtree.

Examples:

- transport bar subtree
- browser sidebar subtree
- inspector sidebar subtree
- arrangement subtree
- launcher subtree
- mixer subtree
- detail panel subtree
- status bar subtree

A mature `View` object should usually become **one keyed TerraUI subtree**, not one raw node and not an arbitrary scatter of unrelated nodes.

## 2. Key every stable surface boundary

The shell should derive stable TerraUI ids from:

- `View.Identity`
- explicit shell region names

Important keyed boundaries:

- app root
- transport
- main area
- each sidebar
- arrangement / launcher / mixer root
- detail panel root
- status bar
- repeated stable children such as track strips, launcher columns, device entries, piano notes, grid modules, browser items

This supports:

- local state stability
- anchor/floating targeting
- subtree-local interaction naming
- later memoized specialization/debugging

## 3. Use local anchors, not global semantic naming, inside keyed scopes

Per both `View` and TerraUI:

- semantic refs identify semantic objects
- anchors identify local visual targets within the nearest keyed scope

So shell lowering should follow this rule:

- create a keyed subtree for the semantic object/surface
- create simple local anchor ids inside it like `root`, `header`, `body`, `meter`, `title`, `canvas`
- do not force anchor names to carry the full semantic path if the keyed scope already does that

## 4. Use row/column structure honestly

The shell should prefer plain TerraUI row/column composition for the major frame:

- top transport row
- middle workspace row
- bottom status row
- internal split columns/rows for sidebars, main area, and detail panel

Do not prematurely invent a docking meta-system.
The DAW shell already has a strong known structure.

## 5. Use scroll structurally, not as a layout hack

Any shell region that is conceptually a viewport over larger content should use TerraUI scroll honestly.

Likely shell scroll regions:

- browser content list
- inspector content area
- arrangement timeline viewport
- launcher grid viewport
- mixer channel viewport when wide
- device chain viewport
- piano-roll note canvas
- grid patch canvas

The rule is:

- use `Scroll` for viewport behavior
- use `Clip` for subtree clipping
- do not fake scrolling with authored child offsets

## 6. Floating should attach to stable shell targets

Tooltips, context popovers, temporary overlays, and certain inspectors should attach through TerraUI floating semantics.

That means shell composition must ensure stable targets exist for:

- transport controls
- browser rows/items
- device params
- grid ports/modules
- piano-roll notes and keys
- inspector fields

The shell composition pass therefore cares about targetable local ids even before the first floating overlay is implemented.

## 7. Keep theme structure lexical and coarse at shell level

Use shell-level `ThemeScope` only where the region genuinely changes presentational context.

Good shell theme-scope boundaries:

- app shell root
- transport region
- browser sidebar
- inspector sidebar
- detail panel root
- overlays/dialogs

Do not over-fragment the shell into tiny theme scopes unless the design system actually needs it.

---

## Canonical shell lowering map

This section defines the intended TerraUI structural map for `View.Root`.

## 1. `View.Root`

Should lower to one TerraUI component root subtree.

Recommended high-level shape:

```text
root column
├── transport row
├── workspace row/column stack
│   ├── optional left sidebar
│   ├── main workspace region
│   ├── optional right sidebar
│   └── optional detail panel
└── status row
```

The exact internal split can vary, but the conceptual zoning should remain stable.

## 2. `View.Shell`

Recommended TerraUI structure:

- root column, grow x/y
- child 1: transport fixed-height row
- child 2: workspace grow region
- child 3: status fixed-height row if present

## 3. `View.TransportBar`

Recommended TerraUI structure:

- one keyed row subtree
- grouped child rows for:
  - navigation/project utilities
  - transport controls
  - tempo/time area
  - status indicators
  - optional right tools

Use local anchors for:
- play
- stop
- record
- loop
- tempo
- time signature
- position
- quantize

## 4. `View.MainArea`

Treat `MainArea` as variant lowering, not as one generic container.

### `ArrangementMain`
Recommended shell shape:

```text
workspace column
├── arrangement grow region
└── optional detail panel
```

### `LauncherMain`
Recommended shell shape:

```text
workspace column
├── launcher grow region
└── optional detail panel
```

### `MixerMain`
Recommended shell shape:

```text
workspace column
├── mixer grow region
└── optional detail panel
```

### `HybridMain`
Recommended shell shape:

```text
workspace column
├── top or main split containing arrangement / launcher / mixer
└── optional detail panel
```

The exact split proportions are session/workspace state, not a new ontology.

## 5. `View.Sidebar`

Each sidebar should lower as its own keyed column subtree.

- browser sidebar = quieter list/search/navigation region
- inspector sidebar = denser focused-edit region

Both should usually contain a scrollable content area.

## 6. `View.DetailPanel`

The detail panel is an attached lower editor region.

Recommended TerraUI shape:

- keyed root column subtree
- optional header/tab row
- one active detail editor grow region

Variant children:

- device chain detail
- focused device detail
- grid detail
- piano-roll detail

The panel should be a shell-attached region, not a floating card.

## 7. `View.StatusBar`

Recommended TerraUI structure:

- fixed-height row
- left / center / right zones
- quiet typography
- optional compact diagnostics summary

---

## Surface-specific shell expectations

## Arrangement shell expectations

The shell pass should reserve structural room for:

- ruler region
- scrollable timeline region
- lane header/body split
- overlay layer for playhead/selection/loop

In TerraUI terms, arrangement likely needs:

- one scrollable viewport subtree
- one clipped canvas region
- one overlay-friendly child ordering

## Launcher shell expectations

The shell pass should reserve structural room for:

- scene header row/column relationship
- stop row
- scrollable slot grid
- repeated keyed columns and slots

## Mixer shell expectations

The shell pass should reserve structural room for:

- repeated strip rhythm
- vertical controls inside horizontal strip repetition
- optional horizontal scrolling when strips overflow

## Device chain shell expectations

The shell pass should reserve structural room for:

- repeated device cards
- insert/drop anchors
- optional scrolling in long chains

## Grid patch shell expectations

The shell pass should reserve structural room for:

- clipped/scrollable patch viewport
- absolute/spatial module placement inside a canvas-like region
- local floating/tooltip targeting for ports/modules
- overlay ordering for cables, selection, diagnostics

## Piano roll shell expectations

The shell pass should reserve structural room for:

- keyboard column
- note canvas viewport
- lower velocity/expression lane stack
- clipped + scrollable note region viewport
- overlay ordering for playhead, loop, marquee selection

---

## Input/action boundary rules

## 1. `View.*Command.action_id -> Decl.Input.action`

This should be the default shell wiring rule.

TerraUI should receive:

- local input affordance
- stable node id
- action string

The DAW-side dispatch system should resolve the typed command payload.

## 2. Input lives on the smallest meaningful target

Examples:

- transport button input on the button node
- clip body input on the clip body node
- note resize input on note trim handle node
- grid cable start input on the port target node

Do not put every interaction on the largest parent region when a smaller semantic target exists.

## 3. Shell-level hit regions should stay structural, not semantic dumps

The shell subtree should expose the interaction regions required by the `View` ontology, but should not encode app logic directly into arbitrary TerraUI structure.

---

## Widget usage policy at the shell boundary

TerraUI supports authored widgets, but bind elaborates them away.
That means widgets are good when they reduce repetition honestly.

Recommended shell-level widget candidates:

- button family
- tab family
- track header
- browser row
- mixer strip shell pieces
- device card shell pieces
- inspector field rows
- piano key / note block shell pieces
- diagnostic badge / placeholder panel

Not recommended as a first move:

- inventing one giant `DAWShellWidget`
- hiding all shell composition inside opaque widget internals

The shell boundary should remain inspectable and structurally obvious.

---

## Theme and parts policy at the shell boundary

Once TerraUI theme tokens / widget parts are used more deeply, the shell pass should follow these rules:

1. shell regions use coarse lexical theme scopes
2. reusable widgets expose explicit parts
3. local presentational overrides happen through part style patches
4. shell structure itself is not changed by style patches

That matches the TerraUI theming design cleanly.

---

## First implementation slice: shell composition target

Before deeper runtime behavior, the first shell slice should be capable of lowering:

- app root
- transport bar
- left browser sidebar
- center arrangement or hybrid placeholder
- right inspector sidebar
- lower detail panel placeholder
- status bar

with:

- stable ids from `View.Identity`
- local anchors from `View.*Anchor`
- action strings from `View.*Command.action_id`
- scroll regions where conceptually required
- placeholder/error panels for incomplete surfaces

That gives us the correct shell boundary without requiring the whole DAW to be fully implemented.

---

## Red lines

Do not:

- invent a second shell ontology outside `View`
- collapse semantic subtrees into one giant anonymous TerraUI node forest
- fake scroll with manual child translation in authored shell composition
- use floating without stable ids/anchors
- hide shell structure behind giant opaque widgets too early
- make shell theming so fragmented that the region hierarchy becomes unclear

---

## Summary

The TerraUI-facing shell composition rule is:

> `View.Root` lowers to one stable TerraUI component tree whose major semantic surfaces become keyed, scroll-aware, locally targetable subtrees.

That is the boundary we should preserve during implementation.
