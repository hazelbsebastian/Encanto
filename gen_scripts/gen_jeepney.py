"""Generates the traditional Filipino jeepney (exterior + interior) and driver."""
from PIL import Image, ImageDraw
from common import new_canvas, rect, ellipse, save, path, vgradient, BLACK

BODY_RED = (196, 46, 44, 255)
BODY_RED_SH = (150, 30, 30, 255)
TRIM_YELLOW = (244, 196, 48, 255)
CHROME = (222, 226, 232, 255)
CHROME_SH = (170, 176, 186, 255)
WINDOW = (150, 205, 225, 255)
TIRE = (30, 28, 28, 255)
RIM = (200, 200, 200, 255)

def draw_jeepney(w=176, h=72):
    img = new_canvas(w, h)
    d = ImageDraw.Draw(img)
    body_y = 14
    # main body
    rect(d, 8, body_y, w - 40, 34, BODY_RED)
    rect(d, 8, body_y + 24, w - 40, 10, BODY_RED_SH)
    # front hood (chrome nose - classic jeepney)
    rect(d, w - 40, body_y + 6, 30, 30, CHROME)
    rect(d, w - 40, body_y + 24, 30, 12, CHROME_SH)
    d.polygon([(w - 14, body_y + 6), (w - 4, body_y + 6), (w - 4, body_y + 34), (w - 14, body_y + 36)],
              fill=CHROME_SH, outline=BLACK)
    # roof trim + decorative arch
    rect(d, 4, body_y - 6, w - 44, 8, TRIM_YELLOW)
    for i in range(6):
        ellipse(d, 10 + i * 24, body_y - 10, 8, 8, TRIM_YELLOW, outline=None)
    # windows
    for i in range(4):
        rect(d, 16 + i * 26, body_y + 4, 20, 14, WINDOW)
    # yellow side stripe
    rect(d, 8, body_y + 20, w - 40, 4, TRIM_YELLOW, outline=None)
    # headlight
    ellipse(d, w - 16, body_y + 12, 8, 8, (255, 240, 180, 255))
    # wheels
    for wx in (28, w - 60):
        ellipse(d, wx, body_y + 30, 22, 22, TIRE)
        ellipse(d, wx + 6, body_y + 36, 10, 10, RIM)
    return img

def draw_interior_bg(w=480, h=270):
    img = vgradient((w, h), (150, 205, 225), (210, 235, 235))
    d = ImageDraw.Draw(img)
    # roof
    rect(d, 0, 0, w, 40, (150, 40, 40, 255))
    rect(d, 0, 36, w, 6, (196, 46, 44, 255))
    # side benches
    rect(d, 0, h - 90, w, 90, (150, 40, 40, 255))
    rect(d, 0, h - 90, w, 8, (244, 196, 48, 255))
    # window frames showing outside scenery hint
    for i in range(3):
        wx = 40 + i * 160
        rect(d, wx, 50, 120, 90, (190, 225, 235, 255))
        rect(d, wx, 50, 120, 90, None, outline=(90, 60, 40, 255), width=4)
        ellipse(d, wx + 20, 70, 30, 16, (120, 170, 120, 255))  # hill silhouette
    # dashboard hint left side
    rect(d, 0, h - 140, 70, 140, (110, 70, 45, 255))
    return img

def draw_driver(cap=True, talk=False):
    img = new_canvas(28, 40)
    d = ImageDraw.Draw(img)
    SKIN = (216, 168, 128, 255)
    SHIRT = (90, 120, 90, 255)
    rect(d, 6, 16, 16, 18, SHIRT)
    rect(d, 2, 18, 6, 12, SKIN)
    rect(d, 20, 18, 6, 12, SKIN)
    ellipse(d, 6, 2, 16, 16, SKIN)
    if talk:
        d.ellipse([12, 11, 16, 14], fill=(80, 30, 30, 255))
    else:
        d.line([11, 12, 17, 12], fill=BLACK, width=1)
    if cap:
        d.pieslice([5, -1, 21, 13], 180, 360, fill=(60, 60, 90, 255))
        rect(d, 4, 5, 18, 4, (60, 60, 90, 255))
    return img

def generate():
    save(draw_jeepney(), path("jeepney", "jeepney_side.png"), factor=3)
    save(draw_interior_bg(), path("jeepney", "jeepney_interior_bg.png"), factor=6)
    save(draw_driver(talk=False), path("jeepney", "driver_idle.png"), factor=2)
    save(draw_driver(talk=True), path("jeepney", "driver_talk_0.png"), factor=2)
    save(draw_driver(talk=False), path("jeepney", "driver_talk_1.png"), factor=2)

if __name__ == "__main__":
    generate()
