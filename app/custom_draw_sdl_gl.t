-- app/custom_draw_sdl_gl.t
-- GPU-drawn semantic icons and custom rendering for Terra DAW (SDL+GL).
--
-- This module provides the draw_custom callback implementation that
-- dispatches on CustomCmd.kind to render icon geometry with direct GL.
-- It receives GL primitives (gl_quad, gl_color, C) from the caller.

local compile = require("lib/compile")

local M = {}

-- Build the custom draw implementation for the given GL primitive table.
-- `gl` must have: gl.quad, gl.color, gl.C (the C header namespace with
-- GL constants, glBegin, glEnd, glVertex2f, cosf, sinf, strcmp).
function M.make_draw_custom(gl)
    local PI = 3.14159265358979323846

    terra M.draw_filled_circle(cx: float, cy: float, r: float, c: compile.Color, segments: int)
        gl.color(c, 1.0f)
        gl.C.glBegin(gl.C.GL_TRIANGLE_FAN)
        gl.C.glVertex2f(cx, cy)
        for i = 0, segments do
            var angle = 2.0f * [float](PI) * [float](i) / [float](segments)
            gl.C.glVertex2f(cx + r * gl.C.cosf(angle), cy + r * gl.C.sinf(angle))
        end
        gl.C.glEnd()
    end

    terra M.draw_filled_triangle(x1: float, y1: float, x2: float, y2: float, x3: float, y3: float, c: compile.Color)
        gl.color(c, 1.0f)
        gl.C.glBegin(gl.C.GL_TRIANGLES)
        gl.C.glVertex2f(x1, y1)
        gl.C.glVertex2f(x2, y2)
        gl.C.glVertex2f(x3, y3)
        gl.C.glEnd()
    end

    -- ═══════════════════════════════════════════════════════════════════
    -- Icon dispatch
    -- ═══════════════════════════════════════════════════════════════════

    terra M.draw_icon(cmd: compile.CustomCmd)
        var x = cmd.x
        var y = cmd.y
        var w = cmd.w
        var h = cmd.h
        var c = cmd.color
        var cx = x + w * 0.5f
        var cy = y + h * 0.5f
        var s = terralib.select(w < h, w, h)

        if gl.C.strcmp(cmd.kind, "icon.play") == 0 then
            -- Play triangle: points right
            var pad = s * 0.15f
            var x0 = x + pad + s * 0.05f
            var y0 = y + pad
            var x1 = x + w - pad
            var y1 = y + h - pad
            M.draw_filled_triangle(x0, y0, x1, cy, x0, y1, c)

        elseif gl.C.strcmp(cmd.kind, "icon.stop") == 0 then
            -- Filled square
            var pad = s * 0.22f
            gl.color(c, 1.0f)
            gl.quad(x + pad, y + pad, w - 2*pad, h - 2*pad)

        elseif gl.C.strcmp(cmd.kind, "icon.record") == 0 then
            -- Filled circle
            var r = s * 0.30f
            M.draw_filled_circle(cx, cy, r, c, 20)

        elseif gl.C.strcmp(cmd.kind, "icon.loop") == 0 then
            -- Two horizontal bars
            var bh = terralib.select(s * 0.16f > 2.0f, s * 0.16f, 2.0f)
            var bw = s * 0.65f
            var gap = s * 0.12f
            var bx = cx - bw * 0.5f
            gl.color(c, 1.0f)
            gl.quad(bx, cy - gap - bh, bw, bh)
            gl.quad(bx, cy + gap, bw, bh)

        elseif gl.C.strcmp(cmd.kind, "icon.solo") == 0 then
            -- Stylized "S": three bars + connectors
            var bh = terralib.select(s * 0.14f > 1.5f, s * 0.14f, 1.5f)
            var bw = s * 0.55f
            var pad = s * 0.15f
            gl.color(c, 1.0f)
            gl.quad(cx - bw*0.5f, y + pad, bw, bh)
            gl.quad(cx - bw*0.5f, cy - bh*0.5f, bw, bh)
            gl.quad(cx - bw*0.5f, y + h - pad - bh, bw, bh)
            gl.quad(cx - bw*0.5f, y + pad, bh, cy - bh*0.5f - y - pad)
            gl.quad(cx + bw*0.5f - bh, cy + bh*0.5f, bh, y + h - pad - bh - cy - bh*0.5f)

        elseif gl.C.strcmp(cmd.kind, "icon.mute") == 0 then
            -- Stylized "M": two verticals + two diagonals to center
            var bh_v = s * 0.14f
            var pad = s * 0.18f
            var left = x + pad
            var right = x + w - pad - bh_v
            var top_y = y + pad
            var bot_y = y + h - pad
            gl.color(c, 1.0f)
            gl.quad(left, top_y, bh_v, bot_y - top_y)
            gl.quad(right, top_y, bh_v, bot_y - top_y)
            M.draw_filled_triangle(left, top_y, left + bh_v, top_y, cx, cy, c)
            M.draw_filled_triangle(right, top_y, right + bh_v, top_y, cx, cy, c)

        elseif gl.C.strcmp(cmd.kind, "icon.plus") == 0 then
            -- Cross shape
            var bh = terralib.select(s * 0.16f > 2.0f, s * 0.16f, 2.0f)
            var len = s * 0.6f
            gl.color(c, 1.0f)
            gl.quad(cx - len*0.5f, cy - bh*0.5f, len, bh)
            gl.quad(cx - bh*0.5f, cy - len*0.5f, bh, len)

        elseif gl.C.strcmp(cmd.kind, "icon.meter") == 0 then
            -- Three ascending bars
            var bw = terralib.select(s * 0.18f > 2.0f, s * 0.18f, 2.0f)
            var gap = terralib.select(s * 0.08f > 1.0f, s * 0.08f, 1.0f)
            var total_w = 3*bw + 2*gap
            var bx = cx - total_w * 0.5f
            var bot = y + h - s*0.12f
            gl.color(c, 1.0f)
            gl.quad(bx, bot - s*0.35f, bw, s*0.35f)
            gl.quad(bx + bw + gap, bot - s*0.55f, bw, s*0.55f)
            gl.quad(bx + 2*(bw + gap), bot - s*0.75f, bw, s*0.75f)
        end
    end

    return M.draw_icon
end

return M
