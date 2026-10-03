#!/usr/bin/env python3
"""Pixel-art illustrations for the State Troops story campaign.

Seven 320x180 scenes (saved x4 = 1280x720 in Assets/Story/) drawn with the
retro_overhaul palette and helpers, reusing the game's own faction flags and
card sprites so the story screens match the rest of the art:

  ch1  Smoke Over Anatolia   - a quiet domed town at dusk, smoke on the eastern hills
  ch2  Fire From the South   - a blazing desert, purple banners on every dune
  ch3  The Puppet Masters    - the Horde's flag working its puppets on strings
  ch4  Appetite              - a golden army eyeing the Coalition's skyline
  ch5  The World Against Us  - one gold flag against a wall of every other one
  epilogue                   - fireworks over the last flag standing (and the soup)
  defeat                     - a fallen flag in the rain

    python3 tools/story_art.py            # writes Assets/Story/*.png + build/previews/story.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import retro_overhaul as R  # noqa: E402

W, H = 320, 180
OUT = os.path.join(R.ROOT, "Assets", "Story")


# ---------------------------------------------------------------- helpers
def up(src, k):
    """Nearest-neighbour upscale of a canvas."""
    g = R.Pix(src.w * k, src.h * k)
    for y in range(src.h):
        for x in range(src.w):
            c = src.px[y * src.w + x]
            if c is not None:
                for j in range(k):
                    for i in range(k):
                        g.px[(y * k + j) * g.w + x * k + i] = c
    return g


def silhouette(src, col, keep_outline=False):
    g = R.Pix(src.w, src.h)
    for i, c in enumerate(src.px):
        if c is not None and c[3] >= 200:
            g.px[i] = R.rgba(col)
    return g


def flipped(src):
    g = R.Pix(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            g.px[y * src.w + (src.w - 1 - x)] = src.px[y * src.w + x]
    return g


def card(name, nation=None, frame=0):
    """A card sprite (32x32) without its ground shadow."""
    g = R.CARDS[name](frame, False)
    out = R.Pix(32, 32)
    for i, c in enumerate(g.px):
        if c is not None and c[3] >= 200:
            out.px[i] = c
    return out


def flag(name, k=1, frame=0):
    f = R.draw_flag(name, frame)
    return up(f, k) if k > 1 else f


def smoke(g, x, base_y, height, seed, dark=True, alpha=210):
    for i in range(height // 4):
        t = i / max(height // 4, 1)
        drift = math.sin(i * 0.7 + seed) * 3 + t * 10
        r = 2 + t * 7
        col = (60, 54, 62) if dark else (150, 150, 160)
        g.disc(x + drift, base_y - i * 4, r, col + (int(alpha * (1 - t * 0.6)),))
        g.disc(x + drift - 1, base_y - i * 4 - 1, max(r - 2, 1), (90, 82, 90, int(alpha * (1 - t * 0.6))) if dark else (190, 190, 200, int(alpha * (1 - t))))


def fire(g, x, y, s=1.0):
    g.disc(x, y, 3 * s, "O")
    g.disc(x, y - 2 * s, 2 * s, "Y")
    g.p(int(x), int(y - 4 * s), "W")


def dome(g, x, base_y, w, h, col, tip=None):
    g.r(x, base_y - h, w, h, col)
    g.disc(x + w / 2 - 0.5, base_y - h, w / 2, col)
    g.r(int(x + w / 2) - 1, base_y - h - int(w / 2) - 3, 1, 3, col)
    if tip:
        g.p(int(x + w / 2) - 1, base_y - h - int(w / 2) - 4, tip)


def minaret(g, x, base_y, h, col):
    g.r(x, base_y - h, 3, h, col)
    g.r(x - 1, base_y - h + 4, 5, 1, col)
    g.p(x + 1, base_y - h - 2, col)
    g.p(x + 1, base_y - h - 1, col)


def ground(g, y0, a, b):
    for y in range(y0, H):
        for x in range(W):
            g.px[y * W + x] = R.rgba(a if (x * 7 + y * 3) % 11 else b)


def rain(g, n, seed, col=(150, 160, 190, 150)):
    k = seed
    for _ in range(n):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        x, y = k % W, (k >> 9) % H
        g.ln(x, y, x - 2, y + 5, col)


def firework(g, cx, cy, r, col):
    for a in range(16):
        ang = a * math.pi / 8
        for d in range(2, r, 2):
            x = int(cx + math.cos(ang) * d)
            y = int(cy + math.sin(ang) * d)
            g.p(x, y, col + (max(60, 255 - d * 9),))
    g.disc(cx, cy, 1.5, "W")


def vignette(g, strength=0.55):
    for y in range(H):
        for x in range(W):
            c = g.px[y * W + x]
            if c is None:
                continue
            dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            k = 1 - strength * max(0.0, (dx * dx + dy * dy) - 0.45) / 1.6
            g.px[y * W + x] = tuple(max(0, int(v * k)) for v in c[:3]) + (255,)


# ---------------------------------------------------------------- scenes
def ch1():
    g = R.Pix(W, H)
    R.sky(g, (46, 30, 78), (246, 150, 84), 10)
    R.stars(g, 40, 3, 50)
    g.disc(70, 118, 16, (255, 214, 140))
    R.ridge(g, 128, 12, 0.025, (104, 64, 92), 2, 1.2)
    R.ridge(g, 140, 9, 0.04, (78, 48, 74), 6)
    # the eastern hills are burning
    for sx, sh in ((230, 70), (262, 56), (292, 80), (208, 44)):
        smoke(g, sx, 132, sh, sx)
        fire(g, sx, 134, 1.0)
    f = flag("Insurgents", 1, 2)
    g.over(f, 268, 104)
    # the old town: domes, towers, warm windows
    town = (34, 26, 46)
    R.skyline(g, 160, town, (255, 212, 120), 13, 0.55)
    for x, w, h in ((20, 26, 22), (64, 18, 16), (104, 30, 26), (150, 16, 14)):
        dome(g, x, 160, w, h, town, "Y")
    for x, h in ((14, 44), (52, 38), (98, 50), (140, 36)):
        minaret(g, x, 160, h, town)
    sf = flag("State Troops", 2, 1)
    g.over(sf, 112, 74)
    ground(g, 160, (40, 30, 40), (52, 40, 50))
    # a lone soldier on the road, looking east
    g.over(up(card("Infantry"), 2), 168, 120)
    vignette(g)
    return g


def ch2():
    g = R.Pix(W, H)
    R.sky(g, (250, 200, 90), (220, 80, 50), 9)
    g.disc(220, 54, 26, (255, 240, 180))
    g.disc(220, 54, 20, (255, 252, 220))
    R.ridge(g, 112, 10, 0.02, (226, 164, 90), 4)
    R.ridge(g, 126, 9, 0.035, (204, 138, 72), 8)
    R.ridge(g, 140, 7, 0.05, (176, 112, 58), 1)
    # purple banners on every dune
    for i, (x, y) in enumerate(((176, 84), (214, 92), (250, 86), (288, 96), (150, 100))):
        g.over(flag("Fundamentalists", 1, i), x, y)
    for x in (196, 236, 270):
        g.over(silhouette(flipped(card("Tank")), (110, 54, 70)), x, 104)
    ground(g, 156, (150, 98, 52), (132, 84, 44))
    g.over(up(card("Tank"), 2), 20, 104)
    g.over(up(card("Infantry"), 2), 84, 112)
    g.over(flag("State Troops", 2, 3), 0, 60)
    vignette(g, 0.5)
    return g


def ch3():
    g = R.Pix(W, H)
    R.sky(g, (10, 10, 28), (120, 26, 34), 10)
    R.stars(g, 120, 21, 90)
    R.ridge(g, 132, 6, 0.02, (196, 204, 226), 3)
    # the puppeteer: a huge Horde flag with strings down to its puppets
    hf = flag("Horde", 3, 0)
    g.over(hf, 112, 0)
    hand_y = 74
    for (px, py, name) in ((60, 98, "Insurgents"), (170, 104, "Fundamentalists"), (262, 92, "Mercenaries")):
        for sx in (px + 6, px + 20):
            g.ln(160, hand_y, sx, py + 6, (220, 210, 200))
        g.over(flag(name, 1, 1), px, py)
    # snow plain and the Horde's armour rolling out
    for y in range(140, H):
        for x in range(W):
            g.px[y * W + x] = R.rgba((214, 222, 238) if (x + y * 3) % 9 else (190, 200, 222))
    for i, x in enumerate(range(10, 300, 46)):
        g.over(silhouette(card("Tank"), (40, 20, 26)), x, 126 + (i % 2) * 6)
        g.p(x + 8, 128 + (i % 2) * 6, "R")
    for k in range(220):                               # snowfall
        g.p((k * 67) % W, (k * 29) % 140, (240, 244, 255, 200))
    vignette(g, 0.6)
    return g


def ch4():
    g = R.Pix(W, H)
    R.sky(g, (70, 50, 120), (255, 196, 96), 10)
    g.disc(250, 110, 22, (255, 230, 150))
    # the Coalition's proud skyline on the horizon
    R.skyline(g, 132, (86, 74, 120), (255, 236, 160), 7, 0.9, (262, 64))
    R.skyline(g, 140, (60, 52, 92), (255, 220, 130), 19, 1.1)
    for x in (190, 228, 296):
        g.over(flag("Coalition Army", 1, x % 5), x, 92)
    # the State Troops' golden army on the hill
    R.ridge(g, 150, 14, 0.012, (58, 42, 30), 5)
    for i, x in enumerate((8, 46, 84)):
        g.over(up(card("Tank"), 2), x, 100 - i * 3)
    g.over(up(card("Infantry"), 2), 120, 110)
    g.over(flag("State Troops", 3, 2), 0, 18)
    for k in range(40):                                # glints of gold
        x, y = (k * 53) % 150, 30 + (k * 37) % 70
        g.p(x, y, "Y" if k % 3 else "W")
    ground(g, 166, (46, 34, 26), (58, 44, 32))
    vignette(g, 0.45)
    return g


def ch5():
    g = R.Pix(W, H)
    R.sky(g, (24, 6, 12), (160, 40, 30), 10)
    g.ln(220, 0, 210, 30, "W", 2)                       # lightning
    g.ln(210, 30, 226, 44, "W", 2)
    g.ln(226, 44, 214, 80, (200, 220, 255), 1)
    rain(g, 160, 9, (180, 120, 120, 110))
    R.ridge(g, 120, 16, 0.018, (60, 20, 26), 7, 1.0)
    # the wall of the world's flags
    for i, name in enumerate(("Peace Keepers", "Corporate Troops", "Horde", "Insurgents", "Peace Keepers")):
        g.over(flag(name, 2, i), 128 + i * 38, 40 + (i % 2) * 10)
    for i, x in enumerate(range(124, 320, 22)):
        g.over(silhouette(flipped(card(("Tank", "Infantry", "Rocket Launcher", "Drone")[i % 4])), (30, 10, 14)), x, 104 + (i % 3) * 4)
    # one gold flag on a lonely hill
    for x in range(0, 120):
        top = int(132 - 22 * math.sin(x / 120 * math.pi))
        for y in range(top, H):
            g.px[y * W + x] = R.rgba((44, 30, 26))
    g.over(flag("State Troops", 2, 4), 36, 54)
    g.over(up(card("Infantry"), 2), 60, 92)
    ground(g, 160, (30, 16, 18), (40, 22, 22))
    vignette(g, 0.6)
    return g


def epilogue():
    g = R.Pix(W, H)
    R.sky(g, (8, 10, 30), (40, 36, 90), 9)
    R.stars(g, 140, 5, 120)
    for (cx, cy, r, col) in ((70, 40, 22, (255, 210, 90)), (250, 34, 26, (120, 220, 255)), (170, 22, 16, (255, 120, 150)),
                             (120, 66, 14, (160, 255, 140)), (290, 70, 14, (255, 240, 200))):
        firework(g, cx, cy, r, col)
    # the planet, and the last flag standing
    g.disc(160, 250, 140, (40, 90, 150))
    g.disc(160, 250, 136, (52, 120, 70))
    for k in range(30):
        g.disc(60 + (k * 41) % 200, 124 + (k * 13) % 40, 4 + k % 4, (64, 140, 84))
    g.over(flag("State Troops", 3, 1), 140, 30)
    # ...and the Tuesday soup
    g.disc(270, 166, 12, (220, 220, 230))
    g.r(258, 160, 25, 8, (200, 200, 214))
    g.ellipse(270, 160, 11, 3, (196, 150, 70))
    for k in range(3):
        smoke(g, 264 + k * 6, 152, 16, k, dark=False, alpha=120)
    vignette(g, 0.5)
    return g


def defeat():
    g = R.Pix(W, H)
    R.sky(g, (40, 44, 56), (100, 104, 120), 8)
    R.ridge(g, 120, 8, 0.03, (64, 66, 78), 2)
    ground(g, 140, (46, 44, 52), (56, 54, 62))
    # the flag lies flat in the mud (cloth squashed for perspective), its pole beside it
    f = flag("State Troops", 3, 0)
    cloth_x0 = 15                                      # columns left of this are the pole
    fw = f.w - cloth_x0
    fh = 20
    x0, y0 = 118, 134
    for y in range(fh):
        sy = int(y / fh * f.h)
        skew = (fh - y) // 2                           # far edge leans back
        for x in range(fw):
            c = f.px[sy * f.w + cloth_x0 + x]
            if c is not None:
                g.p(x0 + x + skew, y0 + y, tuple(int(v * 0.5) for v in c[:3]) + (255,))
    g.ln(x0 - 52, y0 + 8, x0 + 2, y0 + 4, (84, 60, 40), 2)   # the pole, snapped and down
    g.r(x0 - 55, y0 + 7, 3, 3, (150, 120, 40))
    g.ln(x0 - 74, y0 + 10, x0 - 58, y0 + 9, (84, 60, 40), 2)  # the broken-off end
    for x in range(x0 - 4, x0 + fw + 8):               # mud lapping over the edges
        if (x * 7) % 5:
            g.p(x, y0 + fh - (x % 3 == 0), (52, 48, 56))
    for x in range(20, 300, 37):                       # puddles
        g.ellipse(x, 158 + (x % 3) * 5, 12, 2, (90, 96, 120))
    rain(g, 260, 4)
    vignette(g, 0.65)
    return g


# ------------------------------------------------------------ composed scenes
# The other campaigns' pictures are described as data and drawn by compose():
#   sky (top, bottom), stars n, sun/moon (x, y, r), aurora, ridges [(y, amp, freq, colour, seed)],
#   sea y (water from there down to the ground), skyline (y, colour, lit, seed, tall),
#   domes, props [...], ground (y, a, b), hero faction + hero_units (big, left),
#   foes [factions] + foe_units (silhouettes, right), weather, vignette.
def palm(g, x, y, h=16, col=(40, 60, 30), trunk=(70, 50, 30)):
    for k in range(h):
        g.p(x + int(math.sin(k / h * 1.4) * 2), y - k, trunk)
    for a in range(-3, 4):
        g.ln(x + 2, y - h, x + 2 + a * 3, y - h + 4 + abs(a), col)


def pyramid(g, x, base_y, w, col, shade):
    for d in range(w // 2):
        g.r(x + d, base_y - d, w - 2 * d, 1, col)
        g.r(x + w // 2, base_y - d, w // 2 - d, 1, shade)


def derrick(g, x, base_y, h, col):
    g.ln(x, base_y, x + h // 4, base_y - h, col)
    g.ln(x + h // 2, base_y, x + h // 4, base_y - h, col)
    for k in range(4, h, 6):
        g.ln(x + k // 4, base_y - k, x + h // 2 - k // 4, base_y - k, col)


def factory_row(g, base_y, col, lit, n=4, x0=150):
    for i in range(n):
        x = x0 + i * 40
        g.r(x, base_y - 20, 30, 20, col)
        for d in range(3):
            g.r(x + d * 10, base_y - 26 + d, 10, 6 - d, col)
        g.r(x + 22, base_y - 44, 5, 24, col)
        smoke(g, x + 24, base_y - 46, 34, i, dark=True, alpha=170)
        for wx in range(x + 3, x + 27, 6):
            g.r(wx, base_y - 14, 3, 3, lit)


def ice(g, y, n, seed):
    k = seed
    for _ in range(n):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        x = k % W
        w = 8 + (k >> 8) % 22
        yy = y + (k >> 16) % 14
        g.r(x, yy, w, 2, (224, 236, 248))
        g.r(x + 1, yy + 2, w - 2, 1, (170, 190, 214))


def jungle(g, y, seed, cols=((24, 70, 40), (36, 96, 50), (52, 120, 60))):
    k = seed
    for i in range(60):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        cx = k % W
        r = 6 + (k >> 8) % 9
        g.disc(cx, y + (k >> 12) % 14, r, cols[i % 3])


def aurora(g, seed):
    for band in range(3):
        col = ((80, 255, 170, 70), (120, 200, 255, 60), (200, 120, 255, 50))[band]
        for x in range(W):
            yy = 30 + band * 10 + int(math.sin(x * 0.04 + seed + band) * 8 + math.sin(x * 0.11 + band) * 3)
            for d in range(6):
                g.p(x, yy + d, col)


def boat(g, x, y, col, flag_name=None, w=26):
    g.r(x, y, w, 4, col)
    g.r(x + 2, y + 4, w - 4, 2, col)
    g.r(x + w // 3, y - 6, w // 3, 6, col)
    if flag_name:
        f = R.draw_flag(flag_name, 0)
        g.over(f, x + w // 2 - 4, y - 30)


def crate(g, x, y, emblem_col):
    g.r(x, y, 34, 26, (120, 84, 46))
    g.r(x, y, 34, 2, (160, 116, 66))
    for k in (0, 11, 22):
        g.r(x, y + k + 2, 34, 1, (86, 58, 32))
    g.ln(x, y, x + 33, y + 25, (86, 58, 32))
    g.disc(x + 17, y + 13, 5, emblem_col)
    g.disc(x + 17, y + 11, 3, (255, 210, 120))


def cliffs(g):
    """White chalk cliffs on the left, grass on top, ragged edge to the sea."""
    for y in range(98, 170):
        # the face slopes out towards the sea and is ragged with fallen chalk
        edge = 92 + (y - 98) * 0.35 + math.sin(y * 0.7) * 3 + math.sin(y * 0.23) * 4
        for x in range(0, int(edge)):
            top = 100 + int(math.sin(x * 0.09) * 4 + math.sin(x * 0.31) * 2)
            if y < top:
                continue
            if y < top + 3:
                g.p(x, y, (70, 120, 60))
            else:
                g.p(x, y, (232, 232, 224) if (x * 3 + y) % 11 else (200, 200, 196))
        g.p(int(edge), y, (160, 160, 156))


def coins(g, n, seed, x0=0, x1=W, y0=0, y1=H):
    k = seed
    for _ in range(n):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        x = x0 + k % max(x1 - x0, 1)
        y = y0 + (k >> 9) % max(y1 - y0, 1)
        g.disc(x, y, 1.6, (255, 210, 60))
        g.p(int(x), int(y), (255, 250, 200))


def sea_band(g, y0, y1, a=(30, 70, 130), b=(46, 96, 160)):
    for y in range(y0, y1):
        for x in range(W):
            g.px[y * W + x] = R.rgba(a if ((x // 6 + y) % 5) else b)


PROPS = {
    "palms": lambda g, c: [palm(g, x, c.get("prop_y", 150), 14 + (x % 7)) for x in c.get("palm_x", (40, 120, 230, 280))],
    "pyramids": lambda g, c: (pyramid(g, 170, 140, 60, (214, 176, 110), (176, 136, 80)), pyramid(g, 236, 140, 40, (214, 176, 110), (176, 136, 80))),
    "derricks": lambda g, c: [derrick(g, x, 146, 40, (40, 36, 48)) for x in (150, 200, 250)],
    "factories": lambda g, c: factory_row(g, 140, (52, 46, 56), (255, 210, 120)),
    "ice": lambda g, c: ice(g, c.get("sea", 120) + 2, 26, 3),
    "jungle": lambda g, c: jungle(g, c.get("jungle_y", 128), 5),
    "aurora": lambda g, c: aurora(g, 2),
    "coins": lambda g, c: coins(g, 60, 11),
    "boats": lambda g, c: [boat(g, x, c.get("sea", 120) + 8 + i * 6, (40, 40, 52), c.get("boat_flag")) for i, x in enumerate((150, 200, 254))],
    "crate": lambda g, c: crate(g, 200, 128, (180, 70, 210)),
    "volcano": lambda g, c: (R.ridge(g, 120, 30, 0.012, (80, 56, 60), 4), smoke(g, 160, 82, 60, 7, dark=True)),
    "cliffs": lambda g, c: cliffs(g),
    "wall": lambda g, c: [g.r(x, 116 - int(math.sin(x * 0.02) * 6), 3, 4, (120, 100, 80)) for x in range(0, W, 6)],
    "fires": lambda g, c: [(fire(g, x, 132, 1.2), smoke(g, x, 128, 44, x)) for x in (170, 220, 270)],
    "campfire": lambda g, c: (fire(g, 160, 150, 1.6), smoke(g, 160, 146, 30, 1, dark=False, alpha=120)),
}


def compose(c):
    g = R.Pix(W, H)
    R.sky(g, c["sky"][0], c["sky"][1], 10)
    if c.get("stars"):
        R.stars(g, c["stars"], 13, 90)
    if "aurora" in c.get("props", []):
        aurora(g, 2)
    if c.get("sun"):
        x, y, r = c["sun"]
        g.disc(x, y, r, c.get("sun_col", (255, 226, 150)))
    if c.get("moon"):
        x, y, r = c["moon"]
        g.disc(x, y, r, (236, 236, 250))
        g.disc(x + r * 0.4, y - r * 0.3, r * 0.8, None) if False else None
    for (y, amp, freq, col, seed) in c.get("ridges", []):
        R.ridge(g, y, amp, freq, col, seed, 1.0)
    if c.get("sea") is not None:
        sea_band(g, c["sea"], c.get("ground", (160,))[0], *c.get("sea_cols", ((30, 70, 130), (46, 96, 160))))
    if c.get("skyline"):
        y, col, lit, seed, tall = c["skyline"]
        R.skyline(g, y, col, lit, seed, tall, c.get("spire"))
    if c.get("domes"):
        for x, w, h in ((150, 26, 20), (196, 18, 14), (240, 30, 24)):
            dome(g, x, c["domes"], w, h, c.get("dome_col", (60, 44, 60)), "Y")
        for x, h in ((186, 40), (232, 44)):
            minaret(g, x, c["domes"], h, c.get("dome_col", (60, 44, 60)))
    for name in c.get("props", []):
        if name != "aurora":
            PROPS[name](g, c)
    if c.get("ground"):
        ground(g, *c["ground"])
    # the enemy, on the right: flags on the skyline and an army in silhouette
    for i, foe in enumerate(c.get("foes", [])):
        g.over(flag(foe, 1, i), 200 + i * 34 + (i % 2) * 6, c.get("foe_flag_y", 92) + (i % 2) * 8)
    sil = c.get("foe_col", (30, 20, 30))
    for i, card_name in enumerate(c.get("foe_units", [])):
        g.over(silhouette(flipped(card(card_name)), sil), 196 + i * 30, c.get("foe_y", 118) + (i % 2) * 5)
    # the hero, on the left: a big flag and its army
    if c.get("hero"):
        g.over(flag(c["hero"], 2, 1), c.get("hero_x", 6), c.get("hero_flag_y", 52))
    for i, card_name in enumerate(c.get("hero_units", [])):
        g.over(up(card(card_name), 2), 40 + i * 52, c.get("hero_y", 108) - (i % 2) * 4)
    w = c.get("weather")
    if w == "snow":
        for k in range(240):
            g.p((k * 67) % W, (k * 29) % H, (240, 244, 255, 200))
    elif w == "rain":
        rain(g, 220, 5)
    elif w == "sand":
        k = 77
        for _ in range(260):  # windblown grit, scattered (a plain stride draws stripes)
            k = (k * 1103515245 + 12345) & 0x7FFFFFFF
            x, y = k % W, (k >> 9) % H
            g.ln(x, y, x + 2, y, (230, 190, 120, 120))
    elif w == "fireworks":
        for (cx, cy, r, col) in ((60, 30, 18, (255, 210, 90)), (160, 22, 14, (120, 220, 255)), (260, 36, 20, (255, 120, 150))):
            firework(g, cx, cy, r, col)
    vignette(g, c.get("vignette", 0.55))
    return g


def defeat_of(faction):
    """The fallen-flag picture, for any faction."""
    g = R.Pix(W, H)
    R.sky(g, (40, 44, 56), (100, 104, 120), 8)
    R.ridge(g, 120, 8, 0.03, (64, 66, 78), 2)
    ground(g, 140, (46, 44, 52), (56, 54, 62))
    f = flag(faction, 3, 0)
    cloth_x0, fh, x0, y0 = 15, 20, 118, 134
    fw = f.w - cloth_x0
    for y in range(fh):
        sy = int(y / fh * f.h)
        skew = (fh - y) // 2
        for x in range(fw):
            c = f.px[sy * f.w + cloth_x0 + x]
            if c is not None:
                g.p(x0 + x + skew, y0 + y, tuple(int(v * 0.5) for v in c[:3]) + (255,))
    g.ln(x0 - 52, y0 + 8, x0 + 2, y0 + 4, (84, 60, 40), 2)
    g.r(x0 - 55, y0 + 7, 3, 3, (150, 120, 40))
    for x in range(20, 300, 37):
        g.ellipse(x, 158 + (x % 3) * 5, 12, 2, (90, 96, 120))
    rain(g, 260, 4)
    vignette(g, 0.65)
    return g


CO, HO, CA, FU, ME, IN, PK, ST = ("Corporate Troops", "Horde", "Coalition Army", "Fundamentalists",
                                  "Mercenaries", "Insurgents", "Peace Keepers", "State Troops")
DUSK = ((60, 40, 100), (250, 150, 90))
NIGHT = ((8, 10, 30), (40, 40, 90))
DAY = ((90, 150, 220), (200, 226, 240))
STORM = ((40, 44, 60), (110, 114, 130))
COMPOSED = {
    # Corporate Troops: Hostile Takeover
    "corporate_1": {"sky": ((90, 40, 90), (255, 170, 100)), "sun": (240, 110, 20), "ridges": [(124, 16, 0.02, (170, 90, 70), 3), (138, 8, 0.04, (130, 70, 56), 7)],
                    "props": ["palms"], "palm_x": (150, 186, 300), "prop_y": 152, "ground": (152, (120, 80, 50), (132, 90, 56)),
                    "hero": CO, "hero_units": ["Tank", "Drone"], "foes": [PK, PK], "foe_units": ["Infantry", "Wall", "Infantry", "Anti Aircraft"], "foe_col": (60, 40, 50)},
    "corporate_2": {"sky": NIGHT, "stars": 120, "props": ["aurora", "derricks"], "ridges": [(130, 6, 0.02, (196, 206, 230), 4)],
                    "ground": (146, (220, 228, 242), (196, 206, 226)), "hero": CO, "hero_units": ["Tank", "Anti Aircraft"],
                    "foes": [HO, HO], "foe_units": ["Tank", "Infantry", "Tank"], "foe_col": (40, 30, 40), "weather": "snow"},
    "corporate_3": {"sky": ((120, 50, 60), (255, 160, 80)), "sun": (60, 100, 18), "sea": 132, "props": ["factories"],
                    "ground": (156, (60, 54, 50), (72, 64, 58)), "hero": CO, "hero_units": ["Drone", "Fighter Jet"], "hero_y": 112,
                    "foes": [ME, ME], "foe_flag_y": 70, "foe_units": ["Rocket Launcher", "Tank"], "foe_y": 124, "foe_col": (40, 20, 24)},
    "corporate_end": {"sky": ((20, 10, 40), (120, 50, 140)), "stars": 60, "skyline": (150, (30, 20, 50), (90, 220, 250), 9, 1.4),
                      "spire": (160, 90), "props": ["coins"], "ground": (160, (24, 18, 34), (34, 26, 46)), "hero": CO,
                      "foes": [CA, IN, HO, ME], "foe_flag_y": 110},
    # Horde: The Puppet Master
    "horde_1": {"sky": ((40, 30, 60), (240, 170, 90)), "sun": (250, 96, 16), "ridges": [(116, 14, 0.02, (110, 80, 70), 2), (132, 8, 0.03, (160, 130, 70), 6)],
                "props": ["wall"], "ground": (148, (170, 140, 70), (150, 120, 60)), "hero": HO, "hero_units": ["Tank", "Infantry"],
                "foes": [PK, PK], "foe_units": ["Infantry", "Wall", "Anti Aircraft"], "foe_col": (60, 50, 50), "weather": "sand"},
    "horde_2": {"sky": ((60, 70, 110), (200, 200, 220)), "ridges": [(100, 30, 0.03, (120, 120, 140), 5), (118, 22, 0.05, (90, 90, 110), 2), (134, 8, 0.06, (70, 66, 80), 9)],
                "props": ["coins"], "ground": (150, (90, 80, 70), (104, 92, 80)), "hero": HO, "hero_units": ["Infantry", "Special Ops"],
                "foes": [IN, IN], "foe_units": ["Infantry", "Infantry"], "foe_col": (50, 44, 50), "weather": "snow"},
    "horde_3": {"sky": NIGHT, "stars": 90, "props": ["aurora", "ice", "boats"], "sea": 120, "boat_flag": CO,
                "ground": (158, (220, 228, 242), (196, 206, 226)), "hero": HO, "hero_units": ["Tank", "Rocket Launcher"], "hero_y": 112, "weather": "snow"},
    "horde_end": {"sky": ((20, 24, 50), (120, 140, 180)), "stars": 60, "ridges": [(130, 6, 0.02, (196, 206, 230), 4)],
                  "ground": (146, (220, 228, 242), (196, 206, 226)), "hero": HO, "hero_units": ["Tank", "Tank", "Infantry"],
                  "foes": [PK, CO, IN], "foe_flag_y": 80, "weather": "snow"},
    # Coalition Army: Old Europe
    "coalition_1": {"sky": STORM, "ridges": [(122, 8, 0.03, (70, 90, 60), 3)], "props": ["jungle"], "jungle_y": 124,
                    "ground": (148, (80, 70, 50), (94, 82, 58)), "hero": CA, "hero_units": ["Tank", "Infantry"],
                    "foes": [HO, HO], "foe_units": ["Tank", "Tank", "Infantry"], "foe_col": (36, 24, 30), "weather": "rain"},
    "coalition_2": {"sky": DUSK, "sun": (90, 104, 16), "sea": 126, "props": ["volcano", "boats"], "boat_flag": ME,
                    "ground": (158, (150, 120, 80), (170, 136, 90)), "hero": CA, "hero_units": ["Artilery", "Infantry"], "hero_y": 114},
    "coalition_3": {"sky": STORM, "props": ["factories"], "ground": (150, (70, 80, 70), (84, 94, 80)), "hero": CA, "hero_units": ["Tank", "Artilery"],
                    "foes": [CO, CO], "foe_flag_y": 64, "weather": "rain"},
    "coalition_end": {"sky": ((20, 10, 20), (160, 60, 40)), "skyline": (150, (40, 24, 30), (255, 180, 90), 17, 1.2), "props": ["fires"],
                      "ground": (160, (30, 20, 22), (42, 28, 30)), "hero": CA, "foes": [ST, ST, ST], "foe_flag_y": 96},
    # Fundamentalists: The Flame
    "fundamentalists_1": {"sky": ((80, 60, 120), (250, 180, 110)), "sun": (60, 100, 14), "sea": 136, "sea_cols": ((60, 90, 110), (80, 110, 130)),
                          "props": ["palms"], "palm_x": (120, 160, 280), "prop_y": 136, "ground": (156, (190, 150, 90), (176, 136, 80)),
                          "hero": FU, "hero_units": ["Infantry", "Infantry"], "foes": [IN], "foe_units": ["Infantry", "Infantry"], "foe_y": 112},
    "fundamentalists_2": {"sky": ((250, 200, 120), (220, 120, 70)), "sun": (60, 50, 20), "domes": 132, "dome_col": (90, 60, 70),
                          "ground": (150, (200, 160, 100), (184, 146, 88)), "hero": FU, "hero_units": ["Tank", "Infantry"],
                          "foes": [PK, PK], "foe_flag_y": 70},
    "fundamentalists_3": {"sky": ((250, 190, 90), (230, 110, 60)), "sun": (280, 60, 18), "props": ["pyramids", "palms"], "palm_x": (110, 300),
                          "prop_y": 148, "sea": 144, "ground": (156, (190, 150, 90), (176, 136, 80)), "hero": FU, "hero_units": ["Tank", "Rocket Launcher"],
                          "foes": [ME], "foe_flag_y": 80, "foe_units": ["Tank", "Infantry"], "foe_y": 124, "foe_col": (60, 30, 30)},
    "fundamentalists_end": {"sky": ((30, 30, 50), (110, 90, 100)), "props": ["crate"], "ridges": [(130, 6, 0.03, (90, 74, 70), 3)],
                            "ground": (154, (70, 60, 56), (82, 70, 64)), "hero": ST, "weather": "sand"},
    # Mercenaries: Contracts
    "mercenaries_1": {"sky": DAY, "sun": (260, 30, 14), "sea": 116, "props": ["boats"], "boat_flag": ME,
                      "ridges": [], "ground": (150, (220, 196, 140), (204, 180, 124)), "hero": ME, "hero_units": ["Infantry", "Tank"],
                      "foes": [PK], "foe_flag_y": 100},
    "mercenaries_2": {"sky": ((60, 40, 70), (220, 120, 80)), "ridges": [(104, 26, 0.025, (120, 90, 90), 3), (128, 10, 0.05, (90, 66, 70), 8)],
                      "props": ["fires"], "ground": (150, (130, 96, 70), (116, 86, 62)), "hero": ME, "hero_units": ["Rocket Launcher", "Tank"],
                      "foes": [CA, CA], "foe_flag_y": 80},
    "mercenaries_3": {"sky": NIGHT, "stars": 140, "moon": (260, 30, 10), "props": ["palms"], "palm_x": (150, 176, 210), "prop_y": 140,
                      "sea": 140, "sea_cols": ((30, 50, 90), (40, 66, 110)), "ground": (150, (110, 84, 60), (96, 74, 52)),
                      "hero": ME, "hero_units": ["Infantry", "Special Ops"], "foes": [FU], "foe_flag_y": 96},
    "mercenaries_end": {"sky": NIGHT, "stars": 160, "props": ["campfire", "coins"], "ground": (150, (90, 70, 50), (78, 62, 46)), "hero": ME},
    # Insurgents: The Mountain and the Sun
    "insurgents_1": {"sky": ((70, 60, 110), (250, 190, 120)), "sun": (250, 80, 14), "ridges": [(96, 30, 0.03, (120, 90, 100), 4), (118, 20, 0.05, (90, 70, 80), 1)],
                     "skyline": (150, (60, 44, 60), (255, 210, 120), 3, 0.5), "ground": (154, (80, 60, 60), (92, 70, 66)),
                     "hero": IN, "hero_units": ["Infantry", "Infantry"], "foes": [ST], "foe_flag_y": 104},
    "insurgents_2": {"sky": STORM, "ridges": [(100, 24, 0.03, (70, 100, 80), 5), (122, 12, 0.05, (50, 80, 60), 2)], "sea": 138,
                     "props": ["boats"], "boat_flag": IN, "ground": (156, (60, 80, 60), (70, 92, 68)), "hero": IN, "hero_units": ["Infantry"],
                     "foes": [CA], "foe_flag_y": 80, "weather": "rain"},
    "insurgents_3": {"sky": DAY, "ridges": [(108, 3, 0.05, (110, 130, 96), 2)], "props": ["cliffs", "boats"], "sea": 112, "boat_flag": IN,
                     "ground": (160, (60, 60, 70), (70, 70, 80)), "hero": IN, "hero_flag_y": 40, "foes": [ST, ST], "foe_flag_y": 78},
    "insurgents_end": {"sky": DUSK, "skyline": (150, (60, 44, 70), (255, 210, 120), 23, 1.1), "spire": (240, 70),
                       "ground": (160, (40, 34, 44), (50, 42, 54)), "hero": IN, "hero_units": ["Infantry", "Infantry"], "weather": "fireworks"},
    # Peace Keepers: The Blue Line
    "peacekeepers_1": {"sky": ((60, 90, 90), (170, 200, 180)), "props": ["jungle"], "jungle_y": 112, "ground": (150, (40, 70, 40), (50, 84, 48)),
                       "hero": PK, "hero_units": ["Infantry", "Interceptor"], "foes": [IN, IN], "foe_flag_y": 76, "weather": "rain"},
    "peacekeepers_2": {"sky": ((250, 200, 110), (230, 130, 70)), "sun": (230, 60, 22), "props": ["palms"], "palm_x": (140, 220, 290),
                       "prop_y": 146, "ground": (150, (190, 150, 90), (176, 136, 80)), "hero": PK, "hero_units": ["Anti Aircraft", "Interceptor"],
                       "foes": [FU], "foe_flag_y": 98, "weather": "sand"},
    "peacekeepers_3": {"sky": ((90, 50, 70), (250, 160, 80)), "sun": (240, 112, 20), "ridges": [(126, 8, 0.03, (150, 100, 70), 2)],
                       "ground": (150, (160, 110, 70), (144, 98, 62)), "hero": PK, "hero_units": ["Tank", "Infantry"],
                       "foes": [ME, ME], "foe_units": ["Tank", "Infantry"], "foe_col": (60, 30, 30)},
    "peacekeepers_end": {"sky": ((20, 40, 90), (140, 190, 240)), "sun": (160, 150, 40), "ground": (160, (40, 70, 110), (50, 84, 124)),
                         "hero": PK, "foes": [CO, HO, IN], "foe_flag_y": 70},
}

SCENES = {"ch1": ch1, "ch2": ch2, "ch3": ch3, "ch4": ch4, "ch5": ch5, "epilogue": epilogue, "defeat": defeat}
for _name, _spec in COMPOSED.items():
    SCENES[_name] = (lambda sp: (lambda: compose(sp)))(_spec)
for _cid, _faction in (("corporate", CO), ("horde", HO), ("coalition", CA), ("fundamentalists", FU),
                       ("mercenaries", ME), ("insurgents", IN), ("peacekeepers", PK)):
    SCENES["defeat_" + _cid] = (lambda f: (lambda: defeat_of(f)))(_faction)


def main():
    os.makedirs(OUT, exist_ok=True)
    shots = []
    for name, fn in SCENES.items():
        g = fn()
        g.save(os.path.join(OUT, name + ".png"), 4)
        shots.append(g)
        print("story art", name)
    prev = os.path.join(R.ROOT, "build", "previews")
    os.makedirs(prev, exist_ok=True)
    R.sheet(shots, 4, 1, os.path.join(prev, "story.png"))


if __name__ == "__main__":
    main()
