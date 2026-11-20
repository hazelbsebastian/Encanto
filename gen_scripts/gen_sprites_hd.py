"""HD (non-pixel) sprites: farmer, folklore creatures, Kapre's balete tree,
projectiles/effects, jeepney + driver, HUD/menu icons.

Every sprite keeps its original logical size (so collision shapes and
offsets in the scenes still line up) but is exported at 2x and displayed at
scale 0.5 in-game, which keeps edges crisp on high-DPI phones and monitors.
"""
import math
import sys

import numpy as np
from PIL import Image

from hd import Art, path, rgba, mix, shade, seeded, INK

OW = 1.1  # outline width in logical px


OUT = 2  # export scale; gen_portraits.py raises this to reuse the drawings large


def sprite(w, h):
    return Art(w, h, out=OUT, ss=4 if OUT <= 2 else 2)


def pol(cx, cy, length, deg):
    r = math.radians(deg)
    return (cx + math.sin(r) * length, cy + math.cos(r) * length)


def tint_img(art, color, amount):
    """Tint the non-transparent pixels (hurt / death flashes)."""
    arr = np.asarray(art.img, dtype=np.float32).copy()
    for c in range(3):
        arr[:, :, c] = arr[:, :, c] * (1 - amount) + color[c] * amount
    art.img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    from PIL import ImageDraw
    art.d = ImageDraw.Draw(art.img)


def rotate_art(art, deg, pivot):
    px, py = art.s(pivot[0]), art.s(pivot[1])
    art.img = art.img.rotate(deg, resample=Image.BICUBIC, center=(px, py))
    from PIL import ImageDraw
    art.d = ImageDraw.Draw(art.img)


# =============================================================== FARMER ======
SKIN = (196, 140, 98)
SKIN_SH = (164, 110, 76)
SHIRT = (246, 244, 232)
SHIRT_SH = (212, 206, 190)
PANTS = (112, 86, 58)
PANTS_SH = (86, 64, 42)
HAIR = (36, 26, 22)
BANDANA = (200, 52, 48)
SUMPAK = (132, 94, 56)


def leg(a, hip, thigh_deg, shin_deg, color, dark=False):
    knee = pol(hip[0], hip[1], 8.5, thigh_deg)
    foot = pol(knee[0], knee[1], 8.5, shin_deg)
    col = shade(color, 0.85) if dark else color
    a.limb(hip, knee, 5.6, col, INK, OW)
    a.limb(knee, foot, 4.8, col, INK, OW)
    # rolled-up cuff + bare foot / sandal
    cuff = pol(knee[0], knee[1], 6.2, shin_deg)
    a.limb(cuff, foot, 3.8, SKIN_SH if dark else SKIN, INK, OW)
    a.oval(foot[0] + 1.6, foot[1] + 0.6, 3.4, 1.8, (70, 50, 36), INK, OW * 0.8)
    return foot


def arm(a, shoulder, upper_deg, fore_deg, dark=False, fist=True):
    elbow = pol(shoulder[0], shoulder[1], 6.5, upper_deg)
    hand = pol(elbow[0], elbow[1], 6.5, fore_deg)
    sleeve = pol(shoulder[0], shoulder[1], 5.0, upper_deg)
    a.limb(shoulder, sleeve, 5.0, SHIRT_SH if dark else SHIRT, INK, OW)
    a.limb(sleeve, elbow, 3.6, SKIN_SH if dark else SKIN, INK, OW)
    a.limb(elbow, hand, 3.4, SKIN_SH if dark else SKIN, INK, OW)
    if fist:
        a.oval(hand[0], hand[1], 2.1, 2.1, SKIN_SH if dark else SKIN, INK, OW * 0.8)
    return hand


def draw_farmer(legs=(0, 0, 0, 0), arms=(10, -10, -10, 10), bob=0.0, lean=0.0, weapon=False,
                cheer=False, fallen=False, tint=None):
    a = sprite(40, 56)
    cx = 20
    if fallen:
        # lying on the ground, face up
        a.limb((6, 50), (18, 50), 5.4, PANTS, INK, OW)
        a.limb((8, 47.5), (18, 47.5), 5.0, PANTS_SH, INK, OW)
        a.blob([(16, 44), (30, 44), (31, 52), (16, 52)], SHIRT, INK, OW, 2)
        a.oval(34, 47, 5.6, 5.4, SKIN, INK, OW)
        a.ellipse(30.5, 41.5, 8, 5, HAIR)
        a.limb((22, 44), (28, 40), 3.4, SKIN, INK, OW)
        if tint:
            tint_img(a, tint[:3], tint[3] / 255)
        return a

    hip = (cx + lean * 0.3, 32 + bob)
    neck = (cx + lean, 19 + bob)
    th_b, sh_b, th_f, sh_f = legs
    # back leg + back arm first
    leg(a, (hip[0] - 1, hip[1]), th_b, sh_b, PANTS, dark=True)
    if cheer:
        arm(a, (neck[0] - 3, neck[1] + 2), 205, 195, dark=True)
    else:
        arm(a, (neck[0] - 2, neck[1] + 2), arms[0], arms[1], dark=True)
    leg(a, (hip[0] + 1, hip[1]), th_f, sh_f, PANTS)

    # torso: loose white camisa, sash of pants at the waist
    torso = [(neck[0] - 5.5, neck[1] + 0.5), (neck[0] + 5.5, neck[1] + 0.5), (hip[0] + 6.2, hip[1] - 1),
             (hip[0] + 5.8, hip[1] + 2.5), (hip[0] - 5.8, hip[1] + 2.5), (hip[0] - 6.2, hip[1] - 1)]
    a.blob(torso, SHIRT, INK, OW, 2)
    with a.layer(opacity=0.9):
        a.poly([(hip[0] - 5.6, hip[1] - 3), (hip[0] + 5.8, hip[1] - 3), (hip[0] + 5.6, hip[1] + 2.2), (hip[0] - 5.6, hip[1] + 2.2)],
               SHIRT_SH, smooth=1)
    a.line([(neck[0] + 1, neck[1] + 2), (hip[0] + 1.4, hip[1] - 3)], SHIRT_SH, 0.6)
    a.rect(hip[0] - 6, hip[1] + 0.5, 12, 2.4, PANTS_SH, INK, 0.5, radius=1)
    # red bandana knotted around the neck
    a.blob([(neck[0] - 4.8, neck[1] - 0.8), (neck[0] + 4.8, neck[1] - 0.8), (neck[0] + 3.2, neck[1] + 3.4), (neck[0] - 3.2, neck[1] + 3.4)],
           BANDANA, INK, OW * 0.8, 2)
    a.poly([(neck[0] - 3.8, neck[1] + 2), (neck[0] - 6.4, neck[1] + 6.5), (neck[0] - 2.4, neck[1] + 3.6)], shade(BANDANA, 0.85))

    # head
    hx, hy = neck[0] + 0.6, neck[1] - 7.4
    a.oval(hx, hy, 6.8, 7.2, SKIN, INK, OW)
    a.ellipse(hx - 6.6, hy - 1.2, 3.2, 4.0, SKIN_SH)  # ear side shading
    a.oval(hx - 4.8, hy + 0.6, 1.5, 2.0, SKIN, INK, OW * 0.7)  # ear
    # hair: short black crop with a fringe
    a.blob([(hx - 7.2, hy + 0.5), (hx - 7.0, hy - 5), (hx - 2, hy - 8.4), (hx + 4.8, hy - 7.6), (hx + 7.4, hy - 3.4),
            (hx + 6.0, hy - 2.4), (hx + 2.6, hy - 4.6), (hx - 3.0, hy - 3.2), (hx - 4.6, hy + 0.6)], HAIR, INK, OW * 0.6, 2)
    # face (facing right)
    if cheer:
        a.line([(hx + 1.6, hy + 0.2), (hx + 2.6, hy - 0.8), (hx + 3.6, hy + 0.2)], INK, 0.8)
        a.poly([(hx + 1.8, hy + 3.0), (hx + 5.4, hy + 3.0), (hx + 3.8, hy + 5.0)], (130, 40, 40))
    else:
        a.oval(hx + 3.0, hy + 0.3, 0.95, 1.35, INK, None, 0)
        a.circle(hx + 3.3, hy - 0.1, 0.35, (255, 255, 255))
        a.line([(hx + 1.6, hy - 2.4), (hx + 4.2, hy - 2.7)], INK, 0.7)
        a.line([(hx + 2.8, hy + 4.2), (hx + 4.8, hy + 3.9)], shade(SKIN_SH, 0.8), 0.7)
    a.ellipse(hx + 1.0, hy + 2.0, 2.8, 1.6, (224, 128, 110, 255))  # cheek

    # front arm (+ sumpak bamboo gun when shooting)
    if cheer:
        arm(a, (neck[0] + 3, neck[1] + 2), 150, 160)
    elif weapon:
        hand = arm(a, (neck[0] + 2, neck[1] + 2), 100 + arms[2], 95 + arms[3], fist=False)
        base = (hand[0] - 4, hand[1] + 1)
        tip = (hand[0] + 9, hand[1] - 1.5)
        a.limb(base, tip, 3.6, SUMPAK, INK, OW)
        for t in (0.3, 0.65):
            pt = (base[0] + (tip[0] - base[0]) * t, base[1] + (tip[1] - base[1]) * t)
            a.line([(pt[0], pt[1] - 1.9), (pt[0], pt[1] + 1.9)], shade(SUMPAK, 0.7), 0.7)
        a.oval(hand[0], hand[1], 2.1, 2.1, SKIN, INK, OW * 0.8)
    else:
        arm(a, (neck[0] + 2, neck[1] + 2), arms[2], arms[3])
    if tint:
        tint_img(a, tint[:3], tint[3] / 255)
    return a


