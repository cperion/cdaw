-- impl/scheduled/project.t
-- Scheduled.GraphProgram:compile -> Kernel.Unit
-- Scheduled.TrackProgram:compile -> Kernel.Unit
-- Scheduled.Project:compile -> Kernel.Project

local D = require("daw-unified")
local diag = require("impl/_support/diagnostics")
local F = require("impl/_support/fallbacks")
local compile_binding_value = require("impl/scheduled/compiler/binding")
local L = F.L

diag.status("scheduled.graph_program.compile", "real")
diag.status("scheduled.track_program.compile", "real")
diag.status("scheduled.project.compile", "real")

local function scan_binding(binding, counts)
    if not binding then return end
    local rc = binding.rate_class
    if rc >= 1 and rc <= 5 then
        local need = binding.slot + 1
        if need > counts[rc] then counts[rc] = need end
    end
end

local function eval_tick_to_sample(tempo_map, tick)
    local segs = tempo_map and tempo_map.segs or nil
    if not segs or #segs == 0 then return tick end
    local prev = segs[1]
    for i = 1, #segs do
        local seg = segs[i]
        if tick < seg.end_tick then
            return seg.base_sample + (tick - seg.start_tick) * seg.samples_per_tick
        end
        prev = seg
    end
    return prev.base_sample + (tick - prev.start_tick) * prev.samples_per_tick
end

local function resolve_literal_binding(binding, literal_values)
    if binding and binding.rate_class == 0 then
        return literal_values[binding.slot + 1] or 0.0
    end
    return 0.0
end

local function eval_block_curve(op, block_pts, literal_values, block_tick)
    local pt_count = op.pt_count or 0
    local base = resolve_literal_binding(op.i0, literal_values)
    if pt_count <= 0 then return base end

    local first = block_pts[op.first_pt + 1]
    if not first then return base end
    if block_tick <= first.tick then return first.value end

    local prev = first
    for i = 2, pt_count do
        local cur = block_pts[op.first_pt + i]
        if not cur then break end
        if block_tick <= cur.tick then
            if op.interp == 2 or cur.tick == prev.tick then
                return prev.value
            end
            local t = (block_tick - prev.tick) / (cur.tick - prev.tick)
            if op.interp == 1 then
                t = t * t * (3.0 - 2.0 * t)
            end
            return prev.value + (cur.value - prev.value) * t
        end
        prev = cur
    end
    return prev.value
end

local function emit_runtime_ops(ops_owner, ctx)
    local quotes = terralib.newlist()

    for i = 1, #(ops_owner.init_ops or L()) do
        local op = ops_owner.init_ops[i]
        if op.kind == 0 and ctx.init_slots_sym then
            local slot = op.state_slot
            local v0 = compile_binding_value(op.i0, ctx)
            quotes:insert(quote [ctx.init_slots_sym][slot] = [v0] end)
        end
    end

    for i = 1, #(ops_owner.block_ops or L()) do
        local op = ops_owner.block_ops[i]
        if op.kind == 0 and ctx.block_slots_sym then
            local slot = op.arg0
            local v0 = compile_binding_value(op.i0, ctx)
            quotes:insert(quote [ctx.block_slots_sym][slot] = [v0] end)
        elseif op.kind == 1 and ctx.block_slots_sym then
            local slot = op.arg0
            local v = eval_block_curve(op, ops_owner.block_pts or L(), ctx.literal_values or {}, ctx.block_tick or 0)
            quotes:insert(quote [ctx.block_slots_sym][slot] = [float](v) end)
        end
    end

    for i = 1, #(ops_owner.sample_ops or L()) do
        local op = ops_owner.sample_ops[i]
        if op.kind == 0 and ctx.sample_slots_sym then
            local slot = op.state_slot
            local v0 = compile_binding_value(op.i0, ctx)
            quotes:insert(quote [ctx.sample_slots_sym][slot] = [v0] end)
        end
    end

    for i = 1, #(ops_owner.event_ops or L()) do
        local op = ops_owner.event_ops[i]
        if op.kind == 0 and ctx.event_slots_sym then
            local slot = op.state_slot
            local v = op.min_v
            quotes:insert(quote [ctx.event_slots_sym][slot] = [float](v) end)
        end
    end

    for i = 1, #(ops_owner.voice_ops or L()) do
        local op = ops_owner.voice_ops[i]
        if op.kind == 0 and ctx.voice_slots_sym then
            local slot = op.state_slot
            local v0 = compile_binding_value(op.i0, ctx)
            quotes:insert(quote [ctx.voice_slots_sym][slot] = [v0] end)
        end
    end

    return quotes
end

