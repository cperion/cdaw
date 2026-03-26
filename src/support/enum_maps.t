-- impl2/support/enum_maps.t
-- Editor -> Authored enum mapping helpers.
-- These map identical enum names across phases.
-- Returns a factory: call with (Editor_ns, Authored_ns) to get the mappers.

return function(E, A)
    local M = {}

    function M.quantize(eq)
        if eq == nil then return A.QNone end
        local name = eq.kind
        if name and A[name] then return A[name] end
        return A.QNone
    end

    function M.interp(ei)
        if ei == nil then return A.Linear end
        local name = ei.kind
        if name and A[name] then return A[name] end
        return A.Linear
    end

    function M.combine(ec)
        if ec == nil then return A.Replace end
        local name = ec.kind
        if name and A[name] then return A[name] end
        return A.Replace
    end

    function M.smoothing(es)
        if es == nil then return A.NoSmoothing end
        if es.kind == "Lag" then return A.Lag(es.ms) end
        return A.NoSmoothing
    end

    function M.fade_curve(fc)
        if fc == nil then return A.LinearFade end
        local name = fc.kind
        if name and A[name] then return A[name] end
        return A.LinearFade
    end

    function M.track_input(ei)
        if ei == nil then return A.NoInput end
        if ei.kind == "AudioInput" then return A.AudioInput(ei.device_id, ei.channel) end
        if ei.kind == "MIDIInput" then return A.MIDIInput(ei.device_id, ei.channel) end
        if ei.kind == "TrackInputTap" then return A.TrackInputTap(ei.track_id, ei.post_fader) end
        return A.NoInput
    end

    function M.domain(ed)
        if ed == nil then return A.AudioDomain end
        local name = ed.kind
        if name and A[name] then return A[name] end
        return A.AudioDomain
    end

    function M.port_hint(h)
        if h == nil then return A.AudioHint end
        local name = h.kind
        if name and A[name] then return A[name] end
        return A.AudioHint
    end

    function M.launch_mode(m)
        if m == nil then return A.Trigger end
        local name = m.kind
        if name and A[name] then return A[name] end
        return A.Trigger
    end

    function M.follow_kind(fk)
        if fk == nil then return A.FNone end
        local name = fk.kind
        if name and A[name] then return A[name] end
        return A.FNone
    end

    function M.slot_content(sc)
        if sc == nil then return A.EmptySlot end
        if sc.kind == "ClipSlot" then return A.ClipSlot(sc.clip_id) end
        if sc.kind == "StopSlot" then return A.StopSlot end
        return A.EmptySlot
    end

    function M.note_expr_kind(ek)
        if ek == nil then return A.NotePressureExpr end
        local name = ek.kind
        if name and A[name] then return A[name] end
        return A.NotePressureExpr
    end

    local grid_source_to_precord = {
        DevicePhase = "PCDevicePhase", GlobalPhase = "PCGlobalPhase",
        NotePitch = "PCNotePitch", NoteGate = "PCNoteGate",
        NoteVelocity = "PCNoteVelocity", NotePressure = "PCNotePressure",
        NoteTimbre = "PCNoteTimbre", NoteGain = "PCNoteGain",
        AudioIn = "PCAudioIn", AudioInL = "PCAudioInL", AudioInR = "PCAudioInR",
        PreviousNote = "PCPreviousNote",
    }

    function M.grid_source_to_precord_kind(gsk)
        if gsk == nil then return A.PCAudioIn end
        local name = grid_source_to_precord[gsk.kind]
        if name and A[name] then return A[name] end
        return A.PCAudioIn
    end

    return M
end