def gen_player():
    p = lambda n: path("player", n)
    stand = (4, 2, -4, -2)
    draw_farmer(stand, bob=0).save(p("farmer_idle_0.png"))
    draw_farmer(stand, arms=(12, -6, -12, 6), bob=0.7).save(p("farmer_idle_1.png"))
    walk = [(-18, -26, 18, 6), (-4, -14, 4, -4), (18, 6, -18, -26), (4, -4, -4, -14)]
    for i, lg in enumerate(walk):
        sw = [22, 0, -22, 0][i]
        draw_farmer(lg, arms=(-sw, -sw - 10, sw, sw + 10), bob=[0, -0.8, 0, -0.8][i], lean=0.6).save(p(f"farmer_walk_{i}.png"))
    run = [(-34, -50, 34, 14), (-6, -40, 10, -10), (34, 14, -34, -50), (10, -10, -6, -40)]
    for i, lg in enumerate(run):
        sw = [40, 0, -40, 0][i]
        draw_farmer(lg, arms=(-sw, -sw - 40, sw, sw + 60), bob=[0, -1.6, 0, -1.6][i], lean=2.2).save(p(f"farmer_run_{i}.png"))
    draw_farmer((-20, -60, 40, -20), arms=(-140, -120, 130, 110), bob=-1).save(p("farmer_jump_0.png"))
    draw_farmer((10, -10, -20, 10), arms=(-120, -150, 120, 150), bob=0).save(p("farmer_fall_0.png"))
    draw_farmer(stand, arms=(20, -10, 0, 0), weapon=True).save(p("farmer_shoot_0.png"))
    draw_farmer(stand, arms=(20, -10, 8, 8), weapon=True, lean=-1.2).save(p("farmer_shoot_1.png"))
    draw_farmer((10, 0, -16, -10), arms=(-40, -70, -40, -60), lean=-2.4, tint=(255, 60, 60, 90)).save(p("farmer_hurt_0.png"))
    draw_farmer((10, 0, -16, -10), arms=(-40, -70, -40, -60), lean=2.0, tint=(255, 60, 60, 60)).save(p("farmer_death_0.png"))
    a = draw_farmer((40, -10, -10, -30), arms=(-60, -90, -70, -100), bob=5, lean=3.0, tint=(255, 60, 60, 70))
    rotate_art(a, -22, (20, 50))
    a.save(p("farmer_death_1.png"))
    draw_farmer(fallen=True, tint=(120, 120, 120, 70)).save(p("farmer_death_2.png"))
    draw_farmer(stand, cheer=True).save(p("farmer_victory_0.png"))
    draw_farmer((8, 0, -8, 0), cheer=True, bob=-2).save(p("farmer_victory_1.png"))


# ================================================================ TYANAK =====
TY = (122, 138, 104)
TY_SH = (92, 108, 80)
TY_EYE = (236, 40, 36)


def draw_tyanak(crawl=0, attack=False, hurt=False, dead=False):
    a = sprite(34, 26)
    skin = TY_SH if hurt else TY
    if dead:
        a.blob([(4, 22), (8, 16), (20, 15), (26, 18), (26, 23), (6, 24)], skin, INK, OW)
        a.oval(27, 19, 6, 5, skin, INK, OW)
        for dx in (-2, 2):
            a.line([(27 + dx - 1.2, 17.8), (27 + dx + 1.2, 20.2)], INK, 0.8)
            a.line([(27 + dx - 1.2, 20.2), (27 + dx + 1.2, 17.8)], INK, 0.8)
        return a
    o = 2.5 if crawl else 0
    # back limbs
    a.limb((9, 17), (5 - o, 24), 3.2, TY_SH, INK, OW)
    a.limb((19, 16), (15 + o, 24), 3.0, TY_SH, INK, OW)
    # chubby body (baby proportions), diaper-cloth wrap
    a.oval(14, 16, 9.5, 5.6, skin, INK, OW)
    a.blob([(6, 17), (12, 14.5), (13, 21), (7, 21.5)], (214, 204, 180), INK, 0.8, 2)
    # front limbs
    a.limb((10, 18), (8 + o, 24.5), 3.4, skin, INK, OW)
    a.limb((20, 17), (22 - o, 24.5), 3.4, skin, INK, OW)
    for fx in (8 + o, 22 - o):
        a.oval(fx, 24.4, 1.8, 1.2, skin, INK, 0.7)
    # big head with wisps of hair
    hx, hy = 26, 10.5 - (1 if attack else 0)
    a.oval(hx, hy, 7.2, 7.0, skin, INK, OW)
    for k in range(4):
        a.line([(hx - 3 + k * 1.8, hy - 6.4), (hx - 4 + k * 2.2, hy - 9)], INK, 0.6)
    a.ellipse(hx - 4, hy + 1, 3, 3, TY_SH)
    # glowing eyes
    a.radial_glow(hx + 3, hy - 1, 3.5, (255, 60, 40, 220))
    for ex in (hx + 0.8, hx + 4.4):
        a.oval(ex, hy - 1, 1.5, 1.3, TY_EYE, INK, 0.5)
        a.circle(ex + 0.3, hy - 1.3, 0.4, (255, 220, 200))
    if attack:
        a.blob([(hx, hy + 2.4), (hx + 6, hy + 2.2), (hx + 5, hy + 5.6), (hx + 1, hy + 5.4)], (70, 16, 20), INK, 0.6, 1)
        for tx in (hx + 1.4, hx + 3, hx + 4.6):
            a.poly([(tx - 0.6, hy + 2.5), (tx + 0.6, hy + 2.5), (tx, hy + 3.9)], (250, 250, 240))
    else:
        a.line([(hx + 1.4, hy + 3.4), (hx + 5, hy + 3)], INK, 0.7)
        a.poly([(hx + 4.2, hy + 3.1), (hx + 5, hy + 3.0), (hx + 4.7, hy + 4.2)], (250, 250, 240))
    return a


