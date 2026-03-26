-- src/scheduled/project.t
-- Scheduled.GraphProgram:compile, Scheduled.TrackProgram:compile, Scheduled.Project:compile

local compile_binding_value = require("src/scheduled/compiler/binding")
local List = require("terralist")
local C = terralib.includec("string.h")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end

return function(types)
    local K = types.Kernel
    local Unit = types.Unit
    local EMPTY_STATE_T = tuple()
    local struct_id = 0

    local function next_struct_name(prefix)
        struct_id = struct_id + 1
        return prefix .. tostring(struct_id)
    end

    local function state_is_empty(t)
        return t == nil or t == EMPTY_STATE_T
    end

    local function make_state_type(n)
        n = n or 0
        if n <= 0 then return EMPTY_STATE_T end
        return float[n]
    end

    local function make_struct_type(prefix, entries)
        if #entries == 0 then return EMPTY_STATE_T end
        local S = terralib.types.newstruct(next_struct_name(prefix))
        for i = 1, #entries do S.entries:insert(entries[i]) end
        return S
    end

    local function nil_raw_state()
        return `([&uint8](0))
    end

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
            if tick < seg.end_tick then return seg.base_sample + (tick - seg.start_tick) * seg.samples_per_tick end
            prev = seg
        end
        return prev.base_sample + (tick - prev.start_tick) * prev.samples_per_tick
    end

    local function resolve_literal_binding(binding, literal_values)
        if binding and binding.rate_class == 0 then return literal_values[binding.slot + 1] or 0.0 end
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
                if op.interp == 2 or cur.tick == prev.tick then return prev.value end
                local t = (block_tick - prev.tick) / (cur.tick - prev.tick)
                if op.interp == 1 then t = t * t * (3.0 - 2.0 * t) end
                return prev.value + (cur.value - prev.value) * t
            end
            prev = cur
        end
        return prev.value
    end

    -- Emit rate-slot initialization quotes from ops owned by a program.
    -- All dependencies are explicit: ops_owner carries its own ops lists;
    -- literal_values and block_tick come from the program's compile-time data;
    -- slot symbols are the runtime fn parameters.
    local function emit_runtime_ops(ops_owner, literal_values, block_tick,
                                     init_sym, block_sym, sample_sym, event_sym, voice_sym)
        local bind = function(b)
            return compile_binding_value(b, literal_values, init_sym, block_sym, sample_sym, event_sym, voice_sym)
        end
        local quotes = terralib.newlist()
        for i = 1, #(ops_owner.init_ops or L()) do
            local op = ops_owner.init_ops[i]
            if op.kind == 0 and init_sym then
                quotes:insert(quote [init_sym][op.state_slot] = [bind(op.i0)] end)
            end
        end
        for i = 1, #(ops_owner.block_ops or L()) do
            local op = ops_owner.block_ops[i]
            if op.kind == 0 and block_sym then
                quotes:insert(quote [block_sym][op.arg0] = [bind(op.i0)] end)
            elseif op.kind == 1 and block_sym then
                local v = eval_block_curve(op, ops_owner.block_pts or L(), literal_values or {}, block_tick or 0)
                quotes:insert(quote [block_sym][op.arg0] = [float](v) end)
            end
        end
        for i = 1, #(ops_owner.sample_ops or L()) do
            local op = ops_owner.sample_ops[i]
            if op.kind == 0 and sample_sym then
                quotes:insert(quote [sample_sym][op.state_slot] = [bind(op.i0)] end)
            end
        end
        for i = 1, #(ops_owner.event_ops or L()) do
            local op = ops_owner.event_ops[i]
            if op.kind == 0 and event_sym then
                quotes:insert(quote [event_sym][op.state_slot] = [float](op.min_v) end)
            end
        end
        for i = 1, #(ops_owner.voice_ops or L()) do
            local op = ops_owner.voice_ops[i]
            if op.kind == 0 and voice_sym then
                quotes:insert(quote [voice_sym][op.state_slot] = [bind(op.i0)] end)
            end
        end
        return quotes
    end

    local function graph_runtime_slot_counts(self)
        local counts = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0}
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
        for i = 1, #self.init_ops do scan_binding(self.init_ops[i].i0, counts); scan_binding(self.init_ops[i].i1, counts)
            local need = self.init_ops[i].state_slot + 1; if need > counts[1] then counts[1] = need end end
        for i = 1, #self.block_ops do scan_binding(self.block_ops[i].i0, counts); scan_binding(self.block_ops[i].i1, counts)
            local need = self.block_ops[i].arg0 + 1; if need > counts[2] then counts[2] = need end end
        for i = 1, #self.sample_ops do scan_binding(self.sample_ops[i].i0, counts); scan_binding(self.sample_ops[i].i1, counts)
            local need = self.sample_ops[i].state_slot + 1; if need > counts[3] then counts[3] = need end end
        for i = 1, #self.event_ops do local need = self.event_ops[i].state_slot + 1; if need > counts[4] then counts[4] = need end end
        for i = 1, #self.voice_ops do scan_binding(self.voice_ops[i].i0, counts); scan_binding(self.voice_ops[i].i1, counts)
            local need = self.voice_ops[i].state_slot + 1; if need > counts[5] then counts[5] = need end end
        return counts
    end

    local function track_runtime_slot_counts(self)
        local counts = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0}
        for i = 1, #self.mixer_param_bindings do scan_binding(self.mixer_param_bindings[i], counts) end
        scan_binding(self.track.volume, counts); scan_binding(self.track.pan, counts)
        for i = 1, #self.send_programs do scan_binding(self.send_programs[i].send.level, counts) end
        for i = 1, #self.mix_programs do scan_binding(self.mix_programs[i].mix.gain, counts) end
        for i = 1, #self.output_programs do scan_binding(self.output_programs[i].output.gain, counts); scan_binding(self.output_programs[i].output.pan, counts) end
        for i = 1, #self.clip_programs do scan_binding(self.clip_programs[i].clip.gain, counts) end
        for i = 1, #self.mixer_init_ops do scan_binding(self.mixer_init_ops[i].i0, counts); scan_binding(self.mixer_init_ops[i].i1, counts)
            local need = self.mixer_init_ops[i].state_slot + 1; if need > counts[1] then counts[1] = need end end
        for i = 1, #self.mixer_block_ops do scan_binding(self.mixer_block_ops[i].i0, counts); scan_binding(self.mixer_block_ops[i].i1, counts)
            local need = self.mixer_block_ops[i].arg0 + 1; if need > counts[2] then counts[2] = need end end
        for i = 1, #self.mixer_sample_ops do scan_binding(self.mixer_sample_ops[i].i0, counts); scan_binding(self.mixer_sample_ops[i].i1, counts)
            local need = self.mixer_sample_ops[i].state_slot + 1; if need > counts[3] then counts[3] = need end end
        for i = 1, #self.mixer_event_ops do local need = self.mixer_event_ops[i].state_slot + 1; if need > counts[4] then counts[4] = need end end
        for i = 1, #self.mixer_voice_ops do scan_binding(self.mixer_voice_ops[i].i0, counts); scan_binding(self.mixer_voice_ops[i].i1, counts)
            local need = self.mixer_voice_ops[i].state_slot + 1; if need > counts[5] then counts[5] = need end end
        return counts
    end

    local function compile_graph_program(self)
        -- All state composition is done via Unit.compose.
        -- No state_raw: &uint8. Each child unit declares its state_t; the
        -- composed GraphState struct falls out of Unit.compose automatically.
        local buffer_size = self.transport.buffer_size
        local n_bufs = math.max(self.total_buffers, 1)
        local total_floats = math.max(n_bufs * buffer_size, 1)
        local literal_values = {}
        for i = 1, #self.literals do literal_values[i] = self.literals[i].value end
        local rate_counts = graph_runtime_slot_counts(self)
        local init_count  = math.max(rate_counts[1], 1)
        local block_count = math.max(rate_counts[2], 1)
        local sample_count = math.max(rate_counts[3], 1)
        local event_count  = math.max(rate_counts[4], 1)
        local voice_count  = math.max(rate_counts[5], 1)

        if #self.node_programs == 0 and #self.mod_programs == 0 then
            local noop = terra(bufs: &float, frames: int32) end
            return Unit(noop, tuple())
        end

        -- Compile every child leaf unit first.
        local child_units = {}
        for i = 1, #self.mod_programs  do child_units[#child_units+1] = self.mod_programs[i]:compile() end
        for i = 1, #self.node_programs do child_units[#child_units+1] = self.node_programs[i]:compile() end

        -- Build the shared rate-slot param symbols (bufs + frames only at graph level;
        -- init/block/sample/event/voice slots are stack-allocated inside the fn body).
        local bufs_sym   = symbol(&float, "bufs")
        local frames_sym = symbol(int32, "frames")
        local params = terralib.newlist({ bufs_sym, frames_sym })

        -- Unit.compose: auto-builds GraphState from children's state_t fields,
        -- injects typed per-child state_expr into annotated list.
        return Unit.compose(child_units, params, function(state_sym, annotated, params)
            local bufs_s   = params[1]
            local frames_s = params[2]

            -- We still need the rate slots (init/block/etc.) as locals inside the fn.
            local init_slots   = symbol(float[init_count],   "init_slots")
            local block_slots  = symbol(float[block_count],  "block_slots")
            local sample_slots = symbol(float[sample_count], "sample_slots")
            local event_slots  = symbol(float[event_count],  "event_slots")
            local voice_slots  = symbol(float[voice_count],  "voice_slots")

            local block_tick   = 0
            local lv           = literal_values

            local body = terralib.newlist()
            body:insert(quote
                var [init_slots];   var [block_slots]
                var [sample_slots]; var [event_slots]; var [voice_slots]
                for i = 0, [int32](total_floats-1)  do [bufs_s][i]      = 0.0f end
                for i = 0, [int32](init_count-1)    do [init_slots][i]   = 0.0f end
                for i = 0, [int32](block_count-1)   do [block_slots][i]  = 0.0f end
                for i = 0, [int32](sample_count-1)  do [sample_slots][i] = 0.0f end
                for i = 0, [int32](event_count-1)   do [event_slots][i]  = 0.0f end
                for i = 0, [int32](voice_count-1)   do [voice_slots][i]  = 0.0f end
            end)
            body:insert(quote [emit_runtime_ops(self, lv, block_tick,
                init_slots, block_slots, sample_slots, event_slots, voice_slots)] end)

            -- Call each child fn. For stateful children, pass typed state pointer.
            -- For stateless children, fn has no state parameter.
            for _, ann in ipairs(annotated) do
                local fn = ann.fn
                local i_s = `&[init_slots][0]
                local b_s = `&[block_slots][0]
                local sa_s = `&[sample_slots][0]
                local e_s = `&[event_slots][0]
                local v_s = `&[voice_slots][0]
                if ann.has_state then
                    local se = ann.state_expr
                    body:insert(quote [fn]([bufs_s], [frames_s], [i_s], [b_s], [sa_s], [e_s], [v_s], [se]) end)
                else
                    body:insert(quote [fn]([bufs_s], [frames_s], [i_s], [b_s], [sa_s], [e_s], [v_s]) end)
                end
            end

            return body
        end)
    end

    local function compile_track_program(self)
        -- State composition via Unit.compose:
        -- - graph_unit: typed state from compile_graph_program (oscillator phases etc.)
        -- - mixer_unit: float[N] for parameter smoothing (rate-slot mechanism)
        -- No state_raw: &uint8 anywhere. Types fall out structurally.
        local buffer_size = self.transport.buffer_size
        local n_bufs = math.max(self.total_buffers, 1)
        local total_floats = math.max(n_bufs * buffer_size, 1)
        local literal_values = {}
        for i = 1, #self.mixer_literals do literal_values[i] = self.mixer_literals[i].value end
        local rate_counts = track_runtime_slot_counts(self)
        local init_count   = math.max(rate_counts[1], 1)
        local block_count  = math.max(rate_counts[2], 1)
        local sample_count = math.max(rate_counts[3], 1)
        local event_count  = math.max(rate_counts[4], 1)
        local voice_count  = math.max(rate_counts[5], 1)
        local mixer_state_count = math.max(self.total_state_slots, 0)
        local mixer_state_t = make_state_type(mixer_state_count)

        local graph_unit    = self.device_graph:compile()
        local graph_fn      = graph_unit.fn
        local graph_state_t = graph_unit.state_t
        local has_graph_state = not state_is_empty(graph_state_t)
        local has_mixer_state = not state_is_empty(mixer_state_t)

        -- Graph nodes use a SEPARATE local buffer array (graph_bufs).
        -- The classified compiler assigns graph node buffer indices independently
        -- from the track-level mixer indices (work_buf, master_left, master_right).
        -- Mixing them into a single flat array causes index collisions (e.g., a node
        -- out_buf=2 colliding with master_left=2). Separate arrays eliminate this.
        -- The graph output is copied into track bufs at work_offset after the graph runs.
        local graph_buf_count     = math.max(self.device_graph.total_buffers * buffer_size, 1)
        local graph_out_offset    = (self.device_graph.graph and self.device_graph.graph.out_buf or 0) * buffer_size
        local work_offset         = self.track.work_buf * buffer_size
        local master_left_offset  = self.master_left  * buffer_size
        local master_right_offset = self.master_right * buffer_size

        -- Build the composed track state: { mixer_slots: float[N]?, graph_state: GraphState? }
        local track_state_entries = terralib.newlist()
        if has_mixer_state then track_state_entries:insert({ field = "mixer_slots", type = mixer_state_t }) end
        if has_graph_state  then track_state_entries:insert({ field = "graph_state", type = graph_state_t }) end
        local track_state_t = make_struct_type("TrackState", track_state_entries)
        local has_track_state = not state_is_empty(track_state_t)

        local clip_units   = {}; for i = 1, #self.clip_programs   do clip_units[i]   = self.clip_programs[i]:compile()   end
        local send_units   = {}; for i = 1, #self.send_programs   do send_units[i]   = self.send_programs[i]:compile()   end
        local mix_units    = {}; for i = 1, #self.mix_programs    do mix_units[i]    = self.mix_programs[i]:compile()    end
        local output_units = {}; for i = 1, #self.output_programs do output_units[i] = self.output_programs[i]:compile() end

        local has_work = #self.clip_programs > 0 or #self.send_programs > 0
            or #self.mix_programs > 0 or #self.output_programs > 0 or graph_fn ~= nil

        local track_fn
        if has_work then
            local ol_sym     = symbol(&float, "output_left")
            local or_sym     = symbol(&float, "output_right")
            local frames_sym = symbol(int32,  "frames")
            -- State symbol: typed, not void pointer.
            local state_sym = nil
            if has_track_state then state_sym = symbol(&track_state_t, "state") end
            -- Mixer state: &float into mixer_slots (for rate-slot mechanism).
            local mixer_state_q = nil
            if has_mixer_state and state_sym then
                mixer_state_q = `([&float](&(@[state_sym]).mixer_slots[0]))
            end
            -- Graph state: typed pointer into graph_state field.
            local graph_state_q = nil
            if has_graph_state and state_sym then
                graph_state_q = `(&(@[state_sym]).graph_state)
            end

            -- Track-level flat buffer array (for mixer jobs only: mix, output, clips, sends).
            -- Graph nodes operate on their own separate graph_bufs to avoid index collisions.
            local bufs_sym         = symbol(float[total_floats],      "bufs")
            local graph_bufs_sym   = symbol(float[graph_buf_count],   "graph_bufs")
            local init_slots_sym   = symbol(float[init_count],        "init_slots")
            local block_slots_sym  = symbol(float[block_count],       "block_slots")
            local sample_slots_sym = symbol(float[sample_count],      "sample_slots")
            local event_slots_sym  = symbol(float[event_count],       "event_slots")
            local voice_slots_sym  = symbol(float[voice_count],       "voice_slots")

            local lv = literal_values
            local block_tick = 0

            local body = terralib.newlist()
            body:insert(quote
                var [bufs_sym];       var [graph_bufs_sym]
                var [init_slots_sym]; var [block_slots_sym]
                var [sample_slots_sym]; var [event_slots_sym]; var [voice_slots_sym]
                for i = 0, [int32](total_floats-1)    do [bufs_sym][i]         = 0.0f end
                for i = 0, [int32](graph_buf_count-1) do [graph_bufs_sym][i]   = 0.0f end
                for i = 0, [int32](init_count-1)      do [init_slots_sym][i]   = 0.0f end
                for i = 0, [int32](block_count-1)     do [block_slots_sym][i]  = 0.0f end
                for i = 0, [int32](sample_count-1)    do [sample_slots_sym][i] = 0.0f end
                for i = 0, [int32](event_count-1)     do [event_slots_sym][i]  = 0.0f end
                for i = 0, [int32](voice_count-1)     do [voice_slots_sym][i]  = 0.0f end
            end)
            body:insert(quote [emit_runtime_ops({
                init_ops   = self.mixer_init_ops,   block_ops  = self.mixer_block_ops,
                block_pts  = self.mixer_block_pts,  sample_ops = self.mixer_sample_ops,
                event_ops  = self.mixer_event_ops,  voice_ops  = self.mixer_voice_ops,
            }, lv, block_tick,
                init_slots_sym, block_slots_sym, sample_slots_sym, event_slots_sym, voice_slots_sym)] end)

            -- Run the graph fn on graph_bufs (separate from track bufs).
            -- Then copy the graph output into bufs at work_offset.
            if graph_fn then
                if graph_state_q then
                    local gs = graph_state_q
                    body:insert(quote [graph_fn](&[graph_bufs_sym][0], [frames_sym], [gs]) end)
                else
                    body:insert(quote [graph_fn](&[graph_bufs_sym][0], [frames_sym]) end)
                end
                body:insert(quote
                    var go = [int32](graph_out_offset)
                    var wo = [int32](work_offset)
                    for i = 0, [frames_sym] do
                        [bufs_sym][wo+i] = [bufs_sym][wo+i] + [graph_bufs_sym][go+i]
                    end
                end)
            end

            -- Mixer leaf fns: all stateless (no state param).
            local function call_stateless_units(units)
                for _, u in ipairs(units) do
                    local fn = u.fn
                    body:insert(quote [fn](&[bufs_sym][0], [frames_sym],
                        &[init_slots_sym][0], &[block_slots_sym][0],
                        &[sample_slots_sym][0], &[event_slots_sym][0],
                        &[voice_slots_sym][0]) end)
                end
            end
            call_stateless_units(clip_units)
            call_stateless_units(send_units)
            call_stateless_units(mix_units)
            call_stateless_units(output_units)

            body:insert(quote
                var lo = [int32](master_left_offset)
                var ro = [int32](master_right_offset)
                for i = 0, [frames_sym] do
                    [ol_sym][i] = [ol_sym][i] + [bufs_sym][lo+i]
                    [or_sym][i] = [or_sym][i] + [bufs_sym][ro+i]
                end
            end)

            if state_sym then
                local ss = state_sym
                track_fn = terra([ol_sym], [or_sym], [frames_sym], [ss])
                    [body]
                end
            else
                track_fn = terra([ol_sym], [or_sym], [frames_sym])
                    [body]
                end
            end
        else
            track_fn = terra(output_left: &float, output_right: &float, frames: int32) end
        end
        return Unit(track_fn, track_state_t)
    end

    local function compile_project(self)
        -- Use Unit.compose: project state = composition of all track states.
        -- No void pointers. KS.alloc_state works via kernel:state_type() = ProjectState.
        local track_units = {}
        for i = 1, #self.track_programs do
            track_units[i] = self.track_programs[i]:compile()
        end

        local ol  = symbol(&float, "output_left")
        local or_ = symbol(&float, "output_right")
        local frames = symbol(int32, "frames")
        local params = terralib.newlist({ ol, or_, frames })

        local project_unit = Unit.compose(track_units, params,
            function(state_sym, annotated, params)
                local ol_s = params[1]
                local or_s = params[2]
                local frames_s = params[3]
                local body = terralib.newlist()
                body:insert(quote
                    for i = 0, [frames_s] do [ol_s][i] = 0.0f; [or_s][i] = 0.0f end
                end)
                for _, ann in ipairs(annotated) do
                    local fn = ann.fn
                    if ann.has_state then
                        local se = ann.state_expr
                        body:insert(quote [fn]([ol_s], [or_s], [frames_s], [se]) end)
                    else
                        body:insert(quote [fn]([ol_s], [or_s], [frames_s]) end)
                    end
                end
                return body
            end)

        -- Wrap into K.Project.
        -- The internal fn is fully typed: (ol, or, frames) or (ol, or, frames, state: &ProjectState).
        -- The audio ABI boundary is (ol, or, frames, state_raw: &uint8): one explicit cast here,
        -- justified by the external audio callback contract. No void pointers inside.
        local project_state_t = project_unit.state_t
        local inner_fn = project_unit.fn
        local render_fn, init_fn
        if state_is_empty(project_state_t) then
            render_fn = terra(ol: &float, or_: &float, frames: int32, state_raw: &uint8)
                [inner_fn](ol, or_, frames)
            end
            init_fn = terra(state_raw: &uint8) end
        else
            render_fn = terra(ol: &float, or_: &float, frames: int32, state_raw: &uint8)
                [inner_fn](ol, or_, frames, [&project_state_t](state_raw))
            end
            init_fn = terra(state_raw: &uint8)
                C.memset(state_raw, 0, [uint64](terralib.sizeof(project_state_t)))
            end
        end
        return K.Project(render_fn, project_state_t, init_fn)
    end

    return {
        graph_program = compile_graph_program,
        track_program = compile_track_program,
        project = compile_project,
    }
end
