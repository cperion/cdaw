-- impl2/authored/node_kind.t
-- Authored.NodeKind:resolve -> Resolved.NodeKindRef

return function(R)
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
    for i, name in ipairs(node_kind_names) do kind_code_map[name] = i - 1 end

    return function(self)
        return R.NodeKindRef(kind_code_map[self.kind] or 0)
    end
end