# =========================================================== MANANANGGAL =====
MN_SKIN = (226, 196, 184)
MN_SKIN_SH = (196, 160, 150)
MN_WING = (90, 24, 40)
MN_WING_SH = (58, 14, 26)
MN_HAIR = (22, 18, 26)
MN_DRESS = (128, 36, 52)


def bat_wing(a, root, side, lift, scale=1.0):
    """Membrane wing with finger bones; side = -1 (left) / +1 (right)."""
    rx, ry = root
    tips = [(rx + side * 26 * scale, ry - 14 * scale - lift), (rx + side * 30 * scale, ry - 2 * scale - lift * 0.5),
            (rx + side * 24 * scale, ry + 9 * scale - lift * 0.2), (rx + side * 12 * scale, ry + 13 * scale)]
    elbow = (rx + side * 14 * scale, ry - 10 * scale - lift * 0.8)
    pts = [root, elbow, tips[0]]
    for i in range(1, len(tips)):
        prev = tips[i - 1]
        cur = tips[i]
        mid = ((prev[0] + cur[0]) / 2 - side * 3 * scale, (prev[1] + cur[1]) / 2)
        pts += [mid, cur]
    pts.append((rx, ry + 7 * scale))
    a.poly(pts, MN_WING, INK, OW)
    with a.layer(opacity=0.5):
        a.poly([root, elbow, tips[0], tips[1], (rx, ry + 4)], MN_WING_SH)
    a.line([root, elbow, tips[0]], shade(MN_WING, 0.55), 1.2)
    for t in tips[1:]:
        a.line([elbow, t], shade(MN_WING, 0.55), 0.8)


def draw_manananggal_upper(flap=0, dive=False, dead=False):
    a = sprite(56, 52)
    cx, cy = 28, 27
    if dead:
        bat_wing(a, (cx - 4, cy + 10), -1, -12, 0.8)
        bat_wing(a, (cx + 4, cy + 10), 1, -12, 0.8)
        a.blob([(cx - 7, cy + 6), (cx + 7, cy + 6), (cx + 6, cy + 18), (cx - 6, cy + 18)], MN_SKIN_SH, INK, OW)
        a.oval(cx, cy + 4, 5.5, 5, MN_SKIN_SH, INK, OW)
        a.blob([(cx - 7, cy + 2), (cx + 7, cy + 2), (cx + 9, cy + 12), (cx - 9, cy + 12)], MN_HAIR, INK, 0.6)
        return a
    lift = 8 if flap else -4
    bat_wing(a, (cx - 4, cy - 2), -1, lift)
    bat_wing(a, (cx + 4, cy - 2), 1, lift)
    # long black hair behind the body
    a.blob([(cx - 8, cy - 18), (cx + 8, cy - 18), (cx + 10, cy + 2), (cx + 7, cy + 10), (cx - 7, cy + 10), (cx - 10, cy + 2)],
           MN_HAIR, INK, OW * 0.6)
    # torso ending in a ragged dark trail (severed at the waist)
    tl = 22 if dive else 16
    a.blob([(cx - 6.5, cy - 7), (cx + 6.5, cy - 7), (cx + 5.5, cy + tl - 8), (cx + 2, cy + tl - 5), (cx - 1, cy + tl - 7),
            (cx - 4, cy + tl - 4), (cx - 5.5, cy + tl - 8)], MN_DRESS, INK, OW, 2)
    a.blob([(cx - 5, cy - 7), (cx + 5, cy - 7), (cx + 4, cy - 2), (cx - 4, cy - 2)], MN_SKIN, INK, 0.6, 2)
    with a.layer(blur=1.2, opacity=0.8):
        a.ellipse(cx - 6, cy + tl - 7, 12, 6, (40, 10, 20))
    # clawed arms reaching forward
    a.limb((cx + 4, cy - 5), (cx + 11, cy + 1), 2.6, MN_SKIN, INK, OW)
    a.limb((cx + 11, cy + 1), (cx + 16, cy - 2), 2.2, MN_SKIN, INK, OW)
    for k in range(3):
        a.line([(cx + 16, cy - 2), (cx + 18.5, cy - 3.5 + k * 1.6)], INK, 0.6)
    # face
    hx, hy = cx, cy - 13
    a.oval(hx, hy, 5.8, 6.4, MN_SKIN, INK, OW)
    a.blob([(hx - 6.4, hy - 1), (hx - 5.8, hy - 5.4), (hx, hy - 7.4), (hx + 5.8, hy - 5.4), (hx + 6.4, hy - 1), (hx + 3, hy - 4), (hx - 3, hy - 4)],
           MN_HAIR, INK, 0.5, 2)
    a.radial_glow(hx, hy, 5, (255, 40, 40, 170))
    for ex in (hx - 2.2, hx + 2.2):
        a.poly([(ex - 1.5, hy - 0.4), (ex + 1.5, hy - 1.0), (ex + 1.0, hy + 0.6), (ex - 1.2, hy + 0.5)], (240, 40, 40))
    a.blob([(hx - 2, hy + 2.8), (hx + 2, hy + 2.8), (hx + 1.2, hy + 4.2), (hx - 1.2, hy + 4.2)], (110, 20, 30), None, 0, 1)
    a.poly([(hx - 1.2, hy + 2.9), (hx - 0.6, hy + 2.9), (hx - 0.9, hy + 4.4)], (250, 250, 240))
    a.poly([(hx + 0.6, hy + 2.9), (hx + 1.2, hy + 2.9), (hx + 0.9, hy + 4.4)], (250, 250, 240))
    if dive:
        rotate_art(a, -18, (cx, cy))
    return a