local function make_state_type(total_state_slots)
    local n = total_state_slots or 0
    if n <= 0 then return tuple() end
    return float[n]
end

local function graph_runtime_slot_counts(self)
    local counts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0 }

    for i = 1, #self.mod_programs do
        local mp = self.mod_programs[i]
        for j = 1, #(mp.param_bindings or L()) do scan_binding(mp.param_bindings[j], counts) end
        scan_binding(mp.mod.output, counts)
    end
    for i = 1, #self.node_programs do
        local np = self.node_programs[i]
        for j = 1, #(np.param_bindings or L()) do scan_binding(np.param_bindings[j], counts) end
        for j = 1, #(np.mod_slots or L()) do scan_binding(np.mod_slots[j].output_binding, counts) end
        for j = 1, #(np.mod_routes or L()) do scan_binding(np.mod_routes[j].depth, counts) end
    end

    for i = 1, #self.init_ops do
        scan_binding(self.init_ops[i].i0, counts)
        scan_binding(self.init_ops[i].i1, counts)
        local need = self.init_ops[i].state_slot + 1
        if need > counts[1] then counts[1] = need end
    end
    for i = 1, #self.block_ops do
        scan_binding(self.block_ops[i].i0, counts)
        scan_binding(self.block_ops[i].i1, counts)
        local need = self.block_ops[i].arg0 + 1
        if need > counts[2] then counts[2] = need end
    end
    for i = 1, #self.sample_ops do
        scan_binding(self.sample_ops[i].i0, counts)
        scan_binding(self.sample_ops[i].i1, counts)
        local need = self.sample_ops[i].state_slot + 1
        if need > counts[3] then counts[3] = need end
    end
    for i = 1, #self.event_ops do
        local need = self.event_ops[i].state_slot + 1
        if need > counts[4] then counts[4] = need end
    end
    for i = 1, #self.voice_ops do
        scan_binding(self.voice_ops[i].i0, counts)
        scan_binding(self.voice_ops[i].i1, counts)
        local need = self.voice_ops[i].state_slot + 1
        if need > counts[5] then counts[5] = need end
    end

    return counts
end

local function track_runtime_slot_counts(self)
    local counts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0 }

    for i = 1, #self.mixer_param_bindings do scan_binding(self.mixer_param_bindings[i], counts) end
    scan_binding(self.track.volume, counts)
    scan_binding(self.track.pan, counts)
    for i = 1, #self.send_programs do scan_binding(self.send_programs[i].send.level, counts) end
    for i = 1, #self.mix_programs do scan_binding(self.mix_programs[i].mix.gain, counts) end
    for i = 1, #self.output_programs do
        scan_binding(self.output_programs[i].output.gain, counts)
        scan_binding(self.output_programs[i].output.pan, counts)
    end
    for i = 1, #self.clip_programs do scan_binding(self.clip_programs[i].clip.gain, counts) end

    for i = 1, #self.mixer_init_ops do
        scan_binding(self.mixer_init_ops[i].i0, counts)
        scan_binding(self.mixer_init_ops[i].i1, counts)
        local need = self.mixer_init_ops[i].state_slot + 1
        if need > counts[1] then counts[1] = need end
    end
    for i = 1, #self.mixer_block_ops do
        scan_binding(self.mixer_block_ops[i].i0, counts)
        scan_binding(self.mixer_block_ops[i].i1, counts)
        local need = self.mixer_block_ops[i].arg0 + 1
        if need > counts[2] then counts[2] = need end
    end
    for i = 1, #self.mixer_sample_ops do
        scan_binding(self.mixer_sample_ops[i].i0, counts)
        scan_binding(self.mixer_sample_ops[i].i1, counts)
        local need = self.mixer_sample_ops[i].state_slot + 1
        if need > counts[3] then counts[3] = need end
    end
    for i = 1, #self.mixer_event_ops do
        local need = self.mixer_event_ops[i].state_slot + 1
        if need > counts[4] then counts[4] = need end
    end
    for i = 1, #self.mixer_voice_ops do
        scan_binding(self.mixer_voice_ops[i].i0, counts)
        scan_binding(self.mixer_voice_ops[i].i1, counts)
        local need = self.mixer_voice_ops[i].state_slot + 1
        if need > counts[5] then counts[5] = need end
    end

    return counts
end

