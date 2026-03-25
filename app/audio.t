-- app/audio.t
-- SDL3 audio output for Terra DAW.
--
-- Provides:
--   audio.open(sample_rate, buffer_size) → session
--   session:set_render_fn(fn)  — swap the compiled render function
--   session:start()            — unpause audio
--   session:stop()             — pause audio
--   session:close()            — shutdown
--
-- The render function signature must be:
--   terra(output_left: &float, output_right: &float, frames: int32)

local C = terralib.includecstring([[
#include <SDL3/SDL.h>
#include <string.h>
#include <stdio.h>
]], {"-I/usr/include"})
terralib.linklibrary("libSDL3.so")

local M = {}

-- Audio session state (Lua-level, holds the Terra callback closure)
function M.open(sample_rate, buffer_size)
    local session = {
        sample_rate = sample_rate or 44100,
        buffer_size = buffer_size or 512,
        stream = nil,
        render_fn = nil,
        _left_buf = nil,
        _right_buf = nil,
        _interleaved = nil,
    }

    -- Allocate persistent buffers
    local BS = session.buffer_size
    session._left_buf = terralib.new(float[BS])
    session._right_buf = terralib.new(float[BS])
    session._interleaved = terralib.new(float[BS * 2])

    -- Initialize SDL audio subsystem
    local ok = C.SDL_Init(C.SDL_INIT_AUDIO)
    if not ok then
        error("SDL_Init(AUDIO) failed: " .. tostring(terralib.new(rawstring, C.SDL_GetError())))
    end

    -- Audio spec: stereo float32
    local spec = terralib.new(C.SDL_AudioSpec)
    spec.freq = session.sample_rate
    spec.format = C.SDL_AUDIO_F32
    spec.channels = 2

    -- We'll use a push model: no callback, we push data in the main loop.
    -- This is simpler and avoids cross-thread issues with Lua state.
    -- SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK = 0xFFFFFFFF (uint32)
    local DEFAULT_PLAYBACK = 4294967295
    session.stream = C.SDL_OpenAudioDeviceStream(
        DEFAULT_PLAYBACK,
        spec,
        nil,  -- no callback
        nil   -- no userdata
    )

    if session.stream == nil then
        error("SDL_OpenAudioDeviceStream failed: " .. tostring(terralib.new(rawstring, C.SDL_GetError())))
    end

    -- Methods
    function session:set_render_fn(fn)
        self.render_fn = fn
    end

    function session:render_and_push()
        if self.render_fn == nil then return end
        local BS = self.buffer_size
        local left = self._left_buf
        local right = self._right_buf
        local interleaved = self._interleaved

        -- Call the compiled render function
        self.render_fn(left, right, BS)

        -- Interleave L/R for SDL (LRLRLR...)
        for i = 0, BS - 1 do
            interleaved[i * 2] = left[i]
            interleaved[i * 2 + 1] = right[i]
        end

        -- Push to SDL stream
        C.SDL_PutAudioStreamData(self.stream, interleaved, BS * 2 * 4)
    end

    function session:start()
        C.SDL_ResumeAudioStreamDevice(self.stream)
    end

    function session:stop()
        C.SDL_PauseAudioStreamDevice(self.stream)
    end

    function session:close()
        if self.stream ~= nil then
            C.SDL_DestroyAudioStream(self.stream)
            self.stream = nil
        end
        C.SDL_Quit()
    end

    function session:queued_bytes()
        if self.stream == nil then return 0 end
        return C.SDL_GetAudioStreamQueued(self.stream)
    end

    return session
end

return M