def draw_manananggal_lower(run=0, attack=False, dead=False):
    a = sprite(26, 36)
    if dead:
        a.blob([(3, 30), (8, 25), (19, 25), (23, 30), (20, 34), (5, 34)], MN_DRESS, INK, OW)
        a.limb((18, 32), (25, 33), 2.6, MN_SKIN_SH, INK, OW)
        return a
    o = 3 if run else 0
    # legs
    if attack:
        a.limb((10, 16), (6, 33), 3.6, MN_SKIN_SH, INK, OW)
        a.limb((15, 16), (24, 12), 3.6, MN_SKIN, INK, OW)
    else:
        a.limb((10, 16), (7 - o, 33), 3.6, MN_SKIN_SH, INK, OW)
        a.limb((15, 16), (18 + o, 33), 3.6, MN_SKIN, INK, OW)
    for fx, fy in ((7 - o if not attack else 6, 33.5), ((18 + o) if not attack else 25, 33.5 if not attack else 12)):
        a.oval(fx + 1, fy, 2.4, 1.3, (60, 40, 40), INK, 0.6)
    # saya (long skirt) + ragged waist
    a.blob([(6, 4), (19, 4), (22, 19), (18, 21), (13, 19.5), (8, 21), (3, 19)], MN_DRESS, INK, OW, 2)
    a.line([(7, 9), (6, 18)], shade(MN_DRESS, 0.75), 0.8)
    a.line([(13, 9), (13, 18)], shade(MN_DRESS, 0.75), 0.8)
    a.line([(18, 9), (20, 18)], shade(MN_DRESS, 0.75), 0.8)
    a.blob([(6, 4), (9, 1.5), (12, 3.5), (15, 1.2), (19, 4), (12.5, 6)], (70, 14, 24), INK, 0.6, 1)
    return a


# ============================================================= TIKBALANG =====
TB = (118, 80, 50)
TB_SH = (88, 58, 36)
TB_MANE = (30, 24, 22)


def draw_tikbalang(run=0, attack=False, hurt=False, dead=False):
    a = sprite(50, 60)
    body = TB_SH if hurt else TB
    if dead:
        a.blob([(4, 50), (10, 42), (32, 41), (40, 45), (40, 52), (6, 54)], body, INK, OW)
        a.blob([(34, 40), (46, 36), (48, 44), (40, 48)], body, INK, OW)
        a.blob([(30, 38), (36, 36), (38, 42), (32, 44)], TB_MANE, None, 0)
        return a
    o = 5 if run else 0
    # long bony legs ending in hooves (back pair darker)
    def hleg(hip, deg1, deg2, col):
        knee = pol(hip[0], hip[1], 11, deg1)
        foot = pol(knee[0], knee[1], 12, deg2)
        a.limb(hip, knee, 4.4, col, INK, OW)
        a.limb(knee, foot, 3.4, col, INK, OW)
        a.blob([(foot[0] - 2.4, foot[1] - 1), (foot[0] + 2.8, foot[1] - 1), (foot[0] + 3.2, foot[1] + 2.4), (foot[0] - 2.6, foot[1] + 2.4)],
               (40, 30, 26), INK, 0.6, 1)
    hleg((20, 33), -20 + o * 4, 10 - o * 2, TB_SH)
    # lean torso
    a.blob([(17, 12), (27, 12), (30, 24), (27, 35), (17, 35), (15, 24)], body, INK, OW, 2)
    a.line([(20, 18), (26, 18)], shade(body, 0.75), 0.6)
    a.line([(20, 22), (26, 22)], shade(body, 0.75), 0.6)
    a.blob([(15, 29), (29, 29), (30, 36), (14, 36)], (70, 56, 40), INK, 0.8, 1)  # loincloth
    hleg((24, 34), 20 - o * 4, -8 + o * 2, body)
    # arms: back arm swings, front arm swipes on attack
    a.limb((18, 15), (10, 27 - o), 3.2, TB_SH, INK, OW)
    if attack:
        a.limb((26, 15), (36, 12), 3.4, body, INK, OW)
        a.limb((36, 12), (45, 16), 3.0, body, INK, OW)
        for k in range(3):
            a.line([(45, 16), (48.5, 14 + k * 2)], INK, 0.7)
    else:
        a.limb((26, 15), (31, 26 + o), 3.4, body, INK, OW)
    # horse head, long mane down the back
    a.blob([(18, 4), (22, -1), (26, 10), (22, 22), (16, 18)], TB_MANE, INK, 0.6, 2)
    head = [(22, 2), (30, -1), (40, 5), (45, 11), (43, 15), (35, 14), (27, 13), (22, 9)]
    a.blob(head, body, INK, OW, 2)
    a.blob([(38, 8), (45, 11), (43, 15), (37, 13.5)], shade(body, 0.8), None, 0, 2)
    a.poly([(26, 2), (27, -5), (30, 0.5)], body, INK, 0.8)
    a.circle(43, 11.5, 0.8, INK)
    a.radial_glow(33, 5, 3.4, (255, 200, 60, 200))
    a.oval(33, 5, 1.6, 1.2, (255, 220, 90), INK, 0.5)
    a.circle(33.4, 5, 0.6, INK)
    a.line([(36, 14), (42, 14.5)], INK, 0.7)
    return a


# ================================================================= KAPRE =====
KP = (70, 52, 40)
KP_SH = (50, 36, 28)
KP_HAIR = (34, 26, 22)
KP_BAHAG = (150, 44, 40)


def draw_kapre(sway=0, attack=False, dead_stage=0):
    a = sprite(100, 128)
    cx = 50 + sway
    if dead_stage:
        h = [0, 64, 40, 22][dead_stage]
        a.blob([(8, 126), (14, 126 - h * 0.7), (40, 126 - h), (70, 126 - h * 0.9), (92, 126 - h * 0.4), (94, 127)], KP_SH, INK, OW * 1.4)
        with a.layer(opacity=0.5):
            for k in range(20):
                x = 14 + k * 4
                a.line([(x, 126 - h * 0.6), (x + 2, 127)], KP_HAIR, 1.2)
        return a
    # legs (tree-trunk thick)
    a.limb((cx - 14, 84), (cx - 17, 120), 15, KP_SH, INK, OW * 1.3)
    a.limb((cx + 14, 84), (cx + 17, 120), 15, KP_SH, INK, OW * 1.3)
    for fx in (cx - 18, cx + 18):
        a.oval(fx, 123, 10, 4, (40, 30, 24), INK, OW)
    # shaggy body
    body = [(cx - 30, 36), (cx - 14, 26), (cx + 14, 26), (cx + 30, 36), (cx + 34, 64), (cx + 26, 90), (cx - 26, 90), (cx - 34, 64)]
    a.blob(body, KP, INK, OW * 1.4, 2)
    with a.layer(opacity=0.6):
        rnd = seeded(9)
        for k in range(90):
            x = rnd.uniform(cx - 30, cx + 30)
            y = rnd.uniform(34, 88)
            a.line([(x, y), (x + rnd.uniform(-2, 2), y + rnd.uniform(4, 8))], KP_HAIR, 1.0)
    # bahag loincloth
    a.blob([(cx - 26, 78), (cx + 26, 78), (cx + 24, 88), (cx + 6, 88), (cx + 4, 104), (cx - 4, 104), (cx - 6, 88), (cx - 24, 88)],
           KP_BAHAG, INK, OW, 1)
    a.line([(cx - 25, 82), (cx + 25, 82)], (230, 190, 90), 1.2)
    # arms
    arm_y = 38 + sway
    a.limb((cx - 30, arm_y), (cx - 40, arm_y + 26), 12, KP, INK, OW * 1.3)
    a.limb((cx - 40, arm_y + 26), (cx - 38, arm_y + 46), 10, KP, INK, OW * 1.3)
    a.oval(cx - 38, arm_y + 49, 6, 5, KP_SH, INK, OW)
    if attack:
        a.limb((cx + 30, arm_y), (cx + 38, arm_y + 16), 12, KP, INK, OW * 1.3)
        a.limb((cx + 38, arm_y + 16), (cx + 20, 26), 10, KP, INK, OW * 1.3)
        hand = (cx + 20, 26)
    else:
        a.limb((cx + 30, arm_y), (cx + 40, arm_y + 26), 12, KP, INK, OW * 1.3)
        a.limb((cx + 40, arm_y + 26), (cx + 38, arm_y + 46), 10, KP, INK, OW * 1.3)
        hand = (cx + 38, arm_y + 49)
    # head: wild hair mane and beard
    hx, hy = cx, 20
    a.blob([(hx - 24, hy + 4), (hx - 20, hy - 12), (hx - 6, hy - 19), (hx + 10, hy - 18), (hx + 22, hy - 10), (hx + 26, hy + 6),
            (hx + 20, hy + 20), (hx - 18, hy + 20)], KP_HAIR, INK, OW, 2)
    a.oval(hx, hy, 14, 13, KP, INK, OW)
    a.blob([(hx - 12, hy + 4), (hx + 12, hy + 4), (hx + 10, hy + 18), (hx, hy + 24), (hx - 10, hy + 18)], KP_HAIR, INK, 0.8, 2)
    a.line([(hx - 9, hy - 5), (hx - 2, hy - 3)], INK, 1.6)
    a.line([(hx + 9, hy - 5), (hx + 2, hy - 3)], INK, 1.6)
    a.radial_glow(hx, hy, 12, (255, 150, 40, 170))
    for ex in (hx - 5, hx + 5):
        a.oval(ex, hy, 2.6, 2.0, (255, 196, 70), INK, 0.6)
        a.circle(ex, hy, 1.0, (120, 30, 10))
    a.oval(hx, hy + 6, 3, 2.2, KP_SH, INK, 0.6)
    # cigar (tabako) with glowing ember
    cig_a = (hx + 6, hy + 11)
    cig_b = (hx + 20, hy + 7) if not attack else (hx + 18, hy + 4)
    a.limb(cig_a, cig_b, 3.2, (150, 100, 60), INK, 0.8)
    a.radial_glow(cig_b[0], cig_b[1], 6, (255, 120, 30, 230))
    a.circle(cig_b[0], cig_b[1], 1.8, (255, 170, 60))
    with a.layer(blur=1.2, opacity=0.7):
        for k in range(4):
            a.circle(cig_b[0] + 3 + k * 2.5, cig_b[1] - 4 - k * 4, 2 + k * 1.2, (220, 220, 220))
    if attack:
        a.oval(hand[0], hand[1], 5, 4.4, KP_SH, INK, OW)
    return a


