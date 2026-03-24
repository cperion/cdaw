-- ================================================================
-- Terra DAW v3: Unified Model
--
-- ONE insight: everything is a signal graph.
--
-- A "device chain" is a serial graph.
-- A "Grid patch" is a free graph.
-- A "Layer container" is a parallel graph.
-- A "Selector" is a switched graph.
-- A "Freq Split" is a crossover graph.
--
-- There is no separate Grid ASDL. There is no separate
-- container model. There is one type: Graph. Graphs contain
-- Nodes. Nodes are connected by Wires. Graphs nest recursively.
--
-- The compilation path is the same for everything:
--   topological sort → classify → schedule → compile
--
-- Seven slices/phases:
--   Editor     → user-facing, Bitwig-shaped authoring model
--   View       → DAW-specific interaction/projection layer → TerraUI Decl
--   Authored   → canonical semantic graph document
--   Resolved   → IDs fixed, ticks, codes
--   Classified → rate classes, bindings
--   Scheduled  → buffer slots, linear jobs
--   Kernel     → TerraType + TerraQuote + TerraFunc
-- ================================================================

local asdl = require 'asdl'
local D = asdl.NewContext()

D:Extern("TerraType",    terralib.types.istype)
D:Extern("TerraQuote",   terralib.isquote)
D:Extern("TerraFunc",    terralib.isfunction)
D:Extern("PluginHandle", function(o) return type(o) == "userdata" end)

D:Extern("ViewCtx",      function(o) return type(o) == "table" end)
D:Extern("TerraUIDecl",  function(o) return type(o) == "table" end)
D:Extern("LowerCtx",     function(o) return type(o) == "table" end)
D:Extern("ResolveCtx",   function(o) return type(o) == "table" end)
D:Extern("ClassifyCtx",  function(o) return type(o) == "table" end)
D:Extern("ScheduleCtx",  function(o) return type(o) == "table" end)
D:Extern("CompileCtx",   function(o) return type(o) == "table" end)

