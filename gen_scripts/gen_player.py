"""Generates the Filipino farmer player character spritesheet frames."""
from PIL import Image, ImageDraw
from common import new_canvas, rect, ellipse, save, path, BLACK

W, H = 40, 56
SKIN = (222, 173, 133, 255)
SKIN_SH = (190, 142, 106, 255)
POLO = (247, 247, 240, 255)
POLO_SH = (215, 215, 205, 255)
PANTS = (101, 88, 63, 255)
PANTS_SH = (78, 67, 48, 255)
HAIR = (35, 26, 22, 255)
SHOE = (58, 42, 30, 255)
WEAPON = (120, 84, 50, 255)

def draw_farmer(arm_l=0, arm_r=0, leg_l=16, leg_r=16, body_dy=0, lean=0, tint=None,
                 weapon=False, weapon_up=False, on_ground=True, fallen=False, cheer=False):
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    cx = W // 2 + lean
    by = 16 + body_dy  # body top

    if fallen:
        # lying down silhouette for death frames
        rect(d, 4, 40, 32, 8, PANTS)
        rect(d, 6, 34, 26, 8, POLO)
        ellipse(d, 26, 32, 12, 12, SKIN)
        d.ellipse([27, 34, 33, 40], fill=HAIR)
        _tint(img, tint)
        return img

    # legs (drawn first, behind torso)
    leg_w = 7
    lx = cx - 9
    rx = cx + 2
    rect(d, lx, by + 16, leg_w, leg_l, PANTS)
    rect(d, rx, by + 16, leg_w, leg_r, PANTS if leg_r > 10 else PANTS_SH)
    # folded pant leg (right leg rolled at knee) - lighter band
    band_y = by + 16 + max(0, leg_r - 6)
    rect(d, rx - 1, band_y, leg_w + 2, 4, SKIN_SH)
    # shoes
    rect(d, lx - 1, by + 16 + leg_l - 4, leg_w + 3, 5, SHOE)
    rect(d, rx - 1, by + 16 + leg_r - 4, leg_w + 3, 5, SHOE)

    # torso (polo)
    rect(d, cx - 10, by, 20, 18, POLO)
    rect(d, cx - 10, by + 12, 20, 6, POLO_SH)

    # arms
    if cheer:
        rect(d, cx - 15, by - 6, 6, 16, POLO, outline=BLACK)
        rect(d, cx + 9, by - 6, 6, 16, POLO, outline=BLACK)
        ellipse(d, cx - 16, by - 10, 8, 8, SKIN)
        ellipse(d, cx + 8, by - 10, 8, 8, SKIN)
    else:
        rect(d, cx - 14, by + 2 + arm_l, 6, 14, POLO, outline=BLACK)
        rect(d, cx + 8, by + 2 + arm_r, 6, 14, POLO, outline=BLACK)
        ellipse(d, cx - 15, by + 12 + arm_l, 8, 8, SKIN)
        ellipse(d, cx + 7, by + 12 + arm_r, 8, 8, SKIN)

    # neck + head
    rect(d, cx - 3, by - 4, 6, 5, SKIN)
    ellipse(d, cx - 8, by - 16, 16, 16, SKIN)
    # hair
    d.pieslice([cx - 8, by - 16, cx + 8, by - 6], 180, 360, fill=HAIR)
    rect(d, cx - 8, by - 16, 16, 5, HAIR)
    # simple face
    d.point((cx - 3, by - 9), fill=BLACK)
    d.point((cx + 3, by - 9), fill=BLACK)

    if weapon:
        wx = cx + (14 if not weapon_up else 12)
        wy = by + (2 if not weapon_up else -6)
        d.line([wx, wy + 8, wx + 12, wy - (6 if weapon_up else 0)], fill=WEAPON, width=3)

    _tint(img, tint)
    return img

def _tint(img, tint):
    if not tint:
        return img
    overlay = Image.new("RGBA", img.size, tint)
    px = img.load()
    ov = overlay.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 0:
                orr, og, ob, oa = ov[x, y]
                px[x, y] = (
                    min(255, (r * (255 - oa) + orr * oa) // 255),
                    min(255, (g * (255 - oa) + og * oa) // 255),
                    min(255, (b * (255 - oa) + ob * oa) // 255),
                    a,
                )
    return img

def generate():
    p = lambda name: path("player", name)

    # Idle: 2 frames, gentle breathing
    save(draw_farmer(leg_l=16, leg_r=16, body_dy=0), p("farmer_idle_0.png"))
    save(draw_farmer(leg_l=16, leg_r=16, body_dy=1), p("farmer_idle_1.png"))

    # Walk: 4 frames leg swing
    walk_legs = [(18, 12), (14, 16), (12, 18), (16, 14)]
    for i, (ll, rl) in enumerate(walk_legs):
        save(draw_farmer(leg_l=ll, leg_r=rl, arm_l=(i % 2) * 3, arm_r=((i + 1) % 2) * 3),
             p(f"farmer_walk_{i}.png"))

    # Run: 4 frames, bigger swing + forward lean
    run_legs = [(20, 10), (12, 18), (10, 20), (18, 12)]
    for i, (ll, rl) in enumerate(run_legs):
        save(draw_farmer(leg_l=ll, leg_r=rl, lean=1, arm_l=(i % 2) * 5 - 2, arm_r=((i + 1) % 2) * 5 - 2),
             p(f"farmer_run_{i}.png"))

    # Jump / Fall
    save(draw_farmer(leg_l=10, leg_r=14, arm_l=-6, arm_r=-6), p("farmer_jump_0.png"))
    save(draw_farmer(leg_l=18, leg_r=12, arm_l=4, arm_r=-2), p("farmer_fall_0.png"))

    # Shoot: 2 frames aim + recoil, weapon raised
    save(draw_farmer(leg_l=16, leg_r=16, weapon=True, weapon_up=True), p("farmer_shoot_0.png"))
    save(draw_farmer(leg_l=16, leg_r=16, weapon=True, weapon_up=True, lean=-1), p("farmer_shoot_1.png"))

    # Hurt
    save(draw_farmer(leg_l=14, leg_r=18, lean=-2, tint=(255, 60, 60, 90)), p("farmer_hurt_0.png"))

    # Death: 3 frames falling
    save(draw_farmer(leg_l=14, leg_r=18, lean=2, tint=(255, 60, 60, 60)), p("farmer_death_0.png"))
    save(draw_farmer(leg_l=10, leg_r=22, lean=4, body_dy=6, tint=(255, 60, 60, 80)), p("farmer_death_1.png"))
    save(draw_farmer(fallen=True, tint=(120, 120, 120, 90)), p("farmer_death_2.png"))

    # Victory: 2 frames cheering
    save(draw_farmer(leg_l=16, leg_r=16, cheer=True), p("farmer_victory_0.png"))
    save(draw_farmer(leg_l=14, leg_r=18, cheer=True, body_dy=-2), p("farmer_victory_1.png"))

if __name__ == "__main__":
    generate()
