-- app/audio.t
-- SDL3 audio output for Terra DAW.
--
-- Provides:
--   audio.open(sample_rate, buffer_size) → session
--   session:set_kernel(kernel)        — eagerly compile + publish a new engine image
--   session:set_kernel_thunk(thunk)   — lazy source of the current compiled kernel
--   session:start()                   — unpause audio
--   session:stop()                    — pause audio
--   session:close()                   — shutdown
--
-- Runtime shape:
--   - each audio session owns a terralib.global pointer to an EngineImage
--   - one stable Terra dispatcher is compiled once per audio session
--   - hot-swap publishes a new { fn_ptr, state_ptr } bundle into that global
--   - render_and_push always calls the stable dispatcher

local C = terralib.includecstring([[
#include <SDL3/SDL.h>
#include <string.h>
#include <stdio.h>
]], {"-I/usr/include"})
terralib.linklibrary("libSDL3.so")

local M = {}
local RenderFnPtr = terralib.types.funcpointer({&float, &float, int32, &uint8}, {})

-- Audio session state (Lua-level orchestration only; the hot path stays in Terra).
function M.open(sample_rate, buffer_size)
    local EngineImage = terralib.types.newstruct("AudioEngineImage")
    EngineImage.entries:insert({ field = "fn_ptr", type = RenderFnPtr })
    EngineImage.entries:insert({ field = "state_ptr", type = &uint8 })

    local current_image_ptr = global(&EngineImage)

    local terra noop_render(output_left: &float, output_right: &float, frames: int32, state_raw: &uint8)
        for i = 0, frames - 1 do
            output_left[i] = 0.0f
            output_right[i] = 0.0f
        end
    end
    noop_render:compile()

    local default_image = terralib.new(EngineImage)
    default_image.fn_ptr = noop_render:getpointer()
    default_image.state_ptr = terralib.cast(&uint8, 0)
    current_image_ptr:set(default_image)

    local terra dispatch_render(output_left: &float, output_right: &float, frames: int32)
        var image = current_image_ptr
        if image ~= nil then
            image.fn_ptr(output_left, output_right, frames, image.state_ptr)
        else
            noop_render(output_left, output_right, frames, [&uint8](0))
        end
    end
    dispatch_render:compile()

    local session = {
        sample_rate = sample_rate or 44100,
        buffer_size = buffer_size or 512,
        stream = nil,
        render_fn = dispatch_render,
        _published_kernel = nil,
        _kernel_thunk = nil,
        _current_image_ptr = current_image_ptr,
        _current_image = default_image,
        _current_state = nil,
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
    local DEFAULT_PLAYBACK = 4294967295
    session.stream = C.SDL_OpenAudioDeviceStream(
        DEFAULT_PLAYBACK,
        spec,
        nil,
        nil
    )

    if session.stream == nil then
        error("SDL_OpenAudioDeviceStream failed: " .. tostring(terralib.new(rawstring, C.SDL_GetError())))
    end

    local function nil_state_ptr()
        return terralib.cast(&uint8, 0)
    end

    function session:set_kernel(kernel)
        if kernel == nil then return self end
        if kernel == self._published_kernel then return self end

        local fn = kernel:entry_fn()
        local state_t = kernel:state_type()
        local init_fn = kernel:state_init_fn()

        fn:compile()
        init_fn:compile()

        local state = nil
        local state_ptr = nil_state_ptr()
        if state_t ~= tuple() then
            state = terralib.new(state_t)
            state_ptr = terralib.cast(&uint8, state)
            init_fn(state_ptr)
        end

        local image = terralib.new(EngineImage)
        image.fn_ptr = fn:getpointer()
        image.state_ptr = state_ptr

        self._current_image_ptr:set(image)
        self._current_image = image
        self._current_state = state
        self._published_kernel = kernel
        return self
    end

    function session:set_kernel_thunk(thunk)
        self._kernel_thunk = thunk
        return self
    end

    function session:render_and_push()
        if self._kernel_thunk then
            self:set_kernel(self._kernel_thunk())
        end
        local BS = self.buffer_size
        local left = self._left_buf
        local right = self._right_buf
        local interleaved = self._interleaved

        -- Call the stable Terra dispatcher. Only the engine-image pointer swaps.
        self.render_fn(left, right, BS)

        for i = 0, BS - 1 do
            interleaved[i * 2] = left[i]
            interleaved[i * 2 + 1] = right[i]
        end

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
