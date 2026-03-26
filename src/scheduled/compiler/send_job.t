-- impl/scheduled/compiler/send_job.t
-- Private scheduled send-job quote compiler.

local compile_binding_value = require("src/scheduled/compiler/binding")

local function compile_with(self, ctx)
        assert(ctx and ctx.bufs_sym, "SendJob:compile requires ctx.bufs_sym")
        if not self.enabled then return quote end end

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local level_q = compile_binding_value(self.level, ctx)
        local soff = self.source_buf * BS
        local toff = self.target_buf * BS

        return quote
            var so = [int32](soff); var to = [int32](toff)
            var lv : float = [level_q]
            for i = 0, frames do
                bufs[to+i] = bufs[to+i] + bufs[so+i] * lv
            end
        end

end

return compile_with
