-- impl/scheduled/node_job.t
-- Scheduled.NodeJob:compile → TerraQuote
--
-- Emits DSP code for a single node job. The ctx must provide:
--   ctx.bufs_sym       — Terra symbol for the buffer array
--   ctx.frames_sym     — Terra symbol for frame count
--   ctx.BS             — buffer size (Lua number, for offset calc)
--   ctx.literal_values — Lua table of literal float values
--   ctx.param_bindings — Lua table of Scheduled.Binding
--
-- Fallback: silence for generators, passthrough for effects.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.node_job.compile", "real")

local C = terralib.includec("math.h")

-- Kind codes
local NK = {
    BasicSynth=0, GainNode=5, PanNode=6, EQNode=7, CompressorNode=8,
    GateNode=9, DelayNode=10, ReverbNode=11, ChorusNode=12,
    SaturatorNode=15, SubGraph=27, SineOsc=28, SawOsc=29, SquareOsc=30,
    Wavefolder=52, Clipper=53, AddN=60, MulN=62, NegN=66, AbsN=65,
    ClampN=69, InvertN=90, AttenuateN=86,
}

local function resolve_binding_value(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end

local function get_param(param_bindings, literal_values, first_param, index)
    local pb = param_bindings[first_param + index + 1]
    if pb then return resolve_binding_value(pb, literal_values) end
    return 0.0
end


function D.Scheduled.NodeJob:compile(ctx)
    return diag.wrap(ctx, "scheduled.node_job.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "NodeJob:compile requires ctx.bufs_sym")
        assert(ctx and ctx.frames_sym, "NodeJob:compile requires ctx.frames_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local literal_values = ctx.literal_values or {}
        local param_bindings = ctx.param_bindings or {}

        local ioff = self.in_buf * BS
        local ooff = self.out_buf * BS
        local kc = self.kind_code

        local function P(index)
            return get_param(param_bindings, literal_values, self.first_param, index)
        end

        if kc == NK.GainNode then
            local g = P(0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * [float](g) end
            end

        elseif kc == NK.PanNode then
            local pg = math.cos(P(0) * math.pi / 4.0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * [float](pg) end
            end

        elseif kc == NK.CompressorNode then
            local thr = math.pow(10.0, P(0) / 20.0)
            local ratio = math.max(P(1), 1.0)
            local inv_r = 1.0 / ratio
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do
                    var x = bufs[io+i]
                    var ax = x; if ax < 0.0f then ax = -ax end
                    if ax > [float](thr) then
                        var compressed = [float](thr) + (ax - [float](thr)) * [float](inv_r)
                        if x >= 0.0f then bufs[oo+i] = compressed
                        else bufs[oo+i] = -compressed end
                    else bufs[oo+i] = x end
                end
            end

        elseif kc == NK.SaturatorNode then
            local drv = math.max(P(0), 0.1)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do
                    bufs[oo+i] = C.tanhf(bufs[io+i] * [float](drv))
                end
            end

        elseif kc == NK.EQNode then
            local glin = math.pow(10.0, P(1) / 20.0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * [float](glin) end
            end

        elseif kc == NK.GateNode then
            local thr = math.pow(10.0, P(0) / 20.0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do
                    var x = bufs[io+i]
                    var ax = x; if ax < 0.0f then ax = -ax end
                    if ax >= [float](thr) then bufs[oo+i] = x
                    else bufs[oo+i] = 0.0f end
                end
            end

        elseif kc == NK.Clipper then
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do
                    var x = bufs[io+i]
                    if x > 1.0f then x = 1.0f end
                    if x < -1.0f then x = -1.0f end
                    bufs[oo+i] = x
                end
            end

        elseif kc == NK.Wavefolder then
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do
                    var x = bufs[io+i] * 2.0f
                    x = x - 4.0f * C.floorf((x + 1.0f) * 0.25f)
                    if x > 1.0f then x = 2.0f - x end
                    if x < -1.0f then x = -2.0f - x end
                    bufs[oo+i] = x
                end
            end

        elseif kc == NK.NegN then
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do bufs[oo+i] = -bufs[io+i] end
            end

        elseif kc == NK.AbsN then
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do
                    var x = bufs[io+i]; if x < 0.0f then x = -x end; bufs[oo+i] = x
                end
            end

        elseif kc == NK.ClampN then
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do
                    var x = bufs[io+i]
                    if x < -1.0f then x = -1.0f end
                    if x > 1.0f then x = 1.0f end
                    bufs[oo+i] = x
                end
            end

        elseif kc == NK.InvertN then
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do bufs[oo+i] = 1.0f - bufs[io+i] end
            end

        elseif kc == NK.AttenuateN then
            local att = P(0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * [float](att) end
            end

        elseif kc == NK.SineOsc then
            local freq = math.max(P(0), 1.0)
            local pinc = freq * 2.0 * math.pi / 44100.0
            return quote
                var oo = [int32](ooff)
                for i = 0, frames do
                    bufs[oo+i] = C.sinf([float](pinc) * [float](i))
                end
            end

        elseif kc == NK.SawOsc then
            local freq = math.max(P(0), 1.0)
            local inc = freq * 2.0 / 44100.0
            return quote
                var oo = [int32](ooff)
                for i = 0, frames do
                    var ph = [float](inc) * [float](i)
                    ph = ph - 2.0f * C.floorf(ph * 0.5f)
                    bufs[oo+i] = ph - 1.0f
                end
            end

        elseif kc == NK.SquareOsc then
            local freq = math.max(P(0), 1.0)
            local inc = freq / 44100.0
            return quote
                var oo = [int32](ooff)
                for i = 0, frames do
                    var ph = [float](inc) * [float](i)
                    ph = ph - C.floorf(ph)
                    if ph < 0.5f then bufs[oo+i] = 1.0f
                    else bufs[oo+i] = -1.0f end
                end
            end

        else
            -- Default: passthrough (copy input to output if different buffers)
            if ioff ~= ooff then
                return quote
                    var io = [int32](ioff); var oo = [int32](ooff)
                    for i = 0, frames do bufs[oo+i] = bufs[io+i] end
                end
            else
                return quote end
            end
        end
    end, function()
        return F.noop_quote()
    end)
end

return true
