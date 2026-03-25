-- impl/authored/node_kind.t
-- Authored.NodeKind:resolve

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("authored.node_kind.resolve", "real")
diag.variant_family("authored.node_kind.resolve", "Authored", "NodeKind")

local node_kind_names = {
    "BasicSynth", "Sampler", "DrumMachine", "Polymer", "HWInstrument",
    "GainNode", "PanNode", "EQNode", "CompressorNode", "GateNode",
    "DelayNode", "ReverbNode", "ChorusNode", "FlangerNode", "PhaserNode",
    "SaturatorNode", "ConvolverNode", "HWFXNode",
    "ArpNode", "ChordNode", "NoteFilterNode", "NoteQuantizeNode",
    "NoteLengthNode", "NoteEchoNode", "NoteLatchNode", "DribbleNode",
    "RicochetNode",
    "SubGraph",
    "SineOsc", "SawOsc", "SquareOsc", "TriangleOsc", "PulseOsc",
    "NoiseGen", "Wavetable", "FMOp", "PhaseDistortion", "Karplus",
    "Resonator", "SamplePlayer", "Granular", "SubOsc",
    "SVF", "Ladder", "CombF", "Allpass", "Formant", "SampleAndHold",
    "DCBlock", "SlewFilter", "OnePoleLow", "OnePoleHigh",
    "Wavefolder", "Clipper", "Saturate", "QuantizeN", "Rectifier",
    "Mirror", "WaveShape", "Bitcrush",
    "AddN", "SubN", "MulN", "DivN", "ModN",
    "AbsN", "NegN", "MinN", "MaxN",
    "ClampN", "MapN", "PowN", "LogN",
    "SinN", "CosN", "AtanN",
    "FloorN", "CeilN", "FracN",
    "LerpN", "SmoothN",
    "GTNode", "LTNode", "EqNode", "AndN", "OrN", "NotN", "XorN",
    "FlipFlopN", "LatchN",
    "MergeN", "SplitN", "StereoMergeN", "StereoSplitN",
    "CrossfadeN", "SwitchN", "AttenuateN", "OffsetN",
    "PanN", "WidthN", "InvertN",
    "DelayLineN", "FeedbackInN", "FeedbackOutN",
    "PhasorN", "PhaseScaleN", "PhaseOffsetN", "PhaseQuantN",
    "PhaseFormantN", "PhaseWrapN", "PhaseResetN", "PhaseTrigN",
    "PhaseStallN",
    "ADEnv", "ADSREnv", "ADHSREnv", "AREnv", "DecayEnv",
    "MSEGEnv", "SlewEnv", "FollowerEnv", "SampleEnv",
    "TrigRise", "TrigFall", "TrigChange",
    "ClockDiv", "ClockMul", "Burst", "ProbGate",
    "Delay1", "TransportGateN",
    "StepSeq", "Counter", "Accum", "StackN",
    "DataTable", "BezierN", "SlewLimit",
    "AudioInN", "AudioOutN", "NoteInN", "NoteOutN",
    "CVInN", "CVOutN",
    "PitchInN", "GateInN", "VelocityInN", "PressureInN",
    "TimbreInN", "GainInN", "ValueInN", "ValueOutN",
    "ScopeN", "SpectrumN", "ValueDispN", "NoteN",
    "LFOMod", "ADSRMod", "ADHSRMod", "MSEGMod", "StepsMod",
    "SidechainMod", "FollowerMod", "ExprMod", "KeyTrackMod",
    "RandomMod", "MacroKnob", "ButtonMod", "ButtonsMod",
    "VectorMod", "MIDICCMod", "HWCVInMod", "Channel16Mod",
    "VSTPlugin", "CLAPPlugin",
    "AudioReceiver", "NoteReceiver", "CVOutDevice",
    "MeterNode", "SpectrumAnalyzer",
}

local kind_code_map = {}
for i, name in ipairs(node_kind_names) do
    kind_code_map[name] = i - 1
end

for member in pairs(D.Authored.NodeKind.members) do
    if type(member) == "table" and member ~= D.Authored.NodeKind then
        local name = rawget(member, "kind")
        if type(name) == "string" and kind_code_map[name] ~= nil then
            diag.variant_status("authored.node_kind.resolve", name, "real")
        end
    end
end

local resolve_node_kind = terralib.memoize(function(self)
    local code = kind_code_map[self.kind] or 0
    return D.Resolved.NodeKindRef(code)
end)

function D.Authored.NodeKind:resolve()
    return diag.wrap(nil, "authored.node_kind.resolve", "real", function()
        return resolve_node_kind(self)
    end, function()
        return F.resolved_node_kind_ref(0)
    end)
end

return true
