"""HD painted backgrounds for the five Philippine locations.

Canvas is 1600 x 540 logical units == the Level's world size (LevelManager
scales the texture to LEVEL_WIDTH x 540). The walkable ground surface is at
y = 460 (GROUND_Y), so every map paints its path / street / sand there.
"""
import math
import sys

import numpy as np
from PIL import Image

from hd import Art, path, rgba, mix, shade, seeded, INK

W, H = 1600, 540
GROUND = 460


def new_map():
    return Art(W, H, out=2, ss=2)


def ridge(xs, seed, base, amps):
    """Deterministic wavy line: base + sum(a * sin(x * f + phase))."""
    rng = np.random.default_rng(seed)
    y = np.full_like(xs, base, dtype=np.float64)
    for a, f in amps:
        y += a * np.sin(xs * f + rng.uniform(0, math.tau))
    return y


def fill_below(a, xs, ys, color, bottom=H):
    pts = [(float(x), float(y)) for x, y in zip(xs, ys)]
    pts += [(xs[-1], bottom), (xs[0], bottom)]
    a.poly(pts, color)


def band(a, xs, top, bottom, color):
    pts = [(float(x), float(y)) for x, y in zip(xs, top)]
    pts += [(float(x), float(y)) for x, y in zip(xs[::-1], bottom[::-1])]
    a.poly(pts, color)


def clouds(a, rnd, n, y0, y1, color=(255, 255, 255, 235), scale=1.0, shadow=None):
    shadow = shadow or mix(color, (150, 170, 200, color[3] if len(color) > 3 else 255), 0.35)
    for _ in range(n):
        cx = rnd.uniform(-50, W + 50)
        cy = rnd.uniform(y0, y1)
        wv = rnd.uniform(60, 150) * scale
        puffs = []
        for j in range(7):
            t = j / 6
            px = cx - wv / 2 + t * wv + rnd.uniform(-6, 6)
            r = (10 + math.sin(t * math.pi) * rnd.uniform(14, 24)) * scale
            puffs.append((px, cy - r * 0.55, r))
        with a.layer(blur=1.2, opacity=0.9):
            for px, py, r in puffs:
                a.circle(px, py + r * 0.18, r, shadow)
            for px, py, r in puffs:
                a.circle(px - r * 0.12, py - r * 0.05, r * 0.9, color)


def mist(a, y, height, color=(255, 255, 255, 120), blur=14):
    with a.layer(blur=blur):
        a.rect(-40, y, W + 80, height, color)


def palm(a, x, base_y, height, lean=0.0, trunk=(122, 92, 62), leaf=(52, 120, 58), scale=1.0, outline=None):
    """Coconut palm: curved segmented trunk + drooping fronds."""
    top = (x + lean * height, base_y - height)
    ctrl = (x + lean * height * 0.25, base_y - height * 0.55)
    pts = []
    for i in range(13):
        t = i / 12
        px = (1 - t) ** 2 * x + 2 * (1 - t) * t * ctrl[0] + t * t * top[0]
        py = (1 - t) ** 2 * base_y + 2 * (1 - t) * t * ctrl[1] + t * t * top[1]
        pts.append((px, py))
    for i in range(len(pts) - 1):
        wdt = (7.5 - i * 0.35) * scale
        a.line([pts[i], pts[i + 1]], shade(trunk, 0.95 if i % 2 else 1.08), wdt)
    tx, ty = top
    for ang, ln in [(-170, 1.0), (-140, 0.95), (-110, 0.8), (-70, 0.8), (-40, 0.95), (-10, 1.0),
                    (160, 0.75), (20, 0.75), (-90, 0.6)]:
        r = math.radians(ang)
        L = 62 * scale * ln
        ex, ey = tx + math.cos(r) * L, ty + math.sin(r) * L * 0.55 + L * 0.35
        mx, my = tx + math.cos(r) * L * 0.5, ty + math.sin(r) * L * 0.45 - 6 * scale
        frond = [(tx, ty), (mx, my - 4 * scale), (ex, ey), (mx, my + 5 * scale)]
        a.poly(frond, shade(leaf, 0.9 if ang > -90 else 1.05), smooth=2)
        a.line([(tx, ty), (mx, my), (ex, ey)], shade(leaf, 0.7), 1.1 * scale, smooth=2)
    a.circle(tx, ty + 3 * scale, 5 * scale, (90, 70, 40))


