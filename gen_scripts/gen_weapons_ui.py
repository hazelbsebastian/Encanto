"""Generates weapon, effect, and UI pixel-art assets."""
from PIL import Image, ImageDraw
from common import new_canvas, rect, ellipse, save, path, BLACK

def rock_projectile():
    img = new_canvas(12, 12)
    d = ImageDraw.Draw(img)
    d.polygon([(2, 6), (4, 2), (9, 1), (11, 5), (9, 10), (4, 11)], fill=(120, 112, 100, 255), outline=BLACK)
    d.line([4, 5, 7, 4], fill=(160, 152, 138, 255), width=1)
    return img

def sumpak():
    img = new_canvas(28, 12)
    d = ImageDraw.Draw(img)
    d.line([2, 6, 24, 6], fill=(120, 84, 50, 255), width=4)
    d.polygon([(20, 2), (26, 6), (20, 10)], fill=(80, 56, 34, 255), outline=BLACK)
    return img

def smoke_puff(n):
    img = new_canvas(32, 32)
    d = ImageDraw.Draw(img)
    grey = (150 + n * 15, 150 + n * 15, 155 + n * 15, 220 - n * 30)
    for i in range(3 + n):
        ellipse(d, 4 + i * 4 - n * 2, 10 + (i % 2) * 6 - n * 3, 14 + n * 3, 14 + n * 3, grey)
    return img

def heart(full=True):
    img = new_canvas(16, 14)
    d = ImageDraw.Draw(img)
    col = (214, 40, 55, 255) if full else (70, 55, 55, 255)
    d.polygon([(8, 13), (0, 6), (0, 3), (3, 0), (8, 4), (13, 0), (16, 3), (16, 6)], fill=col, outline=BLACK)
    return img

def joystick_base():
    img = new_canvas(90, 90)
    d = ImageDraw.Draw(img)
    ellipse(d, 2, 2, 86, 86, (60, 50, 45, 140), outline=(230, 220, 200, 200), width=3)
    return img

def joystick_knob():
    img = new_canvas(44, 44)
    d = ImageDraw.Draw(img)
    ellipse(d, 2, 2, 40, 40, (222, 178, 90, 230), outline=(120, 84, 40, 255), width=3)
    return img

def button(kind):
    img = new_canvas(72, 72)
    d = ImageDraw.Draw(img)
    colors = {
        "shoot": (196, 70, 60), "jump": (70, 140, 90), "generic": (90, 100, 150),
        "charge": (230, 170, 40),
    }
    c = colors.get(kind, (90, 100, 150)) + (230,)
    ellipse(d, 2, 2, 68, 68, c, outline=(30, 20, 15, 255), width=3)
    ellipse(d, 10, 10, 52, 20, (255, 255, 255, 60))
    return img

def button_rect(w=200, h=56):
    img = new_canvas(w, h)
    d = ImageDraw.Draw(img)
    rect(d, 2, 2, w - 4, h - 4, (150, 60, 50, 255), outline=(40, 24, 18, 255), width=3)
    rect(d, 6, 6, w - 12, 8, (230, 190, 120, 180))
    return img

def puzzle_piece(idx):
    img = new_canvas(48, 48)
    d = ImageDraw.Draw(img)
    palette = [(200, 90, 70), (90, 150, 170), (210, 170, 60), (110, 160, 90)]
    rect(d, 2, 2, 44, 44, palette[idx % 4] + (255,), outline=BLACK, width=2)
    d.text((14, 16), str(idx + 1), fill=(255, 255, 255, 255))
    return img

def coin_icon():
    img = new_canvas(24, 24)
    d = ImageDraw.Draw(img)
    ellipse(d, 2, 2, 20, 20, (240, 196, 60, 255), outline=(150, 110, 20, 255), width=2)
    d.text((7, 6), "P", fill=(150, 110, 20, 255))
    return img

def bayong(open_=False):
    img = new_canvas(64, 56)
    d = ImageDraw.Draw(img)
    weave = (150, 118, 66, 255)
    weave_sh = (120, 92, 48, 255)
    d.polygon([(6, 50), (2, 24), (14, 14), (50, 14), (62, 24), (58, 50)], fill=weave, outline=BLACK)
    for y in range(20, 50, 6):
        d.line([(4, y), (60, y)], fill=weave_sh, width=1)
    handle_col = weave_sh
    if open_:
        d.polygon([(10, 16), (2, -4), (18, 4)], fill=handle_col, outline=BLACK)
        d.polygon([(54, 16), (62, -4), (46, 4)], fill=handle_col, outline=BLACK)
        ellipse(d, 22, 6, 20, 18, (250, 220, 120, 255))  # glow of reward
    else:
        d.arc([12, -14, 52, 26], start=200, end=340, fill=handle_col, width=4)
    return img