# ======================================================== BALETE TREE =======
TR_BARK = (104, 78, 56)
TR_BARK_SH = (74, 54, 38)
TR_LEAF = (54, 112, 58)
TR_LEAF_HI = (84, 146, 74)
TR_LEAF_SH = (34, 80, 44)


def draw_tree(state="full"):
    a = sprite(140, 180)
    if state == "fallen":
        a.blob([(6, 168), (10, 158), (96, 156), (104, 164), (100, 172), (8, 174)], TR_BARK, INK, OW * 1.4, 2)
        for x in range(14, 96, 8):
            a.line([(x, 159), (x + 4, 171)], TR_BARK_SH, 1.0)
        for cx_, cy_, r in [(108, 150, 22), (124, 160, 18), (116, 166, 16)]:
            a.oval(cx_, cy_, r, r * 0.7, TR_LEAF_SH, INK, OW)
        return a
    shift = {"full": 0, "shake": 3, "falling": 0}[state]
    # strangler-fig trunk: many twisting aerial roots braided together
    base_y = 178
    a.blob([(46, base_y), (54, 140), (58, 100), (82, 100), (88, 140), (96, base_y)], TR_BARK, INK, OW * 1.4, 2)
    rnd = seeded(3)
    for k in range(9):
        x0 = 50 + k * 5 + rnd.uniform(-2, 2)
        pts = [(x0, base_y), (x0 + rnd.uniform(-4, 4), 150), (x0 + rnd.uniform(-3, 3), 124), (62 + k * 2.2, 100)]
        a.line(pts, shade(TR_BARK, rnd.uniform(0.75, 1.15)), 2.2, smooth=2)
    for rx in (40, 102):
        a.line([(rx + (6 if rx < 70 else -6), 112), (rx, 150), (rx - (4 if rx < 70 else -4), base_y)], TR_BARK_SH, 2.4, smooth=2)
    for k in range(6):
        x = 58 + k * 5
        a.line([(x, 104), (x + rnd.uniform(-2, 2), 128 + rnd.uniform(0, 14))], shade(TR_BARK_SH, 0.9), 0.8)
    # dense crown
    cx = 70 + shift
    blobs = [(-42, 80, 30), (42, 78, 30), (-22, 54, 34), (22, 50, 36), (0, 32, 34), (-50, 96, 20), (50, 96, 22), (0, 72, 38)]
    for dx, cy, r in blobs:
        a.oval(cx + dx, cy, r, r * 0.82, TR_LEAF_SH, INK, OW * 1.2)
    for dx, cy, r in blobs:
        a.ellipse(cx + dx - r * 0.8, cy - r * 0.78, r * 1.4, r * 1.2, TR_LEAF)
        a.ellipse(cx + dx - r * 0.55, cy - r * 0.7, r * 0.8, r * 0.6, TR_LEAF_HI)
    # hanging vines
    for vx in (36, 52, 88, 104):
        a.line([(vx + shift, 90), (vx + shift + 1, 116 + (vx % 3) * 6)], TR_LEAF_SH, 1.1)
    # a pair of eyes glinting in the leaves (the Kapre's home)
    a.radial_glow(cx + 14, 60, 5, (255, 170, 60, 150))
    if state == "shake":
        for k in range(5):
            x = rnd.uniform(20, 120)
            a.oval(x, rnd.uniform(110, 150), 3, 1.6, TR_LEAF_HI, INK, 0.6)
    if state == "falling":
        rotate_art(a, -16, (70, 178))
    return a


# ================================================== PROJECTILES / FX ========
def rock():
    a = sprite(12, 12)
    a.blob([(2, 6), (4, 2.2), (8.6, 1.6), (10.6, 5.2), (9, 10), (4, 10.4)], (132, 124, 112), INK, 0.8, 2)
    a.ellipse(4, 3.5, 3.6, 2.2, (186, 178, 166))
    return a


def smoke(n):
    a = sprite(32, 32)
    base = 196 + n * 18
    with a.layer(blur=1.6 + n * 0.6):
        rnd = seeded(20 + n)
        for i in range(5 + n):
            r = 5 + n * 1.5 + rnd.uniform(0, 3)
            a.circle(16 + rnd.uniform(-7, 7), 16 + rnd.uniform(-6, 6), r, (base - 30, base - 30, base - 22, 230 - n * 40))
        for i in range(3):
            a.circle(13 + i * 3, 13 + (i % 2) * 2, 4 + n, (base, base, base + 4, 200 - n * 40))
    return a


def charge_glow(n):
    a = sprite(40, 40)
    r = 6 + n * 3.5
    a.radial_glow(20, 20, r * 1.15, (255, 170 + n * 25, 60, 255))
    a.circle(20, 20, r * 0.45, (255, 246, 210, 255))
    for k in range(6 + n * 2):
        ang = k * math.tau / (6 + n * 2)
        a.line([(20 + math.cos(ang) * r * 0.6, 20 + math.sin(ang) * r * 0.6),
                (20 + math.cos(ang) * r * 1.1, 20 + math.sin(ang) * r * 1.1)], (255, 214, 120), 1.0)
    return a