def grass_tufts(a, rnd, y, n, colors, h=(6, 14), x0=0, x1=W):
    for _ in range(n):
        x = rnd.uniform(x0, x1)
        hh = rnd.uniform(*h)
        c = rnd.choice(colors)
        for k in range(4):
            dx = rnd.uniform(-4, 4)
            a.line([(x, y), (x + dx, y - hh * rnd.uniform(0.6, 1.0))], c, 1.3)


# =========================================================== BANAUE =========
def banaue():
    a = new_map()
    rnd = seeded(11)
    xs = np.linspace(-10, W + 10, 400)
    a.vgradient(0, 0, W, H, [(0, (88, 146, 206)), (0.38, (170, 206, 228)), (0.62, (250, 226, 196)), (1, (250, 226, 196))])
    a.radial_glow(1250, 120, 220, (255, 236, 190, 200))
    clouds(a, rnd, 7, 70, 170)

    # far cordillera ridges, atmospheric perspective
    for i, (base, col, amps) in enumerate([
        (190, (132, 160, 186), [(28, 0.004), (14, 0.011), (6, 0.03)]),
        (215, (106, 142, 150), [(34, 0.005), (12, 0.014), (5, 0.04)]),
        (242, (86, 128, 110), [(30, 0.006), (14, 0.017), (5, 0.05)]),
    ]):
        fill_below(a, xs, ridge(xs, 20 + i, base, amps), col)
        mist(a, base + 14, 26, (240, 240, 235, 110), blur=10)

    # --- the terraced hillside: nested contours between the hill top and the
    # path. Each contour interpolates from the hill's ridge/gully shape to the
    # flat path, so the steps hug the slope like the real Ifugao terraces.
    g = ridge(xs, 5, 0, [(1.0, 0.006), (0.55, 0.013), (0.25, 0.031)])
    hill_top = 262 + g * 22
    fill_below(a, xs, hill_top, (92, 136, 60))
    paddy_cols = [(112, 164, 70), (136, 184, 84), (98, 154, 66), (164, 194, 104)]
    water = (156, 196, 208)
    N = 17
    wall = (108, 90, 60)
    tops = []
    prev = hill_top
    for L in range(1, N + 1):
        f = (L / N) ** 1.35
        nxt = hill_top + (GROUND - 6 - hill_top) * f
        near = f
        col = water if L % 4 == 2 else paddy_cols[L % len(paddy_cols)]
        band(a, xs, prev, nxt, col)
        wall_h = 1.4 + near * 7
        band(a, xs, nxt - wall_h, nxt, shade(wall, 0.8 + near * 0.25))
        a.line([(float(x), float(y)) for x, y in zip(xs[::3], (nxt - wall_h)[::3])], (178, 206, 112), 0.6 + near * 1.2)
        tops.append((prev.copy(), (nxt - wall_h).copy(), near, col))
        prev = nxt

    # sky reflections + rice rows on the flooded / planted paddies
    for top, bot, near, col in tops:
        if col == water:
            with a.layer(blur=1.5, opacity=0.55):
                for _ in range(10):
                    x = rnd.uniform(0, W)
                    i = int(np.clip((x + 10) / (W + 20) * (len(xs) - 1), 0, len(xs) - 1))
                    a.ellipse(x - 40, (top[i] + bot[i]) / 2 - 1, 80, 2.5, (235, 245, 250))
        elif near > 0.35:
            for _ in range(int(40 * near)):
                x = rnd.uniform(0, W)
                i = int(np.clip((x + 10) / (W + 20) * (len(xs) - 1), 0, len(xs) - 1))
                yy = rnd.uniform(top[i] + 2, bot[i] - 4)
                a.line([(x, yy), (x + rnd.uniform(-1, 1), yy - 3 - near * 5)], shade(col, 0.78), 1.0)

    # Ifugao houses (pyramid thatch roof on stilts) perched on the terraces
    def ifugao_house(x, y, s):
        post = (70, 48, 30)
        for dx in (-9, -3, 3, 9):
            a.line([(x + dx * s, y), (x + dx * s, y - 12 * s)], post, 1.6 * s)
        a.rect(x - 12 * s, y - 20 * s, 24 * s, 9 * s, (118, 80, 48), INK, 0.6 * s)
        a.poly([(x, y - 44 * s), (x - 20 * s, y - 16 * s), (x + 20 * s, y - 16 * s)], (160, 128, 74), INK, 0.7 * s)
        for k in range(1, 5):
            yy = y - 44 * s + k * 6 * s
            half = (k * 6 * s) / 28 * 20
            a.line([(x - half, yy), (x + half, yy)], (128, 98, 54), 0.6 * s)
    for hx, hy, hs in [(1180, 330, 0.8), (1235, 338, 0.7), (360, 352, 0.9), (720, 318, 0.6)]:
        ifugao_house(hx, hy, hs)

    # pine trees on the ridge line
    for x in range(40, W, 97):
        i = int((x + 10) / (W + 20) * (len(xs) - 1))
        y = hill_top[i] + 4
        s = rnd.uniform(0.6, 1.0)
        a.poly([(x, y - 34 * s), (x - 9 * s, y), (x + 9 * s, y)], (52, 92, 56))
        a.line([(x, y), (x, y + 4)], (80, 60, 40), 2)

    # --- foreground: earthen path along the top of a stone retaining wall
    a.vgradient(0, GROUND - 6, W, 16, [(0, (148, 116, 76)), (1, (120, 92, 58))])
    a.rect(0, GROUND - 7, W, 2.2, (184, 196, 104))
    a.vgradient(0, GROUND + 10, W, H - GROUND - 10, [(0, (112, 100, 84)), (1, (78, 66, 52))])
    for row in range(8):
        y = GROUND + 12 + row * 10
        off = (row % 2) * 17
        for x in range(-40 + off, W + 40, 34):
            w = 30 + rnd.uniform(-4, 3)
            c = shade((128, 114, 94), rnd.uniform(0.8, 1.1) - row * 0.03)
            a.blob([(x, y + 1), (x + w * 0.5, y - rnd.uniform(0, 1.5)), (x + w, y + 1), (x + w + 1, y + 8), (x + w * 0.5, y + 9.5), (x - 1, y + 8)], c, (70, 58, 44), 0.6, smooth=2)
    grass_tufts(a, rnd, GROUND - 6, 220, [(96, 150, 60), (124, 172, 70), (80, 130, 52)], h=(5, 12))
    grass_tufts(a, rnd, GROUND + 12, 90, [(90, 140, 60), (70, 118, 50)], h=(4, 9))
    a.noise_overlay(2.5, seed=3)
    return a