def salakot_icon():
    img = new_canvas(32, 24)
    d = ImageDraw.Draw(img)
    d.polygon([(16, 0), (2, 18), (30, 18)], fill=(196, 160, 90, 255), outline=BLACK)
    ellipse(d, 12, 14, 8, 6, (150, 110, 60, 255))
    return img

def barong_icon():
    img = new_canvas(32, 32)
    d = ImageDraw.Draw(img)
    rect(d, 6, 4, 20, 24, (245, 240, 225, 255), outline=BLACK)
    d.line([16, 4, 16, 28], fill=(210, 205, 190, 255), width=1)
    return img

def pants_icon():
    img = new_canvas(32, 32)
    d = ImageDraw.Draw(img)
    rect(d, 8, 2, 16, 14, (101, 88, 63, 255), outline=BLACK)
    rect(d, 8, 16, 6, 14, (101, 88, 63, 255), outline=BLACK)
    rect(d, 18, 16, 6, 14, (101, 88, 63, 255), outline=BLACK)
    return img

def spark(n):
    img = new_canvas(28, 28)
    d = ImageDraw.Draw(img)
    col = (255, 220, 90, 255)
    r = 6 + n * 6
    d.line([14 - r, 14, 14 + r, 14], fill=col, width=2)
    d.line([14, 14 - r, 14, 14 + r], fill=col, width=2)
    d.line([14 - r * 0.7, 14 - r * 0.7, 14 + r * 0.7, 14 + r * 0.7], fill=col, width=2)
    d.line([14 - r * 0.7, 14 + r * 0.7, 14 + r * 0.7, 14 - r * 0.7], fill=col, width=2)
    return img

def charge_glow(n):
    img = new_canvas(40, 40)
    d = ImageDraw.Draw(img)
    r = 8 + n * 6
    col = (255, 160 + n * 20, 60, 160 + n * 25)
    ellipse(d, 20 - r // 2, 20 - r // 2, r, r, col)
    return img

def victory_burst(n):
    img = new_canvas(48, 48)
    d = ImageDraw.Draw(img)
    cols = [(255, 210, 70), (230, 90, 90), (100, 190, 160), (240, 240, 240)]
    import random
    random.seed(n)
    for i in range(10):
        x = random.randint(4, 44)
        y = random.randint(4, 44)
        c = cols[i % 4] + (255,)
        d.rectangle([x, y, x + 3, y + 3], fill=c)
    return img

def generate():
    save(rock_projectile(), path("weapons", "rock_projectile.png"), factor=1, upscale=2)
    save(sumpak(), path("weapons", "sumpak.png"), factor=1, upscale=2)
    for i in range(3):
        save(smoke_puff(i), path("weapons", f"smoke_{i}.png"), factor=2)

    save(heart(True), path("ui", "heart_full.png"), factor=1, upscale=2)
    save(heart(False), path("ui", "heart_empty.png"), factor=1, upscale=2)
    save(joystick_base(), path("ui", "joystick_base.png"), factor=3)
    save(joystick_knob(), path("ui", "joystick_knob.png"), factor=2)
    for k in ("shoot", "jump", "generic", "charge"):
        save(button(k), path("ui", f"button_{k}.png"), factor=3)
    save(button_rect(), path("ui", "button_menu.png"), factor=3)
    for i in range(4):
        save(puzzle_piece(i), path("ui", f"puzzle_piece_{i}.png"), factor=1, upscale=2)
    save(coin_icon(), path("ui", "coin_icon.png"), factor=1, upscale=2)
    save(bayong(False), path("ui", "bayong_closed.png"), factor=2)
    save(bayong(True), path("ui", "bayong_open.png"), factor=2)
    save(salakot_icon(), path("ui", "salakot_icon.png"), factor=1, upscale=2)
    save(barong_icon(), path("ui", "barong_icon.png"), factor=1, upscale=2)
    save(pants_icon(), path("ui", "pants_icon.png"), factor=1, upscale=2)
    for i in range(3):
        save(spark(i), path("ui", f"effect_spark_{i}.png"), factor=2)
        save(charge_glow(i), path("ui", f"effect_charge_{i}.png"), factor=2)
        save(victory_burst(i), path("ui", f"effect_victory_{i}.png"), factor=2)

if __name__ == "__main__":
    generate()
