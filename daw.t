-- Ensure terraui submodule is on the require path.
do
    local root = debug.getinfo(1, "S").source:match("^@?(.*/)") or "./"
    local tui = root .. "terraui/?.t"
    if not package.terrapath:find(tui, 1, true) then
        package.terrapath = tui .. ";" .. package.terrapath
    end
    local tui_lua = root .. "terraui/?.lua;" .. root .. "terraui/?/init.lua"
    if not package.path:find(root .. "terraui", 1, true) then
        package.path = tui_lua .. ";" .. package.path
    end
end

import "lib/schema"

local is_terra_type = function(o) return terralib.types.istype(o) end
local is_terra_quote = terralib.isquote
local is_terra_func = terralib.isfunction
local is_plugin_handle = function(o) return type(o) == "userdata" end
local is_terraui_decl = function(o) return type(o) == "table" end

local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

--- Terra DAW v3: 7-phase signal-graph compiler for music production.
--- Everything is a signal graph. Device chains, grid patches, layer containers,
--- selectors, and freq splits are all Graph instances distinguished by layout.
--- One type, one compilation path.
local DAW = schema DAW
    doc "Terra DAW v3: 7-phase signal-graph compiler for music production."

    extern TerraType = is_terra_type
    extern TerraQuote = is_terra_quote
    extern TerraFunc = is_terra_func
    extern PluginHandle = is_plugin_handle
    extern TerraUIDecl = is_terraui_decl

    use TerraUI = require("lib/terraui_schema")

    pipeline Editor -> Authored -> Resolved -> Classified -> Scheduled -> Kernel
    pipeline Editor -> View -> TerraUI.Decl

    -- ════════════════════════════════════════════════════════════════
    -- PHASE 0: EDITOR
    -- User-authoring layer. Bitwig-shaped editing concepts.
    -- Captures what the musician directly manipulates.
    -- Lowers deterministically into Authored.
    -- ════════════════════════════════════════════════════════════════

    --- User-facing authoring state. Bitwig-shaped concepts: tracks, devices, clips.
    --- Commands operate on Editor types. Invalid states should be unrepresentable.
    --- This layer owns no transient UI state (selection, zoom, hover, drag).
    phase Editor
        --- Top-level project document. The canonical saved form.
        record Project
            name: string
            author: string?
            format_version: number
            transport: Transport
            tracks: Track*
            scenes: Scene*
            tempo_map: TempoMap
            --- Shared cross-phase type. AssetBank lives in Authored because the
            --- algebra is identical at both layers.
            assets: Authored.AssetBank
            unique
        end

        --- Audio engine and playback transport settings.
        record Transport
            sample_rate: number
            buffer_size: number
            bpm: number
            swing: number
            time_sig_num: number
            time_sig_den: number
            launch_quantize: Quantize
            looping: boolean
            loop_range: TimeRange?
        end

        --- Beat-based time range for loop boundaries.
        record TimeRange
            start_beats: number
            end_beats: number
        end

        --- Launch quantization grid values.
        enum Quantize
            doc "Quantize grid for clip launching and recording."
            QNone
            Q1_64
            Q1_32
            Q1_16
            Q1_8
            Q1_4
            Q1_2
            Q1Bar
            Q2Bars
            Q4Bars
        end

        --- Tempo automation points and time signature changes.
        record TempoMap
            tempo: TempoPoint*
            signatures: SigPoint*
        end

        --- A tempo change at a beat position.
        record TempoPoint
            at_beats: number
            bpm: number
        end

        --- A time signature change at a beat position.
        record SigPoint
            at_beats: number
            num: number
            den: number
        end

        --- Editor-only document metadata (color, comment, icon).
        record UserMeta
            color: string?
            comment: string?
            icon: string?
        end

        --- Canonical parameter owner path for commands and UI refs.
        enum ParamOwnerRef
            doc "Semantic owner path for parameter targeting."
            TrackOwner { track_id: number }
            DeviceOwner { device_id: number }
            GridModuleOwner { device_id: number, module_id: number }
            ModulatorOwner { device_id: number, modulator_id: number }
            LayerOwner { container_id: number, layer_id: number }
            SendOwner { track_id: number, send_id: number }
            ClipOwner { clip_id: number }
        end

        --- Preset/browser provenance linkage.
        record PresetRef
            kind: string
            uri: string
            revision: string?
        end

        --- One mixer track. Stable IDs across mutations.
        record Track
            id: number
            name: string
            channels: number
            kind: TrackKind
            input: TrackInput?
            volume: ParamValue
            pan: ParamValue
            devices: DeviceChain
            clips: Clip*
            launcher_slots: Slot*
            sends: Send*
            output_track_id: number?
            group_track_id: number?
            muted: boolean
            soloed: boolean
            armed: boolean
            monitor_input: boolean
            phase_invert: boolean
            meta: UserMeta?
        end

        --- Track classification for defaults and UI.
        enum TrackKind
            doc "User-facing track classification."
            AudioTrack
            InstrumentTrack
            HybridTrack
            GroupTrack
            MasterTrack
        end

        --- Track recording/monitoring source routing.
        enum TrackInput
            doc "Recording and monitoring source selection."
            NoInput
            AudioInput { device_id: number, channel: number }
            MIDIInput { device_id: number, channel: number }
            TrackInputTap { track_id: number, post_fader: boolean }
        end

        --- Serial device chain. Lowers to Graph(layout=Serial).
        record DeviceChain
            devices: Device*
        end

        --- User-visible device atom. Each lowers to one Authored.Node.
        enum Device
            doc "Editor-facing device types. Containers lower to graph+layout."
            NativeDevice { body: NativeDeviceBody }
            LayerDevice { body: LayerContainer }
            SelectorDevice { body: SelectorContainer }
            SplitDevice { body: SplitContainer }
            GridDevice { body: GridContainer }
        end

        --- Plain device panel payload.
        record NativeDeviceBody
            id: number
            name: string
            --- Shared cross-phase type. NodeKind is genuinely the same algebra
            --- at both Editor and Authored layers.
            kind: Authored.NodeKind
            params: ParamValue*
            modulators: Modulator*
            note_fx: NoteFXLane?
            post_fx: AudioFXLane?
            preset: PresetRef?
            enabled: boolean
            meta: UserMeta?
        end

        --- Parallel layer container. Lowers to Graph(layout=Parallel).
        record LayerContainer
            id: number
            name: string
            layers: Layer*
            params: ParamValue*
            modulators: Modulator*
            note_fx: NoteFXLane?
            post_fx: AudioFXLane?
            preset: PresetRef?
            enabled: boolean
            meta: UserMeta?
        end

        --- One layer branch with independent mix controls.
        record Layer
            id: number
            name: string
            chain: DeviceChain
            volume: ParamValue
            pan: ParamValue
            muted: boolean
            meta: UserMeta?
        end

        --- Switched selector container. Lowers to Graph(layout=Switched).
        record SelectorContainer
            id: number
            name: string
            mode: SelectorMode
            branches: SelectorBranch*
            params: ParamValue*
            modulators: Modulator*
            note_fx: NoteFXLane?
            post_fx: AudioFXLane?
            preset: PresetRef?
            enabled: boolean
            meta: UserMeta?
        end

        --- One selector branch.
        record SelectorBranch
            id: number
            name: string
            chain: DeviceChain
            meta: UserMeta?
        end

        --- Selector switching mode.
        enum SelectorMode
            doc "How the selector chooses active branches."
            ManualSelect { selected_index: number }
            RoundRobin
            FreeRobin
            FreeVoice
            Keyswitch { lowest_note: number }
            CCSwitched { cc: number }
            ProgramChange
            VelocitySwitch { thresholds: number* }
        end

        --- Frequency/transient/etc split container. Lowers to Graph(layout=Split).
        record SplitContainer
            id: number
            name: string
            kind: SplitKind
            bands: SplitBand*
            params: ParamValue*
            modulators: Modulator*
            note_fx: NoteFXLane?
            post_fx: AudioFXLane?
            preset: PresetRef?
            enabled: boolean
            meta: UserMeta?
        end

        --- Split routing policy.
        enum SplitKind
            doc "How the split partitions the signal."
            FreqSplit
            TransientSplit
            LoudSplit
            MidSideSplit
            LeftRightSplit
            NoteSplit
        end

        --- One split band with crossover threshold.
        record SplitBand
            id: number
            name: string
            crossover_value: number
            chain: DeviceChain
            meta: UserMeta?
        end

        --- Grid patching container. Lowers to Graph(layout=Free).
        record GridContainer
            id: number
            name: string
            patch: GridPatch
            params: ParamValue*
            modulators: Modulator*
            note_fx: NoteFXLane?
            post_fx: AudioFXLane?
            preset: PresetRef?
            enabled: boolean
            meta: UserMeta?
        end

        --- Free-patch document with modules, cables, and sources.
        record GridPatch
            id: number
            inputs: GridPort*
            outputs: GridPort*
            modules: GridModule*
            cables: GridCable*
            sources: GridSource*
            domain: GridDomain
        end

        --- Grid signal domain hint.
        enum GridDomain
            doc "Signal domain for grid patch."
            NoteDomain
            AudioDomain
            HybridDomain
            ControlDomain
        end

        --- Grid boundary port.
        record GridPort
            id: number
            name: string
            hint: PortHint
            channels: number
            optional: boolean
        end

        --- One grid processing module.
        record GridModule
            id: number
            name: string
            kind: Authored.NodeKind
            params: ParamValue*
            enabled: boolean
            x: number?
            y: number?
            meta: UserMeta?
        end

        --- Connection between grid modules.
        record GridCable
            from_module_id: number
            from_port: number
            to_module_id: number
            to_port: number
        end

        --- Context-bound grid input source.
        record GridSource
            to_module_id: number
            to_port: number
            kind: GridSourceKind
            arg0: number?
        end

        --- Grid source signal kinds.
        enum GridSourceKind
            doc "Pre-wired context sources for grid modules."
            DevicePhase
            GlobalPhase
            NotePitch
            NoteGate
            NoteVelocity
            NotePressure
            NoteTimbre
            NoteGain
            AudioIn
            AudioInL
            AudioInR
            PreviousNote
        end

        --- Note FX lane (pre-instrument note processing chain).
        record NoteFXLane
            chain: DeviceChain
        end

        --- Audio FX lane (post-device audio processing chain).
        record AudioFXLane
            chain: DeviceChain
        end

        --- Modulator attached to a device. Creates ModSlot in Authored.
        record Modulator
            id: number
            name: string
            kind: Authored.NodeKind
            params: ParamValue*
            mappings: ModulationMap*
            per_voice: boolean
            enabled: boolean
        end

        --- One modulation routing assignment.
        record ModulationMap
            target_device_id: number
            target_param_id: number
            depth: number
            bipolar: boolean
            scale_modulator_id: number?
            scale_param_id: number?
        end

        --- User-facing parameter value with source, combine, and smoothing.
        record ParamValue
            id: number
            name: string
            default_value: number
            min_value: number
            max_value: number
            source: ParamSource
            combine: CombineMode
            smoothing: Smoothing
        end

        --- Parameter value source (static or automated).
        enum ParamSource
            doc "Where the parameter gets its value."
            StaticValue { value: number }
            AutomationRef { curve: AutoCurve }
        end

        --- Automation curve with interpolation mode.
        record AutoCurve
            points: AutoPoint*
            mode: InterpMode
        end

        --- One automation breakpoint.
        record AutoPoint
            time_beats: number
            value: number
        end

        --- Automation interpolation between points.
        enum InterpMode
            doc "Interpolation mode between automation points."
            Linear
            Smoothstep
            Hold
        end

        --- How multiple modulation/automation sources combine.
        enum CombineMode
            doc "Parameter value combination mode."
            Replace
            Add
            Multiply
            ModMin
            ModMax
        end

        --- Parameter smoothing policy.
        enum Smoothing
            doc "Parameter smoothing for zipper-free transitions."
            NoSmoothing
            Lag { ms: number }
        end

        --- Port signal type hint for UI and validation.
        enum PortHint
            doc "Signal category hint for ports."
            AudioHint
            ControlHint
            GateHint
            PitchHint
            PhaseHint
            TriggerHint
        end

        --- Audio/note clip on a track timeline.
        record Clip
            id: number
            content: ClipContent
            start_beats: number
            duration_beats: number
            source_offset_beats: number
            lane: number
            muted: boolean
            gain: ParamValue
            fade_in: FadeSpec?
            fade_out: FadeSpec?
            meta: UserMeta?
        end

        --- Clip content type (audio reference or inline note region).
        enum ClipContent
            doc "What kind of content the clip contains."
            AudioContent { audio_asset_id: number }
            NoteContent { body: NoteRegion }
        end

        --- Native piano-roll editing document.
        record NoteRegion
            notes: Note*
            expr_lanes: NoteExprLane*
        end

        --- One semantic piano-roll note block.
        record Note
            id: number
            pitch: number
            start_beats: number
            duration_beats: number
            velocity: number
            release_velocity: number?
            muted: boolean
            meta: UserMeta?
        end

        --- Note expression lane kind.
        enum NoteExprKind
            doc "Per-note expression parameter types."
            NotePressureExpr
            NoteTimbreExpr
            NotePitchBendExpr
            NoteGainExpr
            NotePanExpr
        end

        --- Expression lane with breakpoints.
        record NoteExprLane
            kind: NoteExprKind
            points: NoteExprPoint*
        end

        --- Expression breakpoint, optionally attached to a note.
        record NoteExprPoint
            time_beats: number
            value: number
            note_id: number?
        end

        --- Fade envelope specification.
        record FadeSpec
            duration_beats: number
            curve: FadeCurve
        end

        --- Fade curve shape.
        enum FadeCurve
            doc "Fade envelope curve shapes."
            LinearFade
            EqualPower
            SCurve
            ExpoFade
        end

        --- Launcher slot on a track.
        record Slot
            slot_index: number
            content: SlotContent
            behavior: LaunchBehavior
            enabled: boolean
        end

        --- Slot content variant.
        enum SlotContent
            doc "What occupies a launcher slot."
            EmptySlot
            ClipSlot { clip_id: number }
            StopSlot
        end

        --- Launch behavior settings.
        record LaunchBehavior
            mode: LaunchMode
            quantize_override: Quantize?
            legato: boolean
            retrigger: boolean
            follow: FollowAction?
        end

        --- Clip launch trigger mode.
        enum LaunchMode
            doc "How the clip responds to launch triggers."
            Trigger
            Gate
            Toggle
            Repeat
        end

        --- Follow action after clip finishes.
        record FollowAction
            kind: FollowKind
            weight_a: number
            weight_b: number
            target_scene_id: number?
        end

        --- Follow action target selection.
        enum FollowKind
            doc "What happens after a clip finishes playing."
            FNone
            FNext
            FPrev
            FFirst
            FLast
            FOther
            FRandom
            FStop
        end

        --- Scene (horizontal launcher row across tracks).
        record Scene
            id: number
            name: string
            slots: SceneSlot*
            quantize_override: Quantize?
            tempo_override: number?
        end

        --- One track's participation in a scene launch.
        record SceneSlot
            track_id: number
            slot_index: number
            stop_others: boolean
        end

        --- Send routing to another track.
        record Send
            id: number
            target_track_id: number
            level: ParamValue
            pre_fader: boolean
            enabled: boolean
        end

        --- Editor -> Authored lowering methods.
        methods
            doc "Lower editor authoring state to canonical authored semantic form."
            Project:lower() -> Authored.Project
                doc "Lower full project including tracks, scenes, tempo, and assets."
                impl = "src/editor/project"
                fallback = function(self, err) local A = types.Authored; return A.Project(self.name or "error", nil, 0, A.Transport(44100, 512, 120, 0, 4, 4, A.QNone, false, nil), L(), L(), A.TempoMap(L(), L()), A.AssetBank(L(), L(), L(), L(), L())) end
                status = "real"
            Track:lower() -> Authored.Track
                doc "Lower track with device chain, clips, slots, and sends."
                impl = "src/editor/track"
                fallback = function(self, err) local A = types.Authored; return A.Track(self.id or 0, self.name or "error", self.channels or 2, A.NoInput, A.Param(0,"vol",1,0,4,A.StaticValue(1),A.Replace,A.NoSmoothing), A.Param(1,"pan",0,-1,1,A.StaticValue(0),A.Replace,A.NoSmoothing), A.Graph(0,L(),L(),L(),L(),L(),A.Serial,A.AudioDomain), L(), L(), L(), nil, nil, false, false, false, false, false) end
                status = "real"
            DeviceChain:lower() -> Authored.Graph
                doc "Lower serial device chain to Graph(layout=Serial)."
                impl = "src/editor/device_chain"
                fallback = function(self, err) local A = types.Authored; return A.Graph(0, L(), L(), L(), L(), L(), A.Serial, A.AudioDomain) end
                status = "real"
            Device:lower() -> Authored.Node
                doc "Lower one device (native or container) to one node."
                impl = "src/editor/device"
                fallback = function(self, err) local A = types.Authored; return A.Node(0, "error", A.GainNode, L(), L(), L(), L(), L(), false) end
                status = "real"
            Modulator:lower() -> Authored.ModSlot
                doc "Lower modulator to mod slot with routes."
                impl = "src/editor/modulator"
                fallback = function(self, err) local A = types.Authored; return A.ModSlot(A.Node(0,"error",A.LFOMod(A.Sine),L(),L(),L(),L(),L(),false), L(), false) end
                status = "real"
            ParamValue:lower() -> Authored.Param
                doc "Lower parameter value with source and smoothing."
                impl = "src/editor/param_value"
                fallback = function(self, err) local A = types.Authored; return A.Param(self.id or 0, self.name or "error", self.default_value or 0, self.min_value or 0, self.max_value or 1, A.StaticValue(self.default_value or 0), A.Replace, A.NoSmoothing) end
                status = "real"
            GridPatch:lower() -> Authored.Graph
                doc "Lower grid patch to Graph(layout=Free)."
                impl = "src/editor/grid_patch"
                fallback = function(self, err) local A = types.Authored; return A.Graph(self.id or 0, L(), L(), L(), L(), L(), A.Free, A.AudioDomain) end
                status = "real"
            NoteRegion:lower() -> Authored.NoteAsset
                doc "Lower note region to interned note asset."
                impl = "src/editor/clip"
                fallback = function(self, err) return types.Authored.NoteAsset(0, L(), L(), 0, 0) end
                status = "real"
            Clip:lower() -> Authored.Clip
                doc "Lower clip with content, fades, and gain."
                impl = "src/editor/clip"
                fallback = function(self, err) local A = types.Authored; return A.Clip(self.id or 0, A.AudioContent(0), 0, 0, 0, 0, false, A.Param(0,"gain",1,0,4,A.StaticValue(1),A.Replace,A.NoSmoothing), nil, nil) end
                status = "real"
            Slot:lower() -> Authored.Slot
                doc "Lower launcher slot with behavior."
                impl = "src/editor/slot"
                fallback = function(self, err) local A = types.Authored; return A.Slot(self.slot_index or 0, A.EmptySlot, A.LaunchBehavior(A.Trigger, nil, false, false, nil), false) end
                status = "real"
            Scene:lower() -> Authored.Scene
                doc "Lower scene with slot assignments."
                impl = "src/editor/scene"
                fallback = function(self, err) return types.Authored.Scene(self.id or 0, self.name or "error", L(), nil, nil) end
                status = "real"
            Send:lower() -> Authored.Send
                doc "Lower send routing."
                impl = "src/editor/send"
                fallback = function(self, err) local A = types.Authored; return A.Send(self.id or 0, 0, A.Param(0,"level",1,0,1,A.StaticValue(1),A.Replace,A.NoSmoothing), false, false) end
                status = "real"
            Transport:lower() -> Authored.Transport
                doc "Lower transport settings."
                impl = "src/editor/transport"
                fallback = function(self, err) return types.Authored.Transport(44100, 512, 120, 0, 4, 4, types.Authored.QNone, false, nil) end
                status = "real"
            TempoMap:lower() -> Authored.TempoMap
                doc "Lower tempo map with points and signatures."
                impl = "src/editor/transport"
                fallback = function(self, err) return types.Authored.TempoMap(L(), L()) end
                status = "real"

        --- Editor -> View projection method.
            Project:to_view() -> View.Root
                doc "Project the editor state into a View tree for UI rendering."
                impl = "src/editor/to_view"
                status = "real"
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- PHASE 1: VIEW
    -- DAW-specific interaction/projection semantics.
    -- ════════════════════════════════════════════════════════════════

    --- DAW-specific projection to TerraUI declarations. References Editor
    --- objects, does not duplicate them. Owns application-specific interaction
    --- semantics, not generic UI layout/rendering. Musical truth stays in Editor.
    phase View

        --- Application view tree root for the current editor session.
        record Root
            shell: Shell
            focus: Focus
            session_state: SessionState*
            view_data: ViewData?
            unique
        end

        --- Session-derived data for view rendering. No ctx — all data explicit.
        record ViewData
            track_names: NameEntry*
            device_names: NameEntry*
            param_names: NameEntry*
            clip_layout: ClipLayoutEntry*
            compile_status: CompileStatusEntry*
            compile_pending: boolean
            compile_detail: string?
            dynamic_status_params: boolean
        end

        --- Name lookup entry: semantic key → display name.
        record NameEntry
            key: string
            name: string
        end

        --- Clip layout entry for arrangement display.
        record ClipLayoutEntry
            clip_id: number
            x: number
            y: number
            w: number
            h: number
        end

        --- Per-ref compile status for incremental display.
        record CompileStatusEntry
            key: string
            status: string
            detail: string?
        end

        --- Stable Editor-backed object references used throughout View.
        enum SemanticRef
            doc "Typed references to Editor-backed semantic objects."
            ProjectRef
            TrackRef { track_id: number }
            DeviceRef { device_id: number }
            LayerRef { container_id: number, layer_id: number }
            SelectorBranchRef { container_id: number, branch_id: number }
            SplitBandRef { container_id: number, band_id: number }
            GridModuleRef { device_id: number, module_id: number }
            ClipRef { clip_id: number }
            NoteRef { clip_id: number, note_id: number }
            SceneRef { scene_id: number }
            SlotRef { track_id: number, slot_index: number }
            SendRef { track_id: number, send_id: number }
            ParamRef { owner_ref: Editor.ParamOwnerRef, param_id: number }
            ModulatorRef { device_id: number, modulator_id: number }
        end

        --- Canonical chain scope encoding for TerraUI key derivation.
        enum ChainRef
            doc "Chain scope references for device chain views."
            TrackChain { track_id: number }
            DeviceNoteFX { device_id: number }
            DevicePostFX { device_id: number }
            LayerChain { container_id: number, layer_id: number }
            SelectorBranchChain { container_id: number, branch_id: number }
            SplitBandChain { container_id: number, band_id: number }
        end

        --- Shell layout: transport, main area, sidebars, status.
        record Shell
            transport: TransportBar
            main_area: MainArea
            sidebars: Sidebar*
            status_bar: StatusBar?
        end

        --- Main workspace composition.
        enum MainArea
            doc "Which major DAW work surfaces are present together."
            ArrangementMain { arrangement: ArrangementView, detail_panel: DetailPanel? }
            LauncherMain { launcher: LauncherView, detail_panel: DetailPanel? }
            MixerMain { mixer: MixerView, detail_panel: DetailPanel? }
            HybridMain { arrangement: ArrangementView, launcher: LauncherView, mixer: MixerView, detail_panel: DetailPanel? }
        end

        --- Sidebar content.
        enum Sidebar
            doc "Sidebar panel content variants."
            BrowserSidebar { browser: BrowserView }
            InspectorSidebar { inspector: InspectorView }
        end

        --- Status bar readout.
        record StatusBar
            left_text: string
            center_text: string?
            right_text: string?
            identity: Identity
            anchors: StatusAnchor*
        end

        --- Status bar anchor.
        record StatusAnchor
            kind: StatusAnchorKind
        end

        --- Status bar anchor kinds.
        enum StatusAnchorKind
            doc "Status bar visual targets."
            StatusRootA
            StatusLeftA
            StatusCenterA
            StatusRightA
        end

        --- Focus: semantic selection + active workspace surface.
        record Focus
            selection: Selection
            active_surface: ActiveSurface
        end

        --- Current semantic selection.
        enum Selection
            doc "What Editor object is currently selected."
            NoSelection
            SelectedTrack { track_ref: SemanticRef }
            SelectedDevice { device_ref: SemanticRef }
            SelectedClip { clip_ref: SemanticRef }
            SelectedNote { note_ref: SemanticRef }
            SelectedScene { scene_ref: SemanticRef }
            SelectedSlot { slot_ref: SemanticRef }
            SelectedGridModule { module_ref: SemanticRef }
            SelectedModulator { modulator_ref: SemanticRef }
        end

        --- Active interaction surface.
        enum ActiveSurface
            doc "Which editor surface is currently receiving interaction."
            ArrangementSurface
            LauncherSurface
            MixerSurface
            BrowserSurface
            DeviceSurface { device_ref: SemanticRef }
            GridSurface { device_ref: SemanticRef }
            PianoRollSurface { clip_ref: SemanticRef }
            InspectorSurface
        end

        --- UI-local workspace state (tabs, scroll, splits, collapse).
        enum SessionState
            doc "View-local workspace memory, not project truth."
            SplitRatioState { key: string, value: number }
            ScrollState { key: string, x: number, y: number }
            TabState { key: string, active_tab: string }
            CollapseState { key: string, open: boolean }
        end

        --- Shared track header projection (arrangement, launcher, mixer).
        record TrackHeaderView
            track_ref: SemanticRef
            role: TrackHeaderRole
            identity: Identity
            anchors: TrackHeaderAnchor*
            commands: TrackHeaderCommand*
        end

        --- Track header context role.
        enum TrackHeaderRole
            doc "Which workspace context the track header appears in."
            ArrangementHeaderRole
            LauncherHeaderRole
            MixerHeaderRole
        end

        --- Track header anchor.
        record TrackHeaderAnchor
            kind: TrackHeaderAnchorKind
        end

        --- Track header anchor kinds.
        enum TrackHeaderAnchorKind
            doc "Track header visual targets."
            TrackHeaderRootA
            TrackHeaderTitleA
            TrackHeaderColorA
            TrackHeaderMuteA
            TrackHeaderSoloA
            TrackHeaderArmA
            TrackHeaderMonitorA
            TrackHeaderMeterA
            TrackHeaderFoldA
            TrackHeaderIOA
        end

        --- Track boolean flag kind.
        enum TrackFlagKind
            doc "Track boolean flags for commands."
            TrackMutedF
            TrackSoloedF
            TrackArmedF
            TrackMonitorInputF
            TrackPhaseInvertF
        end

        --- Track header command.
        record TrackHeaderCommand
            action_id: string
            kind: TrackHeaderCommandKind
            track_ref: SemanticRef
            flag: TrackFlagKind?
            bool_value: boolean?
            target_track_ref: SemanticRef?
        end

        --- Track header command kinds.
        enum TrackHeaderCommandKind
            doc "Track header command types."
            THCCSetTrackFlag
            THCCToggleFold
            THCCSetTrackOutput
            THCCSelectTrack
        end

        --- Transport bar surface.
        record TransportBar
            show_tempo: boolean
            show_time_sig: boolean
            show_loop: boolean
            show_quantize: boolean
            identity: Identity
            anchors: TransportAnchor*
            commands: TransportCommand*
        end

        --- Transport anchor.
        record TransportAnchor
            kind: TransportAnchorKind
        end

        --- Transport anchor kinds.
        enum TransportAnchorKind
            doc "Transport bar visual targets."
            TransportRootA
            TransportNavA
            TransportPlayA
            TransportStopA
            TransportRecordA
            TransportLoopA
            TransportTempoA
            TransportTimeSigA
            TransportPositionA
            TransportQuantizeA
            TransportStatusA
        end

        --- Transport command.
        record TransportCommand
            action_id: string
            kind: TransportCommandKind
            number_value: number?
            quantize_value: Editor.Quantize?
            bool_value: boolean?
        end

        --- Transport command kinds.
        enum TransportCommandKind
            doc "Transport control actions."
            TCCPlay
            TCCStop
            TCCToggleRecord
            TCCToggleLoop
            TCCSetTempo
            TCCSetTimeSigNum
            TCCSetTimeSigDen
            TCCSetLaunchQuantize
        end

        --- Arrangement timeline view.
        record ArrangementView
            visible_track_refs: SemanticRef*
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
            ruler: ArrangementRuler?
            grid: ArrangementGridView?
            playhead: ArrangementPlayheadView?
            loop_region: ArrangementLoopRegionView?
            selection: ArrangementSelectionView?
            lanes: ArrangementLane*
        end

        --- Arrangement anchor.
        record ArrangementAnchor
            kind: ArrangementAnchorKind
            track_ref: SemanticRef?
            clip_ref: SemanticRef?
            param_ref: SemanticRef?
            point_index: number?
        end

        --- Arrangement anchor kinds.
        enum ArrangementAnchorKind
            doc "Arrangement timeline visual targets."
            ArrangementRootA
            ArrangementRulerA
            ArrangementGridA
            ArrangementCanvasA
            ArrangementPlayheadA
            ArrangementLoopA
            ArrangementLaneA
            ArrangementLaneHeaderA
            ArrangementLaneBodyA
            ArrangementClipBodyA
            ArrangementClipLabelA
            ArrangementClipLeftTrimA
            ArrangementClipRightTrimA
            ArrangementAutomationLaneA
            ArrangementAutomationPointA
            ArrangementSelectionA
        end

        --- Arrangement command.
        record ArrangementCommand
            action_id: string
            kind: ArrangementCommandKind
            track_ref: SemanticRef?
            clip_ref: SemanticRef?
            param_ref: SemanticRef?
            point_index: number?
            start_beats: number?
            end_beats: number?
            lane: number?
            number_value: number?
            bool_value: boolean?
        end

        --- Arrangement command kinds.
        enum ArrangementCommandKind
            doc "Arrangement timeline actions."
            ACCSetPlayhead
            ACCToggleLoop
            ACCSetLoopRange
            ACCSetTimeSelection
            ACCClearTimeSelection
            ACCAddClip
            ACCMoveClip
            ACCResizeClipStart
            ACCResizeClipEnd
            ACCSelectClip
            ACCAddAutomationPoint
            ACCMoveAutomationPoint
            ACCRemoveAutomationPoint
            ACCSelectAutomationPoint
        end

        --- Arrangement ruler.
        record ArrangementRuler
            visible_start_beats: number
            visible_end_beats: number
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
        end

        --- Arrangement grid scaffold.
        record ArrangementGridView
            visible_start_beats: number
            visible_end_beats: number
            identity: Identity
            anchors: ArrangementAnchor*
        end

        --- Arrangement playhead marker.
        record ArrangementPlayheadView
            position_beats: number
            identity: Identity
            anchors: ArrangementAnchor*
        end

        --- Arrangement loop region overlay.
        record ArrangementLoopRegionView
            start_beats: number
            end_beats: number
            enabled: boolean
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
        end

        --- Arrangement track lane.
        record ArrangementLane
            track_ref: SemanticRef
            identity: Identity
            header: ArrangementLaneHeaderView
            body: ArrangementLaneBodyView
        end

        --- Arrangement lane header.
        record ArrangementLaneHeaderView
            track_ref: SemanticRef
            identity: Identity
            track_header: TrackHeaderView
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
        end

        --- Arrangement lane body with clips and automation.
        record ArrangementLaneBodyView
            track_ref: SemanticRef
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
            clips: ArrangementClipView*
            automation_lanes: ArrangementAutomationLaneView*
        end

        --- Arrangement automation lane.
        record ArrangementAutomationLaneView
            track_ref: SemanticRef
            param_ref: SemanticRef
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
            points: ArrangementAutomationPointView*
        end

        --- Arrangement automation point.
        record ArrangementAutomationPointView
            track_ref: SemanticRef
            param_ref: SemanticRef
            point_index: number
            time_beats: number
            value: number
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
        end

        --- Arrangement time selection overlay.
        record ArrangementSelectionView
            start_beats: number
            end_beats: number
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
        end

        --- One rendered clip in an arrangement lane.
        record ArrangementClipView
            track_ref: SemanticRef
            clip_ref: SemanticRef
            identity: Identity
            anchors: ArrangementAnchor*
            commands: ArrangementCommand*
        end

        --- Piano roll note-region editor.
        record PianoRollView
            clip_ref: SemanticRef
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
            keyboard: PianoKeyboardView
            grid: PianoGridView
            playhead: PianoPlayheadView?
            loop_region: PianoLoopRegionView?
            selection: PianoSelectionView?
            notes: PianoNoteView*
            velocity_lane: PianoVelocityLaneView?
            expr_lanes: PianoExprLaneView*
        end

        --- Piano keyboard.
        record PianoKeyboardView
            lowest_pitch: number
            highest_pitch: number
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
            keys: PianoKeyView*
        end

        --- Piano key.
        record PianoKeyView
            pitch: number
            is_black: boolean
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
        end

        --- Piano grid scaffold.
        record PianoGridView
            visible_start_beats: number
            visible_end_beats: number
            lowest_pitch: number
            highest_pitch: number
            identity: Identity
            anchors: PianoRollAnchor*
        end

        --- Piano playhead.
        record PianoPlayheadView
            position_beats: number
            identity: Identity
            anchors: PianoRollAnchor*
        end

        --- Piano loop region.
        record PianoLoopRegionView
            start_beats: number
            end_beats: number
            enabled: boolean
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
        end

        --- Piano note selection state.
        record PianoSelectionView
            selected_note_refs: SemanticRef*
            start_beats: number?
            end_beats: number?
            low_pitch: number?
            high_pitch: number?
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
        end

        --- One rendered note in the piano roll.
        record PianoNoteView
            clip_ref: SemanticRef
            note_ref: SemanticRef
            pitch: number
            start_beats: number
            end_beats: number
            velocity: number
            muted: boolean
            selected: boolean
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
        end

        --- Velocity lane.
        record PianoVelocityLaneView
            clip_ref: SemanticRef
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
            bars: PianoVelocityBarView*
        end

        --- Velocity bar for one note.
        record PianoVelocityBarView
            clip_ref: SemanticRef
            note_ref: SemanticRef
            value: number
            selected: boolean
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
        end

        --- Expression lane.
        record PianoExprLaneView
            clip_ref: SemanticRef
            kind: Editor.NoteExprKind
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
            points: PianoExprPointView*
        end

        --- Expression point.
        record PianoExprPointView
            clip_ref: SemanticRef
            kind: Editor.NoteExprKind
            point_index: number
            time_beats: number
            value: number
            note_id: number?
            selected: boolean
            identity: Identity
            anchors: PianoRollAnchor*
            commands: PianoRollCommand*
        end

        --- Piano roll anchor.
        record PianoRollAnchor
            kind: PianoRollAnchorKind
            note_ref: SemanticRef?
            expr_kind: Editor.NoteExprKind?
            point_index: number?
            pitch: number?
        end

        --- Piano roll anchor kinds.
        enum PianoRollAnchorKind
            doc "Piano roll visual targets."
            PianoRollRootA
            PianoKeyboardA
            PianoGridA
            PianoCanvasA
            PianoKeyA
            PianoNoteBodyA
            PianoNoteLeftTrimA
            PianoNoteRightTrimA
            PianoVelocityLaneA
            PianoVelocityBarA
            PianoExprLaneA
            PianoExprPointA
            PianoSelectionA
            PianoPlayheadA
            PianoLoopA
        end

        --- Piano roll command.
        record PianoRollCommand
            action_id: string
            kind: PianoRollCommandKind
            clip_ref: SemanticRef
            note_refs: SemanticRef*
            expr_kind: Editor.NoteExprKind?
            point_index: number?
            pitch: number?
            start_beats: number?
            end_beats: number?
            low_pitch: number?
            high_pitch: number?
            number_value: number?
            quantize_value: Editor.Quantize?
            bool_value: boolean?
        end

        --- Piano roll command kinds.
        enum PianoRollCommandKind
            doc "Piano roll note editing actions."
            PRCCAddNote
            PRCCMoveNotes
            PRCCResizeNotesStart
            PRCCResizeNotesEnd
            PRCCDeleteNotes
            PRCCSelectNotes
            PRCCSetVelocity
            PRCCSetNoteMute
            PRCCTransposeNotes
            PRCCQuantizeNotes
            PRCCSetPlayhead
            PRCCSetLoopRange
            PRCCSetTimeSelection
            PRCCClearTimeSelection
            PRCCAddExprPoint
            PRCCMoveExprPoint
            PRCCDeleteExprPoint
        end

        --- Launcher session view.
        record LauncherView
            visible_track_refs: SemanticRef*
            visible_scene_refs: SemanticRef*
            identity: Identity
            anchors: LauncherAnchor*
            commands: LauncherCommand*
            scenes: LauncherSceneView*
            stop_row: LauncherStopRowView?
            columns: LauncherColumn*
        end

        --- Launcher anchor.
        record LauncherAnchor
            kind: LauncherAnchorKind
            track_ref: SemanticRef?
            scene_ref: SemanticRef?
            slot_ref: SemanticRef?
            clip_ref: SemanticRef?
        end

        --- Launcher anchor kinds.
        enum LauncherAnchorKind
            doc "Launcher visual targets."
            LauncherRootA
            LauncherSceneHeaderA
            LauncherSceneLaunchA
            LauncherColumnA
            LauncherTrackTitleA
            LauncherSlotA
            LauncherSlotBodyA
            LauncherSlotLabelA
            LauncherStopA
            LauncherStopRowA
            LauncherScrollA
        end

        --- Launcher command.
        record LauncherCommand
            action_id: string
            kind: LauncherCommandKind
            track_ref: SemanticRef?
            scene_ref: SemanticRef?
            slot_ref: SemanticRef?
            clip_ref: SemanticRef?
            launch_mode: Editor.LaunchMode?
            quantize_override: Editor.Quantize?
            legato: boolean?
            retrigger: boolean?
            follow: Editor.FollowAction?
            bool_value: boolean?
        end

        --- Launcher command kinds.
        enum LauncherCommandKind
            doc "Launcher actions."
            LCCLaunchSlot
            LCCLaunchScene
            LCCStopTrack
            LCCSetSlotBehavior
            LCCSelectScene
            LCCSelectSlot
        end

        --- Launcher scene header row.
        record LauncherSceneView
            scene_ref: SemanticRef
            identity: Identity
            anchors: LauncherAnchor*
            commands: LauncherCommand*
        end

        --- Launcher stop row.
        record LauncherStopRowView
            identity: Identity
            anchors: LauncherAnchor*
            commands: LauncherCommand*
            cells: LauncherStopCellView*
        end

        --- Launcher stop cell per track.
        record LauncherStopCellView
            track_ref: SemanticRef
            identity: Identity
            anchors: LauncherAnchor*
            commands: LauncherCommand*
        end

        --- Launcher per-track column.
        record LauncherColumn
            track_ref: SemanticRef
            identity: Identity
            header: TrackHeaderView
            anchors: LauncherAnchor*
            commands: LauncherCommand*
            slots: LauncherSlotView*
        end

        --- Launcher slot content kind.
        enum LauncherSlotContentKind
            doc "Visual slot content state."
            LauncherEmptySlot
            LauncherClipSlot
            LauncherStopSlot
        end

        --- Launcher slot cell.
        record LauncherSlotView
            track_ref: SemanticRef
            scene_ref: SemanticRef
            slot_ref: SemanticRef
            content_kind: LauncherSlotContentKind
            clip_ref: SemanticRef?
            identity: Identity
            anchors: LauncherAnchor*
            commands: LauncherCommand*
        end

        --- Mixer anchor.
        record MixerAnchor
            kind: MixerAnchorKind
            track_ref: SemanticRef?
            send_ref: SemanticRef?
        end

        --- Mixer anchor kinds.
        enum MixerAnchorKind
            doc "Mixer visual targets."
            MixerRootA
            MixerHeaderA
            MixerTitleA
            MixerMeterA
            MixerVolumeA
            MixerPanA
            MixerMuteA
            MixerSoloA
            MixerArmA
            MixerMonitorA
            MixerSendA
            MixerOutputA
        end

        --- Mixer command.
        record MixerCommand
            action_id: string
            kind: MixerCommandKind
            track_ref: SemanticRef?
            flag: TrackFlagKind?
            send_ref: SemanticRef?
            param_ref: SemanticRef?
            target_track_ref: SemanticRef?
            pre_fader: boolean?
            number_value: number?
            bool_value: boolean?
        end

        --- Mixer command kinds.
        enum MixerCommandKind
            doc "Mixer surface actions."
            MCCSetTrackFlag
            MCCSetTrackOutput
            MCCSetTrackVolume
            MCCSetTrackPan
            MCCSetSendLevel
            MCCSetSendMode
            MCCAddSend
            MCCRemoveSend
        end

        --- Mixer strip view.
        record MixerView
            visible_track_refs: SemanticRef*
            identity: Identity
            anchors: MixerAnchor*
            commands: MixerCommand*
            strips: MixerStrip*
        end

        --- Mixer strip for one track.
        record MixerStrip
            track_ref: SemanticRef
            identity: Identity
            header: TrackHeaderView
            meter: MixerMeterView
            pan: MixerPanView
            volume: MixerVolumeView
            sends: MixerSendView*
            anchors: MixerAnchor*
            commands: MixerCommand*
        end

        --- Mixer meter readout.
        record MixerMeterView
            track_ref: SemanticRef
            identity: Identity
            anchors: MixerAnchor*
        end

        --- Mixer pan control.
        record MixerPanView
            track_ref: SemanticRef
            param_ref: SemanticRef
            identity: Identity
            anchors: MixerAnchor*
            commands: MixerCommand*
        end

        --- Mixer volume control.
        record MixerVolumeView
            track_ref: SemanticRef
            param_ref: SemanticRef
            identity: Identity
            anchors: MixerAnchor*
            commands: MixerCommand*
        end

        --- Mixer send control.
        record MixerSendView
            track_ref: SemanticRef
            send_ref: SemanticRef
            param_ref: SemanticRef
            identity: Identity
            anchors: MixerAnchor*
            commands: MixerCommand*
        end

        --- Detail panel (lower editor region).
        enum DetailPanel
            doc "Specialized editor metaphor for the detail area."
            DeviceChainDetail { chain: DeviceChainView }
            DeviceDetail { device: DeviceView }
            GridDetail { patch: GridPatchView }
            PianoRollDetail { piano_roll: PianoRollView }
        end

        --- Device chain editor.
        record DeviceChainView
            chain_ref: ChainRef
            identity: Identity
            anchors: DeviceChainAnchor*
            commands: DeviceChainCommand*
            entries: DeviceEntry*
        end

        --- Device entry/card in chain.
        record DeviceEntry
            device_ref: SemanticRef
            identity: Identity
            anchors: DeviceEntryAnchor*
            commands: DeviceEntryCommand*
        end

        --- Focused device editor view.
        enum DeviceView
            doc "Specialized device editing surfaces."
            NativeDeviceView { device_ref: SemanticRef, identity: Identity, anchors: DeviceSurfaceAnchor*, commands: DeviceSurfaceCommand*, sections: DeviceSectionView* }
            LayerContainerView { device_ref: SemanticRef, identity: Identity, anchors: DeviceSurfaceAnchor*, commands: DeviceSurfaceCommand*, sections: DeviceSectionView*, layers: LayerLane* }
            SelectorContainerView { device_ref: SemanticRef, identity: Identity, anchors: DeviceSurfaceAnchor*, commands: DeviceSurfaceCommand*, sections: DeviceSectionView*, branches: SelectorLane* }
            SplitContainerView { device_ref: SemanticRef, identity: Identity, anchors: DeviceSurfaceAnchor*, commands: DeviceSurfaceCommand*, sections: DeviceSectionView*, bands: SplitLane* }
            GridContainerView { device_ref: SemanticRef, identity: Identity, anchors: DeviceSurfaceAnchor*, commands: DeviceSurfaceCommand*, sections: DeviceSectionView* }
        end

        --- Device section (header, params, modulators, etc).
        record DeviceSectionView
            device_ref: SemanticRef
            section_key: string
            kind: DeviceSectionKind
            identity: Identity
            anchors: DeviceSurfaceAnchor*
            commands: DeviceSurfaceCommand*
            params: DeviceParamView*
            modulators: DeviceModulatorView*
        end

        --- Device section kind.
        enum DeviceSectionKind
            doc "Device panel section types."
            DeviceHeaderSection
            DeviceParamsSection
            DeviceModulatorsSection
            DeviceNoteFXSection
            DevicePostFXSection
            DeviceChildrenSection
        end

        --- Device parameter view.
        record DeviceParamView
            device_ref: SemanticRef
            param_ref: SemanticRef
            identity: Identity
            anchors: DeviceSurfaceAnchor*
            commands: DeviceSurfaceCommand*
        end

        --- Device modulator view.
        record DeviceModulatorView
            device_ref: SemanticRef
            modulator_ref: SemanticRef
            identity: Identity
            anchors: DeviceSurfaceAnchor*
            commands: DeviceSurfaceCommand*
            routes: DeviceModulationRouteView*
        end

        --- Modulation route view.
        record DeviceModulationRouteView
            device_ref: SemanticRef
            modulator_ref: SemanticRef
            route_index: number
            target_param_ref: SemanticRef
            scale_modulator_ref: SemanticRef?
            scale_param_ref: SemanticRef?
            identity: Identity
            anchors: DeviceSurfaceAnchor*
            commands: DeviceSurfaceCommand*
        end

        --- Device surface anchor.
        record DeviceSurfaceAnchor
            kind: DeviceSurfaceAnchorKind
            section_key: string?
        end

        --- Device surface anchor kinds.
        enum DeviceSurfaceAnchorKind
            doc "Device panel visual targets."
            DeviceSurfaceRootA
            DeviceSurfaceHeaderA
            DeviceSurfaceTitleA
            DeviceSurfaceEnableA
            DeviceSurfaceBodyA
            DeviceSurfaceSectionA
            DeviceSurfaceParamA
            DeviceSurfaceModulatorA
            DeviceSurfaceModulationRouteA
            DeviceSurfaceModulationTargetA
            DeviceSurfaceModulationDepthA
            DeviceSurfaceModulationScaleA
            DeviceSurfaceParamsA
            DeviceSurfaceModulatorsA
            DeviceSurfaceNoteFXA
            DeviceSurfacePostFXA
            DeviceSurfaceChildrenA
        end

        --- Device surface command.
        record DeviceSurfaceCommand
            action_id: string
            kind: DeviceSurfaceCommandKind
            device_ref: SemanticRef
            param_ref: SemanticRef?
            modulator_ref: SemanticRef?
            target_param_ref: SemanticRef?
            scale_modulator_ref: SemanticRef?
            scale_param_ref: SemanticRef?
            preset_ref: Editor.PresetRef?
            route_index: number?
            at_index: number?
            number_value: number?
            section_key: string?
            bool_value: boolean?
        end

        --- Device surface command kinds.
        enum DeviceSurfaceCommandKind
            doc "Device panel editing actions."
            DSCCSetParamValue
            DSCCToggleDeviceEnabled
            DSCCAddModulator
            DSCCRemoveModulator
            DSCCMoveModulator
            DSCCSetModulatorEnabled
            DSCCSetModulatorVoiceMode
            DSCCAddModulationMapping
            DSCCRemoveModulationMapping
            DSCCSetModulationDepth
            DSCCSetModulationScale
            DSCCSelectSection
            DSCCSelectParam
            DSCCSelectModulator
        end

        --- Layer lane in container view.
        record LayerLane
            container_ref: SemanticRef
            layer_ref: SemanticRef
            identity: Identity
            anchors: LayerLaneAnchor*
            commands: LayerLaneCommand*
            chain: DeviceChainView
        end

        --- Selector lane in container view.
        record SelectorLane
            container_ref: SemanticRef
            branch_ref: SemanticRef
            identity: Identity
            anchors: SelectorLaneAnchor*
            commands: SelectorLaneCommand*
            chain: DeviceChainView
        end

        --- Split lane in container view.
        record SplitLane
            container_ref: SemanticRef
            band_ref: SemanticRef
            identity: Identity
            anchors: SplitLaneAnchor*
            commands: SplitLaneCommand*
            chain: DeviceChainView
        end

        --- Layer lane anchor.
        record LayerLaneAnchor
            kind: LayerLaneAnchorKind
        end

        --- Layer lane anchor kinds.
        enum LayerLaneAnchorKind
            doc "Layer lane visual targets."
            LayerLaneRootA
            LayerLaneHeaderA
            LayerLaneTitleA
            LayerLaneMuteA
            LayerLaneVolumeA
            LayerLanePanA
            LayerLaneChainA
            LayerLaneInsertA
        end

        --- Layer lane command.
        record LayerLaneCommand
            action_id: string
            kind: LayerLaneCommandKind
            container_ref: SemanticRef
            layer_ref: SemanticRef
            device_ref: SemanticRef?
            preset_ref: Editor.PresetRef?
            at_index: number?
            bool_value: boolean?
        end

        --- Layer lane command kinds.
        enum LayerLaneCommandKind
            doc "Layer lane editing actions."
            LLCCSetLayerMix
            LLCCAddLayer
            LLCCMoveLayer
            LLCCRemoveLayer
            LLCCAddDevice
            LLCCMoveDevice
            LLCCWrapInLayer
            LLCCWrapInSelector
            LLCCWrapInSplit
        end

        --- Selector lane anchor.
        record SelectorLaneAnchor
            kind: SelectorLaneAnchorKind
        end

        --- Selector lane anchor kinds.
        enum SelectorLaneAnchorKind
            doc "Selector lane visual targets."
            SelectorLaneRootA
            SelectorLaneHeaderA
            SelectorLaneTitleA
            SelectorLaneChainA
            SelectorLaneInsertA
        end

        --- Selector lane command.
        record SelectorLaneCommand
            action_id: string
            kind: SelectorLaneCommandKind
            container_ref: SemanticRef
            branch_ref: SemanticRef
            device_ref: SemanticRef?
            preset_ref: Editor.PresetRef?
            at_index: number?
            selector_mode: Editor.SelectorMode?
        end

        --- Selector lane command kinds.
        enum SelectorLaneCommandKind
            doc "Selector lane editing actions."
            SLCCAddBranch
            SLCCMoveBranch
            SLCCRemoveBranch
            SLCCAddDevice
            SLCCMoveDevice
            SLCCWrapInLayer
            SLCCWrapInSelector
            SLCCWrapInSplit
            SLCCSetSelectorMode
        end

        --- Split lane anchor.
        record SplitLaneAnchor
            kind: SplitLaneAnchorKind
        end

        --- Split lane anchor kinds.
        enum SplitLaneAnchorKind
            doc "Split lane visual targets."
            SplitLaneRootA
            SplitLaneHeaderA
            SplitLaneTitleA
            SplitLaneCrossoverA
            SplitLaneChainA
            SplitLaneInsertA
        end

        --- Split lane command.
        record SplitLaneCommand
            action_id: string
            kind: SplitLaneCommandKind
            container_ref: SemanticRef
            band_ref: SemanticRef
            device_ref: SemanticRef?
            preset_ref: Editor.PresetRef?
            at_index: number?
            number_value: number?
        end

        --- Split lane command kinds.
        enum SplitLaneCommandKind
            doc "Split lane editing actions."
            SpLCCSetCrossover
            SpLCCAddBand
            SpLCCMoveBand
            SpLCCRemoveBand
            SpLCCAddDevice
            SpLCCMoveDevice
            SpLCCWrapInLayer
            SpLCCWrapInSelector
            SpLCCWrapInSplit
        end

        --- Grid patch view.
        record GridPatchView
            device_ref: SemanticRef
            identity: Identity
            anchors: GridPatchAnchor*
            commands: GridPatchCommand*
            modules: GridModuleView*
            cables: GridCableView*
        end

        --- Grid module view.
        record GridModuleView
            device_ref: SemanticRef
            module_ref: SemanticRef
            identity: Identity
            anchors: GridModuleAnchor*
            commands: GridModuleCommand*
        end

        --- Device chain anchor.
        record DeviceChainAnchor
            kind: DeviceChainAnchorKind
            device_ref: SemanticRef?
            at_index: number?
        end

        --- Device chain anchor kinds.
        enum DeviceChainAnchorKind
            doc "Device chain visual targets."
            ChainRootA
            ChainInsertA
            ChainDropA
            ChainHeaderA
        end

        --- Device chain command.
        record DeviceChainCommand
            action_id: string
            kind: DeviceChainCommandKind
            chain_ref: ChainRef
            device_ref: SemanticRef?
            preset_ref: Editor.PresetRef?
            at_index: number?
        end

        --- Device chain command kinds.
        enum DeviceChainCommandKind
            doc "Device chain editing actions."
            DCCAddDevice
            DCCMoveDevice
            DCCRemoveDevice
            DCCWrapInLayer
            DCCWrapInSelector
            DCCWrapInSplit
            DCCToggleDeviceEnabled
        end

        --- Device entry anchor.
        record DeviceEntryAnchor
            kind: DeviceEntryAnchorKind
        end

        --- Device entry anchor kinds.
        enum DeviceEntryAnchorKind
            doc "Device card visual targets."
            DeviceCardA
            DeviceTitleA
            DeviceEnableToggleA
            DeviceNoteFXTabA
            DevicePostFXTabA
            DeviceInsertBeforeA
            DeviceInsertAfterA
        end

        --- Device entry command.
        record DeviceEntryCommand
            action_id: string
            kind: DeviceEntryCommandKind
            device_ref: SemanticRef
            param_ref: SemanticRef?
            number_value: number?
            at_index: number?
        end

        --- Device entry command kinds.
        enum DeviceEntryCommandKind
            doc "Device card actions."
            DECCSetParamValue
            DECCMoveDevice
            DECCRemoveDevice
            DECCToggleDeviceEnabled
            DECCWrapInLayer
            DECCWrapInSelector
            DECCWrapInSplit
        end

        --- Grid patch anchor.
        record GridPatchAnchor
            kind: GridPatchAnchorKind
            module_ref: SemanticRef?
            port_id: number?
        end

        --- Grid patch anchor kinds.
        enum GridPatchAnchorKind
            doc "Grid patch visual targets."
            PatchRootA
            PatchCanvasA
            PatchDropA
            PatchSelectionA
        end

        --- Grid patch command.
        record GridPatchCommand
            action_id: string
            kind: GridPatchCommandKind
            device_ref: SemanticRef
            module_ref: SemanticRef?
            preset_ref: Editor.PresetRef?
            x: number?
            y: number?
            port_id: number?
            source_kind: Editor.GridSourceKind?
            source_arg0: number?
            from_module_ref: SemanticRef?
            from_port: number?
            to_module_ref: SemanticRef?
            to_port: number?
        end

        --- Grid patch command kinds.
        enum GridPatchCommandKind
            doc "Grid patch editing actions."
            GPCCAddModule
            GPCCRemoveModule
            GPCCMoveModule
            GPCCConnectCable
            GPCCDisconnectCable
            GPCCBindSource
            GPCCUnbindSource
        end

        --- Grid module anchor.
        record GridModuleAnchor
            kind: GridModuleAnchorKind
            port_id: number?
        end

        --- Grid module anchor kinds.
        enum GridModuleAnchorKind
            doc "Grid module visual targets."
            ModuleBodyA
            ModuleHeaderA
            ModuleTitleA
            ModuleInputPortA
            ModuleOutputPortA
        end

        --- Grid module command.
        record GridModuleCommand
            action_id: string
            kind: GridModuleCommandKind
            device_ref: SemanticRef
            module_ref: SemanticRef
            x: number?
            y: number?
            port_id: number?
            source_kind: Editor.GridSourceKind?
            source_arg0: number?
            to_module_ref: SemanticRef?
            to_port: number?
        end

        --- Grid module command kinds.
        enum GridModuleCommandKind
            doc "Grid module actions."
            GMCCMoveModule
            GMCCRemoveModule
            GMCCBeginCable
            GMCCCompleteCable
            GMCCBindSource
        end

        --- Grid cable edge view.
        record GridCableView
            from_module_ref: SemanticRef
            from_port: number
            to_module_ref: SemanticRef
            to_port: number
            identity: Identity
            anchors: GridPatchAnchor*
        end

        --- Inspector details view.
        record InspectorView
            selection: Selection
            identity: Identity
            anchors: InspectorAnchor*
            commands: InspectorCommand*
            tabs: InspectorTabView*
        end

        --- Inspector anchor.
        record InspectorAnchor
            kind: InspectorAnchorKind
            section_key: string?
            field_key: string?
        end

        --- Inspector anchor kinds.
        enum InspectorAnchorKind
            doc "Inspector visual targets."
            InspectorRootA
            InspectorTabBarA
            InspectorTabA
            InspectorContentA
            InspectorSectionA
            InspectorFieldA
        end

        --- Inspector command.
        record InspectorCommand
            action_id: string
            kind: InspectorCommandKind
            selection: Selection
            tab_key: string?
            section_key: string?
            field_key: string?
            target_ref: SemanticRef?
            number_value: number?
            string_value: string?
            bool_value: boolean?
        end

        --- Inspector command kinds.
        enum InspectorCommandKind
            doc "Inspector actions."
            ICCSelectTab
            ICCSetValue
            ICCToggleFlag
            ICCExpandSection
        end

        --- Inspector tab reference.
        enum InspectorTabRef
            doc "Tab content reference types."
            TrackTab { track_ref: SemanticRef }
            DeviceTab { device_ref: SemanticRef }
            ClipTab { clip_ref: SemanticRef }
            NoteTab { note_ref: SemanticRef }
            ModulatorTab { modulator_ref: SemanticRef }
            ParamTab { param_ref: SemanticRef }
        end

        --- Inspector tab view.
        record InspectorTabView
            tab: InspectorTabRef
            tab_key: string
            identity: Identity
            anchors: InspectorAnchor*
            commands: InspectorCommand*
            sections: InspectorSectionView*
        end

        --- Inspector section.
        record InspectorSectionView
            section_key: string
            label: string
            expanded: boolean
            identity: Identity
            anchors: InspectorAnchor*
            commands: InspectorCommand*
            fields: InspectorFieldView*
        end

        --- Inspector field.
        record InspectorFieldView
            field_key: string
            label: string
            kind: InspectorFieldKind
            identity: Identity
            anchors: InspectorAnchor*
            commands: InspectorCommand*
        end

        --- Inspector field kind.
        enum InspectorFieldKind
            doc "Inspector field types."
            ToggleField
            NumberField
            EnumField
            TextField
            ActionField
        end

        --- Browser sidebar view.
        record BrowserView
            source_kind: string
            query: string?
            identity: Identity
            anchors: BrowserAnchor*
            commands: BrowserCommand*
            sources: BrowserSourceView*
            query_bar: BrowserQueryView?
            sections: BrowserSection*
        end

        --- Browser anchor.
        record BrowserAnchor
            kind: BrowserAnchorKind
            source_id: string?
            section_id: string?
            item_id: string?
            target_ref: SemanticRef?
        end

        --- Browser anchor kinds.
        enum BrowserAnchorKind
            doc "Browser visual targets."
            BrowserRootA
            BrowserSearchA
            BrowserQueryA
            BrowserSourceA
            BrowserSectionA
            BrowserItemA
            BrowserItemIconA
            BrowserItemLabelA
        end

        --- Browser command.
        record BrowserCommand
            action_id: string
            kind: BrowserCommandKind
            source_id: string?
            section_id: string?
            item_id: string?
            target_ref: SemanticRef?
            query_value: string?
            bool_value: boolean?
        end

        --- Browser command kinds.
        enum BrowserCommandKind
            doc "Browser actions."
            BCCSetQuery
            BCCSelectSource
            BCCToggleSection
            BCCPreviewItem
            BCCCommitItem
        end

        --- Browser source tab.
        record BrowserSourceView
            source_id: string
            label: string
            selected: boolean
            identity: Identity
            anchors: BrowserAnchor*
            commands: BrowserCommand*
        end

        --- Browser query bar.
        record BrowserQueryView
            query: string?
            identity: Identity
            anchors: BrowserAnchor*
            commands: BrowserCommand*
        end

        --- Browser section.
        record BrowserSection
            section_id: string
            label: string
            expanded: boolean
            identity: Identity
            anchors: BrowserAnchor*
            commands: BrowserCommand*
            items: BrowserItem*
        end

        --- Browser item.
        record BrowserItem
            item_id: string
            label: string
            detail: string?
            kind: BrowserItemKind
            selected: boolean
            disabled: boolean
            target_ref: SemanticRef?
            identity: Identity
            anchors: BrowserAnchor*
            commands: BrowserCommand*
        end

        --- Browser item kind.
        enum BrowserItemKind
            doc "Browsable content types."
            BrowserDeviceItem
            BrowserPresetItem
            BrowserSampleItem
            BrowserCollectionItem
            BrowserCategoryItem
            BrowserProjectObjectItem
        end

        --- View identity for TerraUI key derivation.
        record Identity
            key_space: string
            ref: IdentityRef
        end

        --- Identity reference variant.
        enum IdentityRef
            doc "Identity source for keyed subtree derivation."
            IdentitySemantic { semantic_ref: SemanticRef }
            IdentityChain { chain_ref: ChainRef }
            IdentityKey { stable_key: string }
        end

        --- Generic named anchor fallback.
        record Anchor
            name: string
            purpose: string
        end

        --- Payload value for generic commands.
        enum PayloadValue
            doc "Typed payload values for generic command bindings."
            PNumber { value: number }
            PString { value: string }
            PBoolean { value: boolean }
            PSemanticRef { ref: SemanticRef }
            PChainRef { ref: ChainRef }
        end

        --- Payload field for generic commands.
        record PayloadField
            name: string
            value: PayloadValue
        end

        --- Generic Editor command kind (fallback for unspecialized surfaces).
        enum CommandKind
            doc "Semantic Editor command families."
            CmdAddTrack, CmdRemoveTrack, CmdMoveTrack
            CmdSetTrackFlags, CmdSetTrackOutput
            CmdSetParamValue, CmdSetParamRange, CmdSetParamCombine
            CmdAddDevice, CmdMoveDevice, CmdRemoveDevice, CmdReplaceDevice
            CmdToggleDeviceEnabled, CmdConvertDeviceToGrid
            CmdWrapDevicesInLayer, CmdWrapDevicesInSelector, CmdWrapDevicesInSplit
            CmdAddLayer, CmdMoveLayer, CmdRemoveLayer, CmdDuplicateLayer, CmdSetLayerMix
            CmdSetSelectorMode
            CmdAddSelectorBranch, CmdMoveSelectorBranch, CmdRemoveSelectorBranch, CmdDuplicateSelectorBranch
            CmdAddSplitBand, CmdMoveSplitBand, CmdRemoveSplitBand, CmdDuplicateSplitBand, CmdSetSplitBandCrossover
            CmdAddModulator, CmdRemoveModulator, CmdMoveModulator
            CmdSetModulatorEnabled, CmdSetModulatorVoiceMode
            CmdAddModulationMapping, CmdRemoveModulationMapping, CmdSetModulationDepth, CmdSetModulationScale
            CmdAddGridModule, CmdMoveGridModule, CmdRemoveGridModule
            CmdConnectGridCable, CmdDisconnectGridCable, CmdBindGridSource, CmdUnbindGridSource, CmdSetGridInterface
            CmdAddClip, CmdRemoveClip, CmdMoveClip, CmdResizeClip, CmdSetClipGain, CmdSetClipFade
            CmdAddNote, CmdRemoveNote, CmdMoveNote, CmdResizeNoteStart, CmdResizeNoteEnd
            CmdSetNoteVelocity, CmdSetNoteMute
            CmdAddNoteExprPoint, CmdMoveNoteExprPoint, CmdRemoveNoteExprPoint
            CmdTransposeNotes, CmdQuantizeNotes
            CmdSetSlotContent, CmdSetSlotBehavior
            CmdAddScene, CmdRemoveScene, CmdSetSceneProperties
            CmdLaunchSlot, CmdLaunchScene, CmdStopTrack
            CmdAddSend, CmdRemoveSend, CmdSetSendTarget, CmdSetSendLevel, CmdSetSendMode
        end

        --- Generic command binding (fallback for unspecialized surfaces).
        record CommandBind
            action_id: string
            kind: CommandKind
            payload: PayloadField*
        end

        --- View -> TerraUI lowering methods.
        methods
            doc "Lower View types to TerraUI declaration trees."
            Root:lower() -> TerraUIDecl
                doc "Lower full view root to TerraUI shell declaration."
                impl = "src/view/root"
                status = "real"
            Shell:lower() -> TerraUIDecl
                doc "Lower shell layout."
                impl = "src/view/shell"
                status = "real"
            TransportBar:lower() -> TerraUIDecl
                doc "Lower transport bar."
                impl = "src/view/transport_bar"
                status = "real"
            ArrangementView:lower() -> TerraUIDecl
                doc "Lower arrangement timeline."
                impl = "src/view/arrangement/view"
                status = "real"
            LauncherView:lower() -> TerraUIDecl
                doc "Lower launcher session view."
                impl = "src/view/launcher/view"
                status = "real"
            MixerView:lower() -> TerraUIDecl
                doc "Lower mixer strip view."
                impl = "src/view/mixer/view"
                status = "real"
            PianoRollView:lower() -> TerraUIDecl
                doc "Lower piano roll note editor."
                impl = "src/view/piano_roll/view"
                status = "real"
            DeviceChainView:lower() -> TerraUIDecl
                doc "Lower device chain editor."
                impl = "src/view/device_chain/view"
                status = "real"
            DeviceView:lower() -> TerraUIDecl
                doc "Lower focused device editor."
                impl = "src/view/device_view"
                status = "real"
            GridPatchView:lower() -> TerraUIDecl
                doc "Lower grid patch editor."
                impl = "src/view/grid_patch_view"
                status = "real"
            InspectorView:lower() -> TerraUIDecl
                doc "Lower inspector details panel."
                impl = "src/view/inspector/view"
                status = "real"
            BrowserView:lower() -> TerraUIDecl
                doc "Lower browser sidebar."
                impl = "src/view/browser/view"
                status = "real"
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- PHASE 2: AUTHORED
    -- Canonical semantic graph document.
    -- ════════════════════════════════════════════════════════════════

    --- Canonical semantic graph document. The source of truth after lowering.
    --- Graph is the universal container. NodeKind is the one sum type.
    --- Richness belongs here; resolve should not invent absent semantics.
    phase Authored
        --- Authored project: transport, tracks, scenes, tempo, assets.
        record Project
            name: string
            author: string?
            format_version: number
            transport: Transport
            tracks: Track*
            scenes: Scene*
            tempo_map: TempoMap
            assets: AssetBank
            unique
        end

        --- Transport settings in authored form.
        record Transport
            sample_rate: number
            buffer_size: number
            bpm: number
            swing: number
            time_sig_num: number
            time_sig_den: number
            launch_quantize: Quantize
            looping: boolean
            loop_range: TimeRange?
        end

        --- Beat-based time range.
        record TimeRange
            start_beats: number
            end_beats: number
        end

        --- Quantize grid values.
        enum Quantize
            doc "Quantize grid for launching and scheduling."
            QNone
            Q1_64
            Q1_32
            Q1_16
            Q1_8
            Q1_4
            Q1_2
            Q1Bar
            Q2Bars
            Q4Bars
        end

        --- Tempo and time signature automation.
        record TempoMap
            tempo: TempoPoint*
            signatures: SigPoint*
        end

        --- Tempo automation point.
        record TempoPoint
            at_beats: number
            bpm: number
        end

        --- Time signature change point.
        record SigPoint
            at_beats: number
            num: number
            den: number
        end

        --- One mixer track with device graph, clips, slots, sends.
        record Track
            id: number
            name: string
            channels: number
            input: TrackInput
            volume: Param
            pan: Param
            device_graph: Graph
            clips: Clip*
            launcher_slots: Slot*
            sends: Send*
            output_track_id: number?
            group_track_id: number?
            muted: boolean
            soloed: boolean
            armed: boolean
            monitor_input: boolean
            phase_invert: boolean
        end

        --- Track input routing.
        enum TrackInput
            doc "Recording/monitoring source routing."
            NoInput
            AudioInput { device_id: number, channel: number }
            MIDIInput { device_id: number, channel: number }
            TrackInputTap { track_id: number, post_fader: boolean }
        end

        --- Send routing between tracks.
        record Send
            id: number
            target_track_id: number
            level: Param
            pre_fader: boolean
            enabled: boolean
        end

        --- Audio/note clip on the timeline.
        record Clip
            id: number
            content: ClipContent
            start_beats: number
            duration_beats: number
            source_offset_beats: number
            lane: number
            muted: boolean
            gain: Param
            fade_in: FadeSpec?
            fade_out: FadeSpec?
        end

        --- Clip content type.
        enum ClipContent
            doc "Audio reference or note asset reference."
            AudioContent { audio_asset_id: number }
            NoteContent { note_asset_id: number }
        end

        --- Fade specification.
        record FadeSpec
            duration_beats: number
            curve: FadeCurve
        end

        --- Fade curve shape.
        enum FadeCurve
            doc "Fade envelope shapes."
            LinearFade
            EqualPower
            SCurve
            ExpoFade
        end

        --- Launcher slot.
        record Slot
            slot_index: number
            content: SlotContent
            behavior: LaunchBehavior
            enabled: boolean
        end

        --- Slot content.
        enum SlotContent
            doc "Launcher slot content types."
            EmptySlot
            ClipSlot { clip_id: number }
            StopSlot
        end

        --- Launch behavior.
        record LaunchBehavior
            mode: LaunchMode
            quantize_override: Quantize?
            legato: boolean
            retrigger: boolean
            follow: FollowAction?
        end

        --- Launch mode.
        enum LaunchMode
            doc "Clip launch trigger modes."
            Trigger
            Gate
            Toggle
            Repeat
        end

        --- Follow action.
        record FollowAction
            kind: FollowKind
            weight_a: number
            weight_b: number
            target_scene_id: number?
        end

        --- Follow action target.
        enum FollowKind
            doc "Post-clip follow action targets."
            FNone
            FNext
            FPrev
            FFirst
            FLast
            FOther
            FRandom
            FStop
        end

        --- Scene.
        record Scene
            id: number
            name: string
            slots: SceneSlot*
            quantize_override: Quantize?
            tempo_override: number?
        end

        --- Scene slot assignment.
        record SceneSlot
            track_id: number
            slot_index: number
            stop_others: boolean
        end

        -- ── THE GRAPH ──

        --- Universal container. Everything is a Graph.
        --- Serial chain, free patch, parallel layers, switched selector, freq split.
        record Graph
            id: number
            inputs: GraphPort*
            outputs: GraphPort*
            nodes: Node*
            wires: Wire*
            pre_cords: PreCord*
            layout: GraphLayout
            domain: SignalDomain
        end

        --- Graph composition layout contract.
        enum GraphLayout
            doc "How nodes are connected: serial chaining, free patching, parallel mix, switched select, or split."
            Serial
            Free
            Parallel { layers: LayerConfig* }
            Switched { config: SwitchConfig }
            Split { config: SplitConfig }
        end

        --- Per-layer mix config in parallel layout.
        record LayerConfig
            node_id: number
            volume: Param
            pan: Param
            muted: boolean
        end

        --- Selector switching config.
        record SwitchConfig
            mode: SelectorMode
            node_ids: number*
        end

        --- Selector mode.
        enum SelectorMode
            doc "How the selector chooses active branches."
            ManualSelect
            RoundRobin
            FreeRobin
            FreeVoice
            Keyswitch { lowest_note: number }
            CCSwitched { cc: number }
            ProgramChange
            VelocitySplit { thresholds: number* }
        end

        --- Split routing config.
        record SplitConfig
            kind: SplitKind
            bands: SplitBand*
        end

        --- Split routing policy.
        enum SplitKind
            doc "Signal partitioning method."
            FreqSplit
            TransientSplit
            LoudSplit
            MidSideSplit
            LeftRightSplit
            NoteSplit
        end

        --- One split band with crossover.
        record SplitBand
            node_id: number
            crossover_value: number
        end

        --- Graph signal domain hint.
        enum SignalDomain
            doc "Graph-level signal domain classification."
            NoteDomain
            AudioDomain
            HybridDomain
            ControlDomain
        end

        --- Graph boundary port.
        record GraphPort
            id: number
            name: string
            hint: PortHint
            channels: number
            optional: boolean
        end

        --- Port signal hint.
        enum PortHint
            doc "Port signal category hint."
            AudioHint
            ControlHint
            GateHint
            PitchHint
            PhaseHint
            TriggerHint
        end

        --- Explicit dataflow edge between node ports.
        record Wire
            from_node_id: number
            from_port: number
            to_node_id: number
            to_port: number
        end

        --- Context-bound input source (phase, note data, audio).
        record PreCord
            to_node_id: number
            to_port: number
            kind: PreCordKind
            arg0: number?
        end

        --- Pre-wired context source kinds.
        enum PreCordKind
            doc "Context sources normalized during resolve."
            PCDevicePhase
            PCGlobalPhase
            PCNotePitch
            PCNoteGate
            PCNoteVelocity
            PCNotePressure
            PCNoteTimbre
            PCNoteGain
            PCAudioIn
            PCAudioInL
            PCAudioInR
            PCPreviousNote
        end

        -- ── NODES ──

        --- Universal processing unit: device, module, container, modulator.
        record Node
            id: number
            name: string
            kind: NodeKind
            params: Param*
            inputs: Port*
            outputs: Port*
            mod_slots: ModSlot*
            child_graphs: ChildGraph*
            enabled: boolean
            x_pos: number?
            y_pos: number?
        end

        --- Child graph with explicit role attachment.
        record ChildGraph
            role: ChildGraphRole
            graph: Graph
        end

        --- Child graph structural roles.
        enum ChildGraphRole
            doc "Attachment point for nested graphs."
            MainChild
            PreFXChild
            PostFXChild
            NoteFXChild
        end

        --- Node I/O port.
        record Port
            id: number
            name: string
            hint: PortHint
            channels: number
            optional: boolean
            default_value: number?
        end

        --- Modulator slot owned by a node.
        record ModSlot
            modulator: Node
            routings: ModRoute*
            per_voice: boolean
        end

        --- One modulation routing from mod slot to target param.
        record ModRoute
            target_param_id: number
            depth: number
            bipolar: boolean
            scale_mod_slot: number?
            scale_param_id: number?
        end

        -- ── PARAMETERS ──

        --- Named parameter with value source, range, combine, and smoothing.
        record Param
            id: number
            name: string
            default_value: number
            min_value: number
            max_value: number
            source: ParamSource
            combine: CombineMode
            smoothing: Smoothing
        end

        --- Parameter value source.
        enum ParamSource
            doc "Static value or automation curve reference."
            StaticValue { value: number }
            AutomationRef { curve: AutoCurve }
        end

        --- Automation curve.
        record AutoCurve
            points: AutoPoint*
            mode: InterpMode
        end

        --- Automation breakpoint.
        record AutoPoint
            time_beats: number
            value: number
        end

        --- Interpolation mode.
        enum InterpMode
            doc "Interpolation between automation points."
            Linear
            Smoothstep
            Hold
        end

        --- Parameter combine mode.
        enum CombineMode
            doc "How modulation/automation combine with base value."
            Replace
            Add
            Multiply
            ModMin
            ModMax
        end

        --- Smoothing policy.
        enum Smoothing
            doc "Parameter smoothing for zipper-free transitions."
            NoSmoothing
            Lag { ms: number }
        end

        -- ── NODE KINDS ──

        --- THE one sum type carrying all variety. Instruments, FX, grid modules,
        --- containers, modulators, plugins. One enum, intentionally broad.
        enum NodeKind
            doc "Canonical algebra of processing things."

            BasicSynth { cfg: SynthCfg }
            Sampler { zone_bank_id: number }
            DrumMachine { pads: DrumPad* }
            Polymer { osc1: number, osc2: number, filter_type: number }
            HWInstrument { midi_port: number, audio_port: number }

            GainNode
            PanNode
            EQNode { bands: EQBand* }
            CompressorNode
            GateNode
            DelayNode
            ReverbNode
            ChorusNode
            FlangerNode
            PhaserNode
            SaturatorNode { curve: SatCurve }
            ConvolverNode { ir_id: number }
            HWFXNode { out_port: number, in_port: number }

            ArpNode
            ChordNode { notes: ChordNote* }
            NoteFilterNode
            NoteQuantizeNode
            NoteLengthNode
            NoteEchoNode
            NoteLatchNode
            DribbleNode
            RicochetNode

            SubGraph

            SineOsc
            SawOsc
            SquareOsc
            TriangleOsc
            PulseOsc
            NoiseGen { color: NoiseColor }
            Wavetable { table_id: number }
            FMOp
            PhaseDistortion
            Karplus
            Resonator
            SamplePlayer { asset_id: number }
            Granular { asset_id: number }
            SubOsc

            SVF
            Ladder
            CombF
            Allpass
            Formant
            SampleAndHold
            DCBlock
            SlewFilter
            OnePoleLow
            OnePoleHigh

            Wavefolder
            Clipper { mode: ClipMode }
            Saturate
            QuantizeN { levels: number }
            Rectifier { mode: RectMode }
            Mirror
            WaveShape { table: number* }
            Bitcrush

            AddN
            SubN
            MulN
            DivN
            ModN
            AbsN
            NegN
            MinN
            MaxN
            ClampN
            MapN
            PowN
            LogN
            SinN
            CosN
            AtanN
            FloorN
            CeilN
            FracN
            LerpN
            SmoothN

            GTNode
            LTNode
            EqNode { tol: number }
            AndN
            OrN
            NotN
            XorN
            FlipFlopN
            LatchN

            MergeN
            SplitN
            StereoMergeN
            StereoSplitN
            CrossfadeN
            SwitchN { inputs: number }
            AttenuateN
            OffsetN
            PanN
            WidthN
            InvertN
            DelayLineN { max_samples: number }
            FeedbackInN
            FeedbackOutN

            PhasorN
            PhaseScaleN
            PhaseOffsetN
            PhaseQuantN
            PhaseFormantN
            PhaseWrapN
            PhaseResetN
            PhaseTrigN
            PhaseStallN

            ADEnv
            ADSREnv
            ADHSREnv
            AREnv
            DecayEnv
            MSEGEnv { points: MSEGPt* }
            SlewEnv
            FollowerEnv
            SampleEnv

            TrigRise
            TrigFall
            TrigChange
            ClockDiv
            ClockMul
            Burst
            ProbGate { prob: number }
            Delay1
            TransportGateN

            StepSeq { steps: number }
            Counter { max: number }
            Accum
            StackN { size: number }
            DataTable { values: number* }
            BezierN { pts: BezierPt* }
            SlewLimit

            AudioInN
            AudioOutN
            NoteInN
            NoteOutN
            CVInN { port: number }
            CVOutN { port: number }
            PitchInN
            GateInN
            VelocityInN
            PressureInN
            TimbreInN
            GainInN
            ValueInN
            ValueOutN

            ScopeN
            SpectrumN
            ValueDispN
            NoteN

            LFOMod { shape: LFOShape }
            ADSRMod
            ADHSRMod
            MSEGMod { points: MSEGPt* }
            StepsMod { steps: number }
            SidechainMod { source_track_id: number? }
            FollowerMod
            ExprMod { kind: ExprKind }
            KeyTrackMod
            RandomMod
            MacroKnob
            ButtonMod
            ButtonsMod
            VectorMod { dims: number }
            MIDICCMod { cc: number }
            HWCVInMod { port: number }
            Channel16Mod

            VSTPlugin { handle: PluginHandle, format: string }
            CLAPPlugin { handle: PluginHandle }

            AudioReceiver { source_track_id: number? }
            NoteReceiver { source_track_id: number? }
            CVOutDevice { port: number }
            MeterNode
            SpectrumAnalyzer
        end

        -- ── Sub-types for NodeKind ──

        --- Synthesizer oscillator/filter/voice configuration.
        record SynthCfg
            oscillators: OscCfg*
            filter: FilterCfg?
            voice_count: number
            voice_stack: VoiceStack?
            mono: boolean
            glide_ms: number
        end

        --- Oscillator configuration.
        record OscCfg
            shape: OscShape
            tune: number
            fine: number
            level: number
        end

        --- Oscillator waveform shape.
        enum OscShape
            doc "Oscillator waveform types."
            OscSine
            OscSaw
            OscSquare
            OscTri
            OscPulse
            OscNoise
            OscWT { table_id: number }
            OscFM { ratio: number, amount: number }
        end

        --- Filter configuration.
        record FilterCfg
            shape: FilterShape
            key_track: number
        end

        --- Filter topology.
        enum FilterShape
            doc "Filter topologies."
            FLP12
            FLP24
            FHP12
            FHP24
            FBP12
            FBP24
            FNotch
            FComb
            FSVF
            FLadder
            FFormant
        end

        --- Voice stacking/unison.
        record VoiceStack
            count: number
            spread: StackSpread
            detune: number
        end

        --- Unison voice spread mode.
        enum StackSpread
            doc "Voice stack detuning spread."
            SpreadLinear
            SpreadPower
            SpreadRandom
        end

        --- Drum pad (note → chain mapping).
        record DrumPad
            note: number
            chain: Graph
            choke_group: number?
        end

        --- EQ band.
        record EQBand
            type: EQBandType
        end

        --- EQ band type.
        enum EQBandType
            doc "EQ band filter types."
            LowShelf
            HighShelf
            Peak
            LowCut
            HighCut
        end

        --- Saturation curve shape.
        enum SatCurve
            doc "Saturation curve types."
            Tanh
            SoftClip
            HardClip
            Tube
            FoldBack
        end

        --- Chord note interval.
        record ChordNote
            semitone: number
            vel_scale: number
        end

        --- Noise color.
        enum NoiseColor
            doc "Noise generator spectrum color."
            White
            Pink
            Brown
            Blue
            Violet
        end

        --- Hard/soft clip mode.
        enum ClipMode
            doc "Clipper mode."
            HardClipM
            SoftClipM
            FoldClipM
        end

        --- Rectifier mode.
        enum RectMode
            doc "Rectifier mode."
            FullRect
            HalfRect
            SoftRect
        end

        --- LFO waveform shape.
        enum LFOShape
            doc "LFO oscillator shapes."
            Sine
            Triangle
            Square
            Saw
            SampleHoldLFO
            CustomLFO
        end

        --- Expression modulator source.
        enum ExprKind
            doc "Note expression source for ExprMod."
            Velocity
            Pressure
            Timbre
            PitchBendE
            ReleaseVel
            NoteGainE
            NotePanE
        end

        --- MSEG envelope point.
        record MSEGPt
            time: number
            value: number
            curve: number
        end

        --- Bezier curve control point.
        record BezierPt
            x: number
            y: number
            cx1: number
            cy1: number
            cx2: number
            cy2: number
        end

        -- ── ASSETS ──

        --- Project asset bank: audio, notes, wavetables, IRs, zones.
        record AssetBank
            audio: AudioAsset*
            notes: NoteAsset*
            wavetables: WavetableAsset*
            irs: IRAsset*
            zone_banks: ZoneBank*
        end

        --- Audio sample asset reference.
        record AudioAsset
            id: number
            path: string
            sample_rate: number
            channels: number
            length_samples: number
        end

        --- Authored note document with semantic notes and expression.
        record NoteAsset
            id: number
            notes: AuthoredNote*
            expr_lanes: NoteExprLane*
            loop_start_beats: number
            loop_end_beats: number
        end

        --- Semantic note with stable ID.
        record AuthoredNote
            id: number
            pitch: number
            start_beats: number
            duration_beats: number
            velocity: number
            release_velocity: number?
            muted: boolean
        end

        --- Note expression kind.
        enum NoteExprKind
            doc "Per-note expression parameter types."
            NotePressureExpr
            NoteTimbreExpr
            NotePitchBendExpr
            NoteGainExpr
            NotePanExpr
        end

        --- Note expression lane.
        record NoteExprLane
            kind: NoteExprKind
            points: NoteExprPoint*
        end

        --- Note expression breakpoint.
        record NoteExprPoint
            time_beats: number
            value: number
            note_id: number?
        end

        --- Wavetable asset.
        record WavetableAsset
            id: number
            path: string
            frames: number
        end

        --- Impulse response asset.
        record IRAsset
            id: number
            path: string
            sample_rate: number
        end

        --- Sample zone bank.
        record ZoneBank
            id: number
            zones: SampleZone*
        end

        --- Multisampled zone mapping.
        record SampleZone
            path: string
            root: number
            lo_note: number
            hi_note: number
            lo_vel: number
            hi_vel: number
            loop_start: number
            loop_end: number
            loop_mode: LoopMode
        end

        --- Sample loop mode.
        enum LoopMode
            doc "Sample playback loop modes."
            NoLoop
            LoopFwd
            LoopPingPong
            LoopRev
        end

        --- Authored -> Resolved methods.
        methods
            doc "Resolve authored semantics into flat tick-based slices."
            Project:resolve(ticks_per_beat: number) -> Resolved.Project
                doc "Resolve full project: transport, tempo, tracks, scenes, assets."
                impl = "src/authored/project"
                fallback = function(self, err) local R = types.Resolved; return R.Project(R.Transport(44100,512,120,0,4,4,0,false,0,0), R.TempoMap(L()), L(), L(), R.AssetBank(L(),L(),L(),L(),L())) end
                status = "real"
            Transport:resolve(ticks_per_beat: number) -> Resolved.Transport
                doc "Resolve transport to tick-based form."
                impl = "src/authored/transport"
                fallback = function(self, err) return types.Resolved.Transport(44100,512,120,0,4,4,0,false,0,0) end
                status = "real"
            TempoMap:resolve(ticks_per_beat: number, sample_rate: number) -> Resolved.TempoMap
                doc "Resolve tempo map to sample-accurate segments."
                impl = "src/authored/transport"
                fallback = function(self, err) return types.Resolved.TempoMap(L()) end
                status = "real"
            Track:resolve(ticks_per_beat: number) -> Resolved.TrackSlice
                doc "Resolve track into reusable flat slice."
                impl = "src/authored/track"
                fallback = function(self, err) local R = types.Resolved; return R.TrackSlice(R.Track(self.id or 0, self.name or "error", self.channels or 2, 0,0,0,0,1,0,nil,nil,false,false,false,false,false), L(), L(), L(), L(), L(), R.GraphSlice(L{R.Graph(0,0,1,0,0,0,0,L(),L(),0,0,0,0,0,0)},L(),L(),L(),L(),L(),L(),L(),L())) end
                status = "real"
            Graph:resolve(ticks_per_beat: number) -> Resolved.GraphSlice
                doc "Resolve graph subtree into flat slice tables."
                impl = "src/authored/graph"
                fallback = function(self, err) local R = types.Resolved; return R.GraphSlice(L{R.Graph(self.id or 0,0,1,0,0,0,0,L(),L(),0,0,0,0,0,0)},L(),L(),L(),L(),L(),L(),L(),L()) end
                status = "real"
            Param:resolve(ticks_per_beat: number) -> Resolved.Param
                doc "Resolve parameter source to tick-based form."
                impl = "src/authored/param"
                fallback = function(self, err) local R = types.Resolved; return R.Param(self.id or 0, 0, self.name or "error", self.default_value or 0, self.min_value or 0, self.max_value or 1, R.ParamSourceRef(0, self.default_value or 0, nil), 0, 0, 0) end
                status = "real"
            Clip:resolve(ticks_per_beat: number) -> Resolved.Clip
                doc "Resolve clip timing to ticks."
                impl = "src/authored/clip"
                fallback = function(self, err) return types.Resolved.Clip(self.id or 0, 0, 0, 0, 0, 0, 0, false, 0, 0, 0, 0, 0) end
                status = "real"
            Slot:resolve() -> Resolved.Slot
                doc "Resolve launcher slot."
                impl = "src/authored/slot"
                fallback = function(self, err) return types.Resolved.Slot(self.slot_index or 0, 0, 0, 0, 0, false, false, 0, 0, 0, nil, false) end
                status = "real"
            Scene:resolve() -> Resolved.Scene
                doc "Resolve scene."
                impl = "src/authored/scene"
                fallback = function(self, err) return types.Resolved.Scene(self.id or 0, self.name or "error", L(), 0, nil) end
                status = "real"
            Send:resolve() -> Resolved.Send
                doc "Resolve send routing."
                impl = "src/authored/send"
                fallback = function(self, err) return types.Resolved.Send(self.id or 0, 0, 0, false, false) end
                status = "real"
            NodeKind:resolve() -> Resolved.NodeKindRef
                doc "Resolve node kind to integer code."
                impl = "src/authored/node_kind"
                fallback = function(self, err) return types.Resolved.NodeKindRef(0) end
                status = "real"
            AssetBank:resolve(ticks_per_beat: number) -> Resolved.AssetBank
                doc "Resolve asset bank."
                impl = "src/authored/asset_bank"
                fallback = function(self, err) return types.Resolved.AssetBank(L(),L(),L(),L(),L()) end
                status = "real"
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- PHASE 2: RESOLVED
    -- Ticks, codes, flat local slices. Zero sum types.
    -- ════════════════════════════════════════════════════════════════

    --- Flattened runtime-facing semantic boundary. IDs fixed, ticks computed,
    --- local flat tables. Zero sum types from here down.
    phase Resolved
        --- Resolved project.
        record Project
            transport: Transport
            tempo_map: TempoMap
            track_slices: TrackSlice*
            scenes: Scene*
            assets: AssetBank
            unique
        end

        --- Resolved transport.
        record Transport
            sample_rate: number
            buffer_size: number
            bpm: number
            swing: number
            time_sig_num: number
            time_sig_den: number
            launch_quant_code: number
            looping: boolean
            loop_start_tick: number
            loop_end_tick: number
        end

        --- Resolved tempo map with sample-accurate segments.
        record TempoMap
            segments: TempoSeg*
        end

        --- One tempo segment with precomputed sample position.
        record TempoSeg
            start_tick: number
            bpm: number
            base_sample: number
            samples_per_tick: number
        end

        --- Reusable resolved slice for one track.
        record TrackSlice
            track: Track
            mixer_params: Param*
            mixer_curves: AutoCurve*
            clips: Clip*
            slots: Slot*
            sends: Send*
            device_graph: GraphSlice
            unique
        end

        --- Resolved track header.
        record Track
            id: number
            name: string
            channels: number
            input_kind_code: number
            input_arg0: number
            input_arg1: number
            --- Index into TrackSlice.mixer_params for volume.
            volume_param_index: number
            --- Index into TrackSlice.mixer_params for pan.
            pan_param_index: number
            device_graph_id: number
            output_track_id: number?
            group_track_id: number?
            muted: boolean
            soloed: boolean
            armed: boolean
            monitor_input: boolean
            phase_invert: boolean
        end

        --- Resolved send.
        record Send
            id: number
            target_track_id: number
            level_param_id: number
            pre_fader: boolean
            enabled: boolean
        end

        --- Resolved clip with tick timing.
        record Clip
            id: number
            content_kind: number
            asset_id: number
            start_tick: number
            duration_tick: number
            source_offset_tick: number
            lane: number
            muted: boolean
            gain_param_id: number
            fade_in_tick: number
            fade_in_curve_code: number
            fade_out_tick: number
            fade_out_curve_code: number
        end

        --- Resolved launcher slot.
        record Slot
            slot_index: number
            slot_kind: number
            clip_id: number
            launch_mode_code: number
            quant_code: number
            legato: boolean
            retrigger: boolean
            follow_kind_code: number
            follow_weight_a: number
            follow_weight_b: number
            follow_target_scene_id: number?
            enabled: boolean
        end

        --- Resolved scene.
        record Scene
            id: number
            name: string
            slots: SceneSlot*
            quant_code: number
            tempo_override: number?
        end

        --- Resolved scene slot.
        record SceneSlot
            track_id: number
            slot_index: number
            stop_others: boolean
        end

        --- Reusable resolved slice for one graph subtree.
        record GraphSlice
            graphs: Graph*
            graph_ports: GraphPort*
            nodes: Node*
            child_graph_refs: ChildGraphRef*
            wires: Wire*
            params: Param*
            mod_slots: ModSlot*
            mod_routes: ModRoute*
            curves: AutoCurve*
            unique
        end

        --- Resolved graph header.
        record Graph
            id: number
            layout_code: number
            domain_code: number
            first_input: number
            input_count: number
            first_output: number
            output_count: number
            node_ids: number*
            wire_ids: number*
            first_precord: number
            precord_count: number
            arg0: number
            arg1: number
            arg2: number
            arg3: number
        end

        --- Resolved node.
        record Node
            id: number
            node_kind_code: number
            first_param: number
            param_count: number
            first_input: number
            input_count: number
            first_output: number
            output_count: number
            first_mod_slot: number
            mod_slot_count: number
            first_child_graph_ref: number
            child_graph_ref_count: number
            enabled: boolean
            plugin_handle: PluginHandle?
            arg0: number
            arg1: number
            arg2: number
            arg3: number
        end

        --- Resolved wire.
        record Wire
            from_signal: number
            to_signal: number
        end

        --- Resolved graph port.
        record GraphPort
            id: number
            name: string
            hint_code: number
            channels: number
            optional: boolean
        end

        --- Child graph reference.
        record ChildGraphRef
            graph_id: number
            role_code: number
        end

        --- Resolved node kind reference (integer code).
        record NodeKindRef
            kind_code: number
        end

        --- Resolved parameter.
        record Param
            id: number
            node_id: number
            name: string
            default_value: number
            min_value: number
            max_value: number
            source: ParamSourceRef
            combine_code: number
            smoothing_code: number
            smoothing_ms: number
        end

        --- Parameter source reference.
        record ParamSourceRef
            source_kind: number
            value: number
            curve_id: number?
        end

        --- Automation curve.
        record AutoCurve
            id: number
            points: AutoPoint*
            interp_code: number
        end

        --- Automation point in ticks.
        record AutoPoint
            tick: number
            value: number
        end

        --- Resolved modulation slot.
        record ModSlot
            slot_index: number
            parent_node_id: number
            modulator_node_id: number
            modulator_kind_code: number
            first_param: number
            param_count: number
            arg0: number
            arg1: number
            arg2: number
            arg3: number
            per_voice: boolean
            first_route: number
            route_count: number
        end

        --- Resolved modulation route.
        record ModRoute
            mod_slot_index: number
            target_param_id: number
            depth: number
            bipolar: boolean
            scale_mod_slot: number?
            scale_param_id: number?
        end

        --- EQ band (resolved).
        record EQBand
            type_code: number
        end

        --- Resolved asset bank.
        record AssetBank
            audio: AudioAsset*
            notes: NoteAsset*
            wavetables: WavetableAsset*
            irs: IRAsset*
            zone_banks: ZoneBank*
        end

        --- Resolved audio asset.
        record AudioAsset
            id: number
            path: string
            sample_rate: number
            channels: number
            length_samples: number
        end

        --- Resolved note asset (flattened to events).
        record NoteAsset
            id: number
            events: NoteEvent*
            loop_start_tick: number
            loop_end_tick: number
        end

        --- Flattened note event.
        record NoteEvent
            kind: number
            tick: number
            d0: number
            d1: number
            d2: number
        end

        --- Resolved wavetable.
        record WavetableAsset
            id: number
            path: string
            frames: number
        end

        --- Resolved IR.
        record IRAsset
            id: number
            path: string
            sample_rate: number
        end

        --- Resolved zone bank.
        record ZoneBank
            id: number
            zones: SampleZone*
        end

        --- Resolved sample zone.
        record SampleZone
            path: string
            root: number
            lo_note: number
            hi_note: number
            lo_vel: number
            hi_vel: number
            loop_start: number
            loop_end: number
            loop_mode_code: number
        end

        --- Resolved -> Classified methods.
        methods
            doc "Classify resolved types into rate-bound slots."
            Project:classify() -> Classified.Project
                doc "Classify full project."
                impl = "src/resolved/project"
                fallback = function(self, err) local C = types.Classified; return C.Project(C.Transport(44100,512,120,0,4,4,0,false,0,0), C.TempoMap(L()), L(), L()) end
                status = "real"
            Transport:classify() -> Classified.Transport
                doc "Pass transport through to classified form."
                impl = "src/resolved/transport"
                fallback = function(self, err) return types.Classified.Transport(44100,512,120,0,4,4,0,false,0,0) end
                status = "real"
            TempoMap:classify() -> Classified.TempoMap
                doc "Pass tempo map through to classified form."
                impl = "src/resolved/transport"
                fallback = function(self, err) return types.Classified.TempoMap(L()) end
                status = "real"
            TrackSlice:classify() -> Classified.TrackSlice
                doc "Classify track slice with param bindings and literals."
                impl = "src/resolved/project"
                fallback = function(self, err) local C = types.Classified; return C.TrackSlice(C.Track(0,2,0,0,0,C.Binding(0,0),C.Binding(0,0),0,nil,nil,false,false,false,false), L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(), C.GraphSlice(L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),0,0)) end
                status = "real"
            GraphSlice:classify() -> Classified.GraphSlice
                doc "Classify graph slice with rate-bound signal tables."
                impl = "src/resolved/project"
                fallback = function(self, err) return types.Classified.GraphSlice(L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),L(),0,0) end
                status = "real"
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- PHASE 3: CLASSIFIED
    -- Binding = (rate_class, slot). Zero sum types.
    -- ════════════════════════════════════════════════════════════════

    --- Rate classification: every parameter bound to a rate class and slot.
    --- Binding = (rate_class, slot). rate_class: 0=literal 1=init 2=block 3=sample 4=event 5=voice.
    phase Classified
        --- Classified project.
        record Project
            transport: Transport
            tempo_map: TempoMap
            track_slices: TrackSlice*
            scenes: Scene*
            unique
        end

        --- Classified transport.
        record Transport
            sample_rate: number
            buffer_size: number
            bpm: number
            swing: number
            time_sig_num: number
            time_sig_den: number
            launch_quant_code: number
            looping: boolean
            loop_start_tick: number
            loop_end_tick: number
        end

        --- Classified tempo map.
        record TempoMap
            segments: TempoSeg*
        end

        --- Classified tempo segment.
        record TempoSeg
            start_tick: number
            end_tick: number
            bpm: number
            base_sample: number
            samples_per_tick: number
        end

        --- Reusable classified slice for one track.
        record TrackSlice
            track: Track
            mixer_params: Param*
            clips: Clip*
            slots: Slot*
            sends: Send*
            mixer_literals: Literal*
            mixer_init_ops: InitOp*
            mixer_block_ops: BlockOp*
            mixer_block_pts: BlockPt*
            mixer_sample_ops: SampleOp*
            mixer_event_ops: EventOp*
            mixer_voice_ops: VoiceOp*
            device_graph: GraphSlice
            unique
        end

        --- Classified track header.
        record Track
            id: number
            channels: number
            input_kind_code: number
            input_arg0: number
            input_arg1: number
            volume: Binding
            pan: Binding
            device_graph_id: number
            output_track_id: number?
            group_track_id: number?
            muted_structural: boolean
            solo_structural: boolean
            armed: boolean
            monitor_input: boolean
        end

        --- Classified send.
        record Send
            id: number
            target_track_id: number
            level: Binding
            pre_fader: boolean
            enabled: boolean
        end

        --- Classified clip.
        record Clip
            id: number
            content_kind: number
            asset_id: number
            start_tick: number
            end_tick: number
            source_offset_tick: number
            lane: number
            muted: boolean
            gain: Binding
            fade_in_tick: number
            fade_in_curve_code: number
            fade_out_tick: number
            fade_out_curve_code: number
        end

        --- Classified slot.
        record Slot
            slot_index: number
            slot_kind: number
            clip_id: number
            launch_mode_code: number
            quant_code: number
            legato: boolean
            retrigger: boolean
            follow_kind_code: number
            follow_weight_a: number
            follow_weight_b: number
            follow_target_scene_id: number?
            enabled: boolean
        end

        --- Classified scene.
        record Scene
            id: number
            first_slot: number
            slot_count: number
            quant_code: number
            tempo_override: number?
        end

        --- Reusable classified slice for one graph.
        record GraphSlice
            graphs: Graph*
            graph_ports: GraphPort*
            nodes: Node*
            child_graph_refs: ChildGraphRef*
            wires: Wire*
            feedback_pairs: FeedbackPair*
            params: Param*
            mod_slots: ModSlot*
            mod_routes: ModRoute*
            literals: Literal*
            init_ops: InitOp*
            block_ops: BlockOp*
            block_pts: BlockPt*
            sample_ops: SampleOp*
            event_ops: EventOp*
            voice_ops: VoiceOp*
            total_signals: number
            total_state_slots: number
            unique
        end

        --- Classified graph header.
        record Graph
            id: number
            layout_code: number
            domain_code: number
            first_input: number
            input_count: number
            first_output: number
            output_count: number
            node_ids: number*
            first_wire: number
            wire_count: number
            first_feedback: number
            feedback_count: number
            first_signal: number
            signal_count: number
        end

        --- Classified node.
        record Node
            id: number
            node_kind_code: number
            first_param: number
            param_count: number
            signal_offset: number
            state_offset: number
            state_size: number
            first_mod_slot: number
            mod_slot_count: number
            first_child_graph_ref: number
            child_graph_ref_count: number
            enabled: boolean
            runtime_state_slot: number
            arg0: number
            arg1: number
            arg2: number
            arg3: number
        end

        --- Classified wire.
        record Wire
            from_signal: number
            to_signal: number
            weight: number
        end

        --- Classified graph port.
        record GraphPort
            id: number
            hint_code: number
            channels: number
            optional: boolean
            signal_base: number
        end

        --- Classified child graph ref.
        record ChildGraphRef
            graph_id: number
            role_code: number
        end

        --- Classified feedback pair.
        record FeedbackPair
            write_signal: number
            read_signal: number
            delay_state_slot: number
        end

        --- Classified parameter with rate-bound base value.
        record Param
            id: number
            node_id: number
            default_value: number
            min_value: number
            max_value: number
            base_value: Binding
            combine_code: number
            smoothing_code: number
            smoothing_ms: number
            first_modulation: number
            modulation_count: number
            runtime_state_slot: number
        end

        --- Classified modulation slot.
        record ModSlot
            slot_index: number
            parent_node_id: number
            modulator_node_id: number
            modulator_kind_code: number
            first_param: number
            param_count: number
            arg0: number
            arg1: number
            arg2: number
            arg3: number
            per_voice: boolean
            first_route: number
            route_count: number
            state_size: number
            runtime_state_slot: number
            output_binding: Binding
        end

        --- Classified modulation route.
        record ModRoute
            mod_slot_index: number
            target_param_id: number
            depth: Binding
            bipolar: boolean
            scale_binding_slot: number?
        end

        --- Classified EQ band.
        record EQBand
            type_code: number
            freq: Binding
            gain: Binding
            q: Binding
        end

        --- Rate-class binding: (rate_class, slot).
        record Binding
            rate_class: number
            slot: number
        end

        --- Literal value in the literal table.
        record Literal
            value: number
        end

        --- Init-rate operation.
        record InitOp
            kind: number
            arg0: number
            arg1: number
            i0: Binding
            i1: Binding?
            state_slot: number
        end

        --- Block-rate operation.
        record BlockOp
            kind: number
            first_pt: number
            pt_count: number
            interp: number
            arg0: number
            i0: Binding
            i1: Binding?
        end

        --- Block automation breakpoint.
        record BlockPt
            tick: number
            value: number
        end

        --- Sample-rate operation.
        record SampleOp
            kind: number
            i0: Binding
            i1: Binding?
            arg0: number
            arg1: number
            arg2: number
            state_slot: number
        end

        --- Event-rate operation.
        record EventOp
            kind: number
            event_code: number
            min_v: number
            max_v: number
            state_slot: number
        end

        --- Voice-rate operation.
        record VoiceOp
            kind: number
            i0: Binding
            i1: Binding?
            arg0: number
            arg1: number
            arg2: number
            state_slot: number
        end

        --- Classified -> Scheduled methods.
        methods
            doc "Schedule classified types into buffer-allocated reusable programs."
            Project:schedule() -> Scheduled.Project
                doc "Schedule full project into track programs."
                impl = "src/classified/project"
                fallback = function(self, err) local S = types.Scheduled; return S.Project(S.Transport(44100,512,120,0,4,4,0,false,0,0), S.TempoMap(L()), L(), L()) end
                status = "real"
            Transport:schedule() -> Scheduled.Transport
                doc "Pass transport to scheduled form."
                impl = "src/classified/transport"
                fallback = function(self, err) return types.Scheduled.Transport(44100,512,120,0,4,4,0,false,0,0) end
                status = "real"
            TempoMap:schedule() -> Scheduled.TempoMap
                doc "Pass tempo map to scheduled form."
                impl = "src/classified/transport"
                fallback = function(self, err) return types.Scheduled.TempoMap(L()) end
                status = "real"
            Binding:schedule() -> Scheduled.Binding
                doc "Convert classified binding to scheduled binding."
                impl = "src/classified/binding"
                fallback = function(self, err) return types.Scheduled.Binding(0, 0) end
                status = "real"
            TrackSlice:schedule(transport: Transport, tempo_map: TempoMap) -> Scheduled.TrackProgram
                doc "Schedule track slice into reusable track program."
                impl = "src/classified/project"
                status = "real"
            GraphSlice:schedule(transport: Transport, tempo_map: TempoMap) -> Scheduled.GraphProgram
                doc "Schedule graph slice into reusable graph program."
                impl = "src/classified/project"
                status = "real"
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- PHASE 4: SCHEDULED
    -- Buffer slots, reusable programs, leaf compile units.
    -- ════════════════════════════════════════════════════════════════

    --- Buffer-allocated reusable programs. Raw jobs are data; programs own compile().
    phase Scheduled
        --- Scheduled project.
        record Project
            transport: Transport
            tempo_map: TempoMap
            track_programs: TrackProgram*
            scene_entries: SceneEntry*
            unique
        end

        --- Scheduled transport.
        record Transport
            sample_rate: number
            buffer_size: number
            bpm: number
            swing: number
            time_sig_num: number
            time_sig_den: number
            launch_quant_code: number
            looping: boolean
            loop_start_tick: number
            loop_end_tick: number
        end

        --- Scheduled tempo map.
        record TempoMap
            segs: TempoSeg*
        end

        --- Scheduled tempo segment.
        record TempoSeg
            start_tick: number
            end_tick: number
            bpm: number
            base_sample: number
            samples_per_tick: number
        end

        --- Allocated buffer descriptor.
        record Buffer
            index: number
            channels: number
            interleaved: boolean
            persistent: boolean
        end

        --- Reusable track compilation unit with leaf programs.
        record TrackProgram
            transport: Transport
            tempo_map: TempoMap
            buffers: Buffer*
            track: TrackPlan
            device_graph: GraphProgram
            clip_programs: ClipProgram*
            send_programs: SendProgram*
            mix_programs: MixProgram*
            output_programs: OutputProgram*
            launch_entries: LaunchEntry*
            mixer_params: Param*
            mixer_param_bindings: Binding*
            mixer_literals: Literal*
            mixer_init_ops: InitOp*
            mixer_block_ops: BlockOp*
            mixer_block_pts: BlockPt*
            mixer_sample_ops: SampleOp*
            mixer_event_ops: EventOp*
            mixer_voice_ops: VoiceOp*
            total_buffers: number
            total_state_slots: number
            master_left: number
            master_right: number
            unique
        end

        --- Reusable graph compilation unit with node/mod leaf programs.
        record GraphProgram
            transport: Transport
            tempo_map: TempoMap
            buffers: Buffer*
            graph: GraphPlan
            node_programs: NodeProgram*
            mod_programs: ModProgram*
            literals: Literal*
            init_ops: InitOp*
            block_ops: BlockOp*
            block_pts: BlockPt*
            sample_ops: SampleOp*
            event_ops: EventOp*
            voice_ops: VoiceOp*
            total_buffers: number
            total_state_slots: number
            unique
        end

        --- Flat graph metadata header.
        record GraphPlan
            graph_id: number
            in_buf: number
            out_buf: number
            first_feedback: number
            feedback_count: number
        end

        --- Flat track metadata header.
        record TrackPlan
            track_id: number
            volume: Binding
            pan: Binding
            input_kind_code: number
            input_arg0: number
            input_arg1: number
            work_buf: number
            aux_buf: number
            mix_in_buf: number
            out_left: number
            out_right: number
            is_master: boolean
        end

        --- Raw node execution data.
        record NodeJob
            node_id: number
            kind_code: number
            in_buf: number
            out_buf: number
            first_param: number
            param_count: number
            state_slot: number
            state_size: number
            arg0: number
            arg1: number
            arg2: number
            arg3: number
        end

        --- Leaf node compile unit.
        record NodeProgram
            node: NodeJob
            param_bindings: Binding*
            params: Param*
            mod_slots: ModSlot*
            mod_routes: ModRoute*
            literals: Literal*
            transport: Transport
            tempo_map: TempoMap
            unique
        end

        --- Raw clip execution data.
        record ClipJob
            clip_id: number
            content_kind: number
            asset_id: number
            out_buf: number
            start_tick: number
            end_tick: number
            source_offset_tick: number
            gain: Binding
            reversed: boolean
            fade_in_tick: number
            fade_in_curve_code: number
            fade_out_tick: number
            fade_out_curve_code: number
        end

        --- Leaf clip compile unit.
        record ClipProgram
            clip: ClipJob
            literals: Literal*
            transport: Transport
            tempo_map: TempoMap
            unique
        end

        --- Raw modulator execution data.
        record ModJob
            mod_node_id: number
            parent_node_id: number
            kind_code: number
            first_param: number
            param_count: number
            arg0: number
            arg1: number
            arg2: number
            arg3: number
            per_voice: boolean
            first_route: number
            route_count: number
            runtime_state_slot: number
            state_size: number
            output_state_slot: number
            output: Binding
        end

        --- Leaf modulator compile unit.
        record ModProgram
            mod: ModJob
            param_bindings: Binding*
            literals: Literal*
            transport: Transport
            tempo_map: TempoMap
            unique
        end

        --- Raw send execution data.
        record SendJob
            source_buf: number
            target_buf: number
            level: Binding
            pre_fader: boolean
            enabled: boolean
        end

        --- Leaf send compile unit.
        record SendProgram
            send: SendJob
            literals: Literal*
            transport: Transport
            tempo_map: TempoMap
            unique
        end

        --- Raw mix execution data.
        record MixJob
            source_buf: number
            target_buf: number
            gain: Binding
        end

        --- Leaf mix compile unit.
        record MixProgram
            mix: MixJob
            literals: Literal*
            transport: Transport
            tempo_map: TempoMap
            unique
        end

        --- Raw output execution data.
        record OutputJob
            source_buf: number
            out_left: number
            out_right: number
            gain: Binding
            pan: Binding
        end

        --- Leaf output compile unit.
        record OutputProgram
            output: OutputJob
            literals: Literal*
            transport: Transport
            tempo_map: TempoMap
            unique
        end

        --- Launcher entry for runtime.
        record LaunchEntry
            track_id: number
            slot_index: number
            slot_kind: number
            clip_id: number
            launch_mode_code: number
            quant_code: number
            legato: boolean
            retrigger: boolean
            follow_kind_code: number
            follow_weight_a: number
            follow_weight_b: number
            follow_target_scene_id: number?
            enabled: boolean
        end

        --- Scene entry for runtime.
        record SceneEntry
            scene_id: number
            first_slot: number
            slot_count: number
            quant_code: number
            tempo_override: number?
        end

        --- Literal value.
        record Literal
            value: number
        end

        --- Scheduled parameter.
        record Param
            id: number
            node_id: number
            default_value: number
            min_value: number
            max_value: number
            base_value: Binding
            combine_code: number
            smoothing_code: number
            smoothing_ms: number
            first_modulation: number
            modulation_count: number
            runtime_state_slot: number
        end

        --- Scheduled modulation slot.
        record ModSlot
            slot_index: number
            parent_node_id: number
            modulator_node_id: number
            modulator_kind_code: number
            first_param: number
            param_count: number
            arg0: number
            arg1: number
            arg2: number
            arg3: number
            per_voice: boolean
            first_route: number
            route_count: number
            state_size: number
            runtime_state_slot: number
            output_binding: Binding
        end

        --- Scheduled modulation route.
        record ModRoute
            mod_slot_index: number
            target_param_id: number
            depth: Binding
            bipolar: boolean
            scale_binding_slot: number?
        end

        --- Scheduled binding.
        record Binding
            rate_class: number
            slot: number
        end

        --- Init-rate op.
        record InitOp
            kind: number
            arg0: number
            arg1: number
            i0: Binding
            i1: Binding?
            state_slot: number
        end

        --- Block-rate op.
        record BlockOp
            kind: number
            first_pt: number
            pt_count: number
            interp: number
            arg0: number
            i0: Binding
            i1: Binding?
        end

        --- Block automation point.
        record BlockPt
            tick: number
            value: number
        end

        --- Sample-rate op.
        record SampleOp
            kind: number
            i0: Binding
            i1: Binding?
            arg0: number
            arg1: number
            arg2: number
            state_slot: number
        end

        --- Event-rate op.
        record EventOp
            kind: number
            event_code: number
            min_v: number
            max_v: number
            state_slot: number
        end

        --- Voice-rate op.
        record VoiceOp
            kind: number
            i0: Binding
            i1: Binding?
            arg0: number
            arg1: number
            arg2: number
            state_slot: number
        end

        --- Scheduled -> Kernel compile methods.
        methods
            doc "Compile scheduled programs into native Terra code."
            Project:compile() -> Kernel.Project
                doc "Compile full project: compose track units into render entry + state ABI."
                impl = "src/scheduled/project"
                fallback = function(self, err)
                    local terra silent(ol: &float, or_: &float, f: int32, state: &uint8)
                        for i = 0, f do ol[i] = 0.0f; or_[i] = 0.0f end
                    end
                    local terra init(state: &uint8) end
                    return types.Kernel.Project(silent, tuple(), init)
                end
                status = "real"
            TrackProgram:compile() -> Unit
                doc "Compile track program: compose graph, clip, send, mix, output units."
                impl = "src/scheduled/project"
                fallback = function(self, err) local terra noop(ol: &float, or_: &float, f: int32) end; return types.Unit(noop, tuple()) end
                status = "real"
            GraphProgram:compile() -> Unit
                doc "Compile graph program: compose node and mod units."
                impl = "src/scheduled/project"
                fallback = function(self, err) local terra noop(b: &float, f: int32) end; return types.Unit(noop, tuple()) end
                status = "real"
            NodeProgram:compile() -> Unit
                doc "Compile one node's DSP into a reusable unit."
                impl = "src/scheduled/leaf_programs"
                fallback = function(self, err) local terra noop(b: &float, f: int32, a: &float, b2: &float, c: &float, d: &float, e: &float) end; return types.Unit(noop, tuple()) end
                status = "real"
            ModProgram:compile() -> Unit
                doc "Compile one modulator into a reusable unit."
                impl = "src/scheduled/leaf_programs"
                fallback = function(self, err) local terra noop(b: &float, f: int32, a: &float, b2: &float, c: &float, d: &float, e: &float) end; return types.Unit(noop, tuple()) end
                status = "real"
            ClipProgram:compile() -> Unit
                doc "Compile one clip into a reusable unit."
                impl = "src/scheduled/leaf_programs"
                fallback = function(self, err) local terra noop(b: &float, f: int32, a: &float, b2: &float, c: &float, d: &float, e: &float) end; return types.Unit(noop, tuple()) end
                status = "real"
            SendProgram:compile() -> Unit
                doc "Compile one send into a reusable unit."
                impl = "src/scheduled/leaf_programs"
                fallback = function(self, err) local terra noop(b: &float, f: int32, a: &float, b2: &float, c: &float, d: &float, e: &float) end; return types.Unit(noop, tuple()) end
                status = "real"
            MixProgram:compile() -> Unit
                doc "Compile one mix bus into a reusable unit."
                impl = "src/scheduled/leaf_programs"
                fallback = function(self, err) local terra noop(b: &float, f: int32, a: &float, b2: &float, c: &float, d: &float, e: &float) end; return types.Unit(noop, tuple()) end
                status = "real"
            OutputProgram:compile() -> Unit
                doc "Compile one output stage into a reusable unit."
                impl = "src/scheduled/leaf_programs"
                fallback = function(self, err) local terra noop(b: &float, f: int32, a: &float, b2: &float, c: &float, d: &float, e: &float) end; return types.Unit(noop, tuple()) end
                status = "real"
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- PHASE 5: KERNEL
    -- Fully monomorphic execution surface. Terra only.
    -- ════════════════════════════════════════════════════════════════

    --- Fully monomorphic native execution surface.
    --- The builtin Unit intrinsic provides the canonical { fn, state_t } compile product.
    phase Kernel
        --- Compiled project with render entry point and owned state ABI.
        unit Project
            doc "Compiled project with render entry point and owned state ABI."
            init_fn: TerraFunc
        end

        --- Kernel methods.
        methods
            doc "Kernel runtime accessors."
            Project:entry_fn() -> TerraFunc
                doc "Return the compiled render entry function: terra(out_l, out_r, frames, state_raw)."
                impl = "src/kernel/project"
                status = "real"
            Project:state_type() -> TerraType
                doc "Return the runtime state ABI owned by this compiled project."
                impl = "src/kernel/project"
                status = "real"
            Project:state_init_fn() -> TerraFunc
                doc "Return the initializer: terra(state_raw) zero/init the project state tree."
                impl = "src/kernel/project"
                status = "real"
        end
    end
end

return DAW
