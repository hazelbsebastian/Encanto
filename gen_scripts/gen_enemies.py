"""Generates Filipino folklore creature sprites: Tyanak, Manananggal, Tikbalang, Kapre, Tree."""
from PIL import Image, ImageDraw
from common import new_canvas, rect, ellipse, save, path, BLACK

# ---------------------------------------------------------------- TYANAK ----
TY_SKIN = (110, 130, 95, 255)
TY_SKIN_SH = (85, 105, 75, 255)
TY_EYE = (210, 30, 30, 255)

def draw_tyanak(crawl=0, attack=False, hurt=False, dead=False):
    img = new_canvas(34, 26)
    d = ImageDraw.Draw(img)
    tint = TY_SKIN_SH if hurt else TY_SKIN
    if dead:
        ellipse(d, 4, 14, 26, 10, tint)
        ellipse(d, 22, 10, 12, 12, tint)
        d.line([26, 14, 30, 18], fill=BLACK, width=2)
        d.line([26, 18, 30, 14], fill=BLACK, width=2)
        return img
    leg_off = 3 if crawl else 0
    # crawling body low to ground
    ellipse(d, 6, 12, 22, 12, tint)  # torso
    ellipse(d, 22, 4, 14, 14, tint)  # head (big head, small body - baby proportions)
    # limbs (crawling stance)
    rect(d, 4, 18 - leg_off, 6, 8, tint)
    rect(d, 12, 18 + leg_off, 6, 8, tint)
    rect(d, 4, 10 + leg_off, 8, 5, tint)  # arm forward
    rect(d, 14, 8 - leg_off, 8, 5, tint)
    # face
    if attack:
        d.pieslice([25, 10, 33, 16], 0, 360, fill=(40, 10, 10, 255))
        ellipse(d, 26, 6, 3, 3, TY_EYE)
    else:
        ellipse(d, 26, 8, 3, 3, TY_EYE)
        ellipse(d, 31, 8, 3, 3, TY_EYE)
    return img

# ---------------------------------------------------------- MANANANGGAL ----
MN_SKIN = (232, 200, 195, 255)
MN_WING = (94, 22, 34, 255)
MN_WING_SH = (60, 12, 20, 255)
MN_HAIR = (25, 20, 25, 255)

def draw_manananggal_upper(flap=0, dive=False, dead=False):
    img = new_canvas(56, 52)
    d = ImageDraw.Draw(img)
    cx, cy = 28, 26
    if dead:
        rect(d, cx - 10, cy, 20, 16, MN_SKIN)
        d.polygon([(cx - 10, cy), (cx - 30, cy + 10), (cx - 10, cy + 12)], fill=MN_WING_SH, outline=BLACK)
        d.polygon([(cx + 10, cy), (cx + 30, cy + 10), (cx + 10, cy + 12)], fill=MN_WING_SH, outline=BLACK)
        return img
    wing_y = -6 if flap else 6
    # wings
    d.polygon([(cx - 8, cy - 4), (cx - 34, cy - 16 + wing_y), (cx - 26, cy + 6), (cx - 10, cy + 6)],
               fill=MN_WING, outline=BLACK)
    d.polygon([(cx + 8, cy - 4), (cx + 34, cy - 16 + wing_y), (cx + 26, cy + 6), (cx + 10, cy + 6)],
               fill=MN_WING, outline=BLACK)
    # torso
    if dive:
        rect(d, cx - 8, cy - 6, 16, 22, MN_SKIN)
    else:
        rect(d, cx - 8, cy - 6, 16, 16, MN_SKIN)
    # head + hair
    ellipse(d, cx - 8, cy - 22, 16, 16, MN_SKIN)
    d.pieslice([cx - 8, cy - 22, cx + 8, cy - 10], 180, 360, fill=MN_HAIR)
    rect(d, cx - 9, cy - 22, 4, 20, MN_HAIR)
    rect(d, cx + 5, cy - 22, 4, 20, MN_HAIR)
    ellipse(d, cx - 4, cy - 16, 2, 2, BLACK)
    ellipse(d, cx + 2, cy - 16, 2, 2, BLACK)
    return img

