"""Shared helpers for procedurally painting pixel-art sprites for Encanto."""
import os
from PIL import Image, ImageDraw

BLACK = (18, 14, 14, 255)

def new_canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def pixelate(img, factor):
    w, h = img.size
    sw, sh = max(1, w // factor), max(1, h // factor)
    small = img.resize((sw, sh), Image.NEAREST)
    return small.resize((w, h), Image.NEAREST)

def save(img, path, factor=4, upscale=1):
    img = pixelate(img, factor)
    if upscale != 1:
        img = img.resize((img.width * upscale, img.height * upscale), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", path, img.size)

def rect(draw, x, y, w, h, fill, outline=BLACK, width=1):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=fill, outline=outline, width=width)

def ellipse(draw, x, y, w, h, fill, outline=BLACK, width=1):
    draw.ellipse([x, y, x + w - 1, y + h - 1], fill=fill, outline=outline, width=width)

def polygon(draw, pts, fill, outline=BLACK, width=1):
    draw.polygon(pts, fill=fill, outline=outline)

def vgradient(size, top_color, bottom_color):
    w, h = size
    img = Image.new("RGB", (1, h), (0, 0, 0))
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * t)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * t)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * t)
        img.putpixel((0, y), (r, g, b))
    return img.resize((w, h), Image.NEAREST).convert("RGBA")

ASSET_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")

def path(*parts):
    return os.path.join(ASSET_ROOT, *parts)