local compile_graph_program = terralib.memoize(function(self)
    local buffer_size = self.transport.buffer_size
    local n_bufs = math.max(self.total_buffers, 1)
    local total_floats = math.max(n_bufs * buffer_size, 1)
    local literal_values = {}
    for i = 1, #self.literals do literal_values[i] = self.literals[i].value end

    local rate_counts = graph_runtime_slot_counts(self)
    local init_count = math.max(rate_counts[1], 1)
    local block_count = math.max(rate_counts[2], 1)
    local sample_count = math.max(rate_counts[3], 1)
    local event_count = math.max(rate_counts[4], 1)
    local voice_count = math.max(rate_counts[5], 1)
    local state_count = math.max(self.total_state_slots, 1)

    local InitArray = float[init_count]
    local BlockArray = float[block_count]
    local SampleArray = float[sample_count]
    local EventArray = float[event_count]
    local VoiceArray = float[voice_count]
    local StateArray = float[state_count]

    local graph_fn
    if #self.node_programs > 0 or #self.mod_programs > 0 then
        local bufs_sym = symbol(&float, "bufs")
        local frames_sym = symbol(int32, "frames")
        local init_slots_sym = symbol(InitArray, "init_slots")
        local block_slots_sym = symbol(BlockArray, "block_slots")
        local sample_slots_sym = symbol(SampleArray, "sample_slots")
        local event_slots_sym = symbol(EventArray, "event_slots")
        local voice_slots_sym = symbol(VoiceArray, "voice_slots")
        local state_sym = symbol(StateArray, "state")

        local ctx = {
            diagnostics = {},
            BS = buffer_size,
            sample_rate = self.transport.sample_rate,
            literals = self.literals,
            literal_values = literal_values,
            block_tick = 0,
            block_sample = eval_tick_to_sample(self.tempo_map, 0),
            bufs_sym = bufs_sym,
            frames_sym = frames_sym,
            init_slots_sym = init_slots_sym,
            block_slots_sym = block_slots_sym,
            sample_slots_sym = sample_slots_sym,
            event_slots_sym = event_slots_sym,
            voice_slots_sym = voice_slots_sym,
            state_sym = state_sym,
        }

        local mod_units = {}
        for i = 1, #self.mod_programs do mod_units[i] = self.mod_programs[i]:compile() end
        local node_units = {}
        for i = 1, #self.node_programs do node_units[i] = self.node_programs[i]:compile() end

        local body_quotes = terralib.newlist()
        body_quotes:insert(quote
            for i = 0, [int32](total_floats - 1) do [bufs_sym][i] = 0.0f end
            for i = 0, [int32](init_count - 1) do [init_slots_sym][i] = 0.0f end
            for i = 0, [int32](block_count - 1) do [block_slots_sym][i] = 0.0f end
            for i = 0, [int32](sample_count - 1) do [sample_slots_sym][i] = 0.0f end
            for i = 0, [int32](event_count - 1) do [event_slots_sym][i] = 0.0f end
            for i = 0, [int32](voice_count - 1) do [voice_slots_sym][i] = 0.0f end
            for i = 0, [int32](state_count - 1) do [state_sym][i] = 0.0f end
        end)
        body_quotes:insert(quote [emit_runtime_ops(self, ctx)] end)
        for i = 1, #mod_units do
            local fn = mod_units[i].fn
            body_quotes:insert(quote [fn]([bufs_sym], [frames_sym], &[init_slots_sym][0], &[block_slots_sym][0], &[sample_slots_sym][0], &[event_slots_sym][0], &[voice_slots_sym][0]) end)
        end
        for i = 1, #node_units do
            local fn = node_units[i].fn
            body_quotes:insert(quote [fn]([bufs_sym], [frames_sym], &[init_slots_sym][0], &[block_slots_sym][0], &[sample_slots_sym][0], &[event_slots_sym][0], &[voice_slots_sym][0]) end)
        end

        graph_fn = terra([bufs_sym], [frames_sym])
            var [init_slots_sym]
            var [block_slots_sym]
            var [sample_slots_sym]
            var [event_slots_sym]
            var [voice_slots_sym]
            var [state_sym]
            [body_quotes]
        end
    else
        graph_fn = terra(bufs : &float, frames : int32) end
    end

    return D.Kernel.Unit(graph_fn, make_state_type(self.total_state_slots))
end)

