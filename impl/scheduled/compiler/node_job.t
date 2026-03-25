-- impl/scheduled/compiler/node_job.t
-- Private scheduled node-job quote compiler.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_binding_value = require("impl/scheduled/compiler/binding")
local L = F.L
diag.status("scheduled.node_job.quote", "real")

local C = terralib.includec("math.h")

local NK = {
    BasicSynth=0, GainNode=5, PanNode=6, EQNode=7, CompressorNode=8,
    GateNode=9, DelayNode=10, ReverbNode=11, ChorusNode=12,
    SaturatorNode=15, SubGraph=27, SineOsc=28, SawOsc=29, SquareOsc=30,
    Wavefolder=52, Clipper=53, AddN=60, MulN=62, NegN=66, AbsN=65,
    ClampN=69, InvertN=90, AttenuateN=86,
}

local function get_param_binding(param_bindings, first_param, index)
    return param_bindings[first_param + index + 1]
end

local function build_param_value(ctx, first_param, index)
    local pb = get_param_binding(ctx.param_bindings or {}, first_param, index)
    local expr = pb and compile_binding_value(pb, ctx) or `0.0f

    local pm = ctx.param_meta and ctx.param_meta[first_param + index + 1]
    local mod_routes = ctx.mod_routes or {}
    local mod_slot_by_index = ctx.mod_slot_by_index or {}
    if not pm or (pm.modulation_count or 0) <= 0 then
        return expr
    end

    for ri = 0, pm.modulation_count - 1 do
        local mr = mod_routes[pm.first_modulation + ri + 1]
        if mr then
            local ms = mod_slot_by_index[mr.mod_slot_index]
            local out_binding = ms and ms.output_binding or nil
            if out_binding then
                local mod_q = compile_binding_value(out_binding, ctx)
                local depth_q = mr.depth and compile_binding_value(mr.depth, ctx) or `0.0f
                local route_q
                if mr.bipolar then
                    route_q = `([mod_q] * [depth_q])
                else
                    route_q = `(((( [mod_q] + 1.0f) * 0.5f)) * [depth_q])
                end
                expr = `([expr] + [route_q])
            end
        end
    end

    return expr
end

local function compile_with(self, ctx)
    return diag.wrap(ctx, "scheduled.node_job.quote", "real", function()
        assert(ctx and ctx.bufs_sym, "NodeJob:compile requires ctx.bufs_sym")
        assert(ctx and ctx.frames_sym, "NodeJob:compile requires ctx.frames_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local sample_rate = ctx.sample_rate or 44100.0

        local ioff = self.in_buf * BS
        local ooff = self.out_buf * BS
        local kc = self.kind_code

        local function P(index)
            return build_param_value(ctx, self.first_param, index)
        end

        if kc == NK.GainNode then
            local g = P(0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                var gain : float = [g]
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * gain end
            end

        elseif kc == NK.PanNode then
            local pan_q = P(0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                var pan : float = [pan_q]
                var pg : float = C.cosf(pan * [float](math.pi / 4.0))
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * pg end
            end

        elseif kc == NK.CompressorNode then
            local thr_q = P(0)
            local ratio_q = P(1)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                var thr_db : float = [thr_q]
                var ratio : float = [ratio_q]
                if ratio < 1.0f then ratio = 1.0f end
                var thr : float = C.powf(10.0f, thr_db / 20.0f)
                var inv_r : float = 1.0f / ratio
                for i = 0, frames do
                    var x = bufs[io+i]
                    var ax = x; if ax < 0.0f then ax = -ax end
                    if ax > thr then
                        var compressed = thr + (ax - thr) * inv_r
                        if x >= 0.0f then bufs[oo+i] = compressed
                        else bufs[oo+i] = -compressed end
                    else bufs[oo+i] = x end
                end
            end

        elseif kc == NK.SaturatorNode then
            local drv_q = P(0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                var drv : float = [drv_q]
                if drv < 0.1f then drv = 0.1f end
                for i = 0, frames do
                    bufs[oo+i] = C.tanhf(bufs[io+i] * drv)
                end
            end

        elseif kc == NK.EQNode then
            local gain_db_q = P(1)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                var gain_db : float = [gain_db_q]
                var glin : float = C.powf(10.0f, gain_db / 20.0f)
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * glin end
            end

        elseif kc == NK.GateNode then
            local thr_q = P(0)
            return quote
                var io = [int32](ioff); var oo = [int32](ooff)
                var thr_db : float = [thr_q]
                var thr : float = C.powf(10.0f, thr_db / 20.0f)
                for i = 0, frames do
                    var x = bufs[io+i]
                    var ax = x; if ax < 0.0f then ax = -ax end
                    if ax >= thr then bufs[oo+i] = x
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
                var a : float = [att]
                for i = 0, frames do bufs[oo+i] = bufs[io+i] * a end
            end

        elseif kc == NK.SineOsc then
            local freq_q = P(0)
            return quote
                var oo = [int32](ooff)
                var freq : float = [freq_q]
                if freq < 1.0f then freq = 1.0f end
                var pinc : float = freq * [float](2.0 * math.pi / sample_rate)
                for i = 0, frames do
                    bufs[oo+i] = C.sinf(pinc * [float](i))
                end
            end

        elseif kc == NK.SawOsc then
            local freq_q = P(0)
            return quote
                var oo = [int32](ooff)
                var freq : float = [freq_q]
                if freq < 1.0f then freq = 1.0f end
                var inc : float = freq * [float](2.0 / sample_rate)
                for i = 0, frames do
                    var ph = inc * [float](i)
                    ph = ph - 2.0f * C.floorf(ph * 0.5f)
                    bufs[oo+i] = ph - 1.0f
                end
            end

        elseif kc == NK.SquareOsc then
            local freq_q = P(0)
            return quote
                var oo = [int32](ooff)
                var freq : float = [freq_q]
                if freq < 1.0f then freq = 1.0f end
                var inc : float = freq / [float](sample_rate)
                for i = 0, frames do
                    var ph = inc * [float](i)
                    ph = ph - C.floorf(ph)
                    if ph < 0.5f then bufs[oo+i] = 1.0f
                    else bufs[oo+i] = -1.0f end
                end
            end

        else
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

return compile_with
