"""Smooth (non-pixel) drawing helpers for Encanto's HD art pass.

Everything is drawn in *logical* units (the same numbers the game uses for
sprite sizes / world positions) on a supersampled canvas, then downsampled
with Lanczos filtering. The result is anti-aliased, painterly art at
`out` x the logical size (sprites are shown at scale 0.5 in-game, so they stay
crisp on high-DPI screens).
"""
import os
import math
import random
from contextlib import contextmanager

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

INK = (34, 22, 18, 255)

ASSET_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")


def path(*parts):
    return os.path.join(ASSET_ROOT, *parts)


def rgba(c, a=None):
    if len(c) == 3:
        c = tuple(c) + (255,)
    if a is not None:
        c = c[:3] + (int(a),)
    return tuple(int(v) for v in c)


def mix(a, b, t):
    a = rgba(a)
    b = rgba(b)
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def shade(c, f):
    """f < 1 darkens, f > 1 lightens (towards white)."""
    c = rgba(c)
    if f <= 1:
        return (int(c[0] * f), int(c[1] * f), int(c[2] * f), c[3])
    t = min(1.0, f - 1.0)
    return mix(c, (255, 255, 255, c[3]), t)


def chaikin(pts, iterations=3, closed=True):
    """Corner-cutting smoothing so hand-placed polygons read as organic curves."""
    pts = [tuple(p) for p in pts]
    for _ in range(iterations):
        out = []
        n = len(pts)
        rng = range(n) if closed else range(n - 1)
        if not closed:
            out.append(pts[0])
        for i in rng:
            p0 = pts[i]
            p1 = pts[(i + 1) % n]
            out.append((p0[0] * 0.75 + p1[0] * 0.25, p0[1] * 0.75 + p1[1] * 0.25))
            out.append((p0[0] * 0.25 + p1[0] * 0.75, p0[1] * 0.25 + p1[1] * 0.75))
        if not closed:
            out.append(pts[-1])
        pts = out
    return pts