D:Define [[

-- ================================================================
-- PHASE 0: EDITOR
-- User-authoring layer. Bitwig-shaped editing concepts.
-- This layer captures what the musician directly manipulates.
-- It lowers deterministically into the canonical Authored graph IR.
-- ================================================================
module Editor {

    -- Design axioms:
    --   • Editor is semantic authoring state, not transient UI state.
    --   • It owns user-facing composition concepts: device chains,
    --     note-fx lanes, containers, modulators, clips, launcher, scenes.
    --   • It must lower deterministically into Authored.
    --   • It must not store presentation/session state like selection,
    --     zoom, panel openness, hover, or drag-in-progress.
    --   • Invalid states should be made unrepresentable here when feasible.
    --   • The schema itself is the scripting/metaprogramming substrate.
    --     Structural composition should be expressed by constructing and
    --     transforming Editor/Authored trees directly, not by introducing a
    --     separate macro ontology into the domain model.
    --
    -- Canonical command semantics:
    --   Commands operate on Editor.*, never directly on Authored.*.
    --   Raw gestures normalize into a compact semantic command set.
    --
    --   Main command families:
    --     1. Project / track
    --        AddTrack, RemoveTrack, MoveTrack, SetTrackOutput,
    --        SetTrackFlags
    --
    --     2. Device chain
    --        AddDevice, RemoveDevice, MoveDevice, ReplaceDevice,
    --        ToggleDeviceEnabled
    --
    --     3. Containers
    --        WrapDevicesInLayer, WrapDevicesInSelector,
    --        WrapDevicesInSplit, ConvertDeviceToGrid,
    --        Add/Remove/Move/Duplicate Layer,
    --        Add/Remove/Move/Duplicate SelectorBranch,
    --        Add/Remove/Move/Duplicate SplitBand,
    --        SetLayerMix, SetSelectorMode, SetSplitBandCrossover
    --
    --     4. Modulation
    --        AddModulator, RemoveModulator, MoveModulator,
    --        SetModulatorEnabled, SetModulatorVoiceMode,
    --        Add/Remove modulation mapping,
    --        SetModulationDepth, SetModulationScale
    --
    --     5. Grid patch
    --        Add/Remove/Move GridModule,
    --        Connect/Disconnect GridCable,
    --        Bind/Unbind GridSource,
    --        SetGridInterface
    --
    --     6. Clips / launcher
    --        Add/Remove/Move/Resize Clip,
    --        SetClipGain, SetClipFade,
    --        SetSlotContent, SetSlotBehavior,
    --        Add/Remove Scene, SetSceneProperties
    --
    --     7. Routing
    --        Add/Remove Send,
    --        SetSendTarget, SetSendLevel, SetSendMode
    --
    --     8. Parameters
    --        SetParamValue, SetParamRange, SetParamCombine
    --
    --   Shared command references:
    --     • chain targets should normalize to an editor chain ref like:
    --         TrackChain(track_id)
    --         DeviceNoteFX(device_id)
    --         DevicePostFX(device_id)
    --         LayerChain(container_id, layer_id)
    --         SelectorBranchChain(container_id, branch_id)
    --         SplitBandChain(container_id, band_id)
    --     • parameter owners should normalize to an owner ref like:
    --         DeviceOwner(device_id)
    --         ModulatorOwner(device_id, modulator_id)
    --         LayerOwner(container_id, layer_id)
    --         SendOwner(track_id, send_id)
    --         ClipOwner(clip_id)
    --
    --   Command principles:
    --     • preserve stable ids whenever possible
    --     • create valid Editor states directly
    --     • browser drops, menu actions, drags, and shortcuts should lower
    --       into the same semantic commands
    --     • these semantic commands are the right unit for undo/redo

    Project = (
        string              name,
        string?             author,
        number              format_version,
        Editor.Transport    transport,
        Editor.Track*       tracks,
        Editor.Scene*       scenes,
        Editor.TempoMap     tempo_map,
        Authored.AssetBank  assets
    ) unique
    methods {
        lower(LowerCtx ctx) -> Authored.Project
    }

    Transport = (
        number sample_rate, number buffer_size,
        number bpm, number swing,
        number time_sig_num, number time_sig_den,
        Editor.Quantize launch_quantize,
        boolean looping,
        Editor.TimeRange? loop_range
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Transport
    }

    TimeRange = (number start_beats, number end_beats)

    Quantize
        = QNone | Q1_64 | Q1_32 | Q1_16 | Q1_8
        | Q1_4 | Q1_2 | Q1Bar | Q2Bars | Q4Bars

    TempoMap = (
        Editor.TempoPoint* tempo,
        Editor.SigPoint*   signatures
    )
    methods {
        lower(LowerCtx ctx) -> Authored.TempoMap
    }

    TempoPoint = (number at_beats, number bpm)
    SigPoint   = (number at_beats, number num, number den)

    -- Editor-only document metadata that may matter to the musician but does
    -- not change DSP semantics directly.
    UserMeta = (
        string? color,
        string? comment,
        string? icon
    )

    -- Optional provenance / browser linkage for presets and reusable objects.
    -- This is semantic user-document information, even when lowering may
    -- choose to inline the resulting structure into Authored.
    PresetRef = (
        string kind,
        string uri,
        string? revision
    )

    -- Lowering contract:
    --   • the editor-facing device chain lowers to Authored.Track.device_graph
    --   • input lowers to Authored.TrackInput routing metadata
    --   • volume/pan lower to canonical track-level params used by mixer/output
    --   • clip / launcher / send structures lower mostly 1:1
    --   • TrackKind may constrain legal authoring patterns, but should not be
    --     relied on as the sole source of DSP semantics after lowering
    -- Editor invariants:
    --   • Track ids are stable identities
    --   • MasterTrack must not route to another track
    --   • volume/pan are always present as user-facing mixer controls
    --   • input routing legality should be enforced here before lowering
    --   • group/master routing restrictions should be enforced here before
    --     lowering rather than recovered later from graph structure
    Track = (
        number               id,
        string               name,
        number               channels,
        Editor.TrackKind     kind,
        Editor.TrackInput?   input,
        Editor.ParamValue    volume,
        Editor.ParamValue    pan,
        Editor.DeviceChain   devices,
        Editor.Clip*         clips,
        Editor.Slot*         launcher_slots,
        Editor.Send*         sends,
        number?              output_track_id,
        number?              group_track_id,
        boolean muted, boolean soloed,
        boolean armed, boolean monitor_input,
        boolean phase_invert,
        Editor.UserMeta?     meta
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Track
    }

    -- TrackKind is primarily an editor-level/user-facing classification.
    -- It may guide defaults, browser filtering, and legal UI actions, but
    -- it should not duplicate the deeper DSP/domain semantics already
    -- captured by lowered graphs and node kinds.
    TrackKind = AudioTrack | InstrumentTrack | HybridTrack | GroupTrack | MasterTrack

    -- TrackInput is editor-facing recording / monitoring source semantics.
    -- It captures the user-visible notion of source selection while staying
    -- simple enough to lower into canonical routing metadata.
    TrackInput
        = NoInput
        | AudioInput(number device_id, number channel)
        | MIDIInput(number device_id, number channel)
        | TrackInputTap(number track_id, boolean post_fader)

    -- A device chain is the default Bitwig-style authoring surface.
    -- Lowering contract:
    --   • lowers to an Authored.Graph with layout=Serial
    --   • device order is preserved exactly
    --   • chain-level note/audio semantics are expressed through the
    --     lowered node kinds and child graph roles, not by inventing a
    --     separate chain runtime concept
    -- Editor invariants:
    --   • device order is semantically meaningful and stable
    --   • insertion/removal/reordering commands operate here, not in Authored
    DeviceChain = (Editor.Device* devices)
    methods {
        lower(LowerCtx ctx) -> Authored.Graph
    }

    -- Devices are the primary user-visible authoring atoms.
    -- Lowering contract:
    --   • every Editor.Device lowers to exactly one Authored.Node
    --   • plain/native devices keep their semantic NodeKind directly
    --   • container devices lower to a container node plus child graphs
    --   • branching containers use explicit graph-local branch-entry nodes so
    --     branch identity remains stable after lowering
    --   • the user-facing distinction between layer/selector/split/grid
    --     lives here; Authored unifies them as graph/layout semantics
    Device
        = NativeDevice(Editor.NativeDevice body)
        | LayerDevice(Editor.LayerContainer body)
        | SelectorDevice(Editor.SelectorContainer body)
        | SplitDevice(Editor.SplitContainer body)
        | GridDevice(Editor.GridContainer body)
    methods {
        lower(LowerCtx ctx) -> Authored.Node
    }

    -- NativeDevice is the ordinary device-panel case.
    -- Lowering contract:
    --   • lowers to one Authored.Node with the same semantic NodeKind
    --   • params lower 1:1 into Authored.Param
    --   • modulators lower into Authored.ModSlot entries owned by the node
    --   • note_fx lowers to ChildGraph(NoteFXChild, ...)
    --   • post_fx lowers to ChildGraph(PostFXChild, ...)
    --   • preset/meta may remain editor-only provenance/document metadata
    -- Editor invariants:
    --   • device ids are stable identities
    --   • note_fx is only legal when the device's authored semantics admit
    --     note input / note processing at that position
    NativeDevice = (
        number               id,
        string               name,
        Authored.NodeKind    kind,
        Editor.ParamValue*   params,
        Editor.Modulator*    modulators,
        Editor.NoteFXLane?   note_fx,
        Editor.AudioFXLane?  post_fx,
        Editor.PresetRef?    preset,
        boolean              enabled,
        Editor.UserMeta?     meta
    )

    -- LayerContainer is a first-class user concept at Editor level.
    -- Lowering contract:
    --   • lowers to one Authored.Node, typically kind=SubGraph()
    --   • owns a MainChild graph whose layout is Parallel(...)
    --   • each Editor.Layer materializes as a graph-local branch-entry node
    --     whose MainChild is the lowered serial graph of Layer.chain
    --   • Authored.LayerConfig.node_id points at that branch-entry node
    --   • per-layer volume/pan/mute lower into Authored.LayerConfig
    --   • note_fx/post_fx lower to child graph roles on the container node
    --   • preset/meta may remain editor-only provenance/document metadata
    LayerContainer = (
        number               id,
        string               name,
        Editor.Layer*        layers,
        Editor.ParamValue*   params,
        Editor.Modulator*    modulators,
        Editor.NoteFXLane?   note_fx,
        Editor.AudioFXLane?  post_fx,
        Editor.PresetRef?    preset,
        boolean              enabled,
        Editor.UserMeta?     meta
    )

    -- Layers are editor-level branch identities. Their stable ids should be
    -- preserved across edits so automation/modulation targets survive.
    -- Lowering materialization:
    --   • each layer becomes a branch-entry node in the container's MainChild
    --   • that node's MainChild contains the lowered serial graph of `chain`
    -- Editor invariants:
    --   • layer ids are stable within the container
    --   • layer ordering is semantically meaningful to the user even if the
    --     parallel runtime meaning is symmetric in some cases
    Layer = (
        number              id,
        string              name,
        Editor.DeviceChain  chain,
        Editor.ParamValue   volume,
        Editor.ParamValue   pan,
        boolean             muted,
        Editor.UserMeta?    meta
    )

    -- SelectorContainer is a first-class user concept at Editor level.
    -- Lowering contract:
    --   • lowers to one Authored.Node, typically kind=SubGraph()
    --   • owns a MainChild graph whose layout is Switched(...)
    --   • each Editor.SelectorBranch materializes as a graph-local branch-entry
    --     node whose MainChild is the lowered serial graph of branch.chain
    --   • Authored.SwitchConfig.node_ids point at those branch-entry nodes
    --   • mode lowers into Authored.SwitchConfig / Authored.SelectorMode
    --   • Editor.ManualSelect(selected_index) is editor-facing state and may
    --     lower either into selector params or initial authored config policy
    --   • preset/meta may remain editor-only provenance/document metadata
    SelectorContainer = (
        number                 id,
        string                 name,
        Editor.SelectorMode    mode,
        Editor.SelectorBranch* branches,
        Editor.ParamValue*     params,
        Editor.Modulator*      modulators,
        Editor.NoteFXLane?     note_fx,
        Editor.AudioFXLane?    post_fx,
        Editor.PresetRef?      preset,
        boolean                enabled,
        Editor.UserMeta?       meta
    )

    -- Selector branches are editor-level branch identities.
    -- Lowering materialization:
    --   • each branch becomes a branch-entry node in the container's MainChild
    --   • that node's MainChild contains the lowered serial graph of `chain`
    -- Editor invariants:
    --   • branch ids are stable within the container
    SelectorBranch = (
        number              id,
        string              name,
        Editor.DeviceChain  chain,
        Editor.UserMeta?    meta
    )

    -- Editor invariants:
    --   • ManualSelect.selected_index must reference an existing branch
    --   • VelocitySwitch.thresholds must be monotonic
    --   • selector mode legality is constrained by the container's intended
    --     note/control usage and should be checked here before lowering
    SelectorMode
        = ManualSelect(number selected_index)
        | RoundRobin | FreeRobin | FreeVoice
        | Keyswitch(number lowest_note)
        | CCSwitched(number cc)
        | ProgramChange
        | VelocitySwitch(number* thresholds)

    -- SplitContainer is a first-class user concept at Editor level.
    -- Lowering contract:
    --   • lowers to one Authored.Node, typically kind=SubGraph()
    --   • owns a MainChild graph whose layout is Split(...)
    --   • each Editor.SplitBand materializes as a graph-local branch-entry
    --     node whose MainChild is the lowered serial graph of band.chain
    --   • Authored.SplitBand.node_id points at that branch-entry node
    --   • kind lowers into Authored.SplitKind
    --   • crossover values lower into Authored.SplitBand records
    --   • preset/meta may remain editor-only provenance/document metadata
    SplitContainer = (
        number               id,
        string               name,
        Editor.SplitKind     kind,
        Editor.SplitBand*    bands,
        Editor.ParamValue*   params,
        Editor.Modulator*    modulators,
        Editor.NoteFXLane?   note_fx,
        Editor.AudioFXLane?  post_fx,
        Editor.PresetRef?    preset,
        boolean              enabled,
        Editor.UserMeta?     meta
    )

    SplitKind
        = FreqSplit
        | TransientSplit
        | LoudSplit
        | MidSideSplit
        | LeftRightSplit
        | NoteSplit

    -- Split bands are editor-level branch identities plus split metadata.
    -- Lowering materialization:
    --   • each band becomes a branch-entry node in the container's MainChild
    --   • that node's MainChild contains the lowered serial graph of `chain`
    -- Editor invariants:
    --   • band ids are stable within the container
    --   • crossover_value must be monotonic for ordered split kinds
    SplitBand = (
        number              id,
        string              name,
        number              crossover_value,
        Editor.DeviceChain  chain,
        Editor.UserMeta?    meta
    )

    -- GridContainer is the explicit patching surface.
    -- Lowering contract:
    --   • lowers to one Authored.Node, typically kind=SubGraph()
    --   • owns a MainChild graph whose layout is Free
    --   • patch internals lower directly into Authored.Graph content
    --   • note_fx/post_fx remain regular child graph roles on the container
    --   • preset/meta may remain editor-only provenance/document metadata
    GridContainer = (
        number               id,
        string               name,
        Editor.GridPatch     patch,
        Editor.ParamValue*   params,
        Editor.Modulator*    modulators,
        Editor.NoteFXLane?   note_fx,
        Editor.AudioFXLane?  post_fx,
        Editor.PresetRef?    preset,
        boolean              enabled,
        Editor.UserMeta?     meta
    )

    -- GridPatch is the editor-level free patch document.
    -- Lowering contract:
    --   • lowers to Authored.Graph(layout=Free)
    --   • GridModule -> Authored.Node
    --   • GridCable  -> Authored.Wire
    --   • GridSource -> Authored.PreCord
    --   • GridPort   -> Authored.GraphPort
    -- Editor invariants:
    --   • module ids are unique within the patch
    --   • port ids are unique within inputs and within outputs
    --   • cable endpoints must reference valid module/port pairs
    GridPatch = (
        number               id,
        Editor.GridPort*     inputs,
        Editor.GridPort*     outputs,
        Editor.GridModule*   modules,
        Editor.GridCable*    cables,
        Editor.GridSource*   sources,
        Editor.GridDomain    domain
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Graph
    }

    GridDomain = NoteDomain | AudioDomain | HybridDomain | ControlDomain

    GridPort = (
        number id,
        string name,
        Editor.PortHint hint,
        number channels,
        boolean optional
    )

    GridModule = (
        number               id,
        string               name,
        Authored.NodeKind    kind,
        Editor.ParamValue*   params,
        boolean              enabled,
        number?              x,
        number?              y,
        Editor.UserMeta?     meta
    )

    GridCable = (
        number from_module_id,
        number from_port,
        number to_module_id,
        number to_port
    )

    GridSource = (
        number to_module_id,
        number to_port,
        Editor.GridSourceKind kind,
        number? arg0
    )

    GridSourceKind
        = DevicePhase | GlobalPhase
        | NotePitch | NoteGate | NoteVelocity
        | NotePressure | NoteTimbre | NoteGain
        | AudioIn | AudioInL | AudioInR
        | PreviousNote

    -- These are first-class user-visible lanes/tabs in Bitwig-style UX.
    -- Lowering contract:
    --   • NoteFXLane  -> ChildGraph(NoteFXChild, SerialGraph(...))
    --   • AudioFXLane -> ChildGraph(PostFXChild, SerialGraph(...))
    -- They exist here to preserve the user's editing model even though
    -- Authored regularizes them as child graph roles.
    -- Editor invariants:
    --   • NoteFXLane legality must be enforced at the editor layer
    --   • empty lanes may be allowed as explicit authoring state if desired
    NoteFXLane = (Editor.DeviceChain chain)
    AudioFXLane = (Editor.DeviceChain chain)

    -- Modulators are first-class at Editor level because Bitwig-style UX
    -- treats them as attached device elements, not hidden graph internals.
    -- Lowering contract:
    --   • each modulator creates one Authored.Node in modulation context
    --   • the owning device receives one Authored.ModSlot
    --   • mappings lower to Authored.ModRoute
    --   • per_voice lowers directly to ModSlot.per_voice
    -- Editor invariants:
    --   • modulator ids are stable within the owning device scope
    --   • mapping targets must refer to params reachable within the owning
    --     editor scope
    Modulator = (
        number                 id,
        string                 name,
        Authored.NodeKind      kind,
        Editor.ParamValue*     params,
        Editor.ModulationMap*  mappings,
        boolean                per_voice,
        boolean                enabled
    )
    methods {
        lower(LowerCtx ctx) -> Authored.ModSlot
    }

    ModulationMap = (
        number  target_device_id,
        number  target_param_id,
        number  depth,
        boolean bipolar,
        number? scale_modulator_id,
        number? scale_param_id
    )

    -- ParamValue is intentionally parallel to Authored.Param.
    -- It exists at Editor level so the user can directly manipulate values,
    -- automation, smoothing, and combine semantics before lowering.
    -- Editor invariants:
    --   • param ids are stable within the owning object scope
    --   • default/min/max should already form a legal range here
    ParamValue = (
        number                id,
        string                name,
        number                default_value,
        number                min_value,
        number                max_value,
        Editor.ParamSource    source,
        Editor.CombineMode    combine,
        Editor.Smoothing      smoothing
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Param
    }

    ParamSource
        = StaticValue(number value)
        | AutomationRef(Editor.AutoCurve curve)

    AutoCurve = (
        Editor.AutoPoint* points,
        Editor.InterpMode mode
    )

    AutoPoint  = (number time_beats, number value)
    InterpMode = Linear | Smoothstep | Hold
    CombineMode = Replace | Add | Multiply | ModMin | ModMax
    Smoothing   = NoSmoothing | Lag(number ms)

    PortHint
        = AudioHint | ControlHint | GateHint
        | PitchHint | PhaseHint | TriggerHint

    -- Editor clip structures are intentionally close to Authored clips.
    -- The user already thinks in these terms, so little extra sugar is
    -- needed before lowering. Meta may preserve user-facing color/comment
    -- document information even when it does not affect DSP.
    -- Editor invariants:
    --   • clip ids are stable identities
    --   • start/duration/fade relationships must already be legal here
    Clip = (
        number             id,
        Editor.ClipContent content,
        number start_beats, number duration_beats,
        number source_offset_beats, number lane,
        boolean muted,
        Editor.ParamValue gain,
        Editor.FadeSpec? fade_in,
        Editor.FadeSpec? fade_out,
        Editor.UserMeta?   meta
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Clip
    }

    ClipContent
        = AudioContent(number audio_asset_id)
        | NoteContent(number note_asset_id)

    FadeSpec  = (number duration_beats, Editor.FadeCurve curve)
    FadeCurve = LinearFade | EqualPower | SCurve | ExpoFade

    Slot = (
        number                 slot_index,
        Editor.SlotContent     content,
        Editor.LaunchBehavior  behavior,
        boolean                enabled
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Slot
    }

    SlotContent
        = EmptySlot
        | ClipSlot(number clip_id)
        | StopSlot

    LaunchBehavior = (
        Editor.LaunchMode mode,
        Editor.Quantize?  quantize_override,
        boolean legato, boolean retrigger,
        Editor.FollowAction? follow
    )

    LaunchMode = Trigger | Gate | Toggle | Repeat

    FollowAction = (
        Editor.FollowKind kind,
        number weight_a, number weight_b,
        number? target_scene_id
    )

    FollowKind
        = FNone | FNext | FPrev | FFirst
        | FLast | FOther | FRandom | FStop

    Scene = (
        number id, string name,
        Editor.SceneSlot* slots,
        Editor.Quantize? quantize_override,
        number? tempo_override
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Scene
    }

    SceneSlot = (number track_id, number slot_index, boolean stop_others)

    -- Sends also remain close to Authored because the user-facing concept
    -- already matches the semantic concept closely.
    -- Editor invariants:
    --   • send ids are stable within the owning track
    --   • target_track_id must not create illegal routing policies at the
    --     editor level
    Send = (
        number            id,
        number            target_track_id,
        Editor.ParamValue level,
        boolean           pre_fader,
        boolean           enabled
    )
    methods {
        lower(LowerCtx ctx) -> Authored.Send
    }
}


-- ================================================================
-- VIEW SLICE
-- DAW-specific interaction/projection semantics.
-- This slice references Editor semantics and lowers to TerraUI Decl.
-- It is not the generic UI compiler; TerraUI owns Decl -> Bound -> Plan
-- -> Kernel. View only specifies what DAW views exist, what they point at,
-- which anchors they expose, and which Editor commands they may emit.
-- ================================================================
module View {

    -- Design axioms:
    --   • View references Editor objects; it does not duplicate them.
    --   • View owns application-specific interaction semantics, not generic
    --     UI layout/rendering semantics.
    --   • Semantic ids come from Editor. TerraUI keys are derived from them
    --     during lowering to TerraUI Decl.
    --   • Anchors are local visual targets, not semantic object identity.
    --   • View-local state (tabs, scroll memory, split ratios, collapse) may
    --     live here; musical/project truth must stay in Editor.
    --   • View is normally derived from Editor + session state; it is not the
    --     canonical saved project document in the way Editor is.
    --   • TerraUI action dispatch must come back to Editor command semantics,
    --     never bypass them with ad hoc mutations.

    -- Root is the application view tree for the current editor session.
    -- Construction policy:
    --   • usually derived from Editor.Project + current app/session context
    --   • may be cached or partially persisted as workspace/session state
    --   • should not become the authoritative project save format
    Root = (
        View.Shell         shell,
        View.Focus         focus,
        View.SessionState* session_state
    ) unique
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    SemanticRef
        = ProjectRef
        | TrackRef(number track_id)
        | DeviceRef(number device_id)
        | LayerRef(number container_id, number layer_id)
        | SelectorBranchRef(number container_id, number branch_id)
        | SplitBandRef(number container_id, number band_id)
        | GridModuleRef(number device_id, number module_id)
        | ClipRef(number clip_id)
        | SceneRef(number scene_id)
        | SendRef(number track_id, number send_id)
        | ParamRef(number owner_id, number param_id)
        | ModulatorRef(number device_id, number modulator_id)

    -- ChainRef canonical encoding guidance for TerraUI key derivation:
    --   TrackChain(7)                -> "track_chain/7"
    --   DeviceNoteFX(42)             -> "device_note_fx/42"
    --   DevicePostFX(42)             -> "device_post_fx/42"
    --   LayerChain(100,3)            -> "layer_chain/100/3"
    --   SelectorBranchChain(120,2)   -> "selector_chain/120/2"
    --   SplitBandChain(130,1)        -> "split_chain/130/1"
    ChainRef
        = TrackChain(number track_id)
        | DeviceNoteFX(number device_id)
        | DevicePostFX(number device_id)
        | LayerChain(number container_id, number layer_id)
        | SelectorBranchChain(number container_id, number branch_id)
        | SplitBandChain(number container_id, number band_id)

    Shell = (
        View.TransportBar transport,
        View.MainArea     main_area,
        View.Sidebar*     sidebars,
        View.StatusBar?   status_bar
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    MainArea
        = ArrangementMain(View.ArrangementView arrangement,
                          View.DevicePanel? detail_panel)
        | LauncherMain(View.LauncherView launcher,
                       View.DevicePanel? detail_panel)
        | MixerMain(View.MixerView mixer,
                    View.DevicePanel? detail_panel)
        | HybridMain(View.ArrangementView arrangement,
                     View.LauncherView launcher,
                     View.MixerView mixer,
                     View.DevicePanel? detail_panel)

    Sidebar
        = BrowserSidebar(View.BrowserView browser)
        | InspectorSidebar(View.InspectorView inspector)

    StatusBar = (
        string left_text,
        string? center_text,
        string? right_text
    )

    Focus = (
        View.Selection     selection,
        View.ActiveSurface active_surface
    )

    Selection
        = NoSelection
        | SelectedTrack(number track_id)
        | SelectedDevice(number device_id)
        | SelectedClip(number clip_id)
        | SelectedScene(number scene_id)
        | SelectedGridModule(number device_id, number module_id)
        | SelectedModulator(number device_id, number modulator_id)

    ActiveSurface
        = ArrangementSurface
        | LauncherSurface
        | MixerSurface
        | DeviceSurface(number device_id)
        | GridSurface(number device_id)
        | InspectorSurface

    -- SessionState is explicitly UI-local/workspace-local state.
    -- It may be persisted separately from Editor.Project if desired.
    SessionState
        = SplitRatioState(string key, number value)
        | ScrollState(string key, number x, number y)
        | TabState(string key, string active_tab)
        | CollapseState(string key, boolean open)

    TransportBar = (
        boolean show_tempo,
        boolean show_time_sig,
        boolean show_loop,
        boolean show_quantize
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    ArrangementView = (
        number* visible_track_ids,
        View.ArrangementLane* lanes
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    ArrangementLane = (
        number            track_id,
        View.Identity     identity,
        View.Anchor*      anchors,
        View.CommandBind* commands
    )

    LauncherView = (
        number* visible_track_ids,
        number* visible_scene_ids,
        View.LauncherColumn* columns
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    LauncherColumn = (
        number            track_id,
        View.Identity     identity,
        View.Anchor*      anchors,
        View.CommandBind* commands
    )

    -- MixerAnchor lowering guidance:
    --   • MixerRootA   -> local anchor like "root"
    --   • MixerHeaderA -> local anchor like "header"
    --   • MixerTitleA  -> local anchor like "title"
    --   • MixerMeterA  -> local anchor like "meter"
    --   • MixerVolumeA -> local anchor like "volume"
    --   • MixerPanA    -> local anchor like "pan"
    --   • MixerSendA should encode send identity deterministically,
    --     e.g. "send_12"
    --   • MixerOutputA -> local anchor like "output"
    --   • anchor naming is local to the keyed strip subtree, not global
    MixerAnchor = (
        View.MixerAnchorKind kind,
        number? send_id
    )

    MixerAnchorKind
        = MixerRootA
        | MixerHeaderA
        | MixerTitleA
        | MixerMeterA
        | MixerVolumeA
        | MixerPanA
        | MixerMuteA
        | MixerSoloA
        | MixerArmA
        | MixerMonitorA
        | MixerSendA
        | MixerOutputA

    -- MixerCommand lowering guidance:
    --   • action_id should be deterministic and mixer-surface scoped
    --   • track_id is always the semantic track target
    --   • send_id identifies a concrete semantic send when relevant
    --   • target_track_id carries semantic routing payloads
    --   • bool_value is used only for flag-like commands; level/value changes
    --     should still route through semantic param-setting commands
    MixerCommand = (
        string action_id,
        View.MixerCommandKind kind,
        number track_id,
        number? send_id,
        number? target_track_id,
        boolean? bool_value
    )

    MixerCommandKind
        = MCCSetTrackFlags
        | MCCSetTrackOutput
        | MCCSetTrackVolume
        | MCCSetTrackPan
        | MCCSetSendLevel
        | MCCSetSendMode
        | MCCAddSend
        | MCCRemoveSend

    -- MixerView is the track-level mixing surface derived from Editor.Track
    -- mixer semantics, not from implicit UI-only faders.
    -- It should preserve track ordering from the projected Editor subset and
    -- derive one keyed strip subtree per visible track.
    MixerView = (
        number* visible_track_ids,
        View.MixerStrip* strips
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    -- Canonical mixer-strip projection for one Editor.Track.
    -- Typical semantic->UI mapping:
    --   • track_id -> header/title, arm/mute/solo/monitor controls
    --   • Editor.Track.volume/pan -> primary mixer controls
    --   • Editor.Track.sends -> send controls / send section
    --   • output/group routing stay semantic and emit Editor commands
    -- Typical commands:
    --   • CmdSetTrackFlags
    --   • CmdSetTrackOutput
    --   • CmdSetParamValue (volume/pan/send level)
    -- Concrete lowering guidance:
    --   • the strip root usually lowers to one keyed TerraUI column subtree
    --   • meter, title, fader, pan, mute/solo/arm, send controls, and output
    --     routing affordances should be exposed through deterministic anchors
    --   • TerraUI actions should dispatch semantic track/send payloads rather
    --     than relying on widget-local position alone
    MixerStrip = (
        number               track_id,
        View.Identity        identity,
        View.MixerAnchor*    anchors,
        View.MixerCommand*   commands
    )

    DevicePanel
        = ChainPanel(View.DeviceChainView chain)
        | DevicePanelSingle(View.DeviceView device)
        | GridPanel(View.GridPatchView patch)

    -- Canonical chain projection for Bitwig-style device editing.
    -- Projection policy:
    --   • chain_ref identifies the Editor-visible chain scope
    --   • entries correspond to concrete Editor.Device ids in chain order
    --   • commands should cover insertion, movement, wrapping, and removal
    -- Lowering to TerraUI Decl should usually produce:
    --   • one keyed chain root derived from identity
    --   • one ordered device-card subtree per DeviceEntry
    --   • local anchors for insertion points and card-local affordances
    --   • TerraUI actions that dispatch back into the listed Editor commands
    -- Example semantic path:
    --   Editor.DeviceChain
    --     -> View.DeviceChainView(chain_ref,...,entries=[...])
    --     -> TerraUI Decl row/column/scroll composition for the chain editor
    -- Concrete lowering guidance:
    --   • the chain root usually lowers to one keyed TerraUI container node
    --   • each DeviceEntry lowers to one keyed subtree using the entry identity
    --   • chain insert/drop anchors lower to local TerraUI anchors whose names
    --     are deterministic functions of at_index / device_id
    --   • command action ids should be deterministic and surface-specific
    --     (e.g. "chain.add_device", "device.move", "device.wrap.layer")
    DeviceChainView = (
        View.ChainRef            chain_ref,
        View.Identity            identity,
        View.DeviceChainAnchor*  anchors,
        View.DeviceChainCommand* commands,
        View.DeviceEntry*        entries
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    -- One rendered device entry/card inside a chain projection.
    -- Typical anchors:
    --   • title
    --   • enable_toggle
    --   • note_fx_tab
    --   • post_fx_tab
    --   • insert_before / insert_after
    -- Typical commands:
    --   • CmdSetParamValue
    --   • CmdMoveDevice
    --   • CmdRemoveDevice
    --   • wrapping commands when the surface exposes them
    DeviceEntry = (
        number               device_id,
        View.Identity        identity,
        View.DeviceEntryAnchor* anchors,
        View.DeviceEntryCommand* commands
    )

    -- DeviceView selects the specialized editor metaphor for one device.
    -- Native devices usually lower to a card/inspector surface.
    -- Container variants usually lower to specialized subviews (layers,
    -- selector lanes, split bands, grid patch editor) rather than forcing a
    -- generic graph canvas by default.
    -- Container lane records below make those specialized surfaces typed and
    -- commandable rather than implicit conventions in projection code.
    DeviceView
        = NativeDeviceView(number device_id,
                           View.Identity identity,
                           View.Anchor* anchors,
                           View.CommandBind* commands)
        | LayerContainerView(number device_id,
                             View.Identity identity,
                             View.Anchor* anchors,
                             View.CommandBind* commands,
                             View.LayerLane* layers)
        | SelectorContainerView(number device_id,
                                View.Identity identity,
                                View.Anchor* anchors,
                                View.CommandBind* commands,
                                View.SelectorLane* branches)
        | SplitContainerView(number device_id,
                             View.Identity identity,
                             View.Anchor* anchors,
                             View.CommandBind* commands,
                             View.SplitLane* bands)
        | GridContainerView(number device_id,
                            View.Identity identity,
                            View.Anchor* anchors,
                            View.CommandBind* commands)
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    LayerLane = (
        number                  container_id,
        number                  layer_id,
        View.Identity           identity,
        View.LayerLaneAnchor*   anchors,
        View.LayerLaneCommand*  commands
    )

    SelectorLane = (
        number                     container_id,
        number                     branch_id,
        View.Identity              identity,
        View.SelectorLaneAnchor*   anchors,
        View.SelectorLaneCommand*  commands
    )

    SplitLane = (
        number                  container_id,
        number                  band_id,
        View.Identity           identity,
        View.SplitLaneAnchor*   anchors,
        View.SplitLaneCommand*  commands
    )

    LayerLaneAnchor = (
        View.LayerLaneAnchorKind kind
    )

    LayerLaneAnchorKind
        = LayerLaneRootA
        | LayerLaneHeaderA
        | LayerLaneTitleA
        | LayerLaneMuteA
        | LayerLaneVolumeA
        | LayerLanePanA
        | LayerLaneChainA
        | LayerLaneInsertA

    LayerLaneCommand = (
        string action_id,
        View.LayerLaneCommandKind kind,
        number container_id,
        number layer_id,
        number? at_index,
        boolean? bool_value
    )

    LayerLaneCommandKind
        = LLCCSetLayerMix
        | LLCCMoveLayer
        | LLCCRemoveLayer
        | LLCCAddDevice
        | LLCCMoveDevice
        | LLCCWrapInLayer
        | LLCCWrapInSelector
        | LLCCWrapInSplit

    SelectorLaneAnchor = (
        View.SelectorLaneAnchorKind kind
    )

    SelectorLaneAnchorKind
        = SelectorLaneRootA
        | SelectorLaneHeaderA
        | SelectorLaneTitleA
        | SelectorLaneChainA
        | SelectorLaneInsertA

    SelectorLaneCommand = (
        string action_id,
        View.SelectorLaneCommandKind kind,
        number container_id,
        number branch_id,
        number? at_index
    )

    SelectorLaneCommandKind
        = SLCCMoveBranch
        | SLCCRemoveBranch
        | SLCCAddDevice
        | SLCCMoveDevice
        | SLCCWrapInLayer
        | SLCCWrapInSelector
        | SLCCWrapInSplit
        | SLCCSetSelectorMode

    SplitLaneAnchor = (
        View.SplitLaneAnchorKind kind
    )

    SplitLaneAnchorKind
        = SplitLaneRootA
        | SplitLaneHeaderA
        | SplitLaneTitleA
        | SplitLaneCrossoverA
        | SplitLaneChainA
        | SplitLaneInsertA

    SplitLaneCommand = (
        string action_id,
        View.SplitLaneCommandKind kind,
        number container_id,
        number band_id,
        number? at_index,
        number? number_value
    )

    SplitLaneCommandKind
        = SpLCCSetCrossover
        | SpLCCMoveBand
        | SpLCCRemoveBand
        | SpLCCAddDevice
        | SpLCCMoveDevice
        | SpLCCWrapInLayer
        | SpLCCWrapInSelector
        | SpLCCWrapInSplit

    -- Canonical free-patch projection. Ports/anchors here are visual/editor
    -- interaction affordances over Editor.GridPatch, not new semantic DSP ids.
    -- Lowering to TerraUI Decl should usually produce:
    --   • one keyed patch root derived from identity
    --   • one positioned subtree per GridModuleView
    --   • local anchors for module bodies and ports
    --   • actions for move/connect/disconnect/source binding routed back into
    --     Editor grid commands rather than generic UI-local mutation
    -- Concrete lowering guidance:
    --   • the patch root usually lowers to one keyed canvas/scroll subtree
    --   • each module lowers to one keyed positioned subtree using module
    --     identity derived from (device_id,module_id)
    --   • port anchors should encode both module and port identity
    --   • cable interactions should dispatch semantic payloads using module ids
    --     and port numbers, never by referring to UI-local anchor names alone
    GridPatchView = (
        number                device_id,
        View.Identity         identity,
        View.GridPatchAnchor* anchors,
        View.GridPatchCommand* commands,
        View.GridModuleView*  modules,
        View.GridCableView*   cables
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    -- One rendered module body within a GridPatchView.
    -- Anchors should identify stable editor affordances like body, input ports,
    -- output ports, and header/title regions.
    -- The module subtree should normally be keyed from (device_id,module_id)
    -- through the enclosing View.Identity rules.
    GridModuleView = (
        number                 device_id,
        number                 module_id,
        View.Identity          identity,
        View.GridModuleAnchor* anchors,
        View.GridModuleCommand* commands
    )

    -- Typed anchors/commands for the chain editor so the central DAW surface
    -- can be specified precisely rather than only by convention.
    -- DeviceChainAnchor lowering guidance:
    --   • ChainRootA  -> local anchor like "root"
    --   • ChainHeaderA -> local anchor like "header"
    --   • ChainInsertA/ChainDropA should encode `at_index` deterministically,
    --     e.g. "insert_3" / "drop_3"
    --   • device_id may be used when an anchor is attached to an adjacent card
    --   • anchor naming is local to the keyed chain subtree, not global
    DeviceChainAnchor = (
        View.DeviceChainAnchorKind kind,
        number? device_id,
        number? at_index
    )

    DeviceChainAnchorKind
        = ChainRootA
        | ChainInsertA
        | ChainDropA
        | ChainHeaderA

    -- DeviceChainCommand lowering guidance:
    --   • action_id should be a deterministic TerraUI-facing name scoped to the
    --     chain editor surface
    --   • chain_ref is the authoritative semantic chain target
    --   • device_id / at_index provide semantic payload, not UI-local targets
    --   • action dispatch must always normalize back into Editor commands
    DeviceChainCommand = (
        string action_id,
        View.DeviceChainCommandKind kind,
        View.ChainRef chain_ref,
        number? device_id,
        number? at_index
    )

    DeviceChainCommandKind
        = DCCAddDevice
        | DCCMoveDevice
        | DCCRemoveDevice
        | DCCWrapInLayer
        | DCCWrapInSelector
        | DCCWrapInSplit
        | DCCToggleDeviceEnabled

    -- DeviceEntryAnchor lowering guidance:
    --   • these lower to local anchors inside the keyed device-entry subtree
    --   • names should be stable and conventional ("title", "enable_toggle",
    --     "note_fx_tab", "post_fx_tab", ...)
    DeviceEntryAnchor = (
        View.DeviceEntryAnchorKind kind
    )

    DeviceEntryAnchorKind
        = DeviceCardA
        | DeviceTitleA
        | DeviceEnableToggleA
        | DeviceNoteFXTabA
        | DevicePostFXTabA
        | DeviceInsertBeforeA
        | DeviceInsertAfterA

    -- DeviceEntryCommand lowering guidance:
    --   • action_id should be a deterministic TerraUI-facing name scoped to a
    --     device card surface
    --   • device_id is the semantic command target; anchors are only for local
    --     visual targeting
    --   • at_index is used when the card exposes insertion/wrapping positions
    DeviceEntryCommand = (
        string action_id,
        View.DeviceEntryCommandKind kind,
        number device_id,
        number? at_index
    )

    DeviceEntryCommandKind
        = DECCSetParamValue
        | DECCMoveDevice
        | DECCRemoveDevice
        | DECCToggleDeviceEnabled
        | DECCWrapInLayer
        | DECCWrapInSelector
        | DECCWrapInSplit

    -- GridPatchAnchor lowering guidance:
    --   • PatchRootA -> local anchor like "root"
    --   • PatchCanvasA -> local anchor like "canvas"
    --   • PatchDropA should encode patch-local insertion/drop targeting
    --   • module_id / port_id may be carried when the patch root exposes a
    --     root-level target associated with a concrete module/port
    GridPatchAnchor = (
        View.GridPatchAnchorKind kind,
        number? module_id,
        number? port_id
    )

    GridPatchAnchorKind
        = PatchRootA
        | PatchCanvasA
        | PatchDropA
        | PatchSelectionA

    -- GridPatchCommand lowering guidance:
    --   • action_id should be deterministic and patch-surface scoped
    --   • device_id identifies the owning GridContainer / GridPatch scope
    --   • module/port payloads are semantic editor payloads for grid commands
    --   • connect/disconnect actions should carry explicit endpoint ids rather
    --     than reconstructing them from UI-local anchor names
    GridPatchCommand = (
        string action_id,
        View.GridPatchCommandKind kind,
        number device_id,
        number? module_id,
        number? port_id,
        number? from_module_id,
        number? from_port,
        number? to_module_id,
        number? to_port
    )

    GridPatchCommandKind
        = GPCCAddModule
        | GPCCRemoveModule
        | GPCCMoveModule
        | GPCCConnectCable
        | GPCCDisconnectCable
        | GPCCBindSource
        | GPCCUnbindSource

    -- GridModuleAnchor lowering guidance:
    --   • ModuleBodyA   -> local anchor like "body"
    --   • ModuleHeaderA -> local anchor like "header"
    --   • ModuleTitleA  -> local anchor like "title"
    --   • ModuleInputPortA / ModuleOutputPortA should encode port identity
    --     deterministically, e.g. "in_0", "out_1"
    --   • anchor naming is local to the keyed module subtree, not global
    GridModuleAnchor = (
        View.GridModuleAnchorKind kind,
        number? port_id
    )

    GridModuleAnchorKind
        = ModuleBodyA
        | ModuleHeaderA
        | ModuleTitleA
        | ModuleInputPortA
        | ModuleOutputPortA

    -- GridModuleCommand lowering guidance:
    --   • action_id should be deterministic and module-surface scoped
    --   • device_id + module_id identify the semantic module target
    --   • port_id identifies the semantic source/bind port on the module
    --   • completion payloads may carry destination module/port explicitly
    GridModuleCommand = (
        string action_id,
        View.GridModuleCommandKind kind,
        number device_id,
        number module_id,
        number? port_id,
        number? to_module_id,
        number? to_port
    )

    GridModuleCommandKind
        = GMCCMoveModule
        | GMCCRemoveModule
        | GMCCBeginCable
        | GMCCCompleteCable
        | GMCCBindSource

    GridCableView = (
        number from_module_id, number from_port,
        number to_module_id,   number to_port
    )

    InspectorView = (
        View.Selection     selection,
        View.Identity      identity,
        View.Anchor*       anchors,
        View.CommandBind*  commands,
        View.InspectorTab* tabs
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    InspectorTab
        = TrackTab(number track_id)
        | DeviceTab(number device_id)
        | ClipTab(number clip_id)
        | ModulatorTab(number device_id, number modulator_id)
        | ParamTab(number owner_id, number param_id)

    BrowserView = (
        string source_kind,
        string? query,
        View.CommandBind* commands
    )
    methods {
        to_decl(ViewCtx ctx) -> TerraUIDecl
    }

    -- Identity is the declarative bridge from semantic identity to TerraUI
    -- instance identity. Lowering policy:
    --   • semantic_ref identifies the real Editor object
    --   • key_space distinguishes multiple UI projections of the same object
    --   • TerraUI `key`/`scope` is derived from (key_space, semantic_ref)
    --   • derivation must be deterministic and path-stable for the same view
    --     projection so TerraUI local state persists correctly
    -- Canonical naming convention:
    --   • derive a TerraUI scope/key path as:
    --       <key_space>/<semantic_ref encoding>
    --   • semantic_ref encodings should be textual and unambiguous, e.g.:
    --       TrackRef(7)                    -> "track/7"
    --       DeviceRef(42)                  -> "device/42"
    --       LayerRef(100,3)                -> "layer/100/3"
    --       SelectorBranchRef(120,2)       -> "selector_branch/120/2"
    --       SplitBandRef(130,1)            -> "split_band/130/1"
    --       GridModuleRef(200,8)           -> "grid_module/200/8"
    --       ClipRef(55)                    -> "clip/55"
    --       SendRef(7,2)                   -> "send/7/2"
    --       ParamRef(42,9)                 -> "param/42/9"
    --   • example full keys:
    --       "mixer_strip/track/7"
    --       "device_chain/track_chain/7"
    --       "device_entry/device/42"
    -- Typical examples:
    --   • ("mixer_strip", TrackRef(7)) -> keyed strip instance for track 7
    --   • ("device_chain", TrackChain(7)) -> keyed chain root for that scope
    --   • ("device_entry", DeviceRef(42)) -> keyed card instance for device 42
    Identity = (
        string key_space,
        View.SemanticRef semantic_ref
    )

    -- Anchors are local named visual targets exposed intentionally by a view.
    -- They lower to TerraUI local anchors, not to Editor semantic ids.
    -- Anchor names should be deterministic within the keyed subtree that owns
    -- them, so floating/tooltip/gesture targeting is stable.
    -- Canonical naming convention:
    --   • anchors are local leaf names inside a keyed subtree
    --   • simple singleton anchors use conventional names like:
    --       "root", "header", "title", "meter", "body", "canvas"
    --   • indexed anchors append semantic payload deterministically, e.g.:
    --       "insert_3", "drop_3", "send_12", "in_0", "out_1"
    --   • command payloads must never rely on anchor parsing alone; anchors
    --     are for local targeting, while semantic payload remains explicit
    Anchor = (
        string name,
        string purpose
    )

    PayloadValue
        = PNumber(number value)
        | PString(string value)
        | PSemanticRef(View.SemanticRef ref)

    PayloadField = (
        string name,
        View.PayloadValue value
    )

    -- CommandKind mirrors the semantic Editor command families. The View
    -- layer may restrict which commands are available from a given surface,
    -- but it should not invent a second mutation model.
    -- Generic CommandBind remains useful for broad surfaces; heavily edited
    -- surfaces like the chain editor, grid patch editor, mixer, and typed
    -- container lanes may also introduce local command records (see
    -- DeviceChainCommand / DeviceEntryCommand, GridPatchCommand /
    -- GridModuleCommand, MixerCommand, and the lane command types above).
    CommandKind
        = CmdSetTrackFlags
        | CmdSetTrackOutput
        | CmdSetParamValue
        | CmdAddDevice
        | CmdMoveDevice
        | CmdRemoveDevice
        | CmdWrapDevicesInLayer
        | CmdWrapDevicesInSelector
        | CmdWrapDevicesInSplit
        | CmdAddLayer
        | CmdMoveLayer
        | CmdRemoveLayer
        | CmdSetLayerMix
        | CmdSetSelectorMode
        | CmdAddSelectorBranch
        | CmdRemoveSelectorBranch
        | CmdAddSplitBand
        | CmdSetSplitBandCrossover
        | CmdAddModulator
        | CmdSetModulationDepth
        | CmdConnectGridCable
        | CmdDisconnectGridCable
        | CmdBindGridSource
        | CmdAddClip
        | CmdMoveClip
        | CmdResizeClip
        | CmdSetSlotBehavior
        | CmdLaunchSlot
        | CmdLaunchScene
        | CmdStopTrack

    -- action_id is the TerraUI-facing interaction name; kind/payload are the
    -- semantic command dispatch target. Payload values should primarily carry
    -- semantic refs/ids, not UI-local anchors.
    CommandBind = (
        string action_id,
        View.CommandKind kind,
        View.PayloadField* payload
    )
}


-- ================================================================
-- PHASE 1: AUTHORED
-- Canonical semantic graph document.
-- ================================================================
module Authored {

    -- Design axioms:
    --   • Authored is the semantic source of truth. Richness belongs here.
    --   • Prefer invalid states to be unrepresentable by the authored types.
    --   • Resolve should fix references, normalize sugar, and lower intent;
    --     it should not invent semantics that were absent in Authored.
    --   • NodeKind is intentionally broad: one algebra of processing things.
    --   • Graph, Node, Wire, Param, and child graphs are the core
    --     primitives; new features should usually reduce to these.
    --   • Cross-object checks still exist, but they should be narrow:
    --     ownership, identity, ordering, and reference consistency.
    --
    -- ────────────────────────────────────────────────────────
    -- Project
    -- ────────────────────────────────────────────────────────
    Project = (
        string                  name,
        string?                 author,
        number                  format_version,
        Authored.Transport      transport,
        Authored.Track*         tracks,
        Authored.Scene*         scenes,
        Authored.TempoMap       tempo_map,
        Authored.AssetBank      assets
    ) unique
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Project
    }

    Transport = (
        number sample_rate, number buffer_size,
        number bpm, number swing,
        number time_sig_num, number time_sig_den,
        Authored.Quantize launch_quantize,
        boolean looping,
        Authored.TimeRange? loop_range
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Transport
    }

    TimeRange = (number start_beats, number end_beats)

    Quantize
        = QNone | Q1_64 | Q1_32 | Q1_16 | Q1_8
        | Q1_4 | Q1_2 | Q1Bar | Q2Bars | Q4Bars

    TempoMap = (
        Authored.TempoPoint* tempo,
        Authored.SigPoint*   signatures
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.TempoMap
    }

    TempoPoint = (number at_beats, number bpm)
    SigPoint   = (number at_beats, number num, number den)

    -- ────────────────────────────────────────────────────────
    -- Tracks
    --
    -- Track-level mixer semantics are explicit here: input routing,
    -- volume, and pan are part of the authored document, not hidden UI.
    -- Authored is the canonical semantic graph document, not merely a UI
    -- backing store: anything that survives below Editor should justify its
    -- existence as real semantic structure.
    -- ────────────────────────────────────────────────────────
    Track = (
        number              id,
        string              name,
        number              channels,
        Authored.TrackInput input,
        Authored.Param      volume,
        Authored.Param      pan,
        Authored.Graph      device_graph,
        Authored.Clip*      clips,
        Authored.Slot*      launcher_slots,
        Authored.Send*      sends,
        number?             output_track_id,
        number?             group_track_id,
        boolean muted, boolean soloed,
        boolean armed, boolean monitor_input,
        boolean phase_invert
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Track
    }

    -- Authored form of track recording / monitoring source semantics.
    -- This should already be resolved enough that later phases can compile it
    -- as routing codes rather than rediscovering editor intent.
    TrackInput
        = NoInput
        | AudioInput(number device_id, number channel)
        | MIDIInput(number device_id, number channel)
        | TrackInputTap(number track_id, boolean post_fader)

    Send = (
        number id, number target_track_id,
        Authored.Param level,
        boolean pre_fader, boolean enabled
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Send
    }

    -- ────────────────────────────────────────────────────────
    -- Clips
    -- ────────────────────────────────────────────────────────
    Clip = (
        number id,
        Authored.ClipContent content,
        number start_beats, number duration_beats,
        number source_offset_beats, number lane,
        boolean muted,
        Authored.Param gain,
        Authored.FadeSpec? fade_in,
        Authored.FadeSpec? fade_out
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Clip
    }

    ClipContent
        = AudioContent(number audio_asset_id)
        | NoteContent(number note_asset_id)

    FadeSpec  = (number duration_beats, Authored.FadeCurve curve)
    FadeCurve = LinearFade | EqualPower | SCurve | ExpoFade

    -- ────────────────────────────────────────────────────────
    -- Launcher
    -- ────────────────────────────────────────────────────────
    Slot = (
        number slot_index,
        Authored.SlotContent content,
        Authored.LaunchBehavior behavior,
        boolean enabled
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Slot
    }

    SlotContent
        = EmptySlot
        | ClipSlot(number clip_id)
        | StopSlot

    LaunchBehavior = (
        Authored.LaunchMode mode,
        Authored.Quantize?  quantize_override,
        boolean legato, boolean retrigger,
        Authored.FollowAction? follow
    )

    LaunchMode = Trigger | Gate | Toggle | Repeat

    FollowAction = (
        Authored.FollowKind kind,
        number weight_a, number weight_b,
        number? target_scene_id
    )

    FollowKind
        = FNone | FNext | FPrev | FFirst
        | FLast | FOther | FRandom | FStop

    Scene = (
        number id, string name,
        Authored.SceneSlot* slots,
        Authored.Quantize? quantize_override,
        number? tempo_override
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Scene
    }

    SceneSlot = (number track_id, number slot_index, boolean stop_others)

    -- ────────────────────────────────────────────────────────
    -- THE GRAPH
    --
    -- The universal container. Everything is a Graph.
    -- This is also why there is no separate macro system here: graph and node
    -- construction already provide the structural metaprogramming substrate.
    --
    -- A track's device chain is a Graph with layout=Serial.
    -- A Grid patch is a Graph with layout=Free.
    -- A Layer container is a Graph with layout=Parallel.
    -- A Selector is a Graph with layout=Switched.
    -- A FreqSplit is a Graph with layout=Split.
    -- All of these contain Nodes and Wires.
    --
    -- Graphs nest: a Node can contain child Graphs
    -- with explicit roles (pre-fx, post-fx, note-fx, main child).
    -- Graph boundaries are explicit through graph input/output ports.
    -- ────────────────────────────────────────────────────────
    -- Invariants:
    --   • Prefer invalid states to be unrepresentable in the authored type
    --     system itself; extra checking should mainly cover references,
    --     graph-local ownership, and other cross-object constraints.
    --   • Graph port ids are unique within inputs and within outputs.
    --   • Every non-optional graph output must be derivable from node
    --     outputs, graph inputs, or normalized context sources.
    --   • Layout-specific references must point at nodes owned by this graph.
    --   • Unresolved domain crossings are invalid unless legalized by
    --     explicit bridge semantics during resolve.
    Graph = (
        number               id,
        Authored.GraphPort*  inputs,
        Authored.GraphPort*  outputs,
        Authored.Node*       nodes,
        Authored.Wire*       wires,
        Authored.PreCord*    pre_cords,
        Authored.GraphLayout layout,
        Authored.SignalDomain domain
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Graph
    }

    -- GraphLayout is the graph-level composition contract.
    -- It defines both default connectivity and branch semantics.
    --
    -- Serial:
    --   Wires may be omitted. Eligible nodes are chained in author order.
    --   Explicit wires override or refine that default.
    --   If inference yields ambiguity, resolve must fail rather than guess.
    --
    -- Free:
    --   Connectivity is entirely explicit. No implicit chaining.
    --
    -- Parallel:
    --   Graph inputs fan out to each configured branch entry node.
    --   Branch outputs are mixed back to the graph outputs using
    --   per-layer volume/pan/mute controls.
    --
    -- Switched:
    --   Graph inputs feed a selected branch or branches according to
    --   the selector mode. Only active branch outputs contribute.
    --
    -- Split:
    --   Graph inputs are partitioned by the split policy, routed into
    --   configured bands/branches, then recombined at graph outputs.
    GraphLayout
        = Serial
        | Free
        | Parallel(Authored.LayerConfig* layers)
        | Switched(Authored.SwitchConfig config)
        | Split(Authored.SplitConfig config)

    -- node_id must refer to a node owned by this graph and intended as a
    -- branch entry for the parallel composition.
    LayerConfig = (
        number node_id,
        Authored.Param volume,
        Authored.Param pan,
        boolean muted
    )

    -- node_ids must be valid graph-local branch entry nodes.
    -- Empty switched graphs are invalid.
    SwitchConfig = (
        Authored.SelectorMode mode,
        number* node_ids
    )

    SelectorMode
        = ManualSelect | RoundRobin | FreeRobin | FreeVoice
        | Keyswitch(number lowest_note)
        | CCSwitched(number cc)
        | ProgramChange
        | VelocitySplit(number* thresholds)

    -- bands must reference valid graph-local branch entry nodes.
    -- Where ordering matters (e.g. frequency thresholds), resolve must
    -- enforce monotonic crossover values.
    SplitConfig = (
        Authored.SplitKind kind,
        Authored.SplitBand* bands
    )

    SplitKind
        = FreqSplit
        | TransientSplit
        | LoudSplit
        | MidSideSplit
        | LeftRightSplit
        | NoteSplit

    SplitBand = (
        number  node_id,
        number  crossover_value
    )

    -- Graph-level authoring policy, not a complete signal type system.
    -- Fine-grained signal legality is determined by node/port semantics.
    SignalDomain
        = NoteDomain | AudioDomain | HybridDomain | ControlDomain

    -- Explicit graph boundary ports. Nested graphs must declare what
    -- they accept and what they emit rather than relying on inference.
    -- Validation should ensure port ids are unique and channel counts are
    -- compatible with the graph's intended use.
    GraphPort = (
        number id,
        string name,
        Authored.PortHint hint,
        number channels,
        boolean optional
    )

    -- ────────────────────────────────────────────────────────
    -- Wires
    --
    -- Explicit dataflow edges between node ports.
    -- Wires do not imply gain, mixing, branch activation, or graph
    -- boundary behavior; those belong to params/layout semantics.
    -- Each wire endpoint must resolve to a valid node/port pair with a
    -- legal signal-kind connection under the authored type semantics.
    -- In Serial layout, wires are optional (inferred).
    -- In Free layout, wires are the graph.
    -- ────────────────────────────────────────────────────────
    Wire = (
        number from_node_id,
        number from_port,
        number to_node_id,
        number to_port
    )

    -- Context-bound inputs. These are authored sugar for
    -- runtime/external sources that normalize during resolve.
    -- By Resolved/Classified, they should behave like ordinary source
    -- references, not as a second independent wiring system.
    PreCord = (
        number to_node_id, number to_port,
        Authored.PreCordKind kind,
        number? arg0
    )

    PreCordKind
        = PCDevicePhase | PCGlobalPhase
        | PCNotePitch | PCNoteGate | PCNoteVelocity
        | PCNotePressure | PCNoteTimbre | PCNoteGain
        | PCAudioIn | PCAudioInL | PCAudioInR
        | PCPreviousNote

    -- ────────────────────────────────────────────────────────
    -- Nodes
    --
    -- The universal processing unit. A Node is:
    --   • a DAW device (synth, EQ, compressor, plugin)
    --   • a Grid module (oscillator, filter, math op)
    --   • a container (this node hosts one or more child graphs)
    --   • a modulator (LFO, ADSR, sidechain follower)
    --
    -- Every node has params, ports, mod slots, and optional child graphs.
    -- Child graphs are regularized through roles
    -- instead of bespoke fields. The NodeKind determines the DSP.
    -- Child-graph role legality is part of the node kind's authored
    -- semantics, not an afterthought layered on top.
    -- ────────────────────────────────────────────────────────
    Node = (
        number               id,
        string               name,
        Authored.NodeKind    kind,
        Authored.Param*      params,
        Authored.Port*       inputs,
        Authored.Port*       outputs,
        Authored.ModSlot*    mod_slots,
        Authored.ChildGraph* child_graphs,
        boolean              enabled,
        number?              x_pos,
        number?              y_pos
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Node
    }

    ChildGraph = (
        Authored.ChildGraphRole role,
        Authored.Graph          graph
    )

    -- Child graph roles give structural attachment points without
    -- requiring bespoke node fields.
    -- A node should not contain duplicate roles unless that role is
    -- explicitly defined as multi-instance by the node kind's semantics.
    ChildGraphRole = MainChild | PreFXChild | PostFXChild | NoteFXChild

    -- Port ids must be unique within a node's input set and output set.
    -- `hint` is an authoring/UI signal category hint, not the full runtime
    -- type system; authored legality may still be stricter than the hint.
    Port = (
        number id, string name,
        Authored.PortHint hint,
        number channels,
        boolean optional,
        number? default_value
    )

    PortHint
        = AudioHint | ControlHint | GateHint
        | PitchHint | PhaseHint | TriggerHint

    -- ────────────────────────────────────────────────────────
    -- Modulator slots
    -- ────────────────────────────────────────────────────────
    ModSlot = (
        Authored.Node       modulator,
        Authored.ModRoute*  routings,
        boolean             per_voice
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.ModSlot
    }

    ModRoute = (
        number  target_param_id,
        number  depth,
        boolean bipolar,
        number? scale_mod_slot,
        number? scale_param_id
    )

    -- ────────────────────────────────────────────────────────
    -- Parameters
    -- ────────────────────────────────────────────────────────
    Param = (
        number              id,
        string              name,
        number              default_value,
        number              min_value,
        number              max_value,
        Authored.ParamSource source,
        Authored.CombineMode combine,
        Authored.Smoothing   smoothing
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.Param
    }

    ParamSource
        = StaticValue(number value)
        | AutomationRef(Authored.AutoCurve curve)

    AutoCurve = (
        Authored.AutoPoint* points,
        Authored.InterpMode mode
    )

    AutoPoint  = (number time_beats, number value)
    InterpMode = Linear | Smoothstep | Hold
    CombineMode = Replace | Add | Multiply | ModMin | ModMax
    Smoothing   = NoSmoothing | Lag(number ms)

    -- ────────────────────────────────────────────────────────
    -- Node kinds
    --
    -- THE one sum type that carries all variety.
    -- Everything from DAW devices to Grid modules to
    -- containers to modulators. One enum.
    --
    -- This breadth is intentional: NodeKind is the canonical authored
    -- algebra of processing things, not a smell to be factored away.
    -- Container-ness is determined by node kind + child_graphs.
    -- Semantic legality should live here in the authored type system as
    -- much as possible, with resolve handling cross-reference checks and
    -- lowering rather than inventing meaning ad hoc.
    -- No separate container concept needed.
    -- ────────────────────────────────────────────────────────
    NodeKind

        -- ── DAW instruments ──
        = BasicSynth(Authored.SynthCfg cfg)
        | Sampler(number zone_bank_id)
        | DrumMachine(Authored.DrumPad* pads)
        | Polymer(number osc1, number osc2, number filter_type)
        | HWInstrument(number midi_port, number audio_port)

        -- ── DAW audio FX ──
        | GainNode()
        | PanNode()
        | EQNode(Authored.EQBand* bands)
        | CompressorNode()
        | GateNode()
        | DelayNode()
        | ReverbNode()
        | ChorusNode()
        | FlangerNode()
        | PhaserNode()
        | SaturatorNode(Authored.SatCurve curve)
        | ConvolverNode(number ir_id)
        | HWFXNode(number out_port, number in_port)

        -- ── DAW note FX ──
        | ArpNode()
        | ChordNode(Authored.ChordNote* notes)
        | NoteFilterNode()
        | NoteQuantizeNode()
        | NoteLengthNode()
        | NoteEchoNode()
        | NoteLatchNode()
        | DribbleNode()
        | RicochetNode()

        -- ── Containers (these use child_graphs) ──
        | SubGraph()

        -- ── Grid oscillators ──
        | SineOsc() | SawOsc() | SquareOsc()
        | TriangleOsc() | PulseOsc()
        | NoiseGen(Authored.NoiseColor color)
        | Wavetable(number table_id)
        | FMOp()
        | PhaseDistortion()
        | Karplus()
        | Resonator()
        | SamplePlayer(number asset_id)
        | Granular(number asset_id)
        | SubOsc()

        -- ── Grid filters ──
        | SVF() | Ladder() | CombF() | Allpass()
        | Formant() | SampleAndHold()
        | DCBlock() | SlewFilter() | OnePoleLow() | OnePoleHigh()

        -- ── Grid shapers ──
        | Wavefolder() | Clipper(Authored.ClipMode mode)
        | Saturate() | Quantize(number levels)
        | Rectifier(Authored.RectMode mode)
        | Mirror() | WaveShape(number* table)
        | Bitcrush()

        -- ── Grid math ──
        | AddN() | SubN() | MulN() | DivN() | ModN()
        | AbsN() | NegN() | MinN() | MaxN()
        | ClampN() | MapN() | PowN() | LogN()
        | SinN() | CosN() | AtanN()
        | FloorN() | CeilN() | FracN()
        | LerpN() | SmoothN()

        -- ── Grid logic ──
        | GTNode() | LTNode() | EqNode(number tol)
        | AndN() | OrN() | NotN() | XorN()
        | FlipFlopN() | LatchN()

        -- ── Grid mix/routing ──
        | MergeN() | SplitN()
        | StereoMergeN() | StereoSplitN()
        | CrossfadeN() | SwitchN(number inputs)
        | AttenuateN() | OffsetN()
        | PanN() | WidthN() | InvertN()
        | DelayLineN(number max_samples)
        | FeedbackInN() | FeedbackOutN()

        -- ── Grid phase ──
        | PhasorN() | PhaseScaleN()
        | PhaseOffsetN() | PhaseQuantN()
        | PhaseFormantN() | PhaseWrapN()
        | PhaseResetN() | PhaseTrigN()
        | PhaseStallN()

        -- ── Grid envelopes ──
        | ADEnv() | ADSREnv() | ADHSREnv()
        | AREnv() | DecayEnv()
        | MSEGEnv(Authored.MSEGPt* points)
        | SlewEnv() | FollowerEnv() | SampleEnv()

        -- ── Grid triggers ──
        | TrigRise() | TrigFall() | TrigChange()
        | ClockDiv() | ClockMul()
        | Burst() | ProbGate(number prob)
        | Delay1() | TransportGateN()

        -- ── Grid data ──
        | StepSeq(number steps)
        | Counter(number max)
        | Accum() | StackN(number size)
        | DataTable(number* values)
        | BezierN(Authored.BezierPt* pts)
        | SlewLimit()

        -- ── Grid I/O ──
        | AudioInN() | AudioOutN()
        | NoteInN() | NoteOutN()
        | CVInN(number port) | CVOutN(number port)
        | PitchInN() | GateInN()
        | VelocityInN() | PressureInN()
        | TimbreInN() | GainInN()
        | ValueInN() | ValueOutN()

        -- ── Grid display (no-op in compiled code) ──
        | ScopeN() | SpectrumN() | ValueDispN() | NoteN()

        -- ── Modulators ──
        | LFOMod(Authored.LFOShape shape)
        | ADSRMod() | ADHSRMod()
        | MSEGMod(Authored.MSEGPt* points)
        | StepsMod(number steps)
        | SidechainMod(number? source_track_id)
        | FollowerMod()
        | ExprMod(Authored.ExprKind kind)
        | KeyTrackMod()
        | RandomMod()
        | MacroKnob()
        | ButtonMod() | ButtonsMod()
        | VectorMod(number dims)
        | MIDICCMod(number cc)
        | HWCVInMod(number port)
        | Channel16Mod()

        -- ── External plugins ──
        | VSTPlugin(PluginHandle handle, string format)
        | CLAPPlugin(PluginHandle handle)

        -- ── Routing/utility ──
        | AudioReceiver(number? source_track_id)
        | NoteReceiver(number? source_track_id)
        | CVOutDevice(number port)
        | MeterNode() | SpectrumAnalyzer()
    methods {
        resolve(ResolveCtx ctx) -> Resolved.NodeKindRef
    }

    -- ── Sub-types ──

    SynthCfg = (
        Authored.OscCfg* oscillators,
        Authored.FilterCfg? filter,
        number voice_count,
        Authored.VoiceStack? voice_stack,
        boolean mono, number glide_ms
    )

    OscCfg = (Authored.OscShape shape, number tune, number fine, number level)

    OscShape
        = OscSine | OscSaw | OscSquare | OscTri | OscPulse
        | OscNoise | OscWT(number table_id)
        | OscFM(number ratio, number amount)

    FilterCfg = (Authored.FilterShape shape, number key_track)

    FilterShape
        = FLP12 | FLP24 | FHP12 | FHP24
        | FBP12 | FBP24 | FNotch | FComb
        | FSVF | FLadder | FFormant

    VoiceStack = (number count, Authored.StackSpread spread, number detune)
    StackSpread = SpreadLinear | SpreadPower | SpreadRandom

    DrumPad   = (number note, Authored.Graph chain, number? choke_group)
    EQBand    = (Authored.EQBandType type)
    EQBandType = LowShelf | HighShelf | Peak | LowCut | HighCut
    SatCurve   = Tanh | SoftClip | HardClip | Tube | FoldBack
    ChordNote  = (number semitone, number vel_scale)
    NoiseColor = White | Pink | Brown | Blue | Violet
    ClipMode   = HardClipM | SoftClipM | FoldClipM
    RectMode   = FullRect | HalfRect | SoftRect
    LFOShape   = Sine | Triangle | Square | Saw | SampleHoldLFO | CustomLFO
    ExprKind   = Velocity | Pressure | Timbre | PitchBendE
               | ReleaseVel | NoteGainE | NotePanE
    MSEGPt     = (number time, number value, number curve)
    BezierPt   = (number x, number y, number cx1, number cy1, number cx2, number cy2)

    -- ────────────────────────────────────────────────────────
    -- Assets
    -- ────────────────────────────────────────────────────────
    AssetBank = (
        Authored.AudioAsset*     audio,
        Authored.NoteAsset*      notes,
        Authored.WavetableAsset* wavetables,
        Authored.IRAsset*        irs,
        Authored.ZoneBank*       zone_banks
    )
    methods {
        resolve(ResolveCtx ctx) -> Resolved.AssetBank
    }

    AudioAsset     = (number id, string path, number sample_rate,
                      number channels, number length_samples)
    NoteAsset      = (number id, Authored.NoteEvent* events,
                      number loop_start_beats, number loop_end_beats)
    NoteEvent
        = NoteOn(number at_beats, number pitch, number velocity)
        | NoteOff(number at_beats, number pitch)
        | CC(number at_beats, number cc, number value)
        | PitchBend(number at_beats, number value)
        | PolyPressure(number at_beats, number pitch, number pressure)
    WavetableAsset = (number id, string path, number frames)
    IRAsset        = (number id, string path, number sample_rate)
    ZoneBank       = (number id, Authored.SampleZone* zones)
    SampleZone     = (string path, number root,
                      number lo_note, number hi_note,
                      number lo_vel, number hi_vel,
                      number loop_start, number loop_end,
                      Authored.LoopMode loop_mode)
    LoopMode       = NoLoop | LoopFwd | LoopPingPong | LoopRev
}


-- ================================================================
-- PHASE 2: RESOLVED
-- Ticks, codes, flat tables. Zero sum types.
-- ================================================================
module Resolved {

    Project = (
        Resolved.Transport  transport,
        Resolved.TempoMap   tempo_map,
        Resolved.Track*     tracks,
        Resolved.Scene*     scenes,

        Resolved.Graph*     all_graphs,
        Resolved.GraphPort* all_graph_ports,
        Resolved.Node*      all_nodes,
        Resolved.ChildGraphRef* all_child_graph_refs,
        Resolved.Wire*      all_wires,
        Resolved.Param*     all_params,
        Resolved.ModSlot*   all_mod_slots,
        Resolved.ModRoute*  all_mod_routes,
        Resolved.AutoCurve* all_curves,

        Resolved.AssetBank  assets
    ) unique
    methods {
        classify(ClassifyCtx ctx) -> Classified.Project
    }

    Transport = (
        number sample_rate, number buffer_size,
        number bpm, number swing,
        number time_sig_num, number time_sig_den,
        number launch_quant_code,
        boolean looping,
        number loop_start_tick, number loop_end_tick
    )
    methods {
        classify(ClassifyCtx ctx) -> Classified.Transport
    }

    TempoMap = (Resolved.TempoSeg* segments)
    methods {
        classify(ClassifyCtx ctx) -> Classified.TempoMap
    }

    TempoSeg = (number start_tick, number bpm, number base_sample, number samples_per_tick)

    Track = (
        number id, string name, number channels,
        number input_kind_code, number input_arg0, number input_arg1,
        number volume_param_id, number pan_param_id,
        number device_graph_id,
        number first_clip, number clip_count,
        number first_slot, number slot_count,
        number* send_ids,
        number? output_track_id, number? group_track_id,
        boolean muted, boolean soloed,
        boolean armed, boolean monitor_input,
        boolean phase_invert
    )
    methods {
        classify(ClassifyCtx ctx) -> Classified.Track
    }

    Send = (number id, number target_track_id,
            number level_param_id,
            boolean pre_fader, boolean enabled)

    Clip = (
        number id, number content_kind, number asset_id,
        number start_tick, number duration_tick,
        number source_offset_tick, number lane,
        boolean muted, number gain_param_id,
        number fade_in_tick, number fade_in_curve_code,
        number fade_out_tick, number fade_out_curve_code
    )

    Slot = (
        number slot_index, number slot_kind, number clip_id,
        number launch_mode_code, number quant_code,
        boolean legato, boolean retrigger,
        number follow_kind_code,
        number follow_weight_a, number follow_weight_b,
        number? follow_target_scene_id,
        boolean enabled
    )

    Scene = (number id, string name,
             Resolved.SceneSlot* slots,
             number quant_code, number? tempo_override)
    SceneSlot = (number track_id, number slot_index, boolean stop_others)

    -- ── Flattened signal graph ──

    -- layout_code: 0=serial, 1=free, 2=parallel, 3=switched, 4=split
    Graph = (
        number id, number layout_code, number domain_code,
        number first_input, number input_count,
        number first_output, number output_count,
        number* node_ids, number* wire_ids,
        number first_precord, number precord_count,
        number arg0, number arg1, number arg2, number arg3
    )
    methods {
        classify(ClassifyCtx ctx) -> Classified.Graph
    }

    Node = (
        number id, number node_kind_code,
        number first_param, number param_count,
        number first_input, number input_count,
        number first_output, number output_count,
        number first_mod_slot, number mod_slot_count,
        number first_child_graph_ref, number child_graph_ref_count,
        boolean enabled,
        PluginHandle? plugin_handle,
        number arg0, number arg1, number arg2, number arg3
    )
    methods {
        classify(ClassifyCtx ctx) -> Classified.Node
    }

    Wire = (number from_signal, number to_signal)

    GraphPort = (
        number id, string name,
        number hint_code,
        number channels,
        boolean optional
    )

    ChildGraphRef = (
        number graph_id,
        number role_code
    )

    NodeKindRef = (number kind_code)

    Param = (
        number id, number node_id, string name,
        number default_value, number min_value, number max_value,
        Resolved.ParamSourceRef source,
        number combine_code, number smoothing_code, number smoothing_ms
    )
    methods {
        classify(ClassifyCtx ctx) -> Classified.Param
    }

    ParamSourceRef = (number source_kind, number value, number? curve_id)

    AutoCurve = (number id, Resolved.AutoPoint* points, number interp_code)
    AutoPoint = (number tick, number value)

    ModSlot = (
        number slot_index, number parent_node_id,
        number modulator_node_id, boolean per_voice,
        number first_route, number route_count
    )
    methods {
        classify(ClassifyCtx ctx) -> Classified.ModSlot
    }

    ModRoute = (
        number mod_slot_index, number target_param_id,
        number depth, boolean bipolar,
        number? scale_mod_slot, number? scale_param_id
    )
    methods {
        classify(ClassifyCtx ctx) -> Classified.ModRoute
    }

    EQBand = (number type_code)

    -- ── Assets ──
    AssetBank = (
        Resolved.AudioAsset* audio,
        Resolved.NoteAsset* notes,
        Resolved.WavetableAsset* wavetables,
        Resolved.IRAsset* irs,
        Resolved.ZoneBank* zone_banks
    )

    AudioAsset     = (number id, string path, number sample_rate,
                      number channels, number length_samples)
    NoteAsset      = (number id, Resolved.NoteEvent* events,
                      number loop_start_tick, number loop_end_tick)
    NoteEvent      = (number kind, number tick, number d0, number d1, number d2)
    WavetableAsset = (number id, string path, number frames)
    IRAsset        = (number id, string path, number sample_rate)
    ZoneBank       = (number id, Resolved.SampleZone* zones)
    SampleZone     = (string path, number root,
                      number lo_note, number hi_note,
                      number lo_vel, number hi_vel,
                      number loop_start, number loop_end,
                      number loop_mode_code)
}


-- ================================================================
-- PHASE 3: CLASSIFIED
-- Binding = (rate_class, slot). Zero sum types.
-- ================================================================
module Classified {

    Project = (
        Classified.Transport  transport,
        Classified.TempoMap   tempo_map,
        Classified.Track*     tracks,
        Classified.Scene*     scenes,

        Classified.Graph*     graphs,
        Classified.GraphPort* graph_ports,
        Classified.Node*      nodes,
        Classified.ChildGraphRef* child_graph_refs,
        Classified.Wire*      wires,
        Classified.FeedbackPair* feedback_pairs,
        Classified.Param*     params,
        Classified.ModSlot*   mod_slots,
        Classified.ModRoute*  mod_routes,

        Classified.Literal*   literals,
        Classified.InitOp*    init_ops,
        Classified.BlockOp*   block_ops,
        Classified.BlockPt*   block_pts,
        Classified.SampleOp*  sample_ops,
        Classified.EventOp*   event_ops,
        Classified.VoiceOp*   voice_ops,

        number total_signals,
        number total_state_slots
    ) unique
    methods {
        schedule(ScheduleCtx ctx) -> Scheduled.Project
    }

    Transport = (
        number sample_rate, number buffer_size,
        number bpm, number swing,
        number time_sig_num, number time_sig_den,
        number launch_quant_code,
        boolean looping,
        number loop_start_tick, number loop_end_tick
    )
    methods {
        schedule(ScheduleCtx ctx) -> Scheduled.Transport
    }

    TempoMap = (Classified.TempoSeg* segments)
    methods {
        schedule(ScheduleCtx ctx) -> Scheduled.TempoMap
    }

    TempoSeg = (number start_tick, number end_tick, number bpm,
                number base_sample, number samples_per_tick)

    Track = (
        number id, number channels,
        number input_kind_code, number input_arg0, number input_arg1,
        Classified.Binding volume,
        Classified.Binding pan,
        number device_graph_id,
        number first_clip, number clip_count,
        number first_slot, number slot_count,
        number* send_ids,
        number? output_track_id, number? group_track_id,
        boolean muted_structural, boolean solo_structural,
        boolean armed, boolean monitor_input
    )
    methods {
        schedule(ScheduleCtx ctx) -> Scheduled.TrackPlan
    }

    Send = (number id, number target_track_id,
            Classified.Binding level,
            boolean pre_fader, boolean enabled)

    Clip = (
        number id, number content_kind, number asset_id,
        number start_tick, number end_tick,
        number source_offset_tick, number lane,
        boolean muted, Classified.Binding gain,
        number fade_in_tick, number fade_in_curve_code,
        number fade_out_tick, number fade_out_curve_code
    )

    Slot = (
        number slot_index, number slot_kind, number clip_id,
        number launch_mode_code, number quant_code,
        boolean legato, boolean retrigger,
        number follow_kind_code,
        number follow_weight_a, number follow_weight_b,
        number? follow_target_scene_id,
        boolean enabled
    )

    Scene = (number id, number first_slot, number slot_count,
             number quant_code, number? tempo_override)

    -- ── Signal graph (topologically sorted) ──

    Graph = (
        number id, number layout_code, number domain_code,
        number first_input, number input_count,
        number first_output, number output_count,
        number* node_ids,
        number first_wire, number wire_count,
        number first_feedback, number feedback_count,
        number first_signal, number signal_count
    )
    methods {
        schedule(ScheduleCtx ctx) -> Scheduled.GraphPlan
    }

    Node = (
        number id, number node_kind_code,
        number first_param, number param_count,
        number signal_offset, number state_offset,
        number state_size,
        number first_mod_slot, number mod_slot_count,
        number first_child_graph_ref, number child_graph_ref_count,
        boolean enabled,
        number runtime_state_slot,
        number arg0, number arg1, number arg2, number arg3
    )
    methods {
        schedule(ScheduleCtx ctx) -> Scheduled.NodeJob
    }

    Wire = (number from_signal, number to_signal, number weight)

    GraphPort = (
        number id,
        number hint_code,
        number channels,
        boolean optional,
        number signal_base
    )

    ChildGraphRef = (
        number graph_id,
        number role_code
    )

    FeedbackPair = (
        number write_signal, number read_signal,
        number delay_state_slot
    )

    Param = (
        number id, number node_id,
        number default_value, number min_value, number max_value,
        Classified.Binding base_value,
        number combine_code,
        number smoothing_code, number smoothing_ms,
        number first_modulation, number modulation_count,
        number runtime_state_slot
    )

    ModSlot = (
        number slot_index, number parent_node_id,
        number modulator_node_id, boolean per_voice,
        number first_route, number route_count,
        Classified.Binding output_binding
    )

    ModRoute = (
        number mod_slot_index, number target_param_id,
        Classified.Binding depth, boolean bipolar,
        number? scale_binding_slot
    )

    EQBand = (number type_code,
              Classified.Binding freq,
              Classified.Binding gain,
              Classified.Binding q)

    -- rate_class: 0=literal 1=init 2=block 3=sample 4=event 5=voice
    Binding = (number rate_class, number slot)
    methods {
        schedule(ScheduleCtx ctx) -> Scheduled.Binding
    }

    Literal   = (number value)
    InitOp    = (number kind, number arg0, number arg1,
                 Classified.Binding i0, Classified.Binding? i1,
                 number state_slot)
    BlockOp   = (number kind, number first_pt, number pt_count,
                 number interp, number arg0,
                 Classified.Binding i0, Classified.Binding? i1)
    BlockPt   = (number tick, number value)
    SampleOp  = (number kind, Classified.Binding i0,
                 Classified.Binding? i1,
                 number arg0, number arg1, number arg2,
                 number state_slot)
    EventOp   = (number kind, number event_code,
                 number min_v, number max_v, number state_slot)
    VoiceOp   = (number kind, Classified.Binding i0,
                 Classified.Binding? i1,
                 number arg0, number arg1, number arg2,
                 number state_slot)
}


-- ================================================================
-- PHASE 4: SCHEDULED
-- Buffer slots, linear jobs, step sequence.
-- ================================================================
module Scheduled {

    Project = (
        Scheduled.Transport   transport,
        Scheduled.TempoMap    tempo_map,

        Scheduled.Buffer*     buffers,
        Scheduled.TrackPlan*  tracks,
        Scheduled.Step*       steps,

        Scheduled.GraphPlan*  graph_plans,
        Scheduled.NodeJob*    node_jobs,
        Scheduled.SendJob*    send_jobs,
        Scheduled.MixJob*     mix_jobs,
        Scheduled.OutputJob*  output_jobs,
        Scheduled.ClipJob*    clip_jobs,
        Scheduled.ModJob*     mod_jobs,

        Scheduled.LaunchEntry*  launch_entries,
        Scheduled.SceneEntry*   scene_entries,

        Scheduled.Binding*    param_bindings,
        Scheduled.InitOp*     init_ops,
        Scheduled.BlockOp*    block_ops,
        Scheduled.BlockPt*    block_pts,
        Scheduled.SampleOp*   sample_ops,
        Scheduled.EventOp*    event_ops,
        Scheduled.VoiceOp*    voice_ops,

        number total_buffers,
        number total_state_slots,
        number master_left, number master_right
    ) unique
    methods {
        compile(CompileCtx ctx) -> Kernel.Project
    }

    Transport = (
        number sample_rate, number buffer_size,
        number bpm, number swing,
        number time_sig_num, number time_sig_den,
        number launch_quant_code,
        boolean looping,
        number loop_start_tick, number loop_end_tick
    )

    TempoMap = (Scheduled.TempoSeg* segs)
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    TempoSeg = (number start_tick, number end_tick, number bpm,
                number base_sample, number samples_per_tick)

    Buffer = (number index, number channels,
              boolean interleaved, boolean persistent)

    TrackPlan = (
        number track_id,
        Scheduled.Binding volume,
        Scheduled.Binding pan,
        number input_kind_code, number input_arg0, number input_arg1,
        number first_step, number step_count,
        number work_buf, number aux_buf, number mix_in_buf,
        number out_left, number out_right,
        boolean is_master
    )

    Step = (
        number index,
        number clear_buf,
        number clip_job, number node_job,
        number mod_job, number send_job,
        number mix_job, number output_job
    )
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    GraphPlan = (
        number graph_id,
        number first_node_job, number node_job_count,
        number in_buf, number out_buf,
        number first_feedback, number feedback_count
    )
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    NodeJob = (
        number node_id, number kind_code,
        number in_buf, number out_buf,
        number first_param, number param_count,
        number state_slot, number state_size,
        number arg0, number arg1, number arg2, number arg3
    )
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    ClipJob = (
        number clip_id, number content_kind, number asset_id,
        number out_buf, number start_tick, number end_tick,
        number source_offset_tick,
        Scheduled.Binding gain,
        boolean reversed,
        number fade_in_tick, number fade_in_curve_code,
        number fade_out_tick, number fade_out_curve_code
    )
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    ModJob = (
        number mod_node_id, number parent_node_id,
        boolean per_voice,
        number first_route, number route_count,
        number output_state_slot,
        Scheduled.Binding output
    )
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    SendJob = (
        number source_buf, number target_buf,
        Scheduled.Binding level,
        boolean pre_fader, boolean enabled
    )
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    MixJob = (number source_buf, number target_buf, Scheduled.Binding gain)
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    OutputJob = (
        number source_buf, number out_left, number out_right,
        Scheduled.Binding gain, Scheduled.Binding pan
    )
    methods {
        compile(CompileCtx ctx) -> TerraQuote
    }

    LaunchEntry = (
        number track_id, number slot_index,
        number slot_kind, number clip_id,
        number launch_mode_code, number quant_code,
        boolean legato, boolean retrigger,
        number follow_kind_code,
        number follow_weight_a, number follow_weight_b,
        number? follow_target_scene_id,
        boolean enabled
    )

    SceneEntry = (
        number scene_id,
        number first_slot, number slot_count,
        number quant_code, number? tempo_override
    )

    Binding = (number rate_class, number slot)
    methods {
        compile_value(CompileCtx ctx) -> TerraQuote
    }

    InitOp   = (number kind, number arg0, number arg1,
                Scheduled.Binding i0, Scheduled.Binding? i1,
                number state_slot)
    BlockOp  = (number kind, number first_pt, number pt_count,
                number interp, number arg0,
                Scheduled.Binding i0, Scheduled.Binding? i1)
    BlockPt  = (number tick, number value)
    SampleOp = (number kind, Scheduled.Binding i0,
                Scheduled.Binding? i1,
                number arg0, number arg1, number arg2,
                number state_slot)
    EventOp  = (number kind, number event_code,
                number min_v, number max_v, number state_slot)
    VoiceOp  = (number kind, Scheduled.Binding i0,
                Scheduled.Binding? i1,
                number arg0, number arg1, number arg2,
                number state_slot)
}


-- ================================================================
-- PHASE 5: KERNEL
-- Zero sum types. Terra only.
-- ================================================================
module Kernel {

    Buffers = (
        TerraType mono_t,
        TerraType stereo_t,
        TerraType event_t,
        TerraType bus_array_t,
        TerraType state_t
    )

    State = (
        TerraType transport_t,
        TerraType control_t,
        TerraType dsp_t,
        TerraType launcher_t,
        TerraType voice_t,
        TerraType render_t
    )

    API = (
        TerraQuote init_fn,
        TerraQuote destroy_fn,
        TerraQuote render_block_fn,
        TerraQuote set_param_fn,
        TerraQuote queue_launch_fn,
        TerraQuote queue_scene_fn,
        TerraQuote stop_track_fn,
        TerraQuote note_on_fn,
        TerraQuote note_off_fn,
        TerraQuote poly_pressure_fn,
        TerraQuote cc_fn,
        TerraQuote pitch_bend_fn,
        TerraQuote timbre_fn,
        TerraQuote get_peak_fn,
        TerraQuote get_position_fn,
        TerraQuote get_param_fn,
        TerraQuote get_mod_fn
    )

    Project = (
        Kernel.Buffers buffers,
        Kernel.State   state,
        Kernel.API     api
    ) unique
    methods {
        entry_fn() -> TerraFunc
    }
}

]]

return D
