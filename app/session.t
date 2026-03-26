-- app/session.t
-- DAW session: owns Editor state, compilation pipeline, and audio output.
--
-- Usage:
--   local session = require("app/session")
--   local s = session.new(editor_project)
--   s:compile()    -- run full pipeline
--   s:play()       -- start audio
--   s:set_param(owner_id, param_id, value) -- edit + recompile
--   s:stop()
--   s:close()

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local TICKS_PER_BEAT = 960
local audio = require("app/audio")

local M = {}

local function map_preserve(list, fn)
    if list == nil then return nil, false end

    local changed = false
    local out = nil
    for i = 1, #list do
        local old_item = list[i]
        local new_item = fn(old_item, i)
        if new_item ~= old_item and not changed then
            changed = true
            out = L()
            for j = 1, i - 1 do out:insert(list[j]) end
        end
        if changed then out:insert(new_item) end
    end

    if changed then return out, true end
    return list, false
end

local function static_param_value(param)
    local src = param and param.source or nil
    if src and src.kind == "StaticValue" then return src.value end
    return nil
end

local function with_static_param_value(param, value)
    if static_param_value(param) == value then return param end
    return D.Editor.ParamValue(
        param.id, param.name, param.default_value,
        param.min_value, param.max_value,
        D.Editor.StaticValue(value),
        param.combine, param.smoothing
    )
end

local function update_param_list(params, param_id, new_value)
    return map_preserve(params, function(param)
        if param.id ~= param_id then return param end
        return with_static_param_value(param, new_value)
    end)
end

local update_device_chain

local function update_note_fx_lane(lane, device_id, param_id, new_value)
    if not lane then return lane end
    local new_chain = update_device_chain(lane.chain, device_id, param_id, new_value)
    if new_chain == lane.chain then return lane end
    return D.Editor.NoteFXLane(new_chain)
end

local function update_audio_fx_lane(lane, device_id, param_id, new_value)
    if not lane then return lane end
    local new_chain = update_device_chain(lane.chain, device_id, param_id, new_value)
    if new_chain == lane.chain then return lane end
    return D.Editor.AudioFXLane(new_chain)
end

local function rebuild_native_body(body, params, note_fx, post_fx)
    return D.Editor.NativeDeviceBody(
        body.id, body.name, body.kind,
        params, body.modulators,
        note_fx, post_fx,
        body.preset, body.enabled, body.meta
    )
end

local function rebuild_layer_container(body, layers, params, note_fx, post_fx)
    return D.Editor.LayerContainer(
        body.id, body.name, layers,
        params, body.modulators,
        note_fx, post_fx,
        body.preset, body.enabled, body.meta
    )
end

local function rebuild_selector_container(body, branches, params, note_fx, post_fx)
    return D.Editor.SelectorContainer(
        body.id, body.name, body.mode, branches,
        params, body.modulators,
        note_fx, post_fx,
        body.preset, body.enabled, body.meta
    )
end

local function rebuild_split_container(body, bands, params, note_fx, post_fx)
    return D.Editor.SplitContainer(
        body.id, body.name, body.kind, bands,
        params, body.modulators,
        note_fx, post_fx,
        body.preset, body.enabled, body.meta
    )
end

local function rebuild_grid_container(body, params, note_fx, post_fx)
    return D.Editor.GridContainer(
        body.id, body.name, body.patch,
        params, body.modulators,
        note_fx, post_fx,
        body.preset, body.enabled, body.meta
    )
end

local function update_layer(layer, device_id, param_id, new_value)
    local new_chain = update_device_chain(layer.chain, device_id, param_id, new_value)
    if new_chain == layer.chain then return layer end
    return D.Editor.Layer(
        layer.id, layer.name, new_chain,
        layer.volume, layer.pan,
        layer.muted, layer.meta
    )
end

local function update_selector_branch(branch, device_id, param_id, new_value)
    local new_chain = update_device_chain(branch.chain, device_id, param_id, new_value)
    if new_chain == branch.chain then return branch end
    return D.Editor.SelectorBranch(branch.id, branch.name, new_chain, branch.meta)
end

