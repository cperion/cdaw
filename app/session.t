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

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L
local audio = require("app/audio")

local M = {}

function M.new(editor_project, opts)
    opts = opts or {}
    local sample_rate = editor_project.transport.sample_rate or 44100
    local buffer_size = editor_project.transport.buffer_size or 512

    local s = {
        project = editor_project,
        render_fn = nil,
        audio = nil,
        _undo_stack = {},
        _redo_stack = {},
        compiled = false,
    }

    -- ── Compile the full pipeline ──
    function s:compile()
        local ctx = {diagnostics = {}}
        local authored = self.project:lower(ctx)
        local resolved = authored:resolve(ctx)
        local classified = resolved:classify(ctx)
        local scheduled = classified:schedule(ctx)
        local kernel = scheduled:compile(ctx)
        self.render_fn = kernel:entry_fn()
        self.compiled = true
        self._last_diagnostics = ctx.diagnostics

        -- Hot-swap into audio if running
        if self.audio then
            self.audio:set_render_fn(self.render_fn)
        end

        return self
    end

    -- ── Audio control ──
    function s:open_audio()
        self.audio = audio.open(sample_rate, buffer_size)
        if self.render_fn then
            self.audio:set_render_fn(self.render_fn)
        end
        return self
    end

    function s:play()
        if not self.audio then self:open_audio() end
        if not self.compiled then self:compile() end
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
    -- Push current state to undo stack, apply mutation, recompile.
    function s:mutate(fn)
        -- Save for undo
        table.insert(self._undo_stack, self.project)
        self._redo_stack = {}

        -- Apply mutation (fn receives project, returns new project)
        self.project = fn(self.project)

        -- Recompile
        self:compile()
        return self
    end

    function s:undo()
        if #self._undo_stack == 0 then return self end
        table.insert(self._redo_stack, self.project)
        self.project = table.remove(self._undo_stack)
        self:compile()
        return self
    end

    function s:redo()
        if #self._redo_stack == 0 then return self end
        table.insert(self._undo_stack, self.project)
        self.project = table.remove(self._redo_stack)
        self:compile()
        return self
    end

    -- ── Common commands ──

    -- SetParamValue: find a param by device_id + param_id, set static value
    function s:set_param(device_id, param_id, new_value)
        return self:mutate(function(proj)
            -- Deep clone tracks with the modified param
            local new_tracks = L()
            for i = 1, #proj.tracks do
                local track = proj.tracks[i]
                local new_devices = L()
                for j = 1, #track.devices.devices do
                    local dev = track.devices.devices[j]
                    if dev.body and dev.body.id == device_id then
                        -- Found the device, modify its params
                        local new_params = L()
                        for k = 1, #dev.body.params do
                            local p = dev.body.params[k]
                            if p.id == param_id then
                                new_params:insert(D.Editor.ParamValue(
                                    p.id, p.name, p.default_value,
                                    p.min_value, p.max_value,
                                    D.Editor.StaticValue(new_value),
                                    p.combine, p.smoothing))
                            else
                                new_params:insert(p)
                            end
                        end
                        -- Reconstruct the device with new params
                        local new_body = D.Editor.NativeDeviceBody(
                            dev.body.id, dev.body.name, dev.body.kind,
                            new_params, dev.body.modulators,
                            dev.body.note_fx, dev.body.post_fx,
                            dev.body.preset, dev.body.enabled, dev.body.meta)
                        new_devices:insert(D.Editor.NativeDevice(new_body))
                    else
                        new_devices:insert(dev)
                    end
                end
                local new_chain = D.Editor.DeviceChain(new_devices)
                new_tracks:insert(D.Editor.Track(
                    track.id, track.name, track.channels, track.kind,
                    track.input, track.volume, track.pan, new_chain,
                    track.clips, track.launcher_slots, track.sends,
                    track.output_track_id, track.group_track_id,
                    track.muted, track.soloed, track.armed,
                    track.monitor_input, track.phase_invert, track.meta))
            end
            return D.Editor.Project(
                proj.name, proj.author, proj.format_version,
                proj.transport, new_tracks, proj.scenes,
                proj.tempo_map, proj.assets)
        end)
    end

    -- SetTrackVolume: set a track's volume param
    function s:set_track_volume(track_id, value)
        return self:mutate(function(proj)
            local new_tracks = L()
            for i = 1, #proj.tracks do
                local t = proj.tracks[i]
                if t.id == track_id then
                    local new_vol = D.Editor.ParamValue(
                        t.volume.id, t.volume.name, t.volume.default_value,
                        t.volume.min_value, t.volume.max_value,
                        D.Editor.StaticValue(value),
                        t.volume.combine, t.volume.smoothing)
                    new_tracks:insert(D.Editor.Track(
                        t.id, t.name, t.channels, t.kind, t.input,
                        new_vol, t.pan, t.devices,
                        t.clips, t.launcher_slots, t.sends,
                        t.output_track_id, t.group_track_id,
                        t.muted, t.soloed, t.armed,
                        t.monitor_input, t.phase_invert, t.meta))
                else
                    new_tracks:insert(t)
                end
            end
            return D.Editor.Project(
                proj.name, proj.author, proj.format_version,
                proj.transport, new_tracks, proj.scenes,
                proj.tempo_map, proj.assets)
        end)
    end

    return s
end

return M