def spark(n):
    a = sprite(28, 28)
    r = 4 + n * 3.5
    a.radial_glow(14, 14, r * 0.9, (255, 220, 110, 200))
    for k in range(8):
        ang = k * math.tau / 8
        L = r if k % 2 == 0 else r * 0.6
        a.line([(14, 14), (14 + math.cos(ang) * L, 14 + math.sin(ang) * L)], (255, 236, 150), 1.4 if k % 2 == 0 else 0.9)
    return a


def victory_burst(n):
    a = sprite(48, 48)
    rnd = seeded(n)
    cols = [(255, 210, 70), (232, 72, 70), (60, 120, 220), (250, 250, 250)]
    for i in range(14):
        x, y = rnd.uniform(4, 44), rnd.uniform(4, 44)
        c = cols[i % 4]
        if i % 3 == 0:
            for k in range(5):
                ang = k * math.tau / 5 - math.pi / 2
                a.line([(x, y), (x + math.cos(ang) * 3, y + math.sin(ang) * 3)], c, 1.1)
        else:
            a.rect(x, y, 2.6, 1.6, c, radius=0.6)
    return a


# ========================================================= JEEPNEY ==========
J_RED = (206, 44, 48)
J_RED_SH = (156, 28, 34)
J_YELLOW = (250, 200, 52)
J_BLUE = (40, 96, 190)
CHROME = (226, 230, 236)
CHROME_SH = (160, 168, 180)


def draw_jeepney():
    w, h = 176, 72
    a = sprite(w, h)
    body_y = 14
    # chassis shadow
    with a.layer(blur=2, opacity=0.35):
        a.ellipse(10, 60, 156, 10, (0, 0, 0))
    # passenger body
    a.rect(6, body_y, 128, 38, J_RED, INK, OW * 1.3, radius=5)
    a.rect(6, body_y + 26, 128, 12, J_RED_SH, None, 0, radius=4)
    # stripes (Philippine flag colors) + side art
    a.rect(6, body_y + 21, 128, 3, J_YELLOW)
    a.rect(6, body_y + 24.5, 128, 2.2, J_BLUE)
    for i, x in enumerate(range(16, 130, 18)):
        a.circle(x, body_y + 32, 2.6, [J_YELLOW, (255, 255, 255), J_BLUE][i % 3], INK, 0.5)
    # windows with passengers' silhouettes
    for i in range(4):
        wx = 14 + i * 29
        a.rect(wx, body_y + 4, 23, 15, (170, 214, 232), INK, 0.9, radius=2)
        with a.layer(opacity=0.5):
            a.poly([(wx + 3, body_y + 18), (wx + 12, body_y + 5), (wx + 17, body_y + 5), (wx + 8, body_y + 18)], (255, 255, 255))
        if i % 2 == 0:
            a.circle(wx + 16, body_y + 12, 3.2, (60, 44, 36))
            a.rect(wx + 12, body_y + 15, 8, 4, (90, 120, 160))
    # roof rack & chrome trim with little flags
    a.rect(2, body_y - 7, 134, 8, CHROME, INK, OW, radius=3)
    a.rect(2, body_y - 4, 134, 2, CHROME_SH)
    for i in range(6):
        fx = 12 + i * 22
        a.line([(fx, body_y - 7), (fx, body_y - 14)], (90, 90, 90), 0.8)
        a.poly([(fx, body_y - 14), (fx + 6, body_y - 12), (fx, body_y - 10)], [J_YELLOW, J_BLUE, J_RED][i % 3])
    # front: chrome hood + grille + silver horse hood ornament
    a.blob([(130, body_y + 8), (160, body_y + 12), (172, body_y + 18), (172, body_y + 42), (130, body_y + 42)], CHROME, INK, OW * 1.3, 1)
    for gy in range(int(body_y + 22), int(body_y + 38), 3):
        a.line([(160, gy), (171, gy)], CHROME_SH, 0.8)
    a.rect(132, body_y + 2, 14, 18, (170, 214, 232), INK, 0.9, radius=2)
    a.circle(166, body_y + 18, 3, (255, 244, 190), INK, 0.8)
    a.blob([(150, body_y + 10), (153, body_y + 4), (157, body_y + 3), (158, body_y + 6), (155, body_y + 7), (156, body_y + 11)],
           CHROME, INK, 0.7, 1)
    a.rect(162, body_y + 40, 12, 4, CHROME_SH, INK, 0.7, radius=1)
    # wheels
    for wx in (36, 142):
        a.circle(wx, body_y + 44, 11, (34, 32, 32), INK, OW)
        a.circle(wx, body_y + 44, 5.5, CHROME, INK, 0.8)
        a.circle(wx, body_y + 44, 1.6, CHROME_SH)
        a.poly([(wx - 14, body_y + 36), (wx + 14, body_y + 36), (wx + 12, body_y + 32), (wx - 12, body_y + 32)], J_RED_SH, INK, 0.8)
    return a


def draw_interior_bg():
    w, h = 480, 270
    a = Art(w, h, out=2, ss=2)
    a.vgradient(0, 0, w, h, [(0, (120, 30, 36)), (1, (70, 16, 22))])
    # windows showing the passing countryside
    for i in range(3):
        wx = 40 + i * 150
        a.rect(wx - 4, 46, 128, 98, (60, 14, 18), None, 0, radius=8)
        a.vgradient(wx, 50, 120, 90, [(0, (120, 190, 232)), (0.7, (210, 236, 236)), (1, (210, 236, 236))])
        a.poly([(wx, 120), (wx + 30, 96), (wx + 70, 108), (wx + 120, 92), (wx + 120, 140), (wx, 140)], (98, 160, 90))
        a.poly([(wx, 130), (wx + 50, 118), (wx + 120, 126), (wx + 120, 140), (wx, 140)], (120, 180, 96))
        palm_x = wx + 30 + i * 20
        a.line([(palm_x, 140), (palm_x + 4, 104)], (110, 80, 52), 2)
        for ang in (-150, -110, -70, -30):
            r = math.radians(ang)
            a.line([(palm_x + 4, 104), (palm_x + 4 + math.cos(r) * 16, 104 + math.sin(r) * 6 + 8)], (60, 130, 60), 2, smooth=0)
        a.rect(wx - 4, 46, 128, 98, None, (220, 190, 110), 3, radius=8)
        a.line([(wx - 4, 95), (wx + 124, 95)], (220, 190, 110), 1.2)
    # roof lining + chrome handrail
    a.rect(0, 0, w, 34, (150, 36, 42))
    for x in range(0, w, 24):
        a.rect(x, 0, 12, 34, (170, 50, 56))
    a.rect(0, 30, w, 4, J_YELLOW)
    a.line([(0, 40), (w, 40)], CHROME, 3)
    for x in range(30, w, 60):
        a.line([(x, 34), (x, 40)], CHROME_SH, 1.5)
    # padded bench + floor
    a.rect(0, h - 96, w, 34, (180, 40, 48), INK, 1, radius=6)
    for x in range(0, w, 40):
        a.line([(x, h - 94), (x, h - 64)], (140, 26, 34), 1)
    a.rect(0, h - 62, w, 62, (60, 44, 40))
    for x in range(0, w, 30):
        a.line([(x, h - 62), (x - 20, h)], (80, 60, 52), 1)
    # rosary + sampaguita garland hanging from the rail
    a.line([(400, 40), (392, 70), (408, 70), (400, 40)], (236, 230, 210), 1)
    for k in range(8):
        a.circle(392 + k * 2, 70 + math.sin(k) * 1.5, 1.6, (250, 250, 240))
    a.line([(400, 72), (400, 82)], (200, 160, 60), 1.4)
    a.line([(396, 77), (404, 77)], (200, 160, 60), 1.4)
    # "BAYAD DITO" coin tray sign
    a.rect(250, h - 118, 70, 18, (250, 220, 90), INK, 1, radius=4)
    a.noise_overlay(3, seed=12)
    return a


