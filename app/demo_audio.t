-- app/demo_audio.t
-- First audible demo: compile a project, play it through SDL audio,
-- then interactively change parameters and hear the difference.
--
-- Usage: terra app/demo_audio.t

local DAW = require("daw")
local D = DAW.types
local List = require("terralist")
local function L(t) if t == nil then return List() end; local l = List(); for i = 1, #t do l:insert(t[i]) end; return l end
local session = require("app/session")

local C = terralib.includecstring([[
#include <SDL3/SDL.h>
#include <stdio.h>
#include <unistd.h>
]], {"-I/usr/include"})
terralib.linklibrary("libSDL3.so")

-- ══════════════════════════════════════════
-- Build a simple project: SineOsc → Gain → master
-- ══════════════════════════════════════════
local function make_project(freq, gain, volume)
    freq = freq or 440
    gain = gain or 0.3
    volume = volume or 0.8
    return D.Editor.Project(
        "AudioDemo", nil, 1,
        D.Editor.Transport(44100, 512, 120, 0, 4, 4, D.Editor.QNone, false, nil),
        L{D.Editor.Track(1, "Synth", 2, D.Editor.AudioTrack, D.Editor.NoInput,
            D.Editor.ParamValue(0, "vol", 1, 0, 4,
                D.Editor.StaticValue(volume), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.ParamValue(1, "pan", 0, -1, 1,
                D.Editor.StaticValue(0), D.Editor.Replace, D.Editor.NoSmoothing),
            D.Editor.DeviceChain(L{
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    10, "Osc", D.Authored.SineOsc,
                    L{D.Editor.ParamValue(0, "freq", 440, 20, 20000,
                        D.Editor.StaticValue(freq),
                        D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil)),
                D.Editor.NativeDevice(D.Editor.NativeDeviceBody(
                    11, "Gain", D.Authored.GainNode,
                    L{D.Editor.ParamValue(0, "gain", 1, 0, 4,
                        D.Editor.StaticValue(gain),
                        D.Editor.Replace, D.Editor.NoSmoothing)},
                    L(), nil, nil, nil, true, nil)),
            }),
            L(), L(), L(), nil, nil, false, false, false, false, false, nil)},
        L(),
        D.Editor.TempoMap(L{D.Editor.TempoPoint(0, 120)}, L()),
        D.Authored.AssetBank(L(), L(), L(), L(), L()))
end

-- ══════════════════════════════════════════
-- Main
-- ══════════════════════════════════════════
print("╔══════════════════════════════════════════════╗")
print("║  Terra DAW — First Audio Demo (SDL3)         ║")
print("╚══════════════════════════════════════════════╝")
print("")

local proj = make_project(440, 0.3, 0.8)
local s = session.new(proj)

print("Starting playback...")
s:play()
print("  ♪ Playing: SineOsc(440 Hz) → Gain(0.3) → Volume(0.8)")
print("")

-- Audio push loop with interactive parameter changes
local changes = {
    {delay = 2.0, desc = "Frequency → 330 Hz (E4)", fn = function(s) s:set_param(10, 0, 330) end},
    {delay = 2.0, desc = "Frequency → 523 Hz (C5)", fn = function(s) s:set_param(10, 0, 523.25) end},
    {delay = 2.0, desc = "Gain → 0.6 (louder)",     fn = function(s) s:set_param(11, 0, 0.6) end},
    {delay = 2.0, desc = "Volume → 0.4 (softer)",   fn = function(s) s:set_track_volume(1, 0.4) end},
    {delay = 2.0, desc = "Frequency → 880 Hz (A5)", fn = function(s) s:set_param(10, 0, 880) end},
    {delay = 2.0, desc = "Undo (back to 880→523)",   fn = function(s) s:undo() end},
    {delay = 2.0, desc = "Undo (back to 523→330)",   fn = function(s) s:undo() end},
    {delay = 2.0, desc = "Redo (forward to 523)",    fn = function(s) s:redo() end},
    {delay = 2.0, desc = "Done — silence",           fn = function(s) s:set_track_volume(1, 0.0) end},
}

local BS = 512
local bytes_per_buf = BS * 2 * 4  -- stereo float32

-- Keep audio buffer fed
local function pump_audio(duration_sec)
    local frames = math.ceil(duration_sec * 44100 / BS)
    for i = 1, frames do
        -- Only push if the queue is getting low
        local queued = s.audio:queued_bytes()
        if queued < bytes_per_buf * 4 then
            s.audio:render_and_push()
        end
        -- Small sleep to avoid busy-waiting (~11.6ms per buffer at 44100/512)
        C.usleep(5000)  -- 5ms
    end
end

-- Initial audio fill
for i = 1, 8 do
    s.audio:render_and_push()
end

-- Run through changes
for _, change in ipairs(changes) do
    pump_audio(change.delay)
    print("  → " .. change.desc)
    change.fn(s)
end

-- Final buffer drain
pump_audio(1.0)

print("")
print("Stopping audio...")
s:stop()
s:close()
print("  ✓ Audio shutdown complete")
print("")
print("═══════════════════════════════════════════════")
print("  Demo complete! You should have heard:")
print("  440 Hz → 330 Hz → 523 Hz → louder → softer")
print("  → 880 Hz → undo × 2 → redo → silence")
print("═══════════════════════════════════════════════")