def draw_manananggal_lower(run=0, attack=False, dead=False):
    img = new_canvas(26, 36)
    d = ImageDraw.Draw(img)
    tint = MN_SKIN
    if dead:
        rect(d, 4, 20, 18, 8, tint)
        return img
    off = 4 if run else 0
    rect(d, 6, 4, 14, 12, tint)  # lower torso stump
    if attack:
        rect(d, 2, 14, 9, 16, tint)
        rect(d, 14, 8, 9, 10, tint)
    else:
        rect(d, 3, 14 + off, 8, 18 - off, tint)
        rect(d, 14, 14 - off + 4, 8, 18 + off - 4, tint)
    return img

# ----------------------------------------------------------- TIKBALANG ----
TB_BODY = (108, 72, 42, 255)
TB_BODY_SH = (80, 52, 30, 255)
TB_MANE = (30, 24, 20, 255)
TB_SKIN = (196, 150, 110, 255)

def draw_tikbalang(run=0, attack=False, hurt=False, dead=False):
    img = new_canvas(50, 60)
    d = ImageDraw.Draw(img)
    tint = TB_BODY_SH if hurt else TB_BODY
    if dead:
        rect(d, 4, 40, 40, 12, tint)
        ellipse(d, 30, 32, 16, 16, tint)
        return img
    off = 4 if run else 0
    # horse-like hind body
    ellipse(d, 6, 26, 30, 18, tint)
    # legs (long, human+horse mix)
    rect(d, 8, 36 + off, 6, 20 - off, TB_BODY_SH)
    rect(d, 20, 36 - off + 4, 6, 20 + off - 4, TB_BODY_SH)
    rect(d, 28, 36 + off, 6, 20 - off, TB_BODY_SH)
    # human torso rising from horse body
    rect(d, 14, 8, 14, 20, TB_SKIN)
    # arms
    if attack:
        rect(d, 26, 10, 14, 6, TB_SKIN)
    else:
        rect(d, 4, 12, 10, 6, TB_SKIN)
    # horse head
    ellipse(d, 22, -6, 20, 22, tint)
    d.polygon([(24, -6), (20, -16), (28, -8)], fill=tint, outline=BLACK)  # ear
    d.polygon([(34, -6), (40, -16), (36, -6)], fill=tint, outline=BLACK)
    rect(d, 18, -8, 10, 18, TB_MANE)
    ellipse(d, 30, 2, 3, 3, BLACK)
    return img

# ---------------------------------------------------------------- KAPRE ----
KP_SKIN = (72, 52, 38, 255)
KP_SKIN_SH = (50, 36, 26, 255)
KP_LOIN = (110, 70, 40, 255)
KP_EMBER = (240, 130, 40, 255)

def draw_kapre(sway=0, attack=False, dead_stage=0):
    img = new_canvas(100, 128)
    d = ImageDraw.Draw(img)
    cx = 50 + sway
    if dead_stage:
        # collapsed silhouette, stage 1..3 progressively flatter
        h = max(20, 60 - dead_stage * 15)
        rect(d, 10, 128 - h, 80, h, KP_SKIN_SH)
        return img
    # legs
    rect(d, cx - 26, 84, 20, 34, KP_SKIN_SH)
    rect(d, cx + 6, 84, 20, 34, KP_SKIN_SH)
    # torso
    rect(d, cx - 32, 34, 64, 54, KP_SKIN)
    # arms
    arm_y = 40 + sway
    rect(d, cx - 44, arm_y, 14, 40, KP_SKIN)
    if attack:
        rect(d, cx + 30, 20, 16, 16, KP_SKIN)  # arm raised to mouth
    else:
        rect(d, cx + 30, arm_y, 14, 40, KP_SKIN)
    # head
    ellipse(d, cx - 22, 4, 44, 36, KP_SKIN)
    d.polygon([(cx - 18, 6), (cx - 24, -8), (cx - 8, 4)], fill=KP_SKIN, outline=BLACK)
    d.polygon([(cx + 18, 6), (cx + 24, -8), (cx + 8, 4)], fill=KP_SKIN, outline=BLACK)
    ellipse(d, cx - 12, 16, 8, 6, BLACK)
    ellipse(d, cx + 4, 16, 8, 6, BLACK)
    # cigar + ember
    d.line([cx + 14, 28, cx + 26, 24], fill=(230, 220, 200, 255), width=4)
    ellipse(d, cx + 24, 21, 6, 6, KP_EMBER)
    return img

