-- tools/asdl_methods.t
-- Parse ASDL schema files to extract the canonical method inventory.
-- This is the SINGLE SOURCE OF TRUTH for what methods should exist.
--
-- Returns a list of:
--   { module, type_name, method_name, returns, code, signature }

local M = {}

-- PascalCase → snake_case
function M.snake(s)
    if s == nil then return "" end
    -- Insert _ before each uppercase letter that follows a lowercase or is
    -- a capital run followed by lowercase (e.g. "HWFXNode" → "hwfx_node")
    local out = s:gsub("(%u+)(%u%l)", "%1_%2")
                 :gsub("(%l)(%u)", "%1_%2")
                 :lower()
    return out
end

-- Derive the canonical diag code from module + type + method
function M.make_code(module_name, type_name, method_name)
    return M.snake(module_name) .. "." .. M.snake(type_name) .. "." .. method_name
end

-- Parse one .asdl.module.txt file, return list of method entries
function M.parse_file(path)
    local f = io.open(path, "r")
    if not f then error("cannot open: " .. path) end
    local text = f:read("*a")
    f:close()

    local results = {}
    local module_name = nil
    local current_type = nil
    local in_methods = false

    for line in text:gmatch("([^\n]*)\n?") do
        -- Detect module
        local mod = line:match("^%s*module%s+(%w+)%s*{")
        if mod then module_name = mod end

        -- Detect type definition (product or sum)
        -- Match: "    TypeName = ..." or "    TypeName" at start of sum
        local tname = line:match("^%s%s%s%s(%u%w+)%s*=")
            or line:match("^%s%s%s%s(%u%w+)%s*$")
        if tname then current_type = tname end

        -- Detect methods block
        if line:match("^%s*methods%s*{") then
            in_methods = true
        elseif in_methods then
            if line:match("^%s*}%s*$") then
                in_methods = false
            else
                -- Parse method signature:  name(args) -> ReturnType
                local mname, sig_rest = line:match("^%s+([%w_]+)(%b().*)")
                if mname and sig_rest then
                    local returns = sig_rest:match("->%s*(.+)%s*$") or "?"
                    returns = returns:gsub("%s+$", "")
                    local full_sig = mname .. sig_rest:gsub("%s+$", "")
                    local code = M.make_code(module_name, current_type, mname)
                    results[#results + 1] = {
                        module      = module_name,
                        type_name   = current_type,
                        method_name = mname,
                        returns     = returns,
                        code        = code,
                        signature   = full_sig,
                    }
                end
            end
        end
    end

    return results
end

-- Parse all schema files, return the full canonical method inventory
function M.parse_all(schema_dir)
    local modules = {
        "Editor", "View", "Authored", "Resolved",
        "Classified", "Scheduled", "Kernel",
    }
    local all = {}
    for _, name in ipairs(modules) do
        local path = schema_dir .. "/" .. name .. ".asdl.module.txt"
        local ok, methods = pcall(M.parse_file, path)
        if ok then
            for _, m in ipairs(methods) do
                all[#all + 1] = m
            end
        end
    end
    return all
end

return M
