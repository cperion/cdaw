-- impl/scheduled/node_program.t
-- Scheduled.NodeProgram:compile -> Kernel.Unit

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_node_job = require("impl/scheduled/compiler/node_job")

diag.status("scheduled.node_program.compile", "real")
diag.variant_family("scheduled.node_program.compile", "Authored", "NodeKind")
for member in pairs(D.Authored.NodeKind.members) do
    if type(member) == "table" and member ~= D.Authored.NodeKind then
        local name = rawget(member, "kind")
        if type(name) == "string" then
            diag.variant_status("scheduled.node_program.compile", name, "stub")
        end
    end
end
for name, status in pairs({
    GainNode = "real", NegN = "real", AbsN = "real", ClampN = "real", AttenuateN = "real", InvertN = "real",
    PanNode = "partial", EQNode = "partial", CompressorNode = "partial", GateNode = "partial",
    SaturatorNode = "partial", Clipper = "partial", Wavefolder = "partial",
    SineOsc = "partial", SawOsc = "partial", SquareOsc = "partial",
}) do
    diag.variant_status("scheduled.node_program.compile", name, status)
end

local function build_literal_values(literals)
    local values = {}
    for i = 1, #(literals or {}) do values[i] = literals[i].value end
    return values
end

local compile_node_program = terralib.memoize(function(self)
    local bufs_sym = symbol(&float, "bufs")
    local frames_sym = symbol(int32, "frames")
    local init_slots_sym = symbol(&float, "init_slots")
    local block_slots_sym = symbol(&float, "block_slots")
    local sample_slots_sym = symbol(&float, "sample_slots")
    local event_slots_sym = symbol(&float, "event_slots")
    local voice_slots_sym = symbol(&float, "voice_slots")

    local ctx = {
        diagnostics = {},
        BS = (self.transport and self.transport.buffer_size) or 512,
        sample_rate = (self.transport and self.transport.sample_rate) or 44100,
        literals = self.literals,
        literal_values = build_literal_values(self.literals),
        param_bindings = self.param_bindings,
        param_meta = self.params,
        mod_slots = self.mod_slots,
        mod_routes = self.mod_routes,
        bufs_sym = bufs_sym,
        frames_sym = frames_sym,
        init_slots_sym = init_slots_sym,
        block_slots_sym = block_slots_sym,
        sample_slots_sym = sample_slots_sym,
        event_slots_sym = event_slots_sym,
        voice_slots_sym = voice_slots_sym,
    }

    ctx.mod_slot_by_index = {}
    for i = 1, #(self.mod_slots or {}) do
        local ms = self.mod_slots[i]
        ctx.mod_slot_by_index[ms.slot_index] = ms
    end

    local body_q = compile_node_job(self.node, ctx)
    local fn = terra([bufs_sym], [frames_sym], [init_slots_sym], [block_slots_sym], [sample_slots_sym], [event_slots_sym], [voice_slots_sym])
        [body_q]
    end
    return D.Kernel.Unit(fn, tuple())
end)

function D.Scheduled.NodeProgram:compile()
    return diag.wrap(nil, "scheduled.node_program.compile", "real", function()
        return compile_node_program(self)
    end, function()
        return F.kernel_unit()
    end)
end

return true
