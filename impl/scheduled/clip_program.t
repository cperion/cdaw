-- impl/scheduled/clip_program.t
-- Scheduled.ClipProgram:compile -> Kernel.Unit

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_clip_job = require("impl/scheduled/compiler/clip_job")

diag.status("scheduled.clip_program.compile", "real")
diag.variant_family("scheduled.clip_program.compile", "Authored", "ClipContent")
diag.variant_status("scheduled.clip_program.compile", "AudioContent", "partial")
diag.variant_status("scheduled.clip_program.compile", "NoteContent", "stub")

local function build_literal_values(literals)
    local values = {}
    for i = 1, #(literals or {}) do values[i] = literals[i].value end
    return values
end

local compile_clip_program = terralib.memoize(function(self)
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
        bufs_sym = bufs_sym,
        frames_sym = frames_sym,
        init_slots_sym = init_slots_sym,
        block_slots_sym = block_slots_sym,
        sample_slots_sym = sample_slots_sym,
        event_slots_sym = event_slots_sym,
        voice_slots_sym = voice_slots_sym,
    }

    local body_q = compile_clip_job(self.clip, ctx)
    local fn = terra([bufs_sym], [frames_sym], [init_slots_sym], [block_slots_sym], [sample_slots_sym], [event_slots_sym], [voice_slots_sym])
        [body_q]
    end
    return D.Kernel.Unit(fn, tuple())
end)

function D.Scheduled.ClipProgram:compile()
    return diag.wrap(nil, "scheduled.clip_program.compile", "real", function()
        return compile_clip_program(self)
    end, function()
        return F.kernel_unit()
    end)
end

return true
