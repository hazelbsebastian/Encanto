"""Puzzle portraits: one illustrated card per creature (512x512). The puzzle
splits the card into a 2x2 grid, so each creature is centred to span all
four pieces. Reuses the sprite drawings from gen_sprites_hd at a large scale.
"""
import math

import numpy as np
from PIL import Image, ImageFilter

import gen_sprites_hd as S
from hd import Art, path, rgba, mix, shade, seeded, INK

SIZE = 256  # logical; exported at 2x = 512 px


def base():
    return Art(SIZE, SIZE, out=2, ss=2)


def big(fn, scale, **kw):
    S.OUT = scale
    art = fn(**kw)
    S.OUT = 2
    return art.final()


def place(card, img, cx, bottom):
    """Paste a PIL sprite image with its bottom-centre at logical (cx, bottom)."""
    k = card.k
    x = int(cx * k - img.width / 2 * (k / 2))
    y = int(bottom * k - img.height * (k / 2))
    img = img.resize((int(img.width * k / 2), int(img.height * k / 2)), Image.LANCZOS)
    # soft drop-shadow / rim so the creature pops off the background
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(img.getchannel("A").point(lambda v: int(v * 0.55)))
    sh = sh.filter(ImageFilter.GaussianBlur(6))
    card.img.alpha_composite(sh, (x + 6, y + 8))
    card.img.alpha_composite(img, (x, y))


def vignette(card, strength=0.65):
    w, h = card.size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a = np.clip((d - 0.55) / 0.6, 0, 1) ** 1.6 * 255 * strength
    v = Image.new("RGBA", (w, h), (10, 6, 12, 0))
    v.putalpha(Image.fromarray(a.astype(np.uint8)))
    card.img.alpha_composite(v)


def fireflies(card, rnd, n, area=(0, 0, SIZE, SIZE), col=(255, 240, 150, 230)):
    for _ in range(n):
        x = rnd.uniform(area[0], area[2])
        y = rnd.uniform(area[1], area[3])
        card.radial_glow(x, y, rnd.uniform(3, 6), col)
        card.circle(x, y, 0.8, (255, 255, 220))


def tyanak_card():
    c = base()
    rnd = seeded(101)
    c.vgradient(0, 0, SIZE, SIZE, [(0, (18, 34, 40)), (0.6, (34, 64, 54)), (1, (22, 40, 30))])
    c.radial_glow(190, 60, 70, (170, 220, 200, 120))
    for x, w_ in [(20, 18), (70, 12), (210, 22), (245, 14)]:
        c.rect(x, 0, w_, SIZE, (14, 26, 24))
        c.line([(x + w_ / 2, 60), (x + w_ / 2 + 30, 20)], (14, 26, 24), 3)
    with c.layer(blur=6, opacity=0.6):
        c.rect(0, 170, SIZE, 30, (160, 200, 190))
    c.vgradient(0, 196, SIZE, 60, [(0, (40, 60, 40)), (1, (20, 30, 22))])
    for _ in range(50):
        x = rnd.uniform(0, SIZE)
        c.line([(x, 200), (x + rnd.uniform(-3, 3), 188 - rnd.uniform(0, 12))], (60, 96, 56), 1.2)
    fireflies(c, rnd, 14)
    place(c, big(S.draw_tyanak, 9, attack=True), 124, 222)
    vignette(c)
    return c


def manananggal_card():
    c = base()
    rnd = seeded(102)
    c.vgradient(0, 0, SIZE, SIZE, [(0, (24, 14, 44)), (0.55, (70, 30, 70)), (1, (30, 16, 30))])
    for _ in range(60):
        c.circle(rnd.uniform(0, SIZE), rnd.uniform(0, 150), rnd.uniform(0.3, 0.9), (255, 250, 230))
    c.radial_glow(128, 104, 110, (255, 220, 190, 150))
    c.circle(128, 104, 74, (250, 236, 206))
    with c.layer(opacity=0.25):
        for cx_, cy_, r in [(104, 84, 14), (150, 120, 10), (140, 80, 7), (112, 130, 8)]:
            c.circle(cx_, cy_, r, (190, 170, 150))
    # coconut palms + nipa hut silhouettes on the horizon
    sil = (14, 8, 20)
    c.rect(0, 206, SIZE, 50, sil)
    c.poly([(150, 206), (176, 182), (204, 206)], sil)
    c.rect(156, 204, 42, 10, sil)
    for bx, by in [(40, 60), (220, 44), (200, 150)]:
        c.poly([(bx - 8, by), (bx - 3, by - 3), (bx, by), (bx + 3, by - 3), (bx + 8, by), (bx, by + 3)], sil)
    place(c, big(S.draw_manananggal_upper, 8, flap=1), 128, 222)
    vignette(c)
    return c


