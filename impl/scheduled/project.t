-- impl/scheduled/project.t
-- Scheduled.Project:compile → Kernel.Project

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.project.compile", "stub")


function D.Scheduled.Project:compile(ctx)
    return diag.wrap(ctx, "scheduled.project.compile", "stub", function()
        -- Stub: produce a valid Kernel.Project with no-op everything.
        -- Real implementation:
        --   1. Allocates Kernel.Buffers (mono, stereo, event, bus, state types)
        --   2. Allocates Kernel.State (transport, control, dsp, launcher, voice, render)
        --   3. Compiles all steps/jobs into quoted code
        --   4. Assembles Kernel.API entry points from those quotes
        --
        -- For now, return the minimal valid kernel with empty structs and
        -- no-op functions.

        local stub_type = tuple()
        local noop_q = quote end

        local buffers = D.Kernel.Buffers(
            stub_type, stub_type, stub_type, stub_type, stub_type
        )
        local state = D.Kernel.State(
            stub_type, stub_type, stub_type,
            stub_type, stub_type, stub_type
        )
        local api = D.Kernel.API(
            noop_q, noop_q, noop_q,       -- init, destroy, render_block
            noop_q, noop_q, noop_q,       -- set_param, queue_launch, queue_scene
            noop_q, noop_q, noop_q,       -- stop_track, note_on, note_off
            noop_q, noop_q, noop_q,       -- poly_pressure, cc, pitch_bend
            noop_q, noop_q, noop_q,       -- timbre, get_peak, get_position
            noop_q, noop_q                -- get_param, get_mod
        )

        return D.Kernel.Project(buffers, state, api)
    end, function()
        return F.kernel_project()
    end)
end

return true