local function update_split_band(band, device_id, param_id, new_value)
    local new_chain = update_device_chain(band.chain, device_id, param_id, new_value)
    if new_chain == band.chain then return band end
    return D.Editor.SplitBand(
        band.id, band.name, band.crossover_value,
        new_chain, band.meta
    )
end

local function update_device(device, device_id, param_id, new_value)
    local body = device.body
    if not body then return device end

    if device.kind == "NativeDevice" then
        local params = body.params
        if body.id == device_id then
            params = select(1, update_param_list(body.params, param_id, new_value))
        end
        local note_fx = update_note_fx_lane(body.note_fx, device_id, param_id, new_value)
        local post_fx = update_audio_fx_lane(body.post_fx, device_id, param_id, new_value)
        if params == body.params and note_fx == body.note_fx and post_fx == body.post_fx then
            return device
        end
        return D.Editor.NativeDevice(rebuild_native_body(body, params, note_fx, post_fx))

    elseif device.kind == "LayerDevice" then
        local layers = select(1, map_preserve(body.layers, function(layer)
            return update_layer(layer, device_id, param_id, new_value)
        end))
        local params = body.params
        if body.id == device_id then
            params = select(1, update_param_list(body.params, param_id, new_value))
        end
        local note_fx = update_note_fx_lane(body.note_fx, device_id, param_id, new_value)
        local post_fx = update_audio_fx_lane(body.post_fx, device_id, param_id, new_value)
        if layers == body.layers and params == body.params and note_fx == body.note_fx and post_fx == body.post_fx then
            return device
        end
        return D.Editor.LayerDevice(rebuild_layer_container(body, layers, params, note_fx, post_fx))

    elseif device.kind == "SelectorDevice" then
        local branches = select(1, map_preserve(body.branches, function(branch)
            return update_selector_branch(branch, device_id, param_id, new_value)
        end))
        local params = body.params
        if body.id == device_id then
            params = select(1, update_param_list(body.params, param_id, new_value))
        end
        local note_fx = update_note_fx_lane(body.note_fx, device_id, param_id, new_value)
        local post_fx = update_audio_fx_lane(body.post_fx, device_id, param_id, new_value)
        if branches == body.branches and params == body.params and note_fx == body.note_fx and post_fx == body.post_fx then
            return device
        end
        return D.Editor.SelectorDevice(rebuild_selector_container(body, branches, params, note_fx, post_fx))

    elseif device.kind == "SplitDevice" then
        local bands = select(1, map_preserve(body.bands, function(band)
            return update_split_band(band, device_id, param_id, new_value)
        end))
        local params = body.params
        if body.id == device_id then
            params = select(1, update_param_list(body.params, param_id, new_value))
        end
        local note_fx = update_note_fx_lane(body.note_fx, device_id, param_id, new_value)
        local post_fx = update_audio_fx_lane(body.post_fx, device_id, param_id, new_value)
        if bands == body.bands and params == body.params and note_fx == body.note_fx and post_fx == body.post_fx then
            return device
        end
        return D.Editor.SplitDevice(rebuild_split_container(body, bands, params, note_fx, post_fx))

    elseif device.kind == "GridDevice" then
        local params = body.params
        if body.id == device_id then
            params = select(1, update_param_list(body.params, param_id, new_value))
        end
        local note_fx = update_note_fx_lane(body.note_fx, device_id, param_id, new_value)
        local post_fx = update_audio_fx_lane(body.post_fx, device_id, param_id, new_value)
        if params == body.params and note_fx == body.note_fx and post_fx == body.post_fx then
            return device
        end
        return D.Editor.GridDevice(rebuild_grid_container(body, params, note_fx, post_fx))
    end

    return device
end

update_device_chain = function(chain, device_id, param_id, new_value)
    local new_devices = select(1, map_preserve(chain.devices, function(device)
        return update_device(device, device_id, param_id, new_value)
    end))
    if new_devices == chain.devices then return chain end
    return D.Editor.DeviceChain(new_devices)
end

local function rebuild_track(track, volume, devices)
    return D.Editor.Track(
        track.id, track.name, track.channels, track.kind,
        track.input, volume, track.pan, devices,
        track.clips, track.launcher_slots, track.sends,
        track.output_track_id, track.group_track_id,
        track.muted, track.soloed, track.armed,
        track.monitor_input, track.phase_invert, track.meta
    )