# ======================================================= INTRAMUROS =========
def intramuros():
    a = new_map()
    rnd = seeded(22)
    a.vgradient(0, 0, W, H, [(0, (92, 132, 190)), (0.35, (236, 176, 120)), (0.6, (252, 214, 158)), (1, (252, 214, 158))])
    a.radial_glow(300, 250, 260, (255, 210, 140, 220))
    clouds(a, rnd, 7, 40, 160, color=(255, 226, 200, 150))

    # distant Manila skyline haze
    xs = np.linspace(-10, W + 10, 200)
    with a.layer(opacity=0.45):
        for x in range(0, W, 46):
            h = rnd.uniform(40, 110)
            a.rect(x, 300 - h, rnd.uniform(24, 40), h + 20, (150, 130, 140))

    # Manila Cathedral: dome + bell tower + facade (background landmark)
    cx = 1080
    stone = (214, 188, 150)
    stone_sh = (176, 150, 116)
    a.rect(cx - 70, 190, 140, 120, stone, INK, 1.2)
    a.poly([(cx - 78, 192), (cx, 150), (cx + 78, 192)], stone_sh, INK, 1.2)
    a.ellipse(cx - 18, 214, 36, 60, (120, 90, 70), INK, 1)
    a.circle(cx, 176, 10, (160, 200, 220), INK, 1)
    for dx in (-52, 52):
        a.rect(cx + dx - 8, 225, 16, 40, (130, 100, 80), INK, 0.8, radius=6)
    # dome behind
    a.rect(cx + 70, 150, 56, 60, stone, INK, 1)
    a.ellipse(cx + 66, 104, 64, 70, (96, 124, 110), INK, 1.2)
    a.rect(cx + 94, 88, 8, 20, (96, 124, 110), INK, 0.8)
    a.line([(cx + 98, 70), (cx + 98, 88)], INK, 1.4)
    a.line([(cx + 92, 76), (cx + 104, 76)], INK, 1.4)
    # bell tower
    tx = cx - 140
    a.rect(tx - 20, 120, 40, 190, stone, INK, 1.2)
    for k in range(3):
        a.rect(tx - 10, 140 + k * 48, 20, 28, (110, 82, 64), INK, 0.8, radius=9)
    a.rect(tx - 24, 116, 48, 8, stone_sh, INK, 1)
    a.poly([(tx - 16, 116), (tx, 84), (tx + 16, 116)], (96, 124, 110), INK, 1)

    # the Walls (Muralla) with crenellations and the arched Puerta
    wall_top = 300
    a.vgradient(0, wall_top, W, 110, [(0, (168, 150, 118)), (1, (132, 116, 92))])
    for x in range(0, W, 40):
        a.rect(x, wall_top - 18, 24, 20, (168, 150, 118), INK, 1)
    for row in range(10):
        y = wall_top + 4 + row * 11
        off = (row % 2) * 16
        for x in range(-20 + off, W, 32):
            a.rect(x, y, 30, 10, shade((158, 140, 110), rnd.uniform(0.86, 1.06)), (110, 94, 72), 0.6, radius=1.5)
    with a.layer(blur=4, opacity=0.5):
        for _ in range(30):
            x = rnd.uniform(0, W)
            a.ellipse(x, wall_top + rnd.uniform(40, 90), rnd.uniform(20, 60), rnd.uniform(10, 30), (80, 110, 60))
    gx = 520
    a.rect(gx - 70, wall_top - 40, 140, 150, (182, 164, 130), INK, 1.4)
    a.poly([(gx - 76, wall_top - 40), (gx, wall_top - 74), (gx + 76, wall_top - 40)], (160, 142, 110), INK, 1.4)
    a.rect(gx - 38, wall_top + 10, 76, 100, (48, 36, 30), INK, 1.2)
    a.ellipse(gx - 38, wall_top - 26, 76, 72, (48, 36, 30))
    a.circle(gx, wall_top - 50, 9, (200, 170, 90), INK, 1)
    # vines on the wall
    for vx in (120, 830, 1380):
        for k in range(18):
            a.circle(vx + rnd.uniform(-20, 20), wall_top + k * 5, rnd.uniform(3, 6), (72, 120, 60))

    # Bahay na bato: stone ground floor, wooden upper floor, capiz windows
    def bahay(x, w, h1=62, h2=52):
        base_y = GROUND - 4
        a.rect(x, base_y - h1, w, h1, (196, 170, 132), INK, 1.2)
        for k in range(int(w // 46)):
            a.rect(x + 12 + k * 46, base_y - h1 + 16, 26, 38, (70, 50, 40), INK, 1, radius=12)
        up_y = base_y - h1 - h2
        a.rect(x - 8, up_y, w + 16, h2, (120, 70, 42), INK, 1.2)
        n = max(2, int((w + 16) // 34))
        for k in range(n):
            wx = x - 4 + k * (w + 8) / n
            a.rect(wx, up_y + 8, (w + 8) / n - 6, h2 - 18, (246, 234, 206), INK, 0.8)
            cols = 4
            for cc in range(1, cols):
                xx = wx + cc * ((w + 8) / n - 6) / cols
                a.line([(xx, up_y + 8), (xx, up_y + h2 - 10)], (170, 140, 100), 0.5)
            for rr in range(1, 4):
                yy = up_y + 8 + rr * (h2 - 18) / 4
                a.line([(wx, yy), (wx + (w + 8) / n - 6, yy)], (170, 140, 100), 0.5)
        a.rect(x - 14, up_y + h2 - 6, w + 28, 6, (96, 56, 34), INK, 1)
        a.poly([(x - 22, up_y + 2), (x + w / 2, up_y - 34), (x + w + 22, up_y + 2)], (164, 72, 50), INK, 1.4)
        for k in range(12):
            t = k / 12
            a.line([(x - 22 + t * (w / 2 + 22), up_y + 2 - t * 36), (x - 18 + t * (w / 2 + 22), up_y + 2)], (140, 58, 40), 0.5)
    for bx, bw in [(40, 180), (700, 220), (1270, 200)]:
        bahay(bx, bw)

    # vintage lamp posts
    for lx in (320, 640, 1000, 1220, 1540):
        a.line([(lx, GROUND - 2), (lx, GROUND - 92)], (40, 40, 44), 3)
        a.rect(lx - 7, GROUND - 110, 14, 18, (255, 222, 150), (40, 40, 44), 1.4)
        a.poly([(lx - 10, GROUND - 110), (lx, GROUND - 120), (lx + 10, GROUND - 110)], (40, 40, 44))
        a.radial_glow(lx, GROUND - 101, 30, (255, 220, 150, 170))

    # acacia trees shading the street
    for ax in (900, 1510):
        a.limb((ax, GROUND - 2), (ax - 6, GROUND - 90), 10, (92, 66, 46))
        a.limb((ax - 6, GROUND - 80), (ax - 40, GROUND - 120), 5, (92, 66, 46))
        a.limb((ax - 6, GROUND - 84), (ax + 34, GROUND - 124), 5, (92, 66, 46))
        for dx, dy, rx, ry in [(-44, -130, 44, 20), (30, -134, 50, 22), (-6, -150, 56, 24), (-20, -118, 40, 14), (40, -116, 34, 14)]:
            a.ellipse(ax + dx - rx, GROUND + dy - ry, rx * 2, ry * 2, (64, 110, 58))
            a.ellipse(ax + dx - rx * 0.7, GROUND + dy - ry * 1.05, rx * 1.2, ry * 0.9, (88, 136, 70))

    # cobblestone street
    a.vgradient(0, GROUND - 4, W, H - GROUND + 4, [(0, (150, 132, 112)), (1, (96, 84, 72))])
    y = GROUND - 2
    row = 0
    while y < H:
        h = 6 + row * 1.6
        off = (row % 2) * 10
        for x in range(-20 + off, W + 20, int(20 + row * 3)):
            a.ellipse(x, y, 18 + row * 3, h, shade((156, 138, 118), rnd.uniform(0.82, 1.08) - row * 0.02), (96, 84, 72), 0.6)
        y += h + 1
        row += 1
    a.rect(0, GROUND - 5, W, 2.5, (186, 170, 146))
    a.noise_overlay(2.5, seed=4)
    return a


# ============================================================ MAYON ==========
def mayon():
    a = new_map()
    rnd = seeded(33)
    xs = np.linspace(-10, W + 10, 400)
    a.vgradient(0, 0, W, H, [(0, (70, 140, 212)), (0.45, (150, 200, 232)), (0.7, (214, 234, 236)), (1, (214, 234, 236))])
    clouds(a, rnd, 8, 30, 150)

    # Mayon's near-perfect cone: steep concave slopes, ash-grey summit
    # fading to forested green flanks.
    cx, top = 860, 58
    base_y = 392
    half = 470
    def slope(t):  # t 0..1 from summit to base, concave profile
        return 0.035 + t ** 2.1
    left = [(cx - half * slope(t), top + (base_y - top) * t) for t in np.linspace(0, 1, 50)]
    right = [(cx + half * slope(t), top + (base_y - top) * t) for t in np.linspace(1, 0, 50)]
    cone = left + right
    a.gradient_poly(cone, [(0, (206, 204, 204)), (0.14, (150, 150, 158)), (0.34, (104, 116, 124)),
                           (0.58, (86, 122, 96)), (1, (78, 128, 76))])
    # shaded right flank for volume
    with a.layer(opacity=0.22):
        a.poly([(cx, top)] + [(cx + half * slope(t) * 0.25, top + (base_y - top) * t) for t in np.linspace(0, 1, 30)]
               + right, (30, 40, 50))
    # erosion gullies radiating from the summit
    with a.layer(opacity=0.35, blur=0.4):
        for k in range(-5, 6):
            if k == 0:
                continue
            pts = []
            for t in np.linspace(0.04, 0.8, 18):
                pts.append((cx + half * slope(t) * k / 6.5 + math.sin(t * 11 + k) * 2.5, top + (base_y - top) * t))
            a.line(pts, (60, 66, 74), 1.1, smooth=1)
    # summit steam plume drifting right
    with a.layer(blur=4):
        for i in range(10):
            t = i / 9
            r = 7 + t * 26
            a.circle(cx + 6 + t * 150 + math.sin(i * 1.7) * 8, top - 8 - t * 34 - math.sin(t * 3) * 6, r,
                     (244, 242, 238, int(220 - t * 150)))
    a.radial_glow(cx, top + 3, 9, (255, 150, 70, 160))

    # foothills and rice fields
    fill_below(a, xs, ridge(xs, 7, 356, [(12, 0.006), (6, 0.02)]), (96, 146, 80))
    fill_below(a, xs, ridge(xs, 8, 380, [(8, 0.004), (5, 0.018)]), (118, 168, 84))
    for yy in range(392, 452, 12):
        a.line([(0, yy), (W, yy + 4)], (140, 186, 94), 1.6)

    # Cagsawa ruins belfry (iconic!) with broken church wall
    bx = 300
    ruin = (122, 104, 90)
    ruin_sh = (92, 78, 68)
    a.poly([(bx - 26, 440), (bx - 26, 300), (bx - 18, 290), (bx + 18, 290), (bx + 26, 300), (bx + 26, 440)], ruin, INK, 1.4)
    a.poly([(bx - 18, 290), (bx - 14, 250), (bx - 6, 244), (bx + 8, 246), (bx + 14, 256), (bx + 18, 290)], ruin, INK, 1.4)
    a.poly([(bx - 10, 244), (bx - 4, 226), (bx + 2, 230), (bx + 6, 246)], ruin_sh, INK, 1)
    for k, yy in enumerate((320, 370)):
        a.ellipse(bx - 10, yy, 20, 30, (58, 48, 42), INK, 0.8)
    a.ellipse(bx - 7, 262, 14, 20, (58, 48, 42), INK, 0.8)
    a.poly([(bx + 40, 440), (bx + 40, 392), (bx + 60, 380), (bx + 76, 396), (bx + 96, 386), (bx + 110, 440)], ruin_sh, INK, 1.2)
    with a.layer(blur=2, opacity=0.8):
        for _ in range(40):
            a.circle(bx + rnd.uniform(-30, 110), rnd.uniform(380, 440), rnd.uniform(2, 5), (80, 120, 60))

    # coconut palms
    for px, h, lean in [(80, 150, 0.12), (150, 120, -0.08), (1380, 160, -0.1), (1460, 130, 0.08), (1540, 175, 0.05)]:
        palm(a, px, GROUND, h, lean)

    # foreground dirt road
    a.vgradient(0, GROUND - 4, W, H - GROUND + 4, [(0, (156, 122, 82)), (1, (104, 80, 54))])
    a.rect(0, GROUND - 6, W, 3, (120, 168, 80))
    for _ in range(260):
        x = rnd.uniform(0, W)
        y = rnd.uniform(GROUND + 4, H)
        a.ellipse(x, y, rnd.uniform(3, 8), rnd.uniform(1.5, 3), shade((140, 108, 72), rnd.uniform(0.7, 1.2)))
    grass_tufts(a, rnd, GROUND - 5, 240, [(96, 150, 60), (124, 172, 70), (80, 130, 52)])
    a.noise_overlay(2.5, seed=5)
    return a


# =================================================== CHOCOLATE HILLS =========
def chocolate_hills():
    a = new_map()
    rnd = seeded(44)
    xs = np.linspace(-10, W + 10, 300)
    a.vgradient(0, 0, W, H, [(0, (82, 150, 214)), (0.45, (170, 214, 234)), (0.68, (226, 238, 226)), (1, (226, 238, 226))])
    clouds(a, rnd, 10, 30, 190)
    fill_below(a, xs, ridge(xs, 9, 258, [(10, 0.005), (5, 0.02)]), (118, 150, 120))

    # rows of haystack hills receding into the distance, each row sitting in
    # a band of jungle canopy (the real hills rise out of flat forest).
    def hill(x, base, r, h, col):
        prof = [(x + u * r, base - h * (1 - abs(u) ** 2.2) ** 0.75) for u in np.linspace(-1, 1, 36)]
        a.gradient_poly(prof + [(x + r, base + 6), (x - r, base + 6)],
                        [(0, shade(col, 1.12)), (0.55, col), (1, shade(col, 0.82))])
        with a.layer(opacity=0.28):
            a.poly([(x + u * r, base - h * (1 - abs(u) ** 2.2) ** 0.75) for u in np.linspace(0.05, 1, 20)]
                   + [(x + r, base + 6), (x + r * 0.2, base + 6)], (60, 36, 20))
        with a.layer(opacity=0.35, blur=r * 0.05):
            a.ellipse(x - r * 0.55, base - h * 0.86, r * 0.6, h * 0.35, shade(col, 1.3))
    def canopy(base, fade, seed):
        cols = mix((52, 104, 56), (206, 220, 214), (1 - fade) * 0.75)
        top = ridge(xs, seed, base - 3, [(2.5, 0.09), (1.6, 0.21), (1.2, 0.05)])
        fill_below(a, xs, top, cols)
        a.line([(float(x), float(y)) for x, y in zip(xs[::2], top[::2])], shade(cols, 1.15), 1.0)
    rows = [(286, 22, 20, (164, 132, 98), 18, 0.5), (318, 36, 32, (156, 116, 74), 12, 0.7),
            (360, 54, 48, (148, 104, 60), 8, 0.88), (410, 78, 66, (140, 96, 52), 5, 1.0)]
    for ri, (base, r, h, col, n, fade) in enumerate(rows):
        haze = mix(col, (206, 220, 214), (1 - fade) * 0.8)
        for k in range(n):
            x = (k + 0.5 + rnd.uniform(-0.3, 0.3)) * (W / n)
            sc = rnd.uniform(0.8, 1.15)
            hill(x, base + rnd.uniform(-3, 3), r * sc, h * sc, shade(haze, rnd.uniform(0.95, 1.05)))
        canopy(base, fade, 70 + ri)

    # a tarsier on a branch (Bohol!) - left side tree
    tx = 130
    a.limb((tx, GROUND), (tx + 8, 300), 12, (98, 72, 50))
    a.limb((tx + 6, 340), (tx + 70, 322), 5, (98, 72, 50))
    for cx_, cy_, r in [(tx - 10, 290, 40), (tx + 30, 270, 44), (tx + 60, 300, 34), (tx - 30, 320, 30)]:
        a.circle(cx_, cy_, r, (60, 118, 62))
        a.circle(cx_ - r * 0.3, cy_ - r * 0.3, r * 0.5, (84, 142, 74))
    sx, sy = tx + 52, 312
    a.oval(sx, sy, 7, 8, (160, 128, 96))
    a.oval(sx, sy - 10, 7, 6.5, (170, 136, 104))
    a.circle(sx - 3, sy - 11, 3, (250, 220, 120))
    a.circle(sx + 3, sy - 11, 3, (250, 220, 120))
    a.circle(sx - 3, sy - 11, 1.4, INK)
    a.circle(sx + 3, sy - 11, 1.4, INK)
    a.line([(sx + 4, sy + 6), (sx + 14, sy + 26)], (140, 110, 80), 1)

    # wooden boardwalk / viewing-deck railing on the right
    for x in range(1180, W + 20, 44):
        a.rect(x, GROUND - 42, 5, 42, (120, 84, 50), INK, 0.8)
    a.rect(1170, GROUND - 44, W, 5, (140, 98, 58), INK, 0.8)
    a.rect(1170, GROUND - 24, W, 4, (140, 98, 58), INK, 0.8)
    palm(a, 1100, GROUND, 150, 0.1)
    palm(a, 40, GROUND, 120, -0.05)

    # grassy foreground path
    a.vgradient(0, GROUND - 4, W, H - GROUND + 4, [(0, (132, 176, 80)), (1, (84, 124, 56))])
    a.vgradient(0, GROUND - 2, W, 18, [(0, (176, 146, 102)), (1, (150, 120, 80))])
    grass_tufts(a, rnd, GROUND - 3, 260, [(110, 164, 64), (140, 186, 80), (90, 140, 56)], h=(5, 12))
    grass_tufts(a, rnd, GROUND + 30, 200, [(110, 164, 64), (80, 128, 50)], h=(6, 14))
    a.noise_overlay(2.5, seed=6)
    return a


# ========================================================== BORACAY ==========
def boracay():
    a = new_map()
    rnd = seeded(55)
    horizon = 300
    a.vgradient(0, 0, W, horizon, [(0, (74, 70, 140)), (0.35, (206, 108, 128)), (0.7, (250, 168, 102)), (1, (255, 214, 140))])
    sun_x = 1000
    a.radial_glow(sun_x, horizon - 30, 260, (255, 200, 120, 230))
    a.circle(sun_x, horizon - 30, 34, (255, 236, 180))
    with a.layer(blur=3, opacity=0.8):
        for i in range(6):
            yy = 120 + i * 26
            a.ellipse(rnd.uniform(0, W - 400), yy, rnd.uniform(200, 420), 7, (255, 206, 186) if i % 2 else (236, 140, 150))

    # sea: sunset reflection turning turquoise near the shore
    a.vgradient(0, horizon, W, 130, [(0, (96, 112, 170)), (0.5, (70, 170, 190)), (1, (96, 210, 200))])
    with a.layer(blur=1.5, opacity=0.9):
        for i in range(40):
            yy = horizon + 3 + i * 2.8
            wv = 60 - i * 1.2
            a.ellipse(sun_x - wv + rnd.uniform(-10, 10), yy, wv * 2, 1.6, (255, 220, 160))
    for i in range(60):
        yy = rnd.uniform(horizon + 10, horizon + 128)
        x = rnd.uniform(0, W)
        a.line([(x, yy), (x + rnd.uniform(10, 30), yy)], (200, 240, 236), 0.8)

    # Willy's Rock with its little grotto statue
    wx = 470
    a.blob([(wx - 60, horizon + 60), (wx - 50, horizon + 10), (wx - 20, horizon - 20), (wx + 10, horizon - 26),
            (wx + 40, horizon - 6), (wx + 56, horizon + 30), (wx + 64, horizon + 60)], (96, 84, 80))
    a.poly([(wx - 20, horizon - 14), (wx + 2, horizon - 26), (wx + 30, horizon - 10), (wx + 12, horizon)], (122, 108, 100))
    a.circle(wx + 4, horizon - 36, 5, (240, 240, 240))
    a.rect(wx, horizon - 32, 8, 10, (240, 240, 240))
    for dx in (-30, -10, 20, 50):
        a.circle(wx + dx, horizon - 18 + abs(dx) * 0.3, 7, (70, 130, 70))

    # paraw sailboats silhouetted against the sunset
    def paraw(x, y, s, sail):
        a.blob([(x - 30 * s, y), (x + 30 * s, y), (x + 22 * s, y + 7 * s), (x - 22 * s, y + 7 * s)], (60, 40, 40), None, 0, 1)
        a.line([(x - 40 * s, y + 4 * s), (x + 40 * s, y + 4 * s)], (60, 40, 40), 1.2 * s)
        a.line([(x, y), (x, y - 50 * s)], (60, 40, 40), 1.4 * s)
        a.poly([(x + 1, y - 50 * s), (x + 1, y - 4 * s), (x + 34 * s, y - 6 * s)], sail)
        a.poly([(x - 1, y - 44 * s), (x - 1, y - 6 * s), (x - 22 * s, y - 8 * s)], shade(sail, 0.85))
    paraw(760, horizon + 30, 1.0, (230, 80, 70))
    paraw(1240, horizon + 18, 0.7, (250, 200, 80))
    paraw(1460, horizon + 40, 0.85, (90, 150, 210))

    # the famous white sand, wet shoreline, gentle foam
    a.vgradient(0, horizon + 124, W, 20, [(0, (180, 210, 196)), (1, (226, 222, 204))])
    with a.layer(blur=1):
        pts = [(x, horizon + 128 + math.sin(x * 0.03) * 3) for x in range(-10, W + 20, 20)]
        a.line(pts, (255, 255, 255, 230), 2.2)
    a.vgradient(0, horizon + 140, W, H - horizon - 140, [(0, (244, 236, 216)), (0.5, (250, 244, 228)), (1, (232, 220, 196))])
    for _ in range(500):
        x = rnd.uniform(0, W)
        y = rnd.uniform(horizon + 150, H)
        a.circle(x, y, rnd.uniform(0.4, 1.0), shade((230, 220, 196), rnd.uniform(0.85, 1.0)))

    # beach huts (nipa cottages) and leaning coconut palms
    def cottage(x, s=1.0):
        base = GROUND - 4
        for dx in (-26, 26):
            a.line([(x + dx * s, base), (x + dx * s, base - 44 * s)], (110, 80, 50), 3 * s)
        a.poly([(x - 44 * s, base - 40 * s), (x, base - 76 * s), (x + 44 * s, base - 40 * s)], (196, 158, 94), INK, 1.2)
        for k in range(8):
            t = k / 8
            a.line([(x - 44 * s + t * 44 * s, base - 40 * s - t * 36 * s), (x - 40 * s + t * 44 * s, base - 40 * s)], (170, 132, 74), 0.5)
        a.rect(x - 30 * s, base - 20 * s, 60 * s, 5 * s, (140, 100, 60), INK, 0.8)
    cottage(230)
    cottage(1320, 0.9)
    for px, h, lean in [(60, 190, 0.25), (380, 150, -0.2), (620, 170, 0.18), (1120, 160, -0.22), (1560, 200, -0.25)]:
        palm(a, px, GROUND + 6, h, lean)
    # starfish + shells
    for _ in range(14):
        x, y = rnd.uniform(0, W), rnd.uniform(GROUND + 20, H - 10)
        if rnd.random() < 0.5:
            for k in range(5):
                ang = k * math.tau / 5
                a.line([(x, y), (x + math.cos(ang) * 5, y + math.sin(ang) * 5)], (230, 110, 80), 2)
        else:
            a.ellipse(x, y, 7, 5, (250, 220, 210), (200, 160, 150), 0.6)
    a.noise_overlay(2.5, seed=7)
    return a


MAPS = {
    "banaue": banaue,
    "intramuros": intramuros,
    "mayon": mayon,
    "chocolate_hills": chocolate_hills,
    "boracay": boracay,
}


def generate(only=None):
    for name, fn in MAPS.items():
        if only and name not in only:
            continue
        art = fn()
        img = art.save(path("maps", f"bg_{name}.png"))
        # thumbnail = what the camera sees near the start of the level
        crop = img.crop((0, 0, int(img.height * 16 / 9), img.height))
        crop.resize((480, 270), Image.LANCZOS).save(path("maps", f"bg_{name}_thumb.png"), optimize=True)


if __name__ == "__main__":
    generate(sys.argv[1:] or None)