def tikbalang_card():
    c = base()
    rnd = seeded(103)
    c.vgradient(0, 0, SIZE, SIZE, [(0, (236, 150, 90)), (0.5, (170, 90, 80)), (1, (40, 30, 34))])
    c.radial_glow(128, 150, 90, (255, 210, 140, 160))
    # bamboo grove (kawayan) in three depths
    for depth, col, n in [(0, (120, 80, 70), 11), (1, (80, 60, 50), 9), (2, (40, 44, 30), 7)]:
        for i in range(n):
            x = (i + rnd.uniform(0, 0.8)) * SIZE / n
            w_ = 5 + depth * 3
            lean = rnd.uniform(-8, 8)
            c.line([(x, SIZE), (x + lean, 0)], col, w_, round_caps=False)
            for y in range(20, SIZE, 34 - depth * 4):
                c.line([(x + lean * (1 - y / SIZE) - w_ / 2 - 0.5, y), (x + lean * (1 - y / SIZE) + w_ / 2 + 0.5, y)], shade(col, 0.7), 1.2)
            for k in range(3):
                yy = rnd.uniform(10, 150)
                c.poly([(x, yy), (x + 16 * (1 if k % 2 else -1), yy + 4), (x + 2, yy + 5)], shade(col, 1.1))
    with c.layer(blur=8, opacity=0.5):
        c.rect(0, 196, SIZE, 26, (250, 210, 170))
    c.vgradient(0, 214, SIZE, 42, [(0, (54, 40, 34)), (1, (26, 20, 20))])
    place(c, big(S.draw_tikbalang, 6, attack=False), 120, 244)
    vignette(c)
    return c


def kapre_card():
    c = base()
    rnd = seeded(104)
    c.vgradient(0, 0, SIZE, SIZE, [(0, (10, 20, 34)), (0.6, (26, 44, 50)), (1, (14, 20, 18))])
    for _ in range(40):
        c.circle(rnd.uniform(0, SIZE), rnd.uniform(0, 120), rnd.uniform(0.3, 0.8), (230, 240, 255))
    # the balete tree towering behind the Kapre
    tree = big(S.draw_tree, 3.4, state="full")
    k = c.k
    tree = tree.resize((int(tree.width * k / 2), int(tree.height * k / 2)), Image.LANCZOS)
    dark = Image.new("RGBA", tree.size, (0, 0, 0, 0))
    arr = np.asarray(tree, dtype=np.float32).copy()
    arr[:, :, :3] *= 0.45
    arr[:, :, 2] += 12
    tree = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    c.img.alpha_composite(tree, (int(c.s(128) - tree.width / 2), int(c.s(250) - tree.height)))
    fireflies(c, rnd, 10, (10, 20, 246, 160), (255, 170, 80, 200))
    c.vgradient(0, 222, SIZE, 34, [(0, (26, 34, 26)), (1, (12, 16, 12))])
    place(c, big(S.draw_kapre, 3, sway=0), 128, 252)
    with c.layer(blur=6, opacity=0.45):
        c.rect(0, 226, SIZE, 30, (160, 170, 170))
    vignette(c, 0.7)
    return c


CARDS = {
    "tyanak": tyanak_card,
    "manananggal": manananggal_card,
    "tikbalang": tikbalang_card,
    "kapre": kapre_card,
}

if __name__ == "__main__":
    for name, fn in CARDS.items():
        fn().save(path("puzzles", f"portrait_{name}.png"))
