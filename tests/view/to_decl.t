-- tests/view/to_decl.t
-- Per-method tests for all 12 View → TerraUI to_decl methods.
-- Uses TerraUI's real DSL + real ASDL View types from the schema.

-- Add terraui/lib to require path
package.terrapath = (package.terrapath or "") .. ";./terraui/?.t"

local D = require("daw-unified")
require("impl/init")
local F = require("impl/_support/fallbacks")
local L = F.L
local pass, fail = 0, 0
local function check(c, m) if c then pass=pass+1 else fail=fail+1; print("  FAIL: "..m) end end

local V = D.View

-- ── Helper ──
local function id(key) return V.Identity(key or "test", V.IdentitySemantic(V.ProjectRef)) end
local function id_k(key, ref) return V.Identity(key, V.IdentitySemantic(ref)) end

local function test_view(idx, name, build_fn)
    io.write(string.format("%2d. %s", idx, name))
    local ok, view_obj = pcall(build_fn)
    if not ok then
        check(false, name .. " construct: " .. tostring(view_obj))
        print("  FAIL (construct)")
        return
    end
    local ok2, result = pcall(function() return view_obj:to_decl() end)
    if ok2 and result ~= nil then
        check(true, name)
        print("  PASS")
    else
        check(false, name .. " to_decl: " .. tostring(result))
        print("  FAIL")
    end
end

-- ═══ Tests ═══

-- 1. TransportBar (show_tempo, show_time_sig, show_loop, show_quantize, identity, anchors, commands)
test_view(1, "view.transport_bar.to_decl", function()
    return V.TransportBar(true, true, true, true, id("tb"), L(), L())
end)

-- 2. ArrangementView (visible_track_refs, identity, anchors, commands, ruler, grid, playhead, loop, selection, lanes)
test_view(2, "view.arrangement_view.to_decl", function()
    return V.ArrangementView(L(), id("arr"), L(), L(),
        nil, nil, nil, nil, nil, L())
end)

-- 3. PianoRollView (clip_ref, identity, anchors, commands, keyboard, grid, playhead, loop, selection, notes, velocity, expr_lanes)
test_view(3, "view.piano_roll_view.to_decl", function()
    return V.PianoRollView(V.ClipRef(1), id_k("pr", V.ClipRef(1)),
        L(), L(),
        V.PianoKeyboardView(21, 108, id("kb"), L(), L(), L()),
        V.PianoGridView(0, 16, 21, 108, id("grid"), L(), L()),
        nil, nil, nil, L(), nil, L())
end)

-- 4. LauncherView (visible_track_refs, visible_scene_refs, identity, anchors, commands, scenes, stop_row, columns)
test_view(4, "view.launcher_view.to_decl", function()
    return V.LauncherView(L(), L(), id("lv"), L(), L(), L(), nil, L())
end)

-- 5. MixerView (visible_track_refs, identity, anchors, commands, strips)
test_view(5, "view.mixer_view.to_decl", function()
    return V.MixerView(L(), id("mx"), L(), L(), L())
end)

-- 6. DeviceChainView (chain_ref, identity, anchors, commands, entries)
test_view(6, "view.device_chain_view.to_decl", function()
    return V.DeviceChainView(V.TrackChain(1), id("dc"), L(), L(), L())
end)

-- 7. DeviceView (NativeDeviceView: device_ref, identity, anchors, commands, sections)
test_view(7, "view.device_view.to_decl", function()
    return V.NativeDeviceView(V.DeviceRef(10),
        id_k("dv", V.DeviceRef(10)), L(), L(), L())
end)

-- 8. GridPatchView (device_ref, identity, anchors, commands, modules, cables)
test_view(8, "view.grid_patch_view.to_decl", function()
    return V.GridPatchView(V.DeviceRef(10), id_k("gp", V.DeviceRef(10)),
        L(), L(), L(), L())
end)

-- 9. InspectorView (selection, identity, anchors, commands, tabs)
test_view(9, "view.inspector_view.to_decl", function()
    return V.InspectorView(V.NoSelection, id("insp"), L(), L(), L())
end)

-- 10. BrowserView (source_kind, query, identity, anchors, commands, sources, query_bar, sections)
test_view(10, "view.browser_view.to_decl", function()
    return V.BrowserView("all", nil, id("br"), L(), L(), L(), nil, L())
end)

-- 11. Shell (transport, main_area, sidebars, status_bar)
test_view(11, "view.shell.to_decl", function()
    local tb = V.TransportBar(true, true, true, true, id("tb"), L(), L())
    local arr = V.ArrangementView(L(), id("arr"), L(), L(), nil, nil, nil, nil, nil, L())
    local main = V.ArrangementMain(arr, nil)
    return V.Shell(tb, main, L(), nil)
end)

-- 12. Root (shell, focus, session_state)
test_view(12, "view.root.to_decl", function()
    local tb = V.TransportBar(true, true, true, true, id("tb"), L(), L())
    local arr = V.ArrangementView(L(), id("arr"), L(), L(), nil, nil, nil, nil, nil, L())
    local main = V.ArrangementMain(arr, nil)
    local shell = V.Shell(tb, main, L(), nil)
    local focus = V.Focus(V.NoSelection, V.ArrangementSurface)
    return V.Root(shell, focus, L())
end)

print("")
print(string.format("View to_decl: %d pass, %d fail (%d total)", pass, fail, pass+fail))
if fail > 0 then os.exit(1) end
