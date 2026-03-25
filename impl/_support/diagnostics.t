-- impl/_support/diagnostics.t
-- Shared diagnostics API for all phase transitions.
--
-- Every phase method should use diag.wrap() to get local error boundaries:
-- on success, return the result; on failure, record a diagnostic and
-- return a valid degraded fallback.
--
-- The status parameter in wrap() is the SINGLE declaration of implementation
-- maturity.  tools/progress.t reads it.  The ASDL schemas are the single
-- source of truth for WHAT methods should exist; wrap() is the single
-- source of truth for HOW DONE each one is.

local List = require("terralist")

local M = {}

-- ═══════════════════════════════════════════════════════════
-- Method status tracking
-- ═══════════════════════════════════════════════════════════
-- Populated automatically by diag.wrap() and diag.status().
-- code → "stub" | "partial" | "real"

M.method_status = {}
M.method_calls  = {}   -- code → { calls, successes, fallbacks }

-- Register a method's status without wrap (for methods that don't use
-- the wrap pattern, e.g. Kernel.Project:entry_fn).
function M.status(code, status)
    M.method_status[code] = status
end

-- ═══════════════════════════════════════════════════════════
-- ASDL list helper
-- ═══════════════════════════════════════════════════════════

function M.L(t)
    if t == nil then return List() end
    if List:isclassof(t) then return t end
    local l = List()
    for i = 1, #t do l:insert(t[i]) end
    return l
end

-- ═══════════════════════════════════════════════════════════
-- Diagnostics recording
-- ═══════════════════════════════════════════════════════════

function M.record(ctx, severity, code, message)
    if ctx == nil then return end
    ctx.diagnostics = ctx.diagnostics or {}
    ctx.diagnostics[#ctx.diagnostics + 1] = {
        phase    = code and code:match("^(%w+)%.") or "unknown",
        severity = severity,
        code     = code,
        message  = tostring(message),
    }
end

-- ═══════════════════════════════════════════════════════════
-- Error-boundary wrapper
-- ═══════════════════════════════════════════════════════════
--
--   diag.wrap(ctx, "editor.track.lower", "partial", function()
--       return output
--   end, function()
--       return fallback_output
--   end)
--
-- status: "stub"    = returns valid but minimal/degraded output
--         "partial" = does real work but incomplete
--         "real"    = fully implemented

function M.wrap(ctx, code, impl_status, body_fn, fallback_fn)
    -- Auto-register status
    M.method_status[code] = impl_status

    -- Track this call
    local entry = M.method_calls[code]
    if not entry then
        entry = { calls = 0, successes = 0, fallbacks = 0 }
        M.method_calls[code] = entry
    end
    entry.calls = entry.calls + 1

    local ok, result = pcall(body_fn)
    if ok and result ~= nil then
        entry.successes = entry.successes + 1
        return result
    end

    -- Record the failure
    entry.fallbacks = entry.fallbacks + 1
    local msg = ok and "returned nil" or tostring(result)
    M.record(ctx, "warning", code .. ".fallback", msg)

    -- Try the fallback.  Pass the error message so View fallbacks can
    -- display it in their placeholder panels.
    local fok, fallback = pcall(fallback_fn, msg)
    if fok and fallback ~= nil then
        return fallback
    end

    -- Fallback itself failed
    local fmsg = fok and "fallback returned nil" or tostring(fallback)
    M.record(ctx, "error", code .. ".fallback_failed", fmsg)
    error("critical: both body and fallback failed for " .. code
        .. ": " .. msg .. " / " .. fmsg)
end

-- ═══════════════════════════════════════════════════════════
-- List mapping with per-item error protection
-- ═══════════════════════════════════════════════════════════

function M.map(ctx, code, items, fn)
    local results = List()
    if items == nil then return results end
    for i = 1, #items do
        local ok, result = pcall(fn, items[i])
        if ok and result ~= nil then
            results:insert(result)
        else
            local msg = ok and "returned nil" or tostring(result)
            M.record(ctx, "warning", code .. ".item_" .. tostring(i),
                "item " .. tostring(i) .. " failed: " .. msg)
        end
    end
    return results
end

function M.map_or(ctx, code, items, fn, fallback_fn)
    local results = List()
    if items == nil then return results end
    for i = 1, #items do
        local ok, result = pcall(fn, items[i])
        if ok and result ~= nil then
            results:insert(result)
        else
            local msg = ok and "returned nil" or tostring(result)
            M.record(ctx, "warning", code .. ".item_" .. tostring(i),
                "item " .. tostring(i) .. " failed: " .. msg)
            local fok, fb = pcall(fallback_fn, items[i], i)
            if fok and fb ~= nil then
                results:insert(fb)
            end
        end
    end
    return results
end

return M
