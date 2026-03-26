-- main.t
-- Terra DAW app entrypoint: SDL window + TerraUI shell slice.

terralib.linklibrary("/lib64/libSDL3.so")
terralib.linklibrary("/lib64/libSDL3_ttf.so")
terralib.linklibrary("/lib64/libGL.so")

local function dirname(path)
    local dir = path:match("^(.*)/[^/]*$")
    return dir or "."
end

local function script_dir()
    local src = debug.getinfo(1, "S").source
    assert(type(src) == "string" and src:sub(1, 1) == "@", "unable to resolve main.t path")
    return dirname(src:sub(2))
end

local root = script_dir()
local terraui_root = root .. "/terraui"

local root_terra_pat = root .. "/?.t"
local terraui_terra_pat = terraui_root .. "/?.t"
if not package.terrapath:find(root, 1, true) then
    package.terrapath = root_terra_pat .. ";" .. terraui_terra_pat .. ";" .. package.terrapath
elseif not package.terrapath:find(terraui_root, 1, true) then
    package.terrapath = terraui_terra_pat .. ";" .. package.terrapath
end

local root_lua_pat = root .. "/?.lua;" .. root .. "/?/init.lua"
local terraui_lua_pat = terraui_root .. "/?.lua;" .. terraui_root .. "/?/init.lua"
if not package.path:find(root, 1, true) then
    package.path = root_lua_pat .. ";" .. terraui_lua_pat .. ";" .. package.path
elseif not package.path:find(terraui_root, 1, true) then
    package.path = terraui_lua_pat .. ";" .. package.path
end

local function sh(cmd)
    local p = assert(io.popen(cmd, "r"))
    local out = p:read("*a") or ""
    p:close()
    return out
end

local font_path = (sh("fc-match -f '%{file}\n' monospace | head -1"):gsub("%s+$", ""))
assert(#font_path > 0, "could not resolve font path via fc-match")

local max_frames = -1
local hidden = false
if arg and #arg >= 1 then
    max_frames = tonumber(arg[1]) or -1
end
if arg and #arg >= 2 and arg[2] == "hidden" then
    hidden = true
end

local bootstrap = require("app/bootstrap")
local terraui = require("lib/terraui")
local bind = require("lib/bind")
local plan = require("lib/plan")
local compile = require("lib/compile")

local sdl = terraui.sdl_gl_backend.new(font_path)
local root_view = bootstrap.bootstrap_root()

local decl = root_view:to_decl()

local bound = bind.bind_component(decl, { text_backend = sdl.text_backend })
local planned = plan.plan_component(bound)
local kernel = compile.compile_component(planned, { text_backend = sdl.text_backend })
local Frame = kernel:frame_type()
local init_q = kernel.kernels.init_fn
local run_q = kernel.kernels.run_fn

local max_packets = #planned.paints + #planned.texts + #planned.images + (#planned.clips * 2) + #planned.customs
if max_packets < 1 then max_packets = 1 end
local max_scissors = #planned.clips
if max_scissors < 1 then max_scissors = 1 end

struct App {
    backend: sdl.Session
    status_left: rawstring
    status_center: rawstring
    status_right: rawstring
    mode_arrange: float
    mode_mix: float
    mode_edit: float
}

terra set_mode(app: &App, arrange: float, mix: float, edit: float, label: rawstring)
    app.mode_arrange = arrange
    app.mode_mix = mix
    app.mode_edit = edit
    app.status_right = label
end

terra app_init(app: &App, hidden_window: bool) : int
    var rc = sdl.init(&app.backend, "Terra DAW", 1440, 900, hidden_window)
    if rc ~= 0 then return rc end
    app.status_left = "shell online"
    app.status_center = "Bitwig-like shell grammar: Arrange / Mix / Edit"
    set_mode(app, 1.0f, 0.0f, 0.0f, "Arrange mode")
    return 0
end

terra app_shutdown(app: &App)
    sdl.shutdown(&app.backend)
end

terra sync_params(frame: &Frame, app: &App)
    frame.text_backend_state = [&opaque](&app.backend.text)
    frame.params.p0 = app.status_left
    frame.params.p1 = app.status_center
    frame.params.p2 = app.status_right
    frame.params.p3 = app.mode_arrange
    frame.params.p4 = app.mode_mix
    frame.params.p5 = app.mode_edit
end

terra maybe_handle_action(app: &App, frame: &Frame)
    if frame.action_name == nil then return end
    if sdl.C.strcmp(frame.action_name, "app.mode.arrange") == 0 then
        set_mode(app, 1.0f, 0.0f, 0.0f, "Arrange mode")
        app.status_left = "app.mode.arrange"
    elseif sdl.C.strcmp(frame.action_name, "app.mode.mix") == 0 then
        set_mode(app, 0.0f, 1.0f, 0.0f, "Mix mode")
        app.status_left = "app.mode.mix"
    elseif sdl.C.strcmp(frame.action_name, "app.mode.edit") == 0 then
        set_mode(app, 0.0f, 0.0f, 1.0f, "Edit mode")
        app.status_left = "app.mode.edit"
    else
        app.status_left = frame.action_name
        app.status_right = "command routed from TerraUI"
    end
    sdl.C.printf("[terra-daw] action: %s\n", frame.action_name)
end

terra draw_image(_app: &App, _cmd: compile.ImageCmd)
end

local custom_draw = require("app/custom_draw_sdl_gl")
local draw_icon = custom_draw.make_draw_custom({
    quad = sdl.gl_quad,
    color = sdl.gl_color,
    C = sdl.C,
})

terra draw_custom(_app: &App, cmd: compile.CustomCmd)
    draw_icon(cmd)
end

local replay = sdl.make_replay(Frame, max_packets, max_scissors, App, draw_image, draw_custom)

terra run_app(max_frames_arg: int32, hidden_window: bool) : int
    var app: App
    var rc = app_init(&app, hidden_window)
    if rc ~= 0 then return rc end

    var frame: Frame
    [init_q](&frame)

    var quit = false
    var frames: int32 = 0
    while not quit and (max_frames_arg < 0 or frames < max_frames_arg) do
        sdl.pump_input(&app.backend, &frame.input, &frame.viewport_w, &frame.viewport_h, &quit)
        sync_params(&frame, &app)
        [run_q](&frame)
        maybe_handle_action(&app, &frame)
        sync_params(&frame, &app)
        replay(&app.backend, nil, &frame)
        sdl.swap_window(&app.backend)
        frames = frames + 1
    end

    app_shutdown(&app)
    return 0
end

local rc = run_app(max_frames, hidden)
assert(rc == 0, string.format("main exited with code %d", tonumber(rc)))
