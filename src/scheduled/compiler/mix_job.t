-- impl/scheduled/compiler/mix_job.t
-- Private scheduled mix-job quote compiler.

local compile_binding_value = require("src/scheduled/compiler/binding")

local function compile_with(self, ctx)
        assert(ctx and ctx.bufs_sym, "MixJob:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local gain_q = compile_binding_value(self.gain, ctx)
        local soff = self.source_buf * BS
        local toff = self.target_buf * BS

        return quote
            var so = [int32](soff); var to = [int32](toff)
            var g : float = [gain_q]
            for i = 0, frames do
                bufs[to+i] = bufs[to+i] + bufs[so+i] * g
            end
        end

end

return compile_with