def draw_driver(talk=False):
    a = sprite(28, 40)
    skin = (200, 146, 104)
    shirt = (60, 110, 170)
    # body + sando shirt, towel on the shoulder (classic manong driver)
    a.blob([(4, 40), (5, 22), (9, 18), (19, 18), (23, 22), (24, 40)], shirt, INK, OW, 2)
    a.blob([(17, 18), (22, 19), (24, 30), (20, 32)], (250, 250, 240), INK, 0.8, 1)
    a.limb((6, 22), (3, 34), 3.6, skin, INK, OW)
    a.limb((22, 22), (25, 34), 3.6, skin, INK, OW)
    a.rect(11, 15, 6, 5, skin)
    a.oval(14, 10, 7, 7.4, skin, INK, OW)
    # cap
    a.blob([(7, 8), (8, 3), (14, 1), (20, 3), (21, 8)], (230, 60, 50), INK, OW, 2)
    a.poly([(18, 7), (26, 8.5), (19, 9.5)], (190, 40, 36), INK, 0.6)
    a.circle(11.5, 10.5, 0.9, INK)
    a.circle(16.5, 10.5, 0.9, INK)
    a.line([(10, 13.2), (18, 13.2)], (60, 40, 30), 1.4)  # moustache
    if talk:
        a.oval(14, 15.2, 2.2, 1.4, (110, 36, 36), INK, 0.5)
    else:
        a.line([(12, 15.2), (16, 15.2)], INK, 0.7)
    return a


# ============================================================ UI ICONS ======
def heart(full=True):
    a = sprite(16, 14)
    col = (226, 48, 60) if full else (86, 70, 72)
    pts = [(8, 13), (1.2, 6.4), (0.8, 3.2), (3, 0.9), (6, 1), (8, 3.2), (10, 1), (13, 0.9), (15.2, 3.2), (14.8, 6.4)]
    a.blob(pts, col, INK, 0.9, 2)
    if full:
        a.ellipse(3, 2.4, 4, 2.6, (255, 170, 170))
    return a


def joystick_base():
    a = sprite(90, 90)
    with a.layer(opacity=0.55):
        a.circle(45, 45, 42, (30, 20, 16))
    a.circle(45, 45, 42, None, (250, 230, 190, 220), 2.4)
    a.circle(45, 45, 30, None, (250, 230, 190, 90), 1.2)
    for ang in (0, 180):
        r = math.radians(ang)
        cx, cy = 45 + math.cos(r) * 35, 45
        s = 1 if ang == 0 else -1
        a.poly([(cx + s * 5, cy), (cx - s * 2, cy - 5), (cx - s * 2, cy + 5)], (250, 230, 190, 230))
    return a


def joystick_knob():
    a = sprite(44, 44)
    a.circle(22, 22, 19, (220, 170, 80), INK, 1.4)
    a.circle(22, 22, 14, (240, 196, 110))
    a.ellipse(12, 9, 16, 9, (255, 236, 190))
    return a


def round_button(kind):
    a = sprite(72, 72)
    base = {"shoot": (200, 64, 54), "jump": (58, 140, 92), "generic": (80, 96, 160), "charge": (236, 170, 40)}[kind]
    with a.layer(blur=1.5, opacity=0.5):
        a.circle(36, 39, 32, (0, 0, 0))
    a.circle(36, 36, 32, shade(base, 0.7), INK, 1.6)
    a.circle(36, 34, 28, base)
    with a.layer(opacity=0.35):
        a.ellipse(14, 10, 44, 20, (255, 255, 255))
    ic = (255, 248, 230)
    if kind == "jump":
        a.poly([(36, 18), (52, 36), (42, 36), (42, 50), (30, 50), (30, 36), (20, 36)], ic, INK, 1.0)
    elif kind in ("shoot", "charge"):
        # rock flying out of a bamboo sumpak
        a.limb((18, 46), (40, 32), 7, (170, 120, 70), INK, 1.0)
        a.blob([(44, 22), (50, 19), (56, 23), (55, 30), (48, 31), (43, 27)], (190, 184, 170), INK, 1.0, 2)
        for k in range(3):
            a.line([(40 - k * 3, 20 + k * 3), (34 - k * 3, 24 + k * 3)], ic, 1.4)
    else:
        a.circle(36, 34, 8, ic, INK, 1)
    return a


def menu_button():
    a = sprite(200, 56)
    a.rect(2, 2, 196, 50, (150, 72, 40), INK, 2, radius=14)
    a.rect(8, 6, 184, 12, (230, 176, 110, 150), radius=6)
    return a


def puzzle_piece(idx):
    """Generic jigsaw-piece icon (kept for backwards compatibility)."""
    a = sprite(48, 48)
    cols = [(212, 94, 70), (80, 150, 190), (226, 180, 60), (100, 168, 92)]
    c = cols[idx % 4]
    a.rect(6, 10, 32, 32, c, INK, 1.4, radius=4)
    a.circle(22, 10, 6, c, INK, 1.4)
    a.circle(38, 26, 6, c, INK, 1.4)
    a.rect(8, 12, 28, 28, c, radius=3)
    a.rect(20, 7, 4, 8, c)
    a.rect(34, 24, 6, 4, c)
    return a


def coin_icon():
    a = sprite(24, 24)
    a.circle(12, 12, 10.5, (214, 160, 40), INK, 1)
    a.circle(12, 12, 8, (250, 208, 70))
    a.line([(9.5, 7), (9.5, 17)], (170, 120, 30), 1.6)
    a.line([(9.5, 7.6), (13.5, 7.6), (15, 9.6), (13.5, 11.6), (9.5, 11.6)], (170, 120, 30), 1.4)
    a.line([(8, 9), (16, 9)], (170, 120, 30), 0.8)
    a.line([(8, 10.4), (16, 10.4)], (170, 120, 30), 0.8)
    return a


def bayong(open_=False):
    a = sprite(64, 56)
    weave = (190, 150, 84)
    weave_sh = (150, 112, 58)
    body = [(8, 52), (4, 22), (10, 16), (54, 16), (60, 22), (56, 52)]
    a.blob(body, weave, INK, 1.4, 1)
    for y in range(20, 52, 5):
        a.line([(5, y), (59, y)], weave_sh, 0.8)
    for x in range(8, 58, 6):
        for y in range(20, 50, 10):
            a.line([(x, y), (x + 3, y + 5)], shade(weave, 1.12), 0.8)
    a.rect(4, 30, 56, 5, (170, 50, 50))
    a.rect(4, 36, 56, 2, (40, 90, 170))
    if open_:
        a.radial_glow(32, 12, 20, (255, 230, 120, 255))
        a.line([(12, 18), (6, 2)], weave_sh, 2.6)
        a.line([(52, 18), (58, 2)], weave_sh, 2.6)
        for k in range(5):
            a.circle(20 + k * 6, 10 - (k % 2) * 4, 2.2, (255, 244, 170))
    else:
        a.line([(16, 18), (18, 4), (32, 0.5), (46, 4), (48, 18)], weave_sh, 2.6, smooth=2)
    return a


