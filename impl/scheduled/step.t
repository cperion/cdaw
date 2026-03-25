-- impl/scheduled/step.t
-- Scheduled.Step:compile → TerraQuote
--
-- Orchestrates a single step: clear buffer, then run clip/node/mod/send/mix/output
-- jobs in order. Each sub-job index of -1 means "no job" (skip).
-- ctx must provide: bufs_sym, frames_sym, BS, and the job lists.

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local L = F.L
diag.status("scheduled.step.compile", "real")


function D.Scheduled.Step:compile(ctx)
    return diag.wrap(ctx, "scheduled.step.compile", "real", function()
        assert(ctx and ctx.bufs_sym, "Step:compile requires ctx.bufs_sym")

        local bufs = ctx.bufs_sym
        local frames = ctx.frames_sym
        local BS = ctx.BS
        local quotes = terralib.newlist()

        -- 1. Clear the work buffer
        if self.clear_buf >= 0 then
            local coff = self.clear_buf * BS
            quotes:insert(quote
                var co = [int32](coff)
                for i = 0, frames do bufs[co+i] = 0.0f end
            end)
        end

        -- 2. Clip job (write source material into buffer)
        if self.clip_job >= 0 and ctx.clip_jobs and ctx.clip_jobs[self.clip_job + 1] then
            quotes:insert(ctx.clip_jobs[self.clip_job + 1]:compile(ctx))
        end

        -- 3. Node job(s) — run the graph's node chain
        if self.node_job >= 0 and ctx.node_jobs then
            -- node_job points to the first node job for this step's graph.
            -- Find the graph plan that starts at this node job.
            local found = false
            if ctx.graph_plans then
                for _, gp in ipairs(ctx.graph_plans) do
                    if gp.first_node_job == self.node_job then
                        for j = 0, gp.node_job_count - 1 do
                            local nj = ctx.node_jobs[self.node_job + j + 1]
                            if nj then quotes:insert(nj:compile(ctx)) end
                        end
                        found = true
                        break
                    end
                end
            end
            if not found then
                -- Fallback: just compile the single node job
                local nj = ctx.node_jobs[self.node_job + 1]
                if nj then quotes:insert(nj:compile(ctx)) end
            end
        end

        -- 4. Mod job
        if self.mod_job >= 0 and ctx.mod_jobs and ctx.mod_jobs[self.mod_job + 1] then
            quotes:insert(ctx.mod_jobs[self.mod_job + 1]:compile(ctx))
        end

        -- 5. Send job
        if self.send_job >= 0 and ctx.send_jobs and ctx.send_jobs[self.send_job + 1] then
            quotes:insert(ctx.send_jobs[self.send_job + 1]:compile(ctx))
        end

        -- 6. Mix job
        if self.mix_job >= 0 and ctx.mix_jobs and ctx.mix_jobs[self.mix_job + 1] then
            quotes:insert(ctx.mix_jobs[self.mix_job + 1]:compile(ctx))
        end

        -- 7. Output job
        if self.output_job >= 0 and ctx.output_jobs and ctx.output_jobs[self.output_job + 1] then
            quotes:insert(ctx.output_jobs[self.output_job + 1]:compile(ctx))
        end

        -- Splice all quotes
        return quote [quotes] end
    end, function()
        return F.noop_quote()
    end)
end

return true