class Art:
    def __init__(self, w, h, out=2, ss=4, bg=None):
        self.w, self.h = w, h
        self.out = out
        self.k = out * ss
        self.size = (int(round(w * self.k)), int(round(h * self.k)))
        self.img = Image.new("RGBA", self.size, rgba(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # ------------------------------------------------------------ helpers --
    def s(self, v):
        return v * self.k

    def pts(self, pts):
        return [(x * self.k, y * self.k) for x, y in pts]

    def box(self, x, y, w, h):
        return [x * self.k, y * self.k, (x + w) * self.k, (y + h) * self.k]

    @contextmanager
    def layer(self, blur=0.0, opacity=1.0, mask_to_alpha=False):
        """Draw translucent / blurred things on a scratch layer, then composite.
        ImageDraw overwrites pixels instead of blending, so anything with alpha
        < 255 (glows, mist, shadows) should be drawn inside a layer."""
        prev_img, prev_d = self.img, self.d
        lay = Image.new("RGBA", self.size, (0, 0, 0, 0))
        self.img, self.d = lay, ImageDraw.Draw(lay)
        try:
            yield self
        finally:
            self.img, self.d = prev_img, prev_d
            if blur > 0:
                lay = lay.filter(ImageFilter.GaussianBlur(blur * self.k))
            if opacity < 1.0:
                a = lay.getchannel("A").point(lambda v: int(v * opacity))
                lay.putalpha(a)
            if mask_to_alpha:
                base_a = np.asarray(self.img.getchannel("A"), dtype=np.float32) / 255.0
                la = np.asarray(lay.getchannel("A"), dtype=np.float32) * base_a
                lay.putalpha(Image.fromarray(la.astype(np.uint8)))
            self.img.alpha_composite(lay)
            self.d = ImageDraw.Draw(self.img)

    # ------------------------------------------------------------- shapes --
    def ellipse(self, x, y, w, h, fill=None, outline=None, width=0):
        self.d.ellipse(self.box(x, y, w, h), fill=rgba(fill) if fill else None,
                       outline=rgba(outline) if outline else None,
                       width=int(round(self.s(width))) if outline else 0)

    def circle(self, cx, cy, r, fill=None, outline=None, width=0):
        self.ellipse(cx - r, cy - r, r * 2, r * 2, fill, outline, width)

    def rect(self, x, y, w, h, fill=None, outline=None, width=0, radius=0):
        b = self.box(x, y, w, h)
        kw = dict(fill=rgba(fill) if fill else None,
                  outline=rgba(outline) if outline else None,
                  width=int(round(self.s(width))) if outline else 0)
        if radius > 0:
            self.d.rounded_rectangle(b, radius=self.s(radius), **kw)
        else:
            self.d.rectangle(b, **kw)

    def poly(self, pts, fill=None, outline=None, width=0, smooth=0):
        if smooth:
            pts = chaikin(pts, smooth)
        p = self.pts(pts)
        if fill:
            self.d.polygon(p, fill=rgba(fill))
        if outline and width > 0:
            self.d.line(p + [p[0]], fill=rgba(outline), width=max(1, int(round(self.s(width)))), joint="curve")

    def line(self, pts, fill, width=1, smooth=0, round_caps=True):
        if smooth:
            pts = chaikin(pts, smooth, closed=False)
        p = self.pts(pts)
        wpx = max(1, int(round(self.s(width))))
        self.d.line(p, fill=rgba(fill), width=wpx, joint="curve")
        if round_caps:
            r = wpx / 2.0
            for (x, y) in (p[0], p[-1]):
                self.d.ellipse([x - r, y - r, x + r, y + r], fill=rgba(fill))

    def limb(self, a, b, width, fill, outline=INK, ow=1.2):
        """A rounded capsule from point a to point b (arms, legs, bamboo...)."""
        if outline:
            self.line([a, b], outline, width + ow * 2)
        self.line([a, b], fill, width)

    def blob(self, pts, fill, outline=INK, ow=1.2, smooth=3):
        """Smoothed closed shape with an ink outline drawn underneath."""
        sp = chaikin(pts, smooth)
        if outline and ow > 0:
            p = self.pts(sp)
            self.d.polygon(p, fill=rgba(outline))
            self.d.line(p + [p[0]], fill=rgba(outline), width=max(1, int(round(self.s(ow * 2)))), joint="curve")
        self.d.polygon(self.pts(sp), fill=rgba(fill))

    def oval(self, cx, cy, rx, ry, fill, outline=INK, ow=1.2):
        if outline and ow > 0:
            self.ellipse(cx - rx - ow, cy - ry - ow, (rx + ow) * 2, (ry + ow) * 2, outline)
        self.ellipse(cx - rx, cy - ry, rx * 2, ry * 2, fill)

    # ----------------------------------------------------------- textures --
    def vgradient(self, x, y, w, h, stops):
        """stops: list of (t, color). Paints a vertical gradient rectangle."""
        x0, y0 = int(self.s(x)), int(self.s(y))
        pw, ph = int(self.s(w)), int(self.s(h))
        ts = np.linspace(0.0, 1.0, ph)
        cols = np.zeros((ph, 4), dtype=np.float32)
        st = [(t, np.array(rgba(c), dtype=np.float32)) for t, c in stops]
        for i in range(len(st) - 1):
            t0, c0 = st[i]
            t1, c1 = st[i + 1]
            m = (ts >= t0) & (ts <= t1)
            f = ((ts[m] - t0) / max(1e-6, t1 - t0))[:, None]
            cols[m] = c0 + (c1 - c0) * f
        arr = np.repeat(cols[:, None, :], pw, axis=1).astype(np.uint8)
        grad = Image.fromarray(arr, "RGBA")
        self.img.alpha_composite(grad, (x0, y0))

    def gradient_poly(self, pts, stops, smooth=0):
        """Fill a polygon with a vertical gradient spanning its own bounding box."""
        if smooth:
            pts = chaikin(pts, smooth)
        ys = [p[1] for p in pts]
        xs = [p[0] for p in pts]
        x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
        mask = Image.new("L", self.size, 0)
        ImageDraw.Draw(mask).polygon(self.pts(pts), fill=255)
        lay = Image.new("RGBA", self.size, (0, 0, 0, 0))
        prev_img = self.img
        self.img = lay
        self.vgradient(x0, y0, x1 - x0 + 1, y1 - y0 + 1, stops)
        self.img = prev_img
        lay.putalpha(Image.fromarray((np.asarray(lay.getchannel("A"), dtype=np.float32) * np.asarray(mask, dtype=np.float32) / 255).astype(np.uint8)))
        self.img.alpha_composite(lay)
        self.d = ImageDraw.Draw(self.img)

    def radial_glow(self, cx, cy, r, color, strength=1.0):
        with self.layer(blur=r * 0.35):
            steps = 6
            for i in range(steps):
                t = i / steps
                a = int(rgba(color)[3] * (0.25 + 0.75 * t) * strength / steps * 2)
                rr = r * (1 - t * 0.8)
                self.circle(cx, cy, rr, rgba(color, min(255, a)))

    def noise_overlay(self, strength=10, seed=1, scale=1.0):
        """Subtle painterly grain so big flat areas don't look plastic."""
        rng = np.random.default_rng(seed)
        w, h = self.size
        sw, sh = max(1, int(w / (self.k * scale))), max(1, int(h / (self.k * scale)))
        n = rng.normal(0, strength, (sh, sw)).astype(np.float32)
        n_img = Image.fromarray(np.clip(n + 128, 0, 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
        n_arr = np.asarray(n_img, dtype=np.float32) - 128.0
        arr = np.asarray(self.img, dtype=np.float32).copy()
        for c in range(3):
            arr[:, :, c] = np.clip(arr[:, :, c] + n_arr, 0, 255)
        self.img = Image.fromarray(arr.astype(np.uint8), "RGBA")
        self.d = ImageDraw.Draw(self.img)

    def paste(self, other, x, y):
        """Composite another Art (same k) at logical x, y."""
        self.img.alpha_composite(other.img, (int(self.s(x)), int(self.s(y))))

    # ------------------------------------------------------------- output --
    def final(self):
        return self.img.resize((int(round(self.w * self.out)), int(round(self.h * self.out))), Image.LANCZOS)

    def save(self, file_path, extra=None):
        img = self.final()
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        img.save(file_path, optimize=True)
        print("wrote", os.path.relpath(file_path, ASSET_ROOT), img.size)
        return img


def seeded(seed):
    random.seed(seed)
    return random
