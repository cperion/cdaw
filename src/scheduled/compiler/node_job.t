-- src/scheduled/compiler/node_job.t
-- Compiles a Scheduled.NodeProgram into a Terra quote.
--
-- Signature: compile(program: NodeProgram, params, state_sym) -> quote
--
--   program   — the full NodeProgram ASDL record; owns all compile-time data.
--   params    — terralib list of Terra symbols matching the leaf fn signature:
--               [1]=bufs:&float  [2]=frames:int32
--               [3]=init_slots:&float  [4]=block_slots:&float
--               [5]=sample_slots:&float  [6]=event_slots:&float
--               [7]=voice_slots:&float
--   state_sym — typed &OscState symbol for stateful nodes; nil for stateless.
--
-- Every dependency comes from `program` (owned by self) or explicit params.
-- No ctx bag. No void pointers.

local compile_binding = require("src/scheduled/compiler/binding")
local C = terralib.includec("math.h")

local NK = {
    GainNode=5, PanNode=6, EQNode=7, CompressorNode=8,
    GateNode=9, DelayNode=10, ReverbNode=11, ChorusNode=12,
    SaturatorNode=15, SubGraph=27, SineOsc=28, SawOsc=29, SquareOsc=30,
    Wavefolder=52, Clipper=53, AddN=60, MulN=62, NegN=66, AbsN=65,
    ClampN=69, InvertN=90, AttenuateN=86,
}

