-- impl/scheduled/compiler/output_job.t
-- Private scheduled output-job quote compiler.

local compile_binding_value = require("src/scheduled/compiler/binding")

local C = terralib.includec("math.h")

local function compile_with(self, ctx)
        assert(ctx and ctx.bufs_sym, "OutputJob:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local gain_q = compile_binding_value(self.gain, ctx)
        local pan_q = compile_binding_value(self.pan, ctx)
        local soff = self.source_buf * BS
        local loff = self.out_left * BS
        local roff = self.out_right * BS

        return quote
            var so = [int32](soff)
            var lo = [int32](loff); var ro = [int32](roff)
            var gain : float = [gain_q]
            var pan : float = [pan_q]
            var angle : float = (pan + 1.0f) * [float](math.pi / 4.0)
            var lg : float = gain * C.cosf(angle)
            var rg : float = gain * C.sinf(angle)
            for i = 0, frames do
                var s = bufs[so+i]
                bufs[lo+i] = bufs[lo+i] + s * lg
                bufs[ro+i] = bufs[ro+i] + s * rg
            end
        end

end

return compile_with
