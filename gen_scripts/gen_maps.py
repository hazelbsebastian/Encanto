"""Generates pixel-art parallax backgrounds for the 5 Philippine locations."""
from PIL import Image, ImageDraw
from common import new_canvas, rect, ellipse, save, path, vgradient, BLACK

W, H = 640, 360

def banaue():
    img = vgradient((W, H), (150, 200, 235), (225, 240, 235)).convert("RGBA")
    d = ImageDraw.Draw(img)
    greens = [(70, 120, 60), (90, 145, 75), (115, 165, 90), (140, 185, 110)]
    for i, g in enumerate(greens):
        top = 150 + i * 48
        d.polygon([(0, top + 30), (W, top - 10), (W, H), (0, H)], fill=g + (255,))
        for step in range(6):
            sx = (step * 110 + i * 30) % W
            d.line([(sx, top + 10), (sx + 90, top + 4)], fill=(60, 100, 50, 255), width=2)
    # nipa hut silhouette
    hx = 480
    d.polygon([(hx, 210), (hx + 40, 180), (hx + 80, 210)], fill=(90, 60, 30, 255), outline=BLACK)
    rect(d, hx + 10, 208, 60, 26, (140, 110, 70, 255))
    return img

def intramuros():
    img = vgradient((W, H), (235, 200, 150), (245, 225, 190)).convert("RGBA")
    d = ImageDraw.Draw(img)
    rect(d, 0, 230, W, 130, (120, 112, 100, 255))  # cobblestone ground
    for x in range(0, W, 26):
        d.line([(x, 230), (x, 360)], fill=(100, 92, 82, 255), width=2)
    # stone wall + arch gate
    rect(d, 0, 130, W, 110, (150, 142, 128, 255))
    rect(d, 0, 130, W, 12, (170, 162, 148, 255))
    for x in range(0, W, 48):
        rect(d, x, 130, 46, 108, (150, 142, 128, 255), outline=(110, 104, 92, 255), width=2)
    d.polygon([(260, 240), (260, 170), (300, 140), (340, 170), (340, 240)], fill=(190, 180, 160, 255), outline=BLACK)
    d.rectangle([275, 200, 325, 240], fill=(60, 45, 35, 255))
    # spire silhouettes
    for sx in (60, 520):
        d.polygon([(sx, 130), (sx + 14, 70), (sx + 28, 130)], fill=(120, 100, 90, 255), outline=BLACK)
    return img

def mayon():
    img = vgradient((W, H), (120, 185, 235), (210, 235, 235)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # perfect volcano cone
    d.polygon([(W // 2, 40), (W // 2 - 190, 260), (W // 2 + 190, 260)], fill=(70, 90, 60, 255), outline=BLACK)
    d.polygon([(W // 2 - 20, 40), (W // 2, 20), (W // 2 + 20, 40)], fill=(230, 90, 40, 255))  # lava glow tip
    ellipse(d, W // 2 - 30, 4, 60, 24, (210, 210, 210, 200))  # smoke puff
    rect(d, 0, 260, W, 100, (95, 150, 80, 255))  # green field foreground
    for x in range(20, W, 70):
        d.line([(x, 260), (x - 6, 300)], fill=(70, 120, 60, 255), width=6)
    return img

def chocolate_hills():
    img = vgradient((W, H), (150, 205, 235), (225, 240, 225)).convert("RGBA")
    d = ImageDraw.Draw(img)
    rect(d, 0, 260, W, 100, (95, 150, 75, 255))
    import random
    random.seed(7)
    hills = []
    for i in range(14):
        hx = random.randint(-20, W - 20)
        hy = random.randint(190, 250)
        r = random.randint(60, 110)
        hills.append((hy, hx, r))
    for hy, hx, r in sorted(hills):
        ellipse(d, hx, hy, r, int(r * 0.7), (150, 118, 70, 255))
        ellipse(d, hx + r // 4, hy, r // 2, int(r * 0.3), (130, 100, 58, 255))
    return img

def boracay():
    img = vgradient((W, H), (140, 205, 235), (170, 225, 220)).convert("RGBA")
    d = ImageDraw.Draw(img)
    rect(d, 0, 210, W, 60, (70, 190, 190, 255))  # sea
    rect(d, 0, 260, W, 100, (240, 228, 190, 255))  # sand
    d.line([(0, 210), (W, 210)], fill=(255, 255, 255, 200), width=3)
    for px in (90, 420, 540):
        rect(d, px, 150, 10, 90, (110, 80, 50, 255))
        for dx, dy in [(-20, -10), (20, -6), (0, -30), (-10, -30)]:
            ellipse(d, px + dx, 150 + dy, 40, 18, (70, 140, 60, 255))
    return img

def generate():
    for name, fn in [("bg_banaue", banaue), ("bg_intramuros", intramuros),
                      ("bg_mayon", mayon), ("bg_chocolate_hills", chocolate_hills),
                      ("bg_boracay", boracay)]:
        img = fn()
        save(img, path("maps", f"{name}.png"), factor=5)
        thumb = img.resize((160, 90), Image.NEAREST)
        save(thumb, path("maps", f"{name}_thumb.png"), factor=3)

if __name__ == "__main__":
    generate()
