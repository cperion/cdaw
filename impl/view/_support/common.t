-- impl/view/_support/common.t
-- Shared helpers for View -> TerraUI lowering.

local List = require("terralist")

local M = {}

function M.push(t, v)
    t[#t + 1] = v
    return v
end

function M.list(...)
    local l = List()
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then l:insert(v) end
    end
    return l
end

function M.kind_eq(a, b)
    if a == nil or b == nil then return false end
    if a == b then return true end
    return a.kind == b.kind
end

function M.find_command(commands, wanted_kind, pred)
    if commands == nil then return nil end
    for i = 1, #commands do
        local cmd = commands[i]
        if M.kind_eq(cmd.kind, wanted_kind) and (pred == nil or pred(cmd)) then
            return cmd
        end
    end
    return nil
end

function M.record_diag(ctx, severity, code, message)
    if ctx == nil then return end
    ctx.diagnostics = ctx.diagnostics or {}
    M.push(ctx.diagnostics, {
        phase = "view",
        severity = severity,
        code = code,
        message = message,
    })
end

function M.encode_semantic_ref(ref)
    if ref == nil then return "unknown" end
    local k = ref.kind
    if k == "ProjectRef" then
        return "project"
    elseif k == "TrackRef" then
        return "track/" .. tostring(ref.track_id)
    elseif k == "DeviceRef" then
        return "device/" .. tostring(ref.device_id)
    elseif k == "LayerRef" then
        return "layer/" .. tostring(ref.container_id) .. "/" .. tostring(ref.layer_id)
    elseif k == "SelectorBranchRef" then
        return "selector_branch/" .. tostring(ref.container_id) .. "/" .. tostring(ref.branch_id)
    elseif k == "SplitBandRef" then
        return "split_band/" .. tostring(ref.container_id) .. "/" .. tostring(ref.band_id)
    elseif k == "GridModuleRef" then
        return "grid_module/" .. tostring(ref.device_id) .. "/" .. tostring(ref.module_id)
    elseif k == "ClipRef" then
        return "clip/" .. tostring(ref.clip_id)
    elseif k == "NoteRef" then
        return "note/" .. tostring(ref.clip_id) .. "/" .. tostring(ref.note_id)
    elseif k == "SceneRef" then
        return "scene/" .. tostring(ref.scene_id)
    elseif k == "SlotRef" then
        return "slot/" .. tostring(ref.track_id) .. "/" .. tostring(ref.slot_index)
    elseif k == "SendRef" then
        return "send/" .. tostring(ref.track_id) .. "/" .. tostring(ref.send_id)
    elseif k == "ParamRef" then
        local owner = ref.owner_ref
        local owner_part = "owner"
        if owner.kind == "TrackOwner" then
            owner_part = "track/" .. tostring(owner.track_id)
        elseif owner.kind == "DeviceOwner" then
            owner_part = "device/" .. tostring(owner.device_id)
        elseif owner.kind == "GridModuleOwner" then
            owner_part = "grid_module/" .. tostring(owner.device_id) .. "/" .. tostring(owner.module_id)
        elseif owner.kind == "ModulatorOwner" then
            owner_part = "modulator/" .. tostring(owner.device_id) .. "/" .. tostring(owner.modulator_id)
        elseif owner.kind == "LayerOwner" then
            owner_part = "layer/" .. tostring(owner.container_id) .. "/" .. tostring(owner.layer_id)
        elseif owner.kind == "SendOwner" then
            owner_part = "send/" .. tostring(owner.track_id) .. "/" .. tostring(owner.send_id)
        elseif owner.kind == "ClipOwner" then
            owner_part = "clip/" .. tostring(owner.clip_id)
        end
        return "param/" .. owner_part .. "/" .. tostring(ref.param_id)
    elseif k == "ModulatorRef" then
        return "modulator/" .. tostring(ref.device_id) .. "/" .. tostring(ref.modulator_id)
    end
    return string.lower(k)
end

function M.encode_chain_ref(ref)
    if ref == nil then return "chain" end
    local k = ref.kind
    if k == "TrackChain" then
        return "track_chain/" .. tostring(ref.track_id)
    elseif k == "DeviceNoteFX" then
        return "device_note_fx/" .. tostring(ref.device_id)
    elseif k == "DevicePostFX" then
        return "device_post_fx/" .. tostring(ref.device_id)
    elseif k == "LayerChain" then
        return "layer_chain/" .. tostring(ref.container_id) .. "/" .. tostring(ref.layer_id)
    elseif k == "SelectorBranchChain" then
        return "selector_chain/" .. tostring(ref.container_id) .. "/" .. tostring(ref.branch_id)
    elseif k == "SplitBandChain" then
        return "split_chain/" .. tostring(ref.container_id) .. "/" .. tostring(ref.band_id)
    end
    return string.lower(k)
end

function M.identity_key(identity)
    if identity == nil then return "view/missing_identity" end
    local ref = identity.ref
    local encoded = "missing_ref"
    if ref ~= nil then
        if ref.kind == "IdentitySemantic" then
            encoded = M.encode_semantic_ref(ref.semantic_ref)
        elseif ref.kind == "IdentityChain" then
            encoded = M.encode_chain_ref(ref.chain_ref)
        elseif ref.kind == "IdentityKey" then
            encoded = ref.stable_key
        else
            encoded = string.lower(ref.kind)
        end
    end
    return tostring(identity.key_space) .. "/" .. encoded
end

function M.make_scope(ctx, identity, fallback_key)
    return ctx.ui.scope(identity and M.identity_key(identity) or fallback_key)
end

function M.palette(ctx)
    return ctx.palette
end

function M.border(ctx, color, strength)
    strength = strength or 1
    return ctx.ui.border {
        left = strength,
        top = strength,
        right = strength,
        bottom = strength,
        color = color,
    }
end

function M.panel(ctx, props)
    props = props or {}
    local p = M.palette(ctx)
    props.background = props.background or p.surface_panel
    props.border = props.border or M.border(ctx, p.border_subtle, 1)
    props.padding = props.padding or { left = 8, top = 6, right = 8, bottom = 6 }
    props.gap = props.gap or 6
    return props
end

function M.track_name(ctx, track_ref)
    return (ctx.track_names and ctx.track_names[track_ref.track_id]) or ("Track " .. tostring(track_ref.track_id))
end

function M.clip_layout(ctx, clip_ref)
    return ctx.clip_layout and ctx.clip_layout[clip_ref.clip_id]
end

function M.clip_label(ctx, clip_ref)
    local info = M.clip_layout(ctx, clip_ref)
    return (info and info.label) or ("Clip " .. tostring(clip_ref.clip_id))
end

function M.device_name(ctx, device_ref)
    return (ctx.device_names and ctx.device_names[device_ref.device_id]) or ("Device " .. tostring(device_ref.device_id))
end

function M.semantic_ref_eq(a, b)
    if a == nil or b == nil then return false end
    if a == b then return true end
    return M.encode_semantic_ref(a) == M.encode_semantic_ref(b)
end

function M.selection_is_track(selection, track_ref)
    return selection ~= nil
        and selection.kind == "SelectedTrack"
        and M.semantic_ref_eq(selection.track_ref, track_ref)
end

function M.selection_is_clip(selection, clip_ref)
    return selection ~= nil
        and selection.kind == "SelectedClip"
        and M.semantic_ref_eq(selection.clip_ref, clip_ref)
end

function M.selection_is_scene(selection, scene_ref)
    return selection ~= nil
        and selection.kind == "SelectedScene"
        and M.semantic_ref_eq(selection.scene_ref, scene_ref)
end

function M.selection_is_slot(selection, slot_ref)
    return selection ~= nil
        and selection.kind == "SelectedSlot"
        and M.semantic_ref_eq(selection.slot_ref, slot_ref)
end

function M.selection_is_device(selection, device_ref)
    return selection ~= nil
        and selection.kind == "SelectedDevice"
        and M.semantic_ref_eq(selection.device_ref, device_ref)
end

function M.surface_mode(ctx)
    local active = ctx and ctx.active_surface
    if active == nil then return "arrange" end
    if active.kind == "MixerSurface" then return "mix" end
    if active.kind == "PianoRollSurface" then return "edit" end
    if active.kind == "LauncherSurface" then return "launcher" end
    return "arrange"
end

function M.make_palette(ui)
    -- Design tokens from docs/design-system/design-tokens.md
    -- Neutral palette: #0E1114 → #3B444D
    return {
        -- Surfaces
        surface_app        = ui.rgba(0.067, 0.075, 0.082, 1.0),  -- #111315
        surface_main       = ui.rgba(0.067, 0.075, 0.082, 1.0),  -- #111315 (app bg)
        surface_transport  = ui.rgba(0.090, 0.102, 0.118, 1.0),  -- #171A1E (panel)
        surface_status     = ui.rgba(0.078, 0.090, 0.102, 1.0),  -- #14171A (inset)
        surface_sidebar    = ui.rgba(0.090, 0.102, 0.118, 1.0),  -- #171A1E (panel)
        surface_panel      = ui.rgba(0.110, 0.129, 0.149, 1.0),  -- #1C2126 (raised)
        surface_inset      = ui.rgba(0.078, 0.090, 0.102, 1.0),  -- #14171A (inset)
        surface_control    = ui.rgba(0.137, 0.161, 0.188, 1.0),  -- #232930
        surface_control_hover = ui.rgba(0.165, 0.192, 0.220, 1.0), -- #2A3138
        surface_selected   = ui.rgba(0.165, 0.145, 0.110, 1.0),  -- warm selection tint
        surface_accent_soft = ui.rgba(0.160, 0.140, 0.100, 1.0), -- subtle warm accent

        -- Region surfaces
        surface_arrangement       = ui.rgba(0.067, 0.075, 0.082, 1.0),  -- app bg
        surface_arrangement_lane  = ui.rgba(0.078, 0.090, 0.102, 1.0),  -- inset
        surface_arrangement_canvas = ui.rgba(0.090, 0.102, 0.118, 1.0), -- panel
        surface_ruler         = ui.rgba(0.090, 0.102, 0.118, 1.0),  -- panel
        surface_track_column  = ui.rgba(0.078, 0.090, 0.102, 1.0),  -- inset
        surface_track_header  = ui.rgba(0.110, 0.129, 0.149, 1.0),  -- raised
        surface_detail    = ui.rgba(0.090, 0.102, 0.118, 1.0),  -- panel
        surface_device    = ui.rgba(0.110, 0.129, 0.149, 1.0),  -- raised
        surface_record    = ui.rgba(0.20, 0.10, 0.10, 1.0),     -- red-tinted

        -- Clip colors
        clip_bg          = ui.rgba(0.72, 0.33, 0.10, 1.0),
        clip_selected_bg = ui.rgba(0.82, 0.46, 0.16, 1.0),
        clip_border      = ui.rgba(0.95, 0.65, 0.36, 0.28),

        -- Borders (from design tokens alpha palette)
        border_subtle       = ui.rgba(1.0, 1.0, 1.0, 0.06),  -- subtle
        border_separator    = ui.rgba(1.0, 1.0, 1.0, 0.08),  -- separator
        border_control      = ui.rgba(1.0, 1.0, 1.0, 0.10),  -- default
        border_strong       = ui.rgba(1.0, 1.0, 1.0, 0.16),  -- strong
        border_track_header = ui.rgba(1.0, 1.0, 1.0, 0.10),
        border_selected     = ui.rgba(0.784, 0.604, 0.341, 1.0), -- #C89A57
        border_focus        = ui.rgba(0.839, 0.639, 0.353, 1.0), -- #D6A35A
        border_authored     = ui.rgba(1.0, 1.0, 1.0, 0.18),
        border_warning      = ui.rgba(0.839, 0.639, 0.353, 1.0), -- #D6A35A
        border_record       = ui.rgba(1.0, 0.365, 0.365, 1.0),   -- #FF5D5D

        -- Text
        text_primary  = ui.rgba(0.910, 0.929, 0.949, 1.0),  -- #E8EDF2
        text_secondary = ui.rgba(0.667, 0.706, 0.745, 1.0), -- #AAB4BE
        text_muted    = ui.rgba(0.490, 0.529, 0.569, 1.0),  -- #7D8791
        text_disabled = ui.rgba(0.361, 0.400, 0.439, 1.0),  -- #5C6670
        text_warning  = ui.rgba(0.839, 0.639, 0.353, 1.0),  -- #D6A35A

        -- Semantic accent
        track_accent  = ui.rgba(0.839, 0.639, 0.353, 1.0),  -- #D6A35A (warm amber)

        -- State colors
        state_play    = ui.rgba(0.341, 0.820, 0.478, 1.0),  -- #57D17A
        state_record  = ui.rgba(1.0, 0.365, 0.365, 1.0),    -- #FF5D5D
        state_solo    = ui.rgba(1.0, 0.847, 0.302, 1.0),    -- #FFD84D
        state_mute    = ui.rgba(0.498, 0.533, 0.569, 1.0),  -- #7F8891
    }
end

return M
