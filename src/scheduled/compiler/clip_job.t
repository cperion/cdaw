-- impl/scheduled/compiler/clip_job.t
-- Private scheduled clip-job quote compiler.

local compile_binding_value = require("src/scheduled/compiler/binding")

local C = terralib.includec("math.h")

local function compile_with(self, ctx)
        assert(ctx and ctx.bufs_sym, "ClipJob:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local gain_q = compile_binding_value(self.gain, ctx)
        local content_kind = self.content_kind
        local ooff = self.out_buf * BS
        local fade_in_samples = self.fade_in_tick
        local fade_out_samples = self.fade_out_tick

        if content_kind ~= 0 then
            return quote end
        end

        return quote
            var oo = [int32](ooff)
            var g : float = [gain_q]
            if g ~= 0.0f then
                for i = 0, frames do
                    var fade : float = 1.0f
                    escape
                        if fade_in_samples > 0 then
                            emit quote
                                if i < [int32](fade_in_samples) then
                                    fade = [float](i) / [float](fade_in_samples)
                                end
                            end
                        end
                    end
                    escape
                        if fade_out_samples > 0 then
                            emit quote
                                var from_end = frames - 1 - i
                                if from_end < [int32](fade_out_samples) then
                                    fade = fade * ([float](from_end) / [float](fade_out_samples))
                                end
                            end
                        end
                    end
                    bufs[oo+i] = bufs[oo+i] + g * fade
                end
            end
        end

end

return compile_with
