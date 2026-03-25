-- impl/authored/node_kind.t
-- Authored.NodeKind:resolve (parent method for all ~150 variants)
--
-- Returns a Resolved.NodeKindRef containing a numeric code.
-- Real implementations will assign meaningful codes per-variant.
-- For now, all variants get code 0 (GainNode-equivalent fallback).

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.node_kind.resolve", "real")


-- Build a kind_code table from the NodeKind variant names.
-- We assign sequential codes so the mapping is deterministic.
-- The list order matches the ASDL declaration order.
local node_kind_names = {
    -- DAW instruments
    "BasicSynth", "Sampler", "DrumMachine", "Polymer", "HWInstrument",
    -- DAW audio FX
    "GainNode", "PanNode", "EQNode", "CompressorNode", "GateNode",
    "DelayNode", "ReverbNode", "ChorusNode", "FlangerNode", "PhaserNode",
    "SaturatorNode", "ConvolverNode", "HWFXNode",
    -- DAW note FX
    "ArpNode", "ChordNode", "NoteFilterNode", "NoteQuantizeNode",
    "NoteLengthNode", "NoteEchoNode", "NoteLatchNode", "DribbleNode",
    "RicochetNode",
    -- Containers
    "SubGraph",
    -- Grid oscillators
    "SineOsc", "SawOsc", "SquareOsc", "TriangleOsc", "PulseOsc",
    "NoiseGen", "Wavetable", "FMOp", "PhaseDistortion", "Karplus",
    "Resonator", "SamplePlayer", "Granular", "SubOsc",
    -- Grid filters
    "SVF", "Ladder", "CombF", "Allpass", "Formant", "SampleAndHold",
    "DCBlock", "SlewFilter", "OnePoleLow", "OnePoleHigh",
    -- Grid shapers
    "Wavefolder", "Clipper", "Saturate", "QuantizeN", "Rectifier",
    "Mirror", "WaveShape", "Bitcrush",
    -- Grid math
    "AddN", "SubN", "MulN", "DivN", "ModN",
    "AbsN", "NegN", "MinN", "MaxN",
    "ClampN", "MapN", "PowN", "LogN",
    "SinN", "CosN", "AtanN",
    "FloorN", "CeilN", "FracN",
    "LerpN", "SmoothN",
    -- Grid logic
    "GTNode", "LTNode", "EqNode", "AndN", "OrN", "NotN", "XorN",
    "FlipFlopN", "LatchN",
    -- Grid mix/routing
    "MergeN", "SplitN", "StereoMergeN", "StereoSplitN",
    "CrossfadeN", "SwitchN", "AttenuateN", "OffsetN",
    "PanN", "WidthN", "InvertN",
    "DelayLineN", "FeedbackInN", "FeedbackOutN",
    -- Grid phase
    "PhasorN", "PhaseScaleN", "PhaseOffsetN", "PhaseQuantN",
    "PhaseFormantN", "PhaseWrapN", "PhaseResetN", "PhaseTrigN",
    "PhaseStallN",
    -- Grid envelopes
    "ADEnv", "ADSREnv", "ADHSREnv", "AREnv", "DecayEnv",
    "MSEGEnv", "SlewEnv", "FollowerEnv", "SampleEnv",
    -- Grid triggers
    "TrigRise", "TrigFall", "TrigChange",
    "ClockDiv", "ClockMul", "Burst", "ProbGate",
    "Delay1", "TransportGateN",
    -- Grid data
    "StepSeq", "Counter", "Accum", "StackN",
    "DataTable", "BezierN", "SlewLimit",
    -- Grid I/O
    "AudioInN", "AudioOutN", "NoteInN", "NoteOutN",
    "CVInN", "CVOutN",
    "PitchInN", "GateInN", "VelocityInN", "PressureInN",
    "TimbreInN", "GainInN", "ValueInN", "ValueOutN",
    -- Grid display
    "ScopeN", "SpectrumN", "ValueDispN", "NoteN",
    -- Modulators
    "LFOMod", "ADSRMod", "ADHSRMod", "MSEGMod", "StepsMod",
    "SidechainMod", "FollowerMod", "ExprMod", "KeyTrackMod",
    "RandomMod", "MacroKnob", "ButtonMod", "ButtonsMod",
    "VectorMod", "MIDICCMod", "HWCVInMod", "Channel16Mod",
    -- External plugins
    "VSTPlugin", "CLAPPlugin",
    -- Routing/utility
    "AudioReceiver", "NoteReceiver", "CVOutDevice",
    "MeterNode", "SpectrumAnalyzer",
}

local kind_code_map = {}
for i, name in ipairs(node_kind_names) do
    kind_code_map[name] = i - 1
end

-- Parent method: propagated to all ~150 NodeKind variants via __newindex.
function D.Authored.NodeKind:resolve(ctx)
    return diag.wrap(ctx, "authored.node_kind.resolve", "real", function()
        local code = kind_code_map[self.kind] or 0
        return D.Resolved.NodeKindRef(code)
    end, function()
        return F.resolved_node_kind_ref(0)
    end)
end

return true
