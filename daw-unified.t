-- daw-unified.t
-- Terra DAW v3: Unified Model.
--
-- This loader assembles the schema from per-module `.asdl.module.txt` files,
-- strips ASDL-incompatible inline metadata (`--` comments and `methods {}`
-- blocks), defines the ASDL context, and returns it.

local asdl = require 'asdl'
local D = asdl.NewContext()

D:Extern("TerraType",    terralib.types.istype)
D:Extern("TerraQuote",   terralib.isquote)
D:Extern("TerraFunc",    terralib.isfunction)
D:Extern("PluginHandle", function(o) return type(o) == "userdata" end)

D:Extern("ViewCtx",      function(o) return type(o) == "table" end)
D:Extern("TerraUIDecl",  function(o) return type(o) == "table" end)
D:Extern("LowerCtx",     function(o) return type(o) == "table" end)
D:Extern("ResolveCtx",   function(o) return type(o) == "table" end)
D:Extern("ClassifyCtx",  function(o) return type(o) == "table" end)
D:Extern("ScheduleCtx",  function(o) return type(o) == "table" end)
D:Extern("CompileCtx",   function(o) return type(o) == "table" end)

local function dirname(path)
    local dir = path:match("^(.*)/[^/]*$")
    return dir or "."
end

local function script_dir()
    local src = debug.getinfo(1, "S").source
    assert(type(src) == "string" and src:sub(1, 1) == "@",
           "unable to resolve loader path")
    return dirname(src:sub(2))
end

local function read_file(path)
    local f, err = io.open(path, "r")
    if not f then error("failed to open schema file '" .. path .. "': " .. tostring(err)) end
    local s = f:read("*a")
    f:close()
    return s
end

local function strip_asdl_meta(s)
    local out = {}
    local in_methods = false

    for line in s:gmatch("([^\n]*)\n?") do
        if in_methods then
            if line:match("^%s*}%s*$") then
                in_methods = false
                out[#out + 1] = ""
            end
        elseif line:match("^%s*methods%s*{%s*$") then
            in_methods = true
            out[#out + 1] = ""
        elseif line:match("^%s*%-%-") then
            out[#out + 1] = ""
        elseif line == "" and #out > 0 and out[#out] == "" then
            -- keep blank-line runs compact after stripping comments/methods
        else
            out[#out + 1] = line
        end
    end

    return table.concat(out, "\n")
end

local function load_schema_modules(base_dir, module_names)
    local chunks = {}
    for i = 1, #module_names do
        local name = module_names[i]
        local path = base_dir .. "/schema/" .. name .. ".asdl.module.txt"
        chunks[#chunks + 1] = read_file(path)
    end
    return table.concat(chunks, "\n\n")
end

local module_order = {
    "Editor",
    "View",
    "Authored",
    "Resolved",
    "Classified",
    "Scheduled",
    "Kernel",
}

local schema = load_schema_modules(script_dir(), module_order)
D:Define(strip_asdl_meta(schema))

return D