def salakot_icon():
    a = sprite(32, 24)
    a.blob([(16, 2), (29, 16), (26, 18.5), (6, 18.5), (3, 16)], (206, 168, 96), INK, 1.0, 1)
    for k in range(-3, 4):
        a.line([(16, 3), (16 + k * 4, 18)], (170, 132, 70), 0.6)
    a.circle(16, 3, 1.6, (150, 110, 60), INK, 0.5)
    a.line([(8, 18.5), (16, 23), (24, 18.5)], (120, 90, 50), 0.6)
    return a


def kerchief_icon():
    # Week 17: the Traditional Kerchief had no icon of its own (used the Salakot's)
    a = sprite(32, 24)
    red, red_sh = (214, 52, 52), (160, 34, 38)
    a.blob([(5, 15), (8, 6), (16, 2.5), (24, 6), (27, 15), (16, 18)], red, INK, 1.0, 1)
    a.blob([(22, 13), (29, 19), (26, 22), (21, 17)], red_sh, INK, 0.8, 1)
    a.blob([(22, 13), (30, 12), (30, 16), (23, 16)], red_sh, INK, 0.8, 1)
    a.circle(22, 14.5, 2.0, red_sh, INK, 0.6)
    for x, y in ((11, 8), (16, 6), (21, 9), (13, 13), (19, 13.5)):
        a.circle(x, y, 1.1, (250, 236, 200))
    return a


def barong_icon():
    a = sprite(32, 32)
    a.blob([(9, 4), (13, 3), (16, 6), (19, 3), (23, 4), (30, 9), (27, 14), (25, 12), (25, 29), (7, 29), (7, 12), (5, 14), (2, 9)],
           (248, 242, 224), INK, 1.0, 1)
    for k in range(4):
        a.line([(16, 8 + k * 4), (13 + (k % 2) * 6, 10 + k * 4)], (200, 186, 150), 0.6)
    a.line([(16, 6), (16, 28)], (210, 196, 160), 0.6)
    return a


def pants_icon():
    a = sprite(32, 32)
    a.blob([(8, 3), (24, 3), (26, 29), (18.5, 29), (16, 13), (13.5, 29), (6, 29)], (112, 86, 58), INK, 1.0, 1)
    a.rect(8, 3, 16, 3, (86, 64, 42))
    return a


GROUPS = {}


def group(name):
    def deco(fn):
        GROUPS[name] = fn
        return fn
    return deco


@group("player")
def _g_player():
    gen_player()


@group("enemies")
def _g_enemies():
    ty = lambda n: path("enemies", "tyanak", n)
    draw_tyanak(crawl=0).save(ty("tyanak_crawl_0.png"))
    draw_tyanak(crawl=1).save(ty("tyanak_crawl_1.png"))
    draw_tyanak(attack=True).save(ty("tyanak_attack_0.png"))
    draw_tyanak(hurt=True).save(ty("tyanak_hurt.png"))
    draw_tyanak(dead=True).save(ty("tyanak_death_0.png"))
    d1 = draw_tyanak(dead=True)
    tint_img(d1, (40, 40, 40), 0.3)
    d1.save(ty("tyanak_death_1.png"))

    mn = lambda n: path("enemies", "manananggal", n)
    draw_manananggal_upper(flap=0).save(mn("upper_fly_0.png"))
    draw_manananggal_upper(flap=1).save(mn("upper_fly_1.png"))
    draw_manananggal_upper(dive=True).save(mn("upper_dive.png"))
    draw_manananggal_upper(dead=True).save(mn("upper_death.png"))
    draw_manananggal_lower(run=0).save(mn("lower_idle_0.png"))
    draw_manananggal_lower(run=1).save(mn("lower_idle_1.png"))
    draw_manananggal_lower(attack=True).save(mn("lower_attack.png"))
    draw_manananggal_lower(dead=True).save(mn("lower_death.png"))

    tb = lambda n: path("enemies", "tikbalang", n)
    draw_tikbalang(run=0).save(tb("tikbalang_run_0.png"))
    draw_tikbalang(run=1).save(tb("tikbalang_run_1.png"))
    draw_tikbalang(attack=True).save(tb("tikbalang_attack.png"))
    draw_tikbalang(hurt=True).save(tb("tikbalang_hurt.png"))
    draw_tikbalang(dead=True).save(tb("tikbalang_death_0.png"))
    d1 = draw_tikbalang(dead=True)
    tint_img(d1, (40, 40, 40), 0.3)
    d1.save(tb("tikbalang_death_1.png"))

    kp = lambda n: path("enemies", "kapre", n)
    draw_kapre(sway=0).save(kp("kapre_idle_0.png"))
    draw_kapre(sway=2).save(kp("kapre_idle_1.png"))
    draw_kapre(attack=True).save(kp("kapre_attack.png"))
    for i in range(3):
        draw_kapre(dead_stage=i + 1).save(kp(f"kapre_death_{i}.png"))

    for st in ("full", "shake", "falling", "fallen"):
        draw_tree(st).save(path("enemies", f"tree_{st}.png"))


@group("fx")
def _g_fx():
    rock().save(path("weapons", "rock_projectile.png"))
    for i in range(3):
        smoke(i).save(path("weapons", f"smoke_{i}.png"))
        charge_glow(i).save(path("ui", f"effect_charge_{i}.png"))
        spark(i).save(path("ui", f"effect_spark_{i}.png"))
        victory_burst(i).save(path("ui", f"effect_victory_{i}.png"))


@group("jeepney")
def _g_jeep():
    draw_jeepney().save(path("jeepney", "jeepney_side.png"))
    draw_interior_bg().save(path("jeepney", "jeepney_interior_bg.png"))
    draw_driver(talk=False).save(path("jeepney", "driver_idle.png"))
    draw_driver(talk=True).save(path("jeepney", "driver_talk_0.png"))
    draw_driver(talk=False).save(path("jeepney", "driver_talk_1.png"))


@group("ui")
def _g_ui():
    heart(True).save(path("ui", "heart_full.png"))
    heart(False).save(path("ui", "heart_empty.png"))
    joystick_base().save(path("ui", "joystick_base.png"))
    joystick_knob().save(path("ui", "joystick_knob.png"))
    for k in ("shoot", "jump", "generic", "charge"):
        round_button(k).save(path("ui", f"button_{k}.png"))
    menu_button().save(path("ui", "button_menu.png"))
    for i in range(4):
        puzzle_piece(i).save(path("ui", f"puzzle_piece_{i}.png"))
    coin_icon().save(path("ui", "coin_icon.png"))
    bayong(False).save(path("ui", "bayong_closed.png"))
    bayong(True).save(path("ui", "bayong_open.png"))
    salakot_icon().save(path("ui", "salakot_icon.png"))
    kerchief_icon().save(path("ui", "kerchief_icon.png"))
    barong_icon().save(path("ui", "barong_icon.png"))
    pants_icon().save(path("ui", "pants_icon.png"))


if __name__ == "__main__":
    names = sys.argv[1:] or list(GROUPS)
    for n in names:
        GROUPS[n]()