local compile_track_program = terralib.memoize(function(self)
    local buffer_size = self.transport.buffer_size
    local n_bufs = math.max(self.total_buffers, 1)
    local total_floats = math.max(n_bufs * buffer_size, 1)
    local literal_values = {}
    for i = 1, #self.mixer_literals do literal_values[i] = self.mixer_literals[i].value end

    local rate_counts = track_runtime_slot_counts(self)
    local init_count = math.max(rate_counts[1], 1)
    local block_count = math.max(rate_counts[2], 1)
    local sample_count = math.max(rate_counts[3], 1)
    local event_count = math.max(rate_counts[4], 1)
    local voice_count = math.max(rate_counts[5], 1)
    local state_count = math.max(self.total_state_slots, 1)

    local TrackBufArray = float[total_floats]
    local InitArray = float[init_count]
    local BlockArray = float[block_count]
    local SampleArray = float[sample_count]
    local EventArray = float[event_count]
    local VoiceArray = float[voice_count]
    local StateArray = float[state_count]

    local graph_unit = self.device_graph:compile()
    local graph_fn = graph_unit.fn
    local graph_buf_count = math.max(self.device_graph.total_buffers * buffer_size, 1)
    local GraphBufArray = float[graph_buf_count]
    local graph_out_offset = (self.device_graph.graph.out_buf or 0) * buffer_size
    local work_offset = self.track.work_buf * buffer_size
    local master_left_offset = self.master_left * buffer_size
    local master_right_offset = self.master_right * buffer_size

    local track_fn
    if #self.clip_programs > 0 or #self.send_programs > 0 or #self.mix_programs > 0 or #self.output_programs > 0 or graph_fn ~= nil then
        local bufs_sym = symbol(TrackBufArray, "bufs")
        local graph_bufs_sym = symbol(GraphBufArray, "graph_bufs")
        local init_slots_sym = symbol(InitArray, "init_slots")
        local block_slots_sym = symbol(BlockArray, "block_slots")
        local sample_slots_sym = symbol(SampleArray, "sample_slots")
        local event_slots_sym = symbol(EventArray, "event_slots")
        local voice_slots_sym = symbol(VoiceArray, "voice_slots")
        local state_sym = symbol(StateArray, "state")
        local frames_sym = symbol(int32, "frames")
        local ol_sym = symbol(&float, "output_left")
        local or_sym = symbol(&float, "output_right")

        local ctx = {
            diagnostics = {},
            BS = buffer_size,
            sample_rate = self.transport.sample_rate,
            literals = self.mixer_literals,
            literal_values = literal_values,
            block_tick = 0,
            block_sample = eval_tick_to_sample(self.tempo_map, 0),
            param_bindings = self.mixer_param_bindings,
            param_meta = self.mixer_params,
            mod_slots = L(),
            mod_routes = L(),
            bufs_sym = bufs_sym,
            frames_sym = frames_sym,
            init_slots_sym = init_slots_sym,
            block_slots_sym = block_slots_sym,
            sample_slots_sym = sample_slots_sym,
            event_slots_sym = event_slots_sym,
            voice_slots_sym = voice_slots_sym,
            state_sym = state_sym,
        }

        local body_quotes = terralib.newlist()
        body_quotes:insert(quote
            for i = 0, [int32](total_floats - 1) do [bufs_sym][i] = 0.0f end
            for i = 0, [int32](graph_buf_count - 1) do [graph_bufs_sym][i] = 0.0f end
            for i = 0, [int32](init_count - 1) do [init_slots_sym][i] = 0.0f end
            for i = 0, [int32](block_count - 1) do [block_slots_sym][i] = 0.0f end
            for i = 0, [int32](sample_count - 1) do [sample_slots_sym][i] = 0.0f end
            for i = 0, [int32](event_count - 1) do [event_slots_sym][i] = 0.0f end
            for i = 0, [int32](voice_count - 1) do [voice_slots_sym][i] = 0.0f end
            for i = 0, [int32](state_count - 1) do [state_sym][i] = 0.0f end
        end)
        body_quotes:insert(quote [emit_runtime_ops({
            init_ops = self.mixer_init_ops,
            block_ops = self.mixer_block_ops,
            block_pts = self.mixer_block_pts,
            sample_ops = self.mixer_sample_ops,
            event_ops = self.mixer_event_ops,
            voice_ops = self.mixer_voice_ops,
        }, ctx)] end)

        local clip_units = {}
        for i = 1, #self.clip_programs do clip_units[i] = self.clip_programs[i]:compile() end
        local send_units = {}
        for i = 1, #self.send_programs do send_units[i] = self.send_programs[i]:compile() end
        local mix_units = {}
        for i = 1, #self.mix_programs do mix_units[i] = self.mix_programs[i]:compile() end
        local output_units = {}
        for i = 1, #self.output_programs do output_units[i] = self.output_programs[i]:compile() end

        if graph_fn then
            body_quotes:insert(quote [graph_fn](&[graph_bufs_sym][0], [frames_sym]) end)
            body_quotes:insert(quote
                var go = [int32](graph_out_offset)
                var wo = [int32](work_offset)
                for i = 0, [frames_sym] do
                    [bufs_sym][wo+i] = [bufs_sym][wo+i] + [graph_bufs_sym][go+i]
                end
            end)
        end

        for i = 1, #clip_units do
            local fn = clip_units[i].fn
            body_quotes:insert(quote [fn](&[bufs_sym][0], [frames_sym], &[init_slots_sym][0], &[block_slots_sym][0], &[sample_slots_sym][0], &[event_slots_sym][0], &[voice_slots_sym][0]) end)
        end
        for i = 1, #send_units do
            local fn = send_units[i].fn
            body_quotes:insert(quote [fn](&[bufs_sym][0], [frames_sym], &[init_slots_sym][0], &[block_slots_sym][0], &[sample_slots_sym][0], &[event_slots_sym][0], &[voice_slots_sym][0]) end)
        end
        for i = 1, #mix_units do
            local fn = mix_units[i].fn
            body_quotes:insert(quote [fn](&[bufs_sym][0], [frames_sym], &[init_slots_sym][0], &[block_slots_sym][0], &[sample_slots_sym][0], &[event_slots_sym][0], &[voice_slots_sym][0]) end)
        end
        for i = 1, #output_units do
            local fn = output_units[i].fn
            body_quotes:insert(quote [fn](&[bufs_sym][0], [frames_sym], &[init_slots_sym][0], &[block_slots_sym][0], &[sample_slots_sym][0], &[event_slots_sym][0], &[voice_slots_sym][0]) end)
        end

        body_quotes:insert(quote
            var lo = [int32](master_left_offset)
            var ro = [int32](master_right_offset)
            for i = 0, [frames_sym] do
                [ol_sym][i] = [ol_sym][i] + [bufs_sym][lo+i]
                [or_sym][i] = [or_sym][i] + [bufs_sym][ro+i]
            end
        end)

        track_fn = terra([ol_sym], [or_sym], [frames_sym])
            var [bufs_sym]
            var [graph_bufs_sym]
            var [init_slots_sym]
            var [block_slots_sym]
            var [sample_slots_sym]
            var [event_slots_sym]
            var [voice_slots_sym]
            var [state_sym]
            [body_quotes]
        end
    else
        track_fn = terra(output_left : &float, output_right : &float, frames : int32) end
    end

    return D.Kernel.Unit(track_fn, make_state_type(self.total_state_slots))
end)

