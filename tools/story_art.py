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


SCENES = {"ch1": ch1, "ch2": ch2, "ch3": ch3, "ch4": ch4, "ch5": ch5, "epilogue": epilogue, "defeat": defeat}


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
    R.sheet(shots, 2, 2, os.path.join(prev, "story.png"))


if __name__ == "__main__":
    main()