-- Build a helper that compiles param binding for param `index` (0-based)
-- relative to program.param_bindings and program.params.
local function make_param_compiler(program, params)
    local bufs_sym   = params[1]
    local init_sym   = params[3]
    local block_sym  = params[4]
    local sample_sym = params[5]
    local event_sym  = params[6]
    local voice_sym  = params[7]

    local literal_values = {}
    for i = 1, #program.literals do
        literal_values[i] = program.literals[i].value
    end

    local function P(index)
        local first_param = program.node.first_param
        local pb = program.param_bindings[first_param + index + 1]
        local base_expr = compile_binding(pb, literal_values,
            init_sym, block_sym, sample_sym, event_sym, voice_sym)

        -- Apply modulation routes targeting this param.
        local pm = program.params and program.params[first_param + index + 1]
        if not pm or (pm.modulation_count or 0) <= 0 then
            return base_expr
        end

        -- Build a slot_index -> mod_slot lookup for O(1) access.
        local mod_slot_by_index = {}
        for i = 1, #(program.mod_slots or {}) do
            local ms = program.mod_slots[i]
            mod_slot_by_index[ms.slot_index] = ms
        end

        local expr = base_expr
        for ri = 0, pm.modulation_count - 1 do
            local mr = program.mod_routes[pm.first_modulation + ri + 1]
            if mr then
                local ms = mod_slot_by_index[mr.mod_slot_index]
                local out_binding = ms and ms.output_binding or nil
                if out_binding then
                    local mod_q   = compile_binding(out_binding, literal_values,
                                        init_sym, block_sym, sample_sym, event_sym, voice_sym)
                    local depth_q = compile_binding(mr.depth, literal_values,
                                        init_sym, block_sym, sample_sym, event_sym, voice_sym)
                    local route_q
                    if mr.bipolar then
                        route_q = `([mod_q] * [depth_q])
                    else
                        route_q = `((([mod_q] + 1.0f) * 0.5f) * [depth_q])
                    end
                    expr = `([expr] + [route_q])
                end
            end
        end
        return expr
    end

    return P
end

local function compile(program, params, state_sym)
    local job    = program.node
    local BS     = program.transport.buffer_size
    local sr     = program.transport.sample_rate or 44100.0
    local kc     = job.kind_code
    local ioff   = job.in_buf  * BS
    local ooff   = job.out_buf * BS

    local bufs_sym   = params[1]
    local frames_sym = params[2]
    local P          = make_param_compiler(program, params)

    if kc == NK.GainNode then
        local g = P(0)
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            var gain : float = [g]
            for i = 0, frames_sym do [bufs_sym][oo+i] = [bufs_sym][io+i] * gain end
        end

    elseif kc == NK.PanNode then
        local pan_q = P(0)
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            var pan : float = [pan_q]
            var pg  : float = C.cosf(pan * [float](math.pi / 4.0))
            for i = 0, frames_sym do [bufs_sym][oo+i] = [bufs_sym][io+i] * pg end
        end

    elseif kc == NK.CompressorNode then
        local thr_q = P(0); local ratio_q = P(1)
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            var thr_db : float = [thr_q]; var ratio : float = [ratio_q]
            if ratio < 1.0f then ratio = 1.0f end
            var thr : float = C.powf(10.0f, thr_db / 20.0f)
            var inv_r : float = 1.0f / ratio
            for i = 0, frames_sym do
                var x = [bufs_sym][io+i]; var ax = x
                if ax < 0.0f then ax = -ax end
                if ax > thr then
                    var c = thr + (ax - thr) * inv_r
                    if x >= 0.0f then [bufs_sym][oo+i] = c
                    else              [bufs_sym][oo+i] = -c end
                else [bufs_sym][oo+i] = x end
            end
        end

    elseif kc == NK.SaturatorNode then
        local drv_q = P(0)
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            var drv : float = [drv_q]
            if drv < 0.1f then drv = 0.1f end
            for i = 0, frames_sym do
                [bufs_sym][oo+i] = C.tanhf([bufs_sym][io+i] * drv)
            end
        end

    elseif kc == NK.EQNode then
        local gdb_q = P(1)
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            var glin : float = C.powf(10.0f, [gdb_q] / 20.0f)
            for i = 0, frames_sym do [bufs_sym][oo+i] = [bufs_sym][io+i] * glin end
        end

    elseif kc == NK.GateNode then
        local thr_q = P(0)
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            var thr : float = C.powf(10.0f, [thr_q] / 20.0f)
            for i = 0, frames_sym do
                var x = [bufs_sym][io+i]; var ax = x
                if ax < 0.0f then ax = -ax end
                if ax >= thr then [bufs_sym][oo+i] = x
                else              [bufs_sym][oo+i] = 0.0f end
            end
        end

    elseif kc == NK.Clipper then
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            for i = 0, frames_sym do
                var x = [bufs_sym][io+i]
                if x >  1.0f then x =  1.0f end
                if x < -1.0f then x = -1.0f end
                [bufs_sym][oo+i] = x
            end
        end

    elseif kc == NK.Wavefolder then
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            for i = 0, frames_sym do
                var x = [bufs_sym][io+i] * 2.0f
                x = x - 4.0f * C.floorf((x + 1.0f) * 0.25f)
                if x >  1.0f then x =  2.0f - x end
                if x < -1.0f then x = -2.0f - x end
                [bufs_sym][oo+i] = x
            end
        end

    elseif kc == NK.NegN then
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            for i = 0, frames_sym do [bufs_sym][oo+i] = -[bufs_sym][io+i] end
        end

    elseif kc == NK.AbsN then
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            for i = 0, frames_sym do
                var x = [bufs_sym][io+i]
                if x < 0.0f then x = -x end
                [bufs_sym][oo+i] = x
            end
        end

    elseif kc == NK.ClampN then
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            for i = 0, frames_sym do
                var x = [bufs_sym][io+i]
                if x < -1.0f then x = -1.0f end
                if x >  1.0f then x =  1.0f end
                [bufs_sym][oo+i] = x
            end
        end

    elseif kc == NK.InvertN then
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            for i = 0, frames_sym do [bufs_sym][oo+i] = 1.0f - [bufs_sym][io+i] end
        end

    elseif kc == NK.AttenuateN then
        local att = P(0)
        return quote
            var io = [int32](ioff); var oo = [int32](ooff)
            var a : float = [att]
            for i = 0, frames_sym do [bufs_sym][oo+i] = [bufs_sym][io+i] * a end
        end

    elseif kc == NK.SineOsc then
        -- state_sym: &OscState — typed, from Unit.leaf. phase in [0,1).
        return quote
            var oo    = [int32](ooff)
            var freq  : float = [P(0)]
            if freq < 1.0f then freq = 1.0f end
            var inc   : float = freq / [float](sr)
            var phase : float = [state_sym].phase
            for i = 0, frames_sym do
                [bufs_sym][oo+i] = C.sinf(phase * [float](2.0 * math.pi))
                phase = phase + inc
                if phase >= 1.0f then phase = phase - 1.0f end
            end
            [state_sym].phase = phase
        end

    elseif kc == NK.SawOsc then
        return quote
            var oo    = [int32](ooff)
            var freq  : float = [P(0)]
            if freq < 1.0f then freq = 1.0f end
            var inc   : float = freq / [float](sr)
            var phase : float = [state_sym].phase
            for i = 0, frames_sym do
                [bufs_sym][oo+i] = phase * 2.0f - 1.0f
                phase = phase + inc
                if phase >= 1.0f then phase = phase - 1.0f end
            end
            [state_sym].phase = phase
        end

    elseif kc == NK.SquareOsc then
        return quote
            var oo    = [int32](ooff)
            var freq  : float = [P(0)]
            if freq < 1.0f then freq = 1.0f end
            var inc   : float = freq / [float](sr)
            var phase : float = [state_sym].phase
            for i = 0, frames_sym do
                if phase < 0.5f then [bufs_sym][oo+i] =  1.0f
                else                 [bufs_sym][oo+i] = -1.0f end
                phase = phase + inc
                if phase >= 1.0f then phase = phase - 1.0f end
            end
            [state_sym].phase = phase
        end

    else
        -- Unknown / passthrough: copy in → out if different buffers.
        if ioff ~= ooff then
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames_sym do [bufs_sym][oo+i] = [bufs_sym][io+i] end
            end
        else
            return quote end
        end
    end
end

return compile