local compile_project = terralib.memoize(function(self)
    local track_units = {}
    for i = 1, #self.track_programs do
        track_units[i] = self.track_programs[i]:compile()
    end

    local render_fn
    if #track_units > 0 then
        local ol_sym = symbol(&float, "output_left")
        local or_sym = symbol(&float, "output_right")
        local frames_sym = symbol(int32, "frames")
        local body_quotes = terralib.newlist()
        body_quotes:insert(quote
            for i = 0, [frames_sym] do
                [ol_sym][i] = 0.0f
                [or_sym][i] = 0.0f
            end
        end)
        for i = 1, #track_units do
            local fn = track_units[i].fn
            body_quotes:insert(quote [fn]([ol_sym], [or_sym], [frames_sym]) end)
        end
        render_fn = terra([ol_sym], [or_sym], [frames_sym])
            [body_quotes]
        end
    else
        render_fn = terra(output_left : &float, output_right : &float, frames : int32)
            for i = 0, frames do
                output_left[i] = 0.0f
                output_right[i] = 0.0f
            end
        end
    end

    local stub_type = tuple()
    local terra noop_fn() end
    local buffers = D.Kernel.Buffers(stub_type, stub_type, stub_type, stub_type, stub_type)
    local state = D.Kernel.State(stub_type, stub_type, stub_type, stub_type, stub_type, stub_type)
    local api = D.Kernel.API(
        noop_fn, noop_fn, render_fn,
        noop_fn, noop_fn, noop_fn, noop_fn, noop_fn, noop_fn,
        noop_fn, noop_fn, noop_fn, noop_fn, noop_fn, noop_fn, noop_fn, noop_fn
    )
    return D.Kernel.Project(buffers, state, api, render_fn)
end)

function D.Scheduled.GraphProgram:compile()
    return diag.wrap(nil, "scheduled.graph_program.compile", "real", function()
        return compile_graph_program(self)
    end, function()
        return F.kernel_unit()
    end)
end

function D.Scheduled.TrackProgram:compile()
    return diag.wrap(nil, "scheduled.track_program.compile", "real", function()
        return compile_track_program(self)
    end, function()
        return F.kernel_unit()
    end)
end

function D.Scheduled.Project:compile()
    return diag.wrap(nil, "scheduled.project.compile", "real", function()
        return compile_project(self)
    end, function()
        return F.kernel_project()
    end)
end

return true
