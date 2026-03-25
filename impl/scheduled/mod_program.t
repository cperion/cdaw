-- impl/scheduled/mod_program.t
-- Scheduled.ModProgram:compile -> Kernel.Unit

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_mod_job = require("impl/scheduled/compiler/mod_job")

diag.status("scheduled.mod_program.compile", "real")
diag.variant_family("scheduled.mod_program.compile", "Authored", "NodeKind")
for member in pairs(D.Authored.NodeKind.members) do
    if type(member) == "table" and member ~= D.Authored.NodeKind then
        local name = rawget(member, "kind")
        if type(name) == "string" then
            diag.variant_status("scheduled.mod_program.compile", name, "stub")
        end
    end
end
diag.variant_status("scheduled.mod_program.compile", "LFOMod", "real")

local function build_literal_values(literals)
    local values = {}
    for i = 1, #(literals or {}) do values[i] = literals[i].value end
    return values
end

local compile_mod_program = terralib.memoize(function(self)
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
        block_sample = 0,
        param_bindings = self.param_bindings,
        bufs_sym = bufs_sym,
        frames_sym = frames_sym,
        init_slots_sym = init_slots_sym,
        block_slots_sym = block_slots_sym,
        sample_slots_sym = sample_slots_sym,
        event_slots_sym = event_slots_sym,
        voice_slots_sym = voice_slots_sym,
    }

    local body_q = compile_mod_job(self.mod, ctx)
    local fn = terra([bufs_sym], [frames_sym], [init_slots_sym], [block_slots_sym], [sample_slots_sym], [event_slots_sym], [voice_slots_sym])
        [body_q]
    end
    return D.Kernel.Unit(fn, tuple())
end)

function D.Scheduled.ModProgram:compile()
    return diag.wrap(nil, "scheduled.mod_program.compile", "real", function()
        return compile_mod_program(self)
    end, function()
        return F.kernel_unit()
    end)
end

return true