end

local function update_track_param(track, device_id, param_id, new_value)
    local new_chain = update_device_chain(track.devices, device_id, param_id, new_value)
    if new_chain == track.devices then return track end
    return rebuild_track(track, track.volume, new_chain)
end

local function update_track_volume(track, value)
    local new_volume = with_static_param_value(track.volume, value)
    if new_volume == track.volume then return track end
    return rebuild_track(track, new_volume, track.devices)
end

local function rebuild_project(proj, tracks)
    return D.Editor.Project(
        proj.name, proj.author, proj.format_version,
        proj.transport, tracks, proj.scenes,
        proj.tempo_map, proj.assets
    )
end

local function project_with_tracks(proj, tracks)
    if tracks == proj.tracks then return proj end
    return rebuild_project(proj, tracks)
end

function M.update_project_param(proj, device_id, param_id, new_value)
    local new_tracks = select(1, map_preserve(proj.tracks, function(track)
        return update_track_param(track, device_id, param_id, new_value)
    end))
    return project_with_tracks(proj, new_tracks)
end

function M.update_project_track_volume(proj, track_id, value)
    local new_tracks = select(1, map_preserve(proj.tracks, function(track)
        if track.id ~= track_id then return track end
        return update_track_volume(track, value)
    end))
    return project_with_tracks(proj, new_tracks)
end

function M.new(editor_project, opts)
    opts = opts or {}
    local sample_rate = editor_project.transport.sample_rate or 44100
    local buffer_size = editor_project.transport.buffer_size or 512

    local s = {
        project = editor_project,
        audio = nil,
        _undo_stack = {},
        _redo_stack = {},
    }

    -- ── Render function: lazy pipeline, fully memoized ──
    -- No explicit compile step. Each phase memoizes on its input.
    -- Unchanged subtrees are instant cache hits at every level.
    function s:render_fn()
        return self.project
            :lower()
            :resolve(TICKS_PER_BEAT)
            :classify()
            :schedule()
            :compile()
            :entry_fn()
    end

    -- ── Audio control ──
    function s:open_audio()
        self.audio = audio.open(sample_rate, buffer_size)
        -- One thunk, set once. The audio loop resolves it each push.
        -- Mutations change self.project; render_fn() picks it up via memoize.
        self.audio:set_render_thunk(function() return self:render_fn() end)
        return self
    end

    function s:play()
        if not self.audio then self:open_audio() end
        self.audio:start()
        return self
    end

    function s:stop()
        if self.audio then self.audio:stop() end
        return self
    end

    function s:close()
        if self.audio then self.audio:close(); self.audio = nil end
        return self
    end

    -- ── Editor mutations ──
    -- Push current state to undo stack, apply mutation.
    -- No recompile call — render_fn() is lazy and memoized.
    -- ── Editor mutations ──
    -- Just swap the project. The audio thunk resolves render_fn() lazily.
    -- Memoize makes unchanged pipeline steps instant cache hits.
    function s:mutate(fn)
        local next_project = fn(self.project)
        if next_project == nil or next_project == self.project then
            return self
        end
        table.insert(self._undo_stack, self.project)
        self._redo_stack = {}
        self.project = next_project
        return self
    end

    function s:undo()
        if #self._undo_stack == 0 then return self end
        table.insert(self._redo_stack, self.project)
        self.project = table.remove(self._undo_stack)
        return self
    end

    function s:redo()
        if #self._redo_stack == 0 then return self end
        table.insert(self._undo_stack, self.project)
        self.project = table.remove(self._redo_stack)
        return self
    end

    -- ── Common commands ──

    -- SetParamValue: find a param by stable device_id + param_id, set static value.
    -- Structural sharing is preserved for every untouched subtree.
    function s:set_param(device_id, param_id, new_value)
        return self:mutate(function(proj)
            return M.update_project_param(proj, device_id, param_id, new_value)
        end)
    end

    -- SetTrackVolume: set a track's volume param while preserving all untouched structure.
    function s:set_track_volume(track_id, value)
        return self:mutate(function(proj)
            return M.update_project_track_volume(proj, track_id, value)
        end)
    end

    return s
end

return M