# ----------------------------------------------------------------- TREE ----
TR_TRUNK = (94, 62, 34, 255)
TR_TRUNK_SH = (70, 46, 24, 255)
TR_LEAF = (58, 116, 54, 255)
TR_LEAF_SH = (38, 88, 40, 255)

def draw_tree(state="full"):
    img = new_canvas(140, 180)
    d = ImageDraw.Draw(img)
    if state == "fallen":
        rect(d, 10, 150, 120, 20, TR_TRUNK)
        ellipse(d, 90, 130, 40, 40, TR_LEAF_SH)
        return img
    angle_shift = {"full": 0, "shake": 3, "falling": 24}[state]
    rect(d, 58 + (angle_shift // 3), 100, 24, 80, TR_TRUNK)
    rect(d, 58 + (angle_shift // 3), 100, 8, 80, TR_TRUNK_SH)
    cx = 70 + angle_shift
    for i, (dx, dy, r) in enumerate([(-30, -20, 45), (10, -50, 55), (35, -10, 42), (-5, 10, 40)]):
        ellipse(d, cx + dx - r // 2, 90 + dy - r // 2, r, r, TR_LEAF if i % 2 == 0 else TR_LEAF_SH)
    if state == "shake":
        d.line([cx - 40, 60, cx - 46, 54], fill=TR_LEAF_SH, width=2)
    return img

def generate():
    ty = lambda n: path("enemies", "tyanak", n)
    save(draw_tyanak(crawl=0), ty("tyanak_crawl_0.png"), factor=2)
    save(draw_tyanak(crawl=1), ty("tyanak_crawl_1.png"), factor=2)
    save(draw_tyanak(attack=True), ty("tyanak_attack_0.png"), factor=2)
    save(draw_tyanak(hurt=True), ty("tyanak_hurt.png"), factor=2)
    save(draw_tyanak(dead=True), ty("tyanak_death_0.png"), factor=2)
    save(draw_tyanak(dead=True), ty("tyanak_death_1.png"), factor=2)

    mn = lambda n: path("enemies", "manananggal", n)
    save(draw_manananggal_upper(flap=0), mn("upper_fly_0.png"), factor=2)
    save(draw_manananggal_upper(flap=1), mn("upper_fly_1.png"), factor=2)
    save(draw_manananggal_upper(dive=True), mn("upper_dive.png"), factor=2)
    save(draw_manananggal_upper(dead=True), mn("upper_death.png"), factor=2)
    save(draw_manananggal_lower(run=0), mn("lower_idle_0.png"), factor=2)
    save(draw_manananggal_lower(run=1), mn("lower_idle_1.png"), factor=2)
    save(draw_manananggal_lower(attack=True), mn("lower_attack.png"), factor=2)
    save(draw_manananggal_lower(dead=True), mn("lower_death.png"), factor=2)

    tb = lambda n: path("enemies", "tikbalang", n)
    save(draw_tikbalang(run=0), tb("tikbalang_run_0.png"), factor=2)
    save(draw_tikbalang(run=1), tb("tikbalang_run_1.png"), factor=2)
    save(draw_tikbalang(attack=True), tb("tikbalang_attack.png"), factor=2)
    save(draw_tikbalang(hurt=True), tb("tikbalang_hurt.png"), factor=2)
    save(draw_tikbalang(dead=True), tb("tikbalang_death_0.png"), factor=2)
    save(draw_tikbalang(dead=True), tb("tikbalang_death_1.png"), factor=2)

    kp = lambda n: path("enemies", "kapre", n)
    save(draw_kapre(sway=0), kp("kapre_idle_0.png"), factor=3)
    save(draw_kapre(sway=2), kp("kapre_idle_1.png"), factor=3)
    save(draw_kapre(attack=True), kp("kapre_attack.png"), factor=3)
    save(draw_kapre(dead_stage=1), kp("kapre_death_0.png"), factor=3)
    save(draw_kapre(dead_stage=2), kp("kapre_death_1.png"), factor=3)
    save(draw_kapre(dead_stage=3), kp("kapre_death_2.png"), factor=3)

    save(draw_tree("full"), path("enemies", "tree_full.png"), factor=3)
    save(draw_tree("shake"), path("enemies", "tree_shake.png"), factor=3)
    save(draw_tree("falling"), path("enemies", "tree_falling.png"), factor=3)
    save(draw_tree("fallen"), path("enemies", "tree_fallen.png"), factor=3)

if __name__ == "__main__":
    generate()
