#!/usr/bin/env python3
"""8-bit retro pixel-art overhaul generator.

Regenerates every sprite in Assets/ (cards, projectiles, effects, piles,
modifiers, faction flags/backdrops, UI icons and board tiles) in one
consistent NES-style look: a single 32-colour palette, hand-drawn ASCII
sprites on a small logical grid, automatic 1px dark outlines, ground
shadows, and looping 20-frame idle / attack animations.

Pure stdlib (struct/zlib) - no dependencies. Art is drawn on a tiny grid
(32x32 for cards) and upscaled NEAREST so pixels stay crisp. Output file
names and sizes match what the game already loads. Run:

    python3 tools/retro_overhaul.py            # everything
    python3 tools/retro_overhaul.py cards ui   # selected groups
    python3 tools/retro_overhaul.py preview    # contact sheet only
"""
import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FR = 20  # idle / attack frames per animated asset (matches game code)

# ---------------------------------------------------------------- palette
# One shared palette; every sprite is drawn with these single-char codes.
PAL = {
    "K": (20, 16, 30),      # outline
    "n": (30, 26, 40),      # interior black
    "k": (44, 40, 56),      # tyres / deep shadow
    "1": (60, 66, 88),      # steel ramp dark -> light
    "2": (94, 104, 128),
    "3": (138, 150, 172),
    "4": (190, 200, 216),
    "5": (238, 242, 248),
    "o": (42, 56, 30),      # olive ramp
    "p": (70, 92, 42),
    "q": (108, 138, 58),
    "r": (156, 184, 86),
    "t": (82, 56, 36),      # tan / wood ramp
    "u": (132, 94, 56),
    "v": (190, 148, 92),
    "w": (232, 202, 148),
    "s": (242, 190, 148),   # skin
    "z": (192, 126, 90),
    "R": (222, 50, 58),     # red
    "e": (138, 28, 44),
    "O": (252, 146, 34),    # fire
    "Y": (255, 226, 80),
    "W": (255, 252, 240),
    "C": (92, 222, 250),    # cyan light
    "c": (36, 112, 182),
    "G": (98, 236, 112),    # green light
    "g": (104, 164, 214),   # glass
    "h": (198, 236, 252),
    "b": (126, 58, 46),     # brick
    "B": (182, 92, 64),
    "m": (92, 54, 138),     # purple
    "M": (160, 110, 212),
    "y": (198, 146, 30),    # gold
}
OUTLINE = PAL["K"]
SHADOW = (10, 8, 20, 90)
CLEAR = None


def rgba(c, a=255):
    if isinstance(c, str):
        c = PAL[c]
    return (c[0], c[1], c[2], a if len(c) == 3 else c[3])


# -------------------------------------------------------------------- PNG
def png_write(path, rgba_bytes, w, h):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(rgba_bytes[y * stride:(y + 1) * stride])

    def chunk(ctype, data):
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


# ------------------------------------------------------------------ canvas
class Pix:
    """Pixel canvas on a logical grid. None = transparent."""

    def __init__(self, w, h, fill=None):
        self.w, self.h = w, h
        self.px = [fill] * (w * h)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y * self.w + x]
        return None

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = rgba(c) if c is not None else None

    def r(self, x, y, w, h, c):
        col = rgba(c) if c is not None else None
        for j in range(max(y, 0), min(y + h, self.h)):
            for i in range(max(x, 0), min(x + w, self.w)):
                self.px[j * self.w + i] = col

    def disc(self, cx, cy, rad, c):
        for j in range(int(cy - rad) - 1, int(cy + rad) + 2):
            for i in range(int(cx - rad) - 1, int(cx + rad) + 2):
                if (i - cx) ** 2 + (j - cy) ** 2 <= rad * rad + 0.5:
                    self.p(i, j, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((i - cx) / max(rx, 0.1)) ** 2 + ((j - cy) / max(ry, 0.1)) ** 2 <= 1.0:
                    self.p(i, j, c)

    def ln(self, x0, y0, x1, y1, c, th=1):
        steps = max(abs(x1 - x0), abs(y1 - y0)) + 1
        for s in range(steps):
            t = s / max(steps - 1, 1)
            cx = int(round(x0 + (x1 - x0) * t))
            cy = int(round(y0 + (y1 - y0) * t))
            self.r(cx - th // 2, cy - th // 2, th, th, c)

    def stamp(self, rows, x, y, flip=False, remap=None):
        """Draw ASCII art; '.' and ' ' are transparent."""
        for j, row in enumerate(rows):
            if flip:
                row = row[::-1]
            for i, ch in enumerate(row):
                if ch in ". ":
                    continue
                if remap and ch in remap:
                    ch = remap[ch]
                    if ch == ".":
                        continue
                self.p(x + i, y + j, ch)

    def outline(self, c=OUTLINE, diag=False):
        """Add a 1px outline around every opaque pixel."""
        col = rgba(c)
        add = []
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diag:
            nb += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y * self.w + x] is not None:
                    continue
                for dx, dy in nb:
                    q = self.get(x + dx, y + dy)
                    if q is not None and q[3] > 200 and q != col:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y * self.w + x] = col
        return self

    def over(self, other, ox=0, oy=0):
        """Alpha-composite another canvas on top of this one."""
        for j in range(other.h):
            for i in range(other.w):
                c = other.px[j * other.w + i]
                if c is None:
                    continue
                x, y = i + ox, j + oy
                if not (0 <= x < self.w and 0 <= y < self.h):
                    continue
                if c[3] >= 255:
                    self.px[y * self.w + x] = c
                    continue
                d = self.px[y * self.w + x]
                a = c[3] / 255.0
                if d is None:
                    self.px[y * self.w + x] = c
                else:
                    da = d[3] / 255.0
                    oa = a + da * (1 - a)
                    mix = tuple(int((c[k] * a + d[k] * da * (1 - a)) / oa) for k in range(3))
                    self.px[y * self.w + x] = mix + (int(oa * 255),)
        return self

    def shifted(self, dx, dy):
        out = Pix(self.w, self.h)
        out.over(self, dx, dy)
        return out

    def to_bytes(self, scale):
        W = self.w * scale
        buf = bytearray()
        clear = b"\x00\x00\x00\x00"
        for y in range(self.h):
            row = bytearray()
            for x in range(self.w):
                c = self.px[y * self.w + x]
                row.extend((bytes(c) if c is not None else clear) * scale)
            buf.extend(bytes(row) * scale)
        return bytes(buf), W, self.h * scale

    def save(self, path, scale):
        data, W, H = self.to_bytes(scale)
        png_write(path, data, W, H)


def shadow(g, cx, gy, hw, alpha=90):
    """Flat ground-shadow ellipse (drawn on its own layer, under the body)."""
    col = (10, 8, 20, alpha)
    for dy, inset in ((0, 1), (1, 0), (2, 2)):
        yy = gy + dy
        for i in range(cx - hw + inset, cx + hw - inset):
            if 0 <= i < g.w and 0 <= yy < g.h:
                g.px[yy * g.w + i] = col


def wave(i, amp=1.0, period=FR, phase=0.0):
    """Loop-safe sine offset over the 20-frame cycle."""
    return int(round(math.sin((i / period + phase) * 2 * math.pi) * amp))


# --------------------------------------------------------------- FX pieces
def flash(g, x, y, size):
    """Muzzle flash star; size 1..3."""
    if size <= 0:
        return
    if size >= 3:
        g.disc(x, y, 2.2, "O")
        for dx, dy in ((3, 0), (-3, 0), (0, 3), (0, -3), (4, 0)):
            g.p(x + dx, y + dy, "O")
    if size >= 2:
        g.disc(x, y, 1.3, "Y")
        g.p(x + 2, y, "Y")
        g.p(x - 2, y, "Y")
        g.p(x, y + 2, "Y")
        g.p(x, y - 2, "Y")
    g.p(x, y, "W")
    g.p(x + 1, y, "W")


def puff(g, x, y, r, dark=False, alpha=230):
    """Smoke puff with a lit top-left edge."""
    body = PAL["2"] if dark else PAL["3"]
    lite = PAL["3"] if dark else PAL["4"]
    g.disc(x, y, r, body + (alpha,))
    if r >= 1.5:
        g.disc(x - 0.6, y - 0.6, r - 1, lite + (alpha,))


def fx_smoke(g, x, y, t, rise=1.0, dark=False):
    """Smoke puff trail; t in [0,1) is age of the puff."""
    if t < 0 or t >= 1:
        return
    r = 1 + t * 2.4
    puff(g, x + t * 3, y - t * 8 * rise, r, dark, int(235 * (1 - t * 0.7)))


def treads(g, x0, x1, y, phase):
    """Animated tank track, 7px tall, from x0 to x1."""
    g.r(x0 + 1, y, x1 - x0 - 1, 7, "1")
    g.r(x0, y + 1, x1 - x0 + 1, 5, "1")
    for i in range(x0 + 1, x1):
        if (i + phase) % 3 == 0:
            g.p(i, y, "3")
            g.p(i, y + 6, "2")
        else:
            g.p(i, y, "2")
    for wx in range(x0 + 3, x1 - 1, 5):
        g.disc(wx, y + 3, 1.6, "k")
        g.p(wx, y + 3, "3")
        g.p(wx - 1, y + 2, "2")


def wheel(g, cx, cy, rad, spin=0):
    g.disc(cx, cy, rad, "k")
    g.disc(cx, cy, max(rad - 1.4, 0.8), "2")
    g.p(cx, cy, "4")
    if rad >= 3:
        a = spin * math.pi / 4
        g.p(int(round(cx + math.cos(a) * (rad - 1))), int(round(cy + math.sin(a) * (rad - 1))), "3")


def sweep_flag(g, x, y, i, field, stripe):
    """Small waving pennant on a pole (pole x, top y)."""
    g.r(x, y, 1, 9, "2")
    g.p(x, y - 1, "Y")
    ph = (i // 3) % 4
    offs = (0, 1, 0, -1)
    for k in range(6):
        dy = offs[(k // 2 + ph) % 4] if k > 1 else 0
        g.r(x + 1 + k, y + dy, 1, 4, field)
        g.p(x + 1 + k, y + dy + 1, stripe)


# =================================================================== CARDS
# Every card is drawn on a 32x32 grid (x16 -> 512px). draw(i, atk) returns
# three layers: ground shadow, body (auto-outlined) and fx (no outline).

def card_frame(draw_body, i, atk, shadow_spec=None, fx=None):
    g = Pix(32, 32)
    if shadow_spec:
        cx, gy, hw, a = shadow_spec
        shadow(g, cx, gy, hw, a)
    body = Pix(32, 32)
    draw_body(body)
    body.outline()
    g.over(body)
    if fx:
        f = Pix(32, 32)
        fx(f)
        g.over(f)
    return g


def blink(i, on=(0, 1, 2, 3, 4, 5, 6, 7, 8, 9)):
    return i in on


# attack timeline shared by gunners: frame -> flash size / recoil px
ATK_FLASH = {3: 3, 4: 2, 5: 1, 11: 3, 12: 2, 13: 1}
ATK_RECOIL = {3: 1, 4: 1, 5: 1, 11: 1, 12: 1, 13: 1}


def smoke_age(i, start, life=10):
    """Age of a puff emitted at frame `start` (wraps on the 20-frame loop)."""
    return ((i - start) % FR) / life


# ------------------------------------------------------------------ tank
TANK_HULL = [
    "..ppppppppppppppppppppppppp..",
    ".pqrrrrrrrrrrrrrrrrrrrrrrrqp.",
    "pqqqqqqqqqqqqqqqqqqqqqqqqqqqp",
    "pqqpqqqqpqqqqpqqqqpqqqqpqqqqp",
    "ooooooooooooooooooooooooooooo",
]
TANK_TURRET = [
    "....ppppppp...",
    "..ppqrrrrrrqp.",
    ".pqrrqqqqqqqqp",
    "pqqqqqqqWqqqqp",
    "pqqqqqWWWWWqqp",
    "pqqqqqqWqWqqqp",
    "oooooooooooooo",
]


def draw_tank(i, atk):
    rumble = 1 if (i // 2) % 2 and not atk else 0
    rec = ATK_RECOIL.get(i, 0) if atk else 0

    def body(g):
        y = rumble
        treads(g, 2, 28, 21, 0 if atk else i // 2)
        g.stamp(TANK_HULL, 1, 16 + y)
        g.stamp(TANK_TURRET, 7 - rec, 9 + y)
        bx = 20 - rec * 2
        g.r(bx, 11 + y, 10, 1, "4")
        g.r(bx, 12 + y, 10, 1, "2")
        g.r(bx + 9, 10 + y, 2, 4, "2")
        g.p(bx + 9, 10 + y, "3")
        g.r(9 - rec, 7 + y, 4, 2, "2")
        g.r(10 - rec, 7 + y, 2, 1, "3")
        g.r(8 - rec, 2 + y, 1, 7, "1")
        g.p(8 - rec, 1 + y, "R" if blink(i, range(0, 6)) else "e")

    def fx(g):
        # exhaust
        fx_smoke(g, 1, 17, smoke_age(i, 0, 12), dark=True)
        if atk:
            s = ATK_FLASH.get(i, 0)
            flash(g, 31, 12, s)
            fx_smoke(g, 29, 10, smoke_age(i, 6, 10))
            fx_smoke(g, 28, 11, smoke_age(i, 14, 10))

    return card_frame(body, i, atk, (15, 27, 14, 90), fx)


# -------------------------------------------------------------- soldiers
SOLDIER_TOP = [
    "....pppp..........",
    "...pqqrrp.........",
    "..pqrrqqqp........",
    "..pqqqqqqqp.......",
    ".opppppppppo......",
    "...zssss..........",
    "...zssKs..........",
    "...zsssss.........",
    "....zzss..........",
    "..ppqqqqp.........",
    ".pqqrrqqqp........",
    ".pqqqqqqsss2222221",
    ".pqqqqqqqp..11....",
    ".pqqqqqqqp........",
]
SOLDIER_LEGS = [
    "..uuuyuuu.........",
    "..pqqqpqqp........",
    "..pqqp.pqqp.......",
    "..pqq...pqq.......",
    "..pqq...pqq.......",
    ".kkkk...kkkk......",
]
SPECOPS_TOP = [
    "....1111..........",
    "...122221.........",
    "..12222221........",
    "..11111111........",
    "..nnnnnn..........",
    "...nnnnn..........",
    "...nnnGG..........",
    "...nnnnnn.........",
    "....nnnn..........",
    "..11222221........",
    ".1222332221.......",
    ".12222222ss222221.",
    ".122y22221..11....",
    ".122222221........",
]
SPECOPS_LEGS = [
    "..kkkykkk.........",
    "..12221222........",
    "..1221.1221.......",
    "..122...122.......",
    "..122...122.......",
    ".kkkk...kkkk......",
]


def draw_soldier(i, atk, top, legs, gun_y=11, gun_x=17):
    breathe = 1 if (i // 5) % 2 and not atk else 0
    rec = ATK_RECOIL.get(i, 0) if atk else 0

    def body(g):
        g.stamp(legs, 8, 21)
        rows = list(top)
        if not atk and i in (13, 14):   # blink
            rows[6] = rows[6].replace("K", "s").replace("GG", "nn")
        g.stamp(rows, 8 - rec, 7 + breathe)

    def fx(g):
        if atk:
            s = ATK_FLASH.get(i, 0)
            flash(g, 8 + gun_x + 1 - rec, 7 + gun_y, min(s, 2))
            if s:
                g.p(17, 16 - (i % 3), "Y")   # ejected casing
            fx_smoke(g, 26, 16, smoke_age(i, 6, 8))

    return card_frame(body, i, atk, (14, 27, 7, 90), fx)


def draw_infantry(i, atk):
    return draw_soldier(i, atk, SOLDIER_TOP, SOLDIER_LEGS)


def draw_specops(i, atk):
    return draw_soldier(i, atk, SPECOPS_TOP, SPECOPS_LEGS, gun_x=16)


# ----------------------------------------------------------------- drone
DRONE_BODY = [
    "......244444442......",
    ".....24455555442.....",
    ".....23333333332.....",
    "......122222221......",
    "........kkRkk........",
]


def draw_drone(i, atk):
    hover = wave(i, 1.4)

    def body(g):
        y = 9 + hover
        for cx in (6, 25):
            g.r(cx, y + 1, 1, 2, "1")
            if i % 2 == 0:
                g.r(cx - 4, y, 9, 1, "4")
                g.p(cx, y, "2")
            else:
                g.r(cx - 2, y, 5, 1, "3")
                g.p(cx, y, "2")
        g.r(6, y + 3, 20, 1, "2")
        g.r(6, y + 3, 2, 1, "1")
        g.r(24, y + 3, 2, 1, "1")
        rows = list(DRONE_BODY)
        if not blink(i, range(0, 10, 1)) and not atk:
            rows[4] = rows[4].replace("R", "e")
        g.stamp(rows, 5, y + 2)
        g.p(12, y + 7, "1")
        g.p(19, y + 7, "1")
        g.r(10, y + 8, 4, 1, "1")
        g.r(18, y + 8, 4, 1, "1")

    def fx(g):
        y = 9 + hover
        if i % 2:
            for cx in (6, 25):
                for dx in (-4, -3, 3, 4):
                    g.p(cx + dx, y, PAL["4"] + (110,))
        if atk:
            s = ATK_FLASH.get(i, 0)
            if s:
                g.ln(15, y + 8, 15, 31, PAL["R"] + (200,))
                g.ln(16, y + 8, 16, 31, PAL["Y"] + (160,))
                flash(g, 15, y + 8, 1)

    hw = 8 - hover
    return card_frame(body, i, atk, (15, 27, hw, 60), fx)


# ------------------------------------------------------------ fighter jet
JET = [
    "..34..........................",
    "..344.........................",
    "..3444...............hh.......",
    "..34444............ghhhh......",
    ".23333333333333333gggggg333...",
    "244444444444444444444444444433",
    "23333R33333333333333333333322.",
    ".122222222222222222222222221..",
    "......1112222222222211........",
    "........11111111111...........",
]


def draw_jet(i, atk):
    hover = wave(i, 1.0)

    def body(g):
        g.stamp(JET, 1, 8 + hover)

    def fx(g):
        y = 13 + hover
        ln = (2, 3, 2, 4)[i % 4]
        g.r(1 - ln, y, ln, 2, "O")
        g.r(1 - max(ln - 2, 0), y, max(ln - 2, 1), 2, "Y")
        g.p(0, y, "W")
        if atk:
            s = ATK_FLASH.get(i, 0)
            flash(g, 30, y + 1, min(s, 2))
            if 3 <= i <= 9:
                mx = 12 + (i - 3) * 3
                g.r(mx, 18 + hover, 5, 1, "4")
                g.p(mx + 5, 18 + hover, "R")
                g.r(mx - 2, 18 + hover, 2, 1, "O")
                fx_smoke(g, mx - 3, 18 + hover, 0.2)

    return card_frame(body, i, atk, (15, 27, 11, 55), fx)


# ------------------------------------------------------------ interceptor
def draw_interceptor(i, atk):
    def body(g):
        # truck bed + cab
        g.r(2, 20, 26, 4, "p")
        g.r(2, 20, 26, 1, "q")
        g.r(2, 23, 26, 1, "o")
        g.stamp([
            "..pppp.",
            ".pqhhqp",
            "pqqhgqp",
            "pqqqqqp",
        ], 23, 16)
        for wx in (6, 13, 24):
            wheel(g, wx, 25, 2.4, i)
        # radar mast + rotating dish
        g.r(6, 12, 1, 8, "2")
        w = (4, 3, 1, 3)[(i // 3) % 4]
        g.r(6 - w // 2 - (w % 2 == 0), 10, w + (w % 2 == 0), 1, "4")
        g.r(6 - w // 2 - (w % 2 == 0), 11, w + (w % 2 == 0), 1, "3")
        g.p(6, 9, "G" if blink(i, range(0, 20, 2)) else "2")
        # launcher rails with missiles
        g.ln(10, 19, 20, 12, "2", 2)
        fired = atk and i >= 4
        for k, (x0, y0) in enumerate(((11, 16), (13, 18))):
            if k == 0 and fired:
                continue
            g.ln(x0, y0, x0 + 7, y0 - 5, "5")
            g.ln(x0, y0 + 1, x0 + 7, y0 - 4, "3")
            g.p(x0 + 8, y0 - 6, "R")
            g.p(x0 + 8, y0 - 5, "R")

    def fx(g):
        if atk and i >= 4:
            t = min(i - 4, 8)
            mx, my = 20 + t * 1.6, 10 - t * 1.1
            g.ln(int(mx), int(my), int(mx) + 2, int(my) - 1, "5")
            g.p(int(mx) + 3, int(my) - 2, "R")
            g.p(int(mx) - 1, int(my) + 1, "Y")
            g.p(int(mx) - 2, int(my) + 2, "O")
            for k in range(1, 4):
                fx_smoke(g, 18 + k, 13 - k, smoke_age(i, 4 + k * 2, 10))

    return card_frame(body, i, atk, (15, 27, 14, 90), fx)


# ---------------------------------------------------------- anti aircraft
def draw_aa(i, atk):
    alt = (i % 2) if atk else 0

    def body(g):
        g.r(3, 21, 24, 3, "2")
        g.r(3, 21, 24, 1, "3")
        for wx in (7, 15, 23):
            wheel(g, wx, 25, 2.4, i)
        # turret ring + shield
        g.stamp([
            "....qqqqqq....",
            "..pqrrrrrrqp..",
            ".pqqqqqqqqqqp.",
            "pqqqqqqqqqqqqp",
            "oooooooooooooo",
        ], 6, 16)
        g.r(9, 11, 6, 5, "q")
        g.r(9, 11, 6, 1, "r")
        g.p(10, 13, "k")
        g.p(11, 13, "k")
        # twin barrels angled 45deg
        for k, off in enumerate((0, 3)):
            back = 1 if atk and (k == alt) and i in ATK_RECOIL else 0
            g.ln(14 + off - back, 13 - back + back, 24 + off - back, 3 + back, "2", 2)
            g.ln(14 + off - back, 12, 24 + off - back, 2 + back, "4")

    def fx(g):
        if atk:
            s = ATK_FLASH.get(i, 0)
            if s:
                tip = (25, 2) if alt == 0 else (28, 2)
                flash(g, tip[0], tip[1], min(s, 2))
            if i in (5, 6, 13, 14):
                g.disc(27, 1, 1.5, PAL["3"] + (200,))

    return card_frame(body, i, atk, (15, 27, 13, 90), fx)


# --------------------------------------------------------------- artilery
def draw_artillery(i, atk):
    rec = 2 if atk and i in (3, 4, 11, 12) else (1 if atk and i in (5, 13) else 0)

    def body(g):
        # trail legs to ground
        g.ln(3, 26, 12, 20, "u", 2)
        g.ln(3, 26, 12, 20, "v")
        g.r(2, 26, 3, 1, "t")
        # barrel along the elevation axis
        bx0, by0 = 12 - rec, 18 + rec // 2
        g.ln(bx0, by0, bx0 + 17, by0 - 8, "2", 2)
        g.ln(bx0, by0 - 1, bx0 + 17, by0 - 9, "4")
        g.r(bx0 + 16, by0 - 10, 2, 3, "2")
        # cradle + shield
        g.stamp([
            "..pppp..",
            ".pqrrqp.",
            "pqqqqqqp",
            "pqqqqqqp",
            "pqqqqqqp",
            ".oooooo.",
        ], 10, 14)
        wheel(g, 14, 23, 4.2, 0)

    def fx(g):
        if atk:
            s = ATK_FLASH.get(i, 0)
            flash(g, 31, 8, s)
            for st in (5, 13):
                fx_smoke(g, 28, 7, smoke_age(i, st, 9))

    return card_frame(body, i, atk, (15, 27, 12, 90), fx)


# --------------------------------------------------------------- howitzer
def draw_howitzer(i, atk):
    rec = 2 if atk and i in (3, 4) else (1 if atk and i in (5, 6) else 0)
    rumble = 1 if (i // 2) % 2 and not atk else 0

    def body(g):
        y = rumble
        treads(g, 2, 28, 21, 0)
        g.stamp(TANK_HULL, 1, 16 + y)
        # heavy barrel 30deg up
        g.ln(16 - rec, 11 + y, 29 - rec, 3 + y, "2", 3)
        g.ln(16 - rec, 10 + y, 29 - rec, 2 + y, "4")
        g.r(28 - rec, 0 + y, 3, 5, "2")
        g.stamp([
            "...ppppppppp...",
            ".ppqrrrrrrrrqp.",
            "pqrrqqqqqqqqqqp",
            "pqqqqqqqqqqqqqp",
            "pqqq1qqqqq1qqqp",
            "pqqqqqqqqqqqqqp",
            "ooooooooooooooo",
        ], 4, 9 + y)
        g.r(6, 7 + y, 3, 2, "2")

    def fx(g):
        fx_smoke(g, 1, 17, smoke_age(i, 3, 12), dark=True)
        if atk:
            s = ATK_FLASH.get(i, 0) if i < 10 else 0
            flash(g, 31, 1, s)
            for st in (5, 7, 9):
                fx_smoke(g, 28, 2, smoke_age(i, st, 11))

    return card_frame(body, i, atk, (15, 27, 14, 90), fx)


# --------------------------------------------------------- rocket launcher
def draw_rocket(i, atk):
    def body(g):
        g.r(2, 20, 20, 4, "p")
        g.r(2, 20, 20, 1, "q")
        g.r(2, 23, 20, 1, "o")
        g.stamp([
            "..ppppp.",
            ".pqqhhhp",
            "pqqqhggp",
            "pqqqqqqp",
            "pqqqqqqp",
            "pqqqqqqp",
            "oooooooo",
        ], 21, 15)
        g.p(28, 20, "Y")
        for wx in (5, 11, 25):
            wheel(g, wx, 25, 2.4, i)
        # tilted launch box (up to the right)
        for k in range(13):
            yy = 17 - k // 2
            g.r(4 + k, yy - 4, 1, 5, "q")
            g.p(4 + k, yy - 4, "r")
            g.p(4 + k, yy, "o")
        # tube mouths on the front face
        fired = atk and i >= 3
        for tx, ty in ((16, 9), (16, 11), (18, 8), (18, 10)):
            g.r(tx, ty, 2, 2, "n")
            if not (fired and (tx, ty) == (18, 8)):
                g.p(tx + 1, ty, "R")
        g.ln(9, 18, 12, 14, "2")

    def fx(g):
        if atk and i >= 3:
            t = i - 3
            rx, ry = 20 + t * 2, 8 - t
            if ry > -3:
                g.r(rx, ry, 3, 1, "5")
                g.p(rx + 3, ry, "R")
                g.p(rx - 1, ry, "Y")
                g.p(rx - 2, ry + 1, "O")
            for k in range(0, min(t, 6)):
                fx_smoke(g, 19 + k * 2, 9 - k, smoke_age(i, 3 + k, 10))
            if i in (3, 4):
                flash(g, 19, 9, 2)

    return card_frame(body, i, atk, (15, 27, 13, 90), fx)


# ------------------------------------------------------------------- wall
def draw_wall(i, atk):
    def body(g):
        # concrete jersey barriers
        for bx in (2, 12, 22):
            g.stamp([
                "..44444..",
                ".4333334.",
                ".3333333.",
                "333323333",
                "333333333",
                "222222222",
                "111111111",
            ], bx - 1, 20)
        # sandbag row
        for k, bx in enumerate(range(3, 29, 5)):
            g.stamp([".vvvv.", "vwwwwv", "uvvvvu"], bx - 1, 16 + (k % 2 == 1) * 0)
        for bx in range(5, 27, 5):
            g.stamp([".vvvv.", "vwwwwv", "uvvvvu"], bx, 13)
        # barbed wire posts
        for px in (4, 15, 27):
            g.r(px, 7, 1, 7, "t")

    def fx(g):
        # coil
        for x in range(3, 29):
            y = 9 + (1 if (x % 4) in (1, 2) else 0) - (1 if x % 4 == 0 else 0)
            g.p(x, y, "3")
            if x % 4 == 2:
                g.p(x, y - 2, "2")
        gx = 3 + (i * 2) % 28
        g.p(gx, 9, "W")
        g.p(gx, 8, PAL["5"] + (150,))

    return card_frame(body, i, atk, (15, 27, 15, 80), fx)


# --------------------------------------------------------------- barracks
def draw_barracks(i, atk):
    def body(g):
        # quonset hut: half cylinder resting on the ground line
        g.ellipse(14, 27, 12, 14, "p")
        g.ellipse(14, 27, 11, 13, "q")
        g.ellipse(11, 24, 6, 9, "r")
        g.r(0, 27, 32, 5, None)
        for rx in range(5, 25, 4):
            for yy in range(12, 27):
                if g.get(rx, yy) is not None:
                    g.p(rx, yy, "p")
        g.r(2, 26, 25, 1, "o")
        g.r(11, 19, 6, 7, "t")
        g.r(12, 20, 4, 6, "u")
        g.p(15, 23, "Y")
        lit = "Y" if (i // 4) % 5 else "O"
        for wx in (5, 20):
            g.r(wx, 20, 3, 3, "n")
            g.r(wx, 20, 3, 2, lit)
        g.stamp(["WWWWW", "R.R.R"], 11, 16)
        g.r(28, 8, 1, 19, "2")
        sweep_flag(g, 28, 8, i, "R", "W")

    def fx(g):
        if atk:
            g.ellipse(14, 22, 14 + (i % 4) * 0.3, 12, PAL["Y"] + (40,))

    return card_frame(body, i, atk, (15, 27, 15, 80), fx)


# ---------------------------------------------------------------- factory
def draw_factory(i, atk):
    def body(g):
        g.r(2, 14, 26, 13, "b")
        g.r(2, 14, 26, 1, "B")
        for yy in range(16, 26, 2):
            for xx in range(2 + (yy // 2) % 2 * 2, 28, 4):
                g.r(xx, yy, 3, 1, "B")
        # sawtooth roof
        for k in range(4):
            x0 = 2 + k * 7
            for d in range(6):
                g.r(x0 + d, 13 - d, 1, d + 1, "2")
                g.p(x0 + d, 13 - d, "3")
            g.r(x0 + 6, 8, 1, 6, "g")
            g.p(x0 + 6, 8, "h")
        # chimney
        g.r(23, 2, 4, 12, "b")
        g.r(23, 2, 4, 1, "3")
        g.r(23, 5, 4, 1, "R")
        # windows glowing
        for k, wx in enumerate((4, 10, 16)):
            glow = "Y" if ((i // 3) + k) % 4 else "O"
            g.r(wx, 18, 4, 4, "n")
            g.r(wx, 18, 4, 3, glow)
            g.r(wx + 1, 18, 1, 3, "O")
        # door
        g.r(22, 19, 5, 8, "2")
        g.r(22, 19, 5, 1, "3")
        for yy in range(21, 27, 2):
            g.r(22, yy, 5, 1, "1")

    def fx(g):
        for st in (0, 7, 14):
            t = smoke_age(i, st, 20)
            puff(g, 25 + t * 4, 1 - t * 2 + 0.5, 1.2 + t * 2.5, dark=True, alpha=int(230 * (1 - t * 0.8)))

    return card_frame(body, i, atk, (15, 27, 15, 80), fx)


# ---------------------------------------------------------------- housing
def draw_housing(i, atk):
    def house(g, x, y, w, roof, roof_hi, wall, lit_on):
        h = 9
        for d in range(w // 2 + 1):
            g.r(x + d, y - d, w - 2 * d, 1, roof)
            g.p(x + d, y - d, roof_hi)
        g.r(x + 1, y + 1, w - 2, h, wall)
        g.r(x + 1, y + 1, w - 2, 1, "u" if wall == "v" else "2")
        g.r(x + w // 2 - 1, y + h - 3, 3, 4, "t")
        for wx in (x + 2, x + w - 5):
            g.r(wx, y + 3, 3, 3, "n")
            if lit_on:
                g.r(wx, y + 3, 3, 3, "Y")
                g.p(wx + 1, y + 4, "O")
            g.p(wx + 1, y + 3, "n")

    def body(g):
        g.r(20, 5, 3, 7, "b")
        house(g, 13, 15, 16, "c", "C", "4", (i // 5) % 4 != 1)
        house(g, 1, 17, 14, "e", "R", "v", (i // 4) % 3 != 2)
        # tree
        g.disc(29, 20, 2.5, "p")
        g.disc(28, 19, 1.5, "q")
        g.r(29, 22, 1, 5, "t")

    def fx(g):
        for st in (0, 10):
            t = smoke_age(i, st, 20)
            puff(g, 21 + t * 3, 4 - t * 5, 1 + t * 2, alpha=int(220 * (1 - t * 0.8)))

    return card_frame(body, i, atk, (15, 27, 15, 80), fx)


# ------------------------------------------------------------- corporation
def draw_corp(i, atk):
    def body(g):
        g.r(9, 7, 14, 21, "c")
        g.r(9, 7, 3, 21, "g")
        g.r(20, 7, 3, 21, "1")
        g.r(11, 4, 10, 3, "2")
        g.r(13, 2, 6, 2, "3")
        g.r(15, 0, 1, 2, "4")
        g.r(9, 10, 14, 2, "y")
        g.stamp(["..Y.Y..", ".YYYYY.", "..Y.Y.."], 12, 9) if False else None
        g.p(15, 10, "W")
        g.p(16, 11, "W")
        # windows grid, a few change each frame
        for yy in range(13, 27, 2):
            for xx in range(10, 22, 2):
                on = ((xx * 7 + yy * 13 + (i // 4) * ((xx + yy) % 3 == 0)) % 5) != 0
                g.p(xx, yy, "Y" if on else "k")
        g.r(14, 24, 4, 4, "n")
        g.r(14, 24, 4, 1, "4")
        # low wings
        g.r(3, 19, 6, 9, "2")
        g.r(23, 21, 6, 7, "2")
        g.r(3, 19, 6, 1, "3")
        g.r(23, 21, 6, 1, "3")
        for xx in (4, 6):
            g.p(xx, 22, "h")
            g.p(xx, 25, "h")
        for xx in (24, 26):
            g.p(xx, 23, "h")
            g.p(xx, 26, "h")

    def fx(g):
        if blink(i, (0, 1, 2, 10, 11, 12)):
            g.p(15, 0, "R")
            g.p(14, 0, PAL["R"] + (110,))
            g.p(16, 0, PAL["R"] + (110,))

    return card_frame(body, i, atk, (16, 27, 14, 80), fx)


CARDS = {
    "Tank": draw_tank,
    "Infantry": draw_infantry,
    "Special Ops": draw_specops,
    "Drone": draw_drone,
    "Fighter Jet": draw_jet,
    "Interceptor": draw_interceptor,
    "Anti Aircraft": draw_aa,
    "Artilery": draw_artillery,
    "Howitzer": draw_howitzer,
    "Rocket Launcher": draw_rocket,
    "RocketLauncher": draw_rocket,
    "Wall": draw_wall,
    "Barracks": draw_barracks,
    "Factory": draw_factory,
    "Housing": draw_housing,
    "Corporation": draw_corp,
}


def gen_cards():
    for name, fn in CARDS.items():
        base = os.path.join(ROOT, "Assets", "Cards", name)
        for i in range(FR):
            fn(i, False).save(os.path.join(base, "sprite_%d.png" % i), 16)
            a = fn(i, True)
            a.save(os.path.join(base, "attack_sprite_%d.png" % i), 16)
            a.save(os.path.join(base, "attack", "sprite_%d.png" % i), 16)
        fn(0, False).save(os.path.join(base, "sprite.png"), 16)
        fn(0, False).save(os.path.join(base, "attack", "sprite.png"), 16)
        print("card", name)


# ---------------------------------------------------------------- preview
def sheet(frames, cols, scale, path, bg=(34, 32, 48, 255)):
    """Contact sheet of equally sized canvases (for eyeballing the art)."""
    w, h = frames[0].w, frames[0].h
    rows = (len(frames) + cols - 1) // cols
    out = Pix(cols * (w + 2), rows * (h + 2), bg)
    for k, f in enumerate(frames):
        out.over(f, (k % cols) * (w + 2) + 1, (k // cols) * (h + 2) + 1)
    out.save(path, scale)


# ============================================================= PROJECTILES
# 16x16 grid x8 = 128px, pointing right (the game rotates them in flight).
def p_bullet(g, i):
    g.r(3, 7, 3, 2, PAL["Y"] + (120,))
    g.r(6, 7, 4, 2, "Y")
    g.r(10, 7, 2, 2, "W")
    g.p(12, 7, "O")
    if i % 2:
        g.p(2, 7, PAL["O"] + (90,))


def p_shell(g, i):
    g.r(1, 7, 4, 2, PAL["3"] + (110 if i % 2 else 70,))
    g.r(5, 6, 6, 4, "y")
    g.r(5, 6, 6, 1, "Y")
    g.r(11, 6, 2, 4, "2")
    g.r(12, 7, 1, 2, "3")
    g.r(13, 7, 1, 2, "1")
    g.r(5, 9, 6, 1, "u")


def p_rocket(g, i):
    ln = (3, 4, 2, 5)[i % 4]
    g.r(4 - ln, 7, ln, 2, "O")
    g.r(4 - max(ln - 2, 1), 7, max(ln - 2, 1), 2, "Y")
    g.r(4, 6, 8, 4, "4")
    g.r(4, 6, 8, 1, "5")
    g.r(4, 9, 8, 1, "3")
    g.r(12, 7, 2, 2, "R")
    g.p(12, 6, "e")
    g.p(12, 9, "e")
    g.r(4, 5, 2, 1, "2")
    g.r(4, 10, 2, 1, "2")


def p_plasma(g, i):
    r = 2.5 + (i % 3) * 0.3
    g.disc(8, 8, r + 1, PAL["C"] + (90,))
    g.disc(8, 8, r, "C")
    g.disc(8, 8, 1.2, "W")
    g.r(1, 8, 4, 1, PAL["C"] + (140,))
    g.r(2 + i % 2, 7, 2, 1, PAL["C"] + (80,))


def p_flak(g, i):
    g.disc(8, 8, 2, "O")
    g.disc(8, 8, 1, "Y")
    g.p(8, 8, "W")
    for k in range(4):
        a = (k * 90 + i * 25) * math.pi / 180
        g.p(int(8 + math.cos(a) * 4), int(8 + math.sin(a) * 4), "Y")


def p_missile(g, i):
    p_rocket(g, i)
    g.r(4, 5, 1, 6, "2")


PROJECTILES = {
    "Infantry": p_bullet,
    "Special Ops": p_bullet,
    "Anti Aircraft": p_flak,
    "Artilery": p_shell,
    "Howitzer": p_shell,
    "Tank": p_shell,
    "Drone": p_plasma,
    "Fighter Jet": p_missile,
    "Interceptor": p_missile,
    "Rocket Launcher": p_rocket,
    "RocketLauncher": p_rocket,
}


def gen_projectiles():
    for name, fn in PROJECTILES.items():
        base = os.path.join(ROOT, "Assets", "Projectiles", name)
        for i in range(FR):
            g = Pix(16, 16)
            fn(g, i)
            g.save(os.path.join(base, "sprite_%d.png" % i), 8)
        g = Pix(16, 16)
        fn(g, 0)
        g.save(os.path.join(base, "sprite.png"), 8)
        print("projectile", name)


# ================================================================= EFFECTS
# 32x32 grid x8 = 256px, 8 frames each.
def e_explosion(g, j):
    ring = [(2, "W", "Y"), (4, "Y", "O"), (6, "Y", "O"), (8, "O", "R"),
            (9, "O", "e"), (10, "2", "1"), (11, "3", "2"), (12, "3", "2")][j]
    r, core, edge = ring
    if j < 5:
        g.disc(16, 16, r, edge)
        g.disc(16, 16, r * 0.7, core)
        if j < 3:
            g.disc(16, 16, r * 0.35, "W")
    else:
        a = int(230 * (1 - (j - 5) / 3.5))
        for k in range(6):
            ang = k * math.pi / 3 + j * 0.2
            puff(g, 16 + math.cos(ang) * r * 0.6, 16 + math.sin(ang) * r * 0.6 - (j - 5), 2.5, dark=(k % 2 == 0), alpha=a)
    for k in range(8):
        ang = k * math.pi / 4 + 0.3
        d = 4 + j * 2
        if j < 6:
            g.p(int(16 + math.cos(ang) * d), int(16 + math.sin(ang) * d), "Y" if j < 3 else "O")


def e_aura(g, j):
    r = 5 + j * 1.5
    a = int(255 * (1 - j / 8))
    for k in range(64):
        ang = k * 2 * math.pi / 64
        x = int(round(16 + math.cos(ang) * r))
        y = int(round(16 + math.sin(ang) * r))
        g.p(x, y, PAL["Y"] + (a,) if k % 2 else PAL["O"] + (a,))
    for k in range(4):
        ang = k * math.pi / 2 + j * 0.4
        g.stamp(["Y"], int(16 + math.cos(ang) * (r - 3)), int(16 + math.sin(ang) * (r - 3)))
    if j < 4:
        g.stamp([".G.", "GGG", ".G."], 15, 15 - j)


def e_bio(g, j):
    y = 20 - j * 2
    a = 255 if j < 6 else int(255 * (8 - j) / 3)
    leaf = [
        "....GG",
        "..GGGG",
        ".GGrGG",
        "GGrGG.",
        "GrGG..",
        "rG....",
    ]
    for row, line in enumerate(leaf):
        for col, ch in enumerate(line):
            if ch != ".":
                g.p(13 + col, y + row, PAL["G" if ch == "G" else "p"] + (a,))
    g.stamp(["W"], 18, y)


def e_money(g, j):
    y = 18 - j * 2
    a = 255 if j < 6 else int(255 * (8 - j) / 3)
    w = (10, 7, 3, 7, 10, 7, 3, 7)[j]
    g.ellipse(16, y + 4, w / 2, 5, PAL["y"] + (a,))
    if w > 3:
        g.ellipse(16, y + 4, w / 2 - 1, 4, PAL["Y"] + (a,))
    if w >= 10:
        for k, row in enumerate([".yyy", "y...", ".yy.", "...y", "yyy."]):
            for c, ch in enumerate(row):
                if ch == "y":
                    g.p(15 + c - 1, y + 2 + k, PAL["y"] + (a,))
        g.p(13, y + 1, PAL["W"] + (a,))


def e_intercept(g, j):
    r = 4 + j * 1.6
    a = int(255 * (1 - j / 9))
    for k in range(6):
        a0 = k * math.pi / 3
        a1 = (k + 1) * math.pi / 3
        g.ln(int(16 + math.cos(a0) * r), int(16 + math.sin(a0) * r),
             int(16 + math.cos(a1) * r), int(16 + math.sin(a1) * r), PAL["C"] + (a,))
    if j < 4:
        flash(g, 16, 16, 3 - j)
    for k in range(6):
        ang = k * math.pi / 3 + 0.5
        g.p(int(16 + math.cos(ang) * (r + 2)), int(16 + math.sin(ang) * (r + 2)), PAL["W"] + (a,))


EFFECTS = {
    "fighter_jet_splash": e_explosion,
    "barracks_aura": e_aura,
    "income_bio": e_bio,
    "income_money": e_money,
    "interceptor_intercept": e_intercept,
}


def gen_effects():
    base = os.path.join(ROOT, "Assets", "Effects")
    for name, fn in EFFECTS.items():
        for j in range(8):
            g = Pix(32, 32)
            fn(g, j)
            g.save(os.path.join(base, "%s_%d.png" % (name, j)), 8)
        g = Pix(32, 32)
        fn(g, 0)
        g.save(os.path.join(base, "%s.png" % name), 8)
        print("effect", name)


# =================================================================== PILES
CARD_BACK = [
    "cccccccccc",
    "cCCCCCCCCc",
    "cCccccccCc",
    "cCcYYYYcCc",
    "cCcYccYcCc",
    "cCcYccYcCc",
    "cCcYYYYcCc",
    "cCccccccCc",
    "cCCCCCCCCc",
    "cccccccccc",
]


def card_rect(g, x, y, w, h, face=False):
    g.r(x, y, w, h, "4" if face else "c")
    g.r(x + 1, y + 1, w - 2, h - 2, "5" if face else "C")
    g.r(x + 2, y + 2, w - 4, h - 4, "4" if face else "c")
    if not face:
        g.r(x + w // 2 - 2, y + h // 2 - 3, 4, 6, "Y")
        g.r(x + w // 2 - 1, y + h // 2 - 2, 2, 4, "c")


def d_draw(g, i):
    body = Pix(32, 32)
    for k in range(4):
        card_rect(body, 8 + k, 12 - k * 2, 16, 18)
    top = 8 + 3
    body.outline()
    g.over(body)
    gx = (i * 2) % 40 - 4
    for d in range(4):
        x = gx + d
        y = 6 + (x - top)
        if top + 1 <= x < top + 15 and 7 <= y < 23:
            g.p(x, y, PAL["W"] + (170,))


def d_discard(g, i):
    body = Pix(32, 32)
    tilt = wave(i, 1)
    for k, (dx, dy) in enumerate(((-6, 3), (0, 0), (6, 3))):
        x0 = 8 + dx
        y0 = 9 + dy + (tilt if k == 1 else 0)
        card_rect(body, x0, y0, 16, 18, face=True)
        body.r(x0 + 3, y0 + 4, 10, 1, "2")
        body.r(x0 + 3, y0 + 7, 7, 1, "3")
        body.r(x0 + 3, y0 + 10, 9, 1, "3")
    body.outline()
    g.over(body)


def d_graveyard(g, i):
    body = Pix(32, 32)
    body.stamp([
        "....33333333....",
        "...3444444443...",
        "..344444444443..",
        "..344442244443..",
        "..344422224443..",
        "..344442244443..",
        "..344442244443..",
        "..344444444443..",
        "..344222222443..",
        "..344444444443..",
        "..344222224443..",
        "..344444444443..",
        "..333333333333..",
        ".pqqqpqqqqpqqqp.",
        "pppppppppppppppp",
    ], 8, 11)
    body.outline()
    g.over(body)
    # drifting ghost wisp
    t = (i % FR) / FR
    a = int(200 * math.sin(t * math.pi))
    gx, gy = 22 + wave(i, 1), 10 - int(t * 6)
    g.stamp([".W.", "WWW", "W.W"], gx, gy, remap=None)
    for (dx, dy) in ((1, 0), (0, 1), (1, 1), (2, 1), (0, 2), (2, 2)):
        px = g.get(gx + dx, gy + dy)
        if px is not None:
            g.px[(gy + dy) * 32 + gx + dx] = PAL["5"] + (a,)


PILES = {"Draw": d_draw, "Discard": d_discard, "Graveyard": d_graveyard}


def gen_piles():
    for name, fn in PILES.items():
        base = os.path.join(ROOT, "Assets", "Piles", name)
        for i in range(FR):
            g = Pix(32, 32)
            fn(g, i)
            g.save(os.path.join(base, "sprite_%d.png" % i), 16)
        g = Pix(32, 32)
        fn(g, 0)
        g.save(os.path.join(base, "sprite.png"), 16)
        print("pile", name)


# =============================================================== MODIFIERS
MOD_GLYPH = {
    "Conscription": ("q", [
        "...........",
        "Y.........Y",
        "YY.......YY",
        ".YY.....YY.",
        "..YY...YY..",
        "...YY.YY...",
        "Y...YYY...Y",
        "YY...Y...YY",
        ".YY.....YY.",
        "..YY...YY..",
        "...YY.YY...",
        "....YYY....",
        ".....Y.....",
    ]),
    "Guerilla Warfare": ("u", [
        "......G....",
        ".....GGG...",
        "....GGrGG..",
        "...GGrGGG..",
        "..GGrGGG...",
        "..GrGGG....",
        ".GrGGG.....",
        ".rGGG......",
        "r..........",
    ]),
    "State of emergency": ("R", [
        "....WWW....",
        "....WWW....",
        "....WWW....",
        "WWWWWWWWWWW",
        "WWWWWWWWWWW",
        "WWWWWWWWWWW",
        "....WWW....",
        "....WWW....",
        "....WWW....",
    ]),
    "Fanaticism": ("O", [
        ".....Y.....",
        "....YY.....",
        "....YYY....",
        "...YYWY....",
        "..YYWWYY.Y.",
        "..YWWWWYYY.",
        ".YYWWWWWYY.",
        ".YWWWWWWWY.",
        ".YYWWWWWYY.",
        "..YYYYYYY..",
    ]),
    "Corruption": ("m", [
        ".....y.....",
        "...yyyyy...",
        "..yYYyYYy..",
        "..yYYy.....",
        "...yyyyy...",
        ".....yYYy..",
        "..yYYyYYy..",
        "...yyyyy...",
        ".....y.....",
    ]),
    "Advanced Robotics": ("c", [
        "....444....",
        "..4.444.4..",
        ".444444444.",
        "..44...44..",
        "444.....444",
        "444..C..444",
        "444.....444",
        "..44...44..",
        ".444444444.",
        "..4.444.4..",
        "....444....",
    ]),
    "Aerial Supremacy": ("C", [
        "W.........W",
        "WW.......WW",
        "WWW.....WWW",
        ".WWW...WWW.",
        ".WWWW.WWWW.",
        "..WWWWWWW..",
        "....WWW....",
        ".....W.....",
    ]),
    "Defensive Doctrine": ("2", [
        ".444444444.",
        "45555555554",
        "45544444554",
        "45544444554",
        "45544444554",
        ".455444554.",
        ".45544455 4",
        "..4554554..",
        "...45554...",
        "....454....",
        ".....4.....",
    ]),
}


def gen_modifiers():
    for name, (col, glyph) in MOD_GLYPH.items():
        base = os.path.join(ROOT, "Assets", "Modifiers", name)
        for i in list(range(FR)) + [None]:
            g = Pix(32, 32)
            # medal badge: dark plate, coloured inner field, animated rim light
            g.r(4, 4, 24, 24, "1")
            g.r(5, 5, 22, 22, col)
            g.r(6, 6, 20, 20, "n")
            g.r(7, 7, 18, 18, col)
            g.r(7, 7, 18, 1, "5" if col not in ("W",) else "4")
            gw = max(len(r) for r in glyph)
            g.stamp(glyph, 16 - gw // 2, 16 - len(glyph) // 2)
            if i is not None:
                k = (i * 4) % 88
                for d in range(3):
                    s = k + d
                    if s < 22:
                        g.p(5 + s, 5, "W")
                    elif s < 44:
                        g.p(26, 5 + s - 22, "W")
                    elif s < 66:
                        g.p(26 - (s - 44), 26, "W")
                    else:
                        g.p(5, 26 - (s - 66), "W")
            g.outline()
            if i is None:
                g.save(os.path.join(base, "sprite.png"), 16)
            else:
                g.save(os.path.join(base, "sprite_%d.png" % i), 16)
        print("modifier", name)


# ================================================================= PLAYERS
# flag: (field, secondary, emblem). Emblems are small ASCII glyphs.
EMBLEMS = {
    "star": [
        "....Y....",
        "....Y....",
        "...YYY...",
        "YYYYYYYYY",
        ".YYYYYYY.",
        "..YYYYY..",
        "..YY.YY..",
        ".YY...YY.",
    ],
    "stars_ring": [
        "...Y.Y...",
        ".Y.....Y.",
        ".........",
        "Y.......Y",
        ".........",
        "Y.......Y",
        ".........",
        ".Y.....Y.",
        "...Y.Y...",
    ],
    "skull": [
        "..WWWWW..",
        ".WWWWWWW.",
        "WWWWWWWWW",
        "WnnWWWnnW",
        "WnnWWWnnW",
        ".WWWnWWW.",
        "..WWWWW..",
        "..W.W.W..",
    ],
    "slashes": [
        "R.....R.....",
        ".R.....R....",
        "RR.R...RR.R.",
        ".RR.R...RR.R",
        "..RR.R...RR.",
        "...RR.....RR",
        "....R.......",
    ],
    "wreath": [
        "..WWWWW..",
        ".WgWgWgW.",
        "WWWWWWWWW",
        "WgWgWgWgW",
        "WWWWWWWWW",
        ".WgWgWgW.",
        "..WWWWW..",
    ],
    "coin": [
        "..yyyyy..",
        ".yYYYYYy.",
        "yYYyyyYYy",
        "yYYyYYYYy",
        "yYYYyyYYy",
        "yYYYYYyYy",
        "yYYyyyYYy",
        ".yYYYYYy.",
        "..yyyyy..",
    ],
    "diamond": [
        "....W....",
        "...WWW...",
        "..WWnWW..",
        ".WWnnnWW.",
        "WWnnnnnWW",
        ".WWnnnWW.",
        "..WWnWW..",
        "...WWW...",
        "....W....",
    ],
    "sun": [
        "Y...Y...Y",
        ".Y..Y..Y.",
        "..OOOOO..",
        "..OOOOO..",
        "YYOOOOOYY",
        "..OOOOO..",
        "..OOOOO..",
        ".Y..Y..Y.",
        "Y...Y...Y",
    ],
    "shield": [
        "WWWWWWWWW",
        "WccWWWccW",
        "WcWWWWWcW",
        "WWWWYWWWW",
        "WWWYYYWWW",
        ".WWWYWWW.",
        ".WWWWWWW.",
        "..WWWWW..",
        "...WWW...",
    ],
    "flame": [
        "....W....",
        "...WW....",
        "...WWW...",
        "..WWYWW..",
        ".WWYYYWW.",
        ".WYYOYYW.",
        "WWYOOOYWW",
        ".WYYOYYW.",
        "..WWWWW..",
    ],
    "question": [
        "..WWWW..",
        ".WW..WW.",
        ".....WW.",
        "....WW..",
        "...WW...",
        "...WW...",
        "........",
        "...WW...",
    ],
}

# name: (field, band, band_style, emblem)
FACTIONS = {
    "State Troops": ("1", "R", "bottom", "star"),
    "Euro Army": ("c", "Y", "hoist", "shield"),
    "Insurgents": ("v", "n", "diag", "sun"),
    "Fundamentalists": ("p", "W", "top_bottom", "flame"),
    "Mercenaries": ("o", "n", "top_bottom", "skull"),
    "Peace Keepers": ("g", "W", None, "wreath"),
    "Horde": ("n", "e", "bottom", "slashes"),
    "Coalition Army": ("2", "c", "cross", "star"),
    "Corporate Troops": ("m", "M", "top_bottom", "coin"),
    "JohnDoe": ("3", "2", "bottom", "question"),
}


def draw_flag(name, i=0):
    field, band, style, emb = FACTIONS[name]
    cloth = Pix(32, 32)
    x0, y0, W, H = 5, 6, 25, 17
    cloth.r(x0, y0, W, H, field)
    if style == "bottom":
        cloth.r(x0, y0 + H - 4, W, 4, band)
    elif style == "top_bottom":
        cloth.r(x0, y0, W, 3, band)
        cloth.r(x0, y0 + H - 3, W, 3, band)
    elif style == "hoist":
        cloth.r(x0, y0, 6, H, band)
    elif style == "diag":
        for k in range(W):
            cloth.r(x0 + k, y0 + H - 1 - (k * H) // W - 2, 1, 3, band)
    elif style == "cross":
        cloth.r(x0 + 7, y0, 3, H, band)
        cloth.r(x0, y0 + 7, W, 3, band)
        cloth.r(x0 + 8, y0, 1, H, "W")
        cloth.r(x0, y0 + 8, W, 1, "W")
    gl = EMBLEMS[emb]
    gw = max(len(r) for r in gl)
    ex = x0 + (W - gw) // 2 + (3 if style == "hoist" else 0)
    if style == "cross":
        ex = x0 + 14
    cloth.stamp(gl, ex, y0 + (H - len(gl)) // 2)
    # wave: shift columns vertically and shade the folds
    g = Pix(32, 32)
    for x in range(32):
        off = int(round(math.sin((x - x0) / 7.0 * math.pi + i * 0.3) * 1.2)) if x >= x0 else 0
        shade = math.cos((x - x0) / 7.0 * math.pi + i * 0.3)
        for y in range(32):
            c = cloth.get(x, y)
            if c is None:
                continue
            k = 1.0 + 0.16 * shade
            c = tuple(min(255, max(0, int(v * k))) for v in c[:3]) + (255,)
            g.p(x, y + off, c)
    # pole with gold finial
    g.r(3, 4, 2, 26, "u")
    g.r(3, 4, 1, 26, "v")
    g.r(2, 2, 4, 2, "y")
    g.p(3, 2, "Y")
    g.outline()
    return g


def draw_roundel(name):
    field, band, _, _ = FACTIONS[name]
    g = Pix(16, 16)
    g.disc(7.5, 7.5, 6.6, band if band != field else "W")
    g.disc(7.5, 7.5, 5, field)
    g.disc(7.5, 7.5, 2, "W")
    g.outline()
    return g


def lerp_c(a, b, t):
    a, b = rgba(a), rgba(b)
    return tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(3)) + (255,)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def sky(g, top, bottom, bands=8):
    """Banded, ordered-dithered retro sky gradient."""
    for y in range(g.h):
        t = y / (g.h - 1) * bands
        b0 = int(t)
        f = t - b0
        for x in range(g.w):
            b = b0 + (1 if f * 16 > BAYER[y % 4][x % 4] else 0)
            g.px[y * g.w + x] = lerp_c(top, bottom, min(b, bands) / bands)


def ridge(g, base_y, amp, freq, col, seed, jag=0.0):
    for x in range(g.w):
        h = (math.sin(x * freq + seed) * amp + math.sin(x * freq * 2.7 + seed * 3) * amp * 0.4
             + (math.sin(x * 1.7 + seed) * jag))
        top = int(base_y - h)
        for y in range(max(top, 0), g.h):
            g.px[y * g.w + x] = rgba(col)


def skyline(g, base_y, col, lit, seed, tall=1.0, spire=None):
    x = 0
    k = seed
    while x < g.w:
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        w = 6 + k % 10
        h = int((10 + (k >> 8) % 26) * tall)
        g.r(x, base_y - h, w, h + 40, col)
        for wy in range(base_y - h + 2, base_y, 3):
            for wx in range(x + 1, x + w - 1, 2):
                k = (k * 1103515245 + 12345) & 0x7FFFFFFF
                if (k >> 16) % 5 == 0:
                    g.p(wx, wy, lit)
        x += w + (k >> 4) % 3
    if spire:
        sx, sh = spire
        g.r(sx - 1, base_y - sh, 3, sh, col)
        g.ln(sx - 6, base_y, sx, base_y - sh, col, 2)
        g.ln(sx + 6, base_y, sx, base_y - sh, col, 2)
        g.p(sx, base_y - sh - 1, "R")


def stars(g, count, seed, max_y):
    k = seed
    for _ in range(count):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        x = k % g.w
        y = (k >> 10) % max_y
        g.p(x, y, "5" if k % 7 else "Y")


# (sky top, sky bottom, scene kind, accent)
BACKDROPS = {
    "Insurgents": ((40, 30, 70), (240, 140, 70), "mountains"),
    "State Troops": ((30, 40, 90), (250, 170, 90), "desert"),
    "Fundamentalists": ((50, 56, 72), (130, 140, 150), "rain_city"),
    "Mercenaries": ((20, 60, 70), (120, 190, 140), "jungle"),
    "Peace Keepers": ((10, 14, 40), (50, 60, 120), "night_city"),
    "Horde": ((20, 24, 50), (120, 140, 180), "snow"),
    "Coalition Army": ((60, 40, 90), (240, 150, 130), "tower_city"),
    "Corporate Troops": ((20, 10, 40), (140, 50, 140), "neon_city"),
    "Euro Army": ((70, 140, 220), (190, 220, 240), "hills"),
    "JohnDoe": ((30, 30, 60), (110, 90, 120), "hills"),
}


def draw_backdrop(kind, top, bottom):
    W, H = 240, 135
    g = Pix(W, H)
    sky(g, top, bottom)
    if kind in ("night_city", "neon_city", "snow", "mountains", "tower_city"):
        stars(g, 90, 7, 60)
    if kind in ("night_city", "snow", "neon_city"):
        g.disc(190, 24, 8, "5")
        g.disc(193, 22, 7, None) if False else None
        g.disc(187, 22, 2, "4")
    if kind in ("desert", "mountains", "tower_city", "hills"):
        g.disc(60, 70 if kind != "hills" else 26, 12, (255, 220, 140) if kind != "hills" else (255, 245, 200))
    if kind == "mountains":
        ridge(g, 82, 22, 0.03, (90, 60, 90), 1, 2)
        ridge(g, 96, 16, 0.05, (60, 40, 70), 4, 1.5)
        ridge(g, 112, 5, 0.08, (40, 28, 40), 9)
    elif kind == "desert":
        ridge(g, 100, 6, 0.04, (200, 140, 80), 2)
        ridge(g, 112, 5, 0.06, (170, 110, 60), 5)
        for px in (40, 150, 200):
            g.r(px, 86, 2, 16, (60, 40, 30))
            for d in range(-5, 6):
                g.p(px + d, 86 + abs(d) // 2, (50, 80, 40))
        ridge(g, 124, 3, 0.09, (130, 80, 45), 8)
    elif kind == "rain_city":
        skyline(g, 110, (40, 44, 56), (230, 200, 120), 3)
        g.r(120, 40, 10, 72, (40, 44, 56))
        g.r(118, 36, 14, 6, (40, 44, 56))
        g.ln(125, 20, 125, 36, (40, 44, 56), 3)
        g.disc(124.5, 48, 3, (230, 220, 160))
        for k in range(260):
            x = (k * 37) % W
            y = (k * 53) % H
            g.p(x, y, (170, 180, 200))
            g.p(x - 1, y + 1, (140, 150, 170))
        g.r(0, 110, W, 25, (30, 32, 40))
    elif kind == "jungle":
        ridge(g, 90, 10, 0.05, (40, 90, 60), 3)
        g.r(0, 108, W, 8, (70, 130, 150))
        for k in range(28):
            cx = (k * 41) % W
            g.disc(cx, 96 + (k % 3) * 4, 9 + k % 4, (30, 70 + (k % 3) * 10, 40))
            g.disc(cx - 2, 93 + (k % 3) * 4, 5, (60, 120, 60))
        ridge(g, 125, 4, 0.1, (20, 50, 30), 5)
    elif kind in ("night_city", "neon_city", "tower_city"):
        lit = (255, 220, 120) if kind != "neon_city" else (255, 90, 200)
        skyline(g, 118, (30, 30, 60) if kind != "tower_city" else (70, 40, 70), (80, 80, 130), 11, 0.8)
        spire = (170, 80) if kind == "tower_city" else None
        skyline(g, 124, (14, 14, 30) if kind != "tower_city" else (40, 24, 44), lit, 5, 1.2, spire)
        if kind == "neon_city":
            for k, c in enumerate(((90, 220, 250), (255, 90, 200), (255, 226, 80))):
                g.r(30 + k * 70, 90 - k * 6, 12, 3, c)
    elif kind == "snow":
        ridge(g, 96, 8, 0.03, (170, 180, 210), 1)
        skyline(g, 112, (40, 44, 70), (255, 210, 120), 21, 0.7)
        for dx in (80, 140):
            g.disc(dx, 84, 5, (40, 44, 70))
            g.r(dx - 5, 84, 11, 28, (40, 44, 70))
            g.r(dx, 74, 1, 6, (40, 44, 70))
        g.r(0, 112, W, 23, (220, 228, 240))
        for k in range(160):
            g.p((k * 67) % W, (k * 29) % 112, "5")
    elif kind == "hills":
        ridge(g, 92, 10, 0.03, (90, 160, 90), 2)
        ridge(g, 108, 8, 0.05, (60, 130, 60), 6)
        ridge(g, 122, 4, 0.08, (40, 100, 50), 3)
        for k in range(12):
            cx = (k * 53 + 7) % W
            g.disc(cx, 104 + k % 3 * 5, 4, (30, 80, 40))
            g.r(cx, 108 + k % 3 * 5, 1, 3, (70, 50, 30))
    # foreground ground strip (everyone fights on dirt)
    for x in range(W):
        for y in range(128, H):
            g.px[y * W + x] = rgba((40, 32, 36)) if (x + y) % 5 else rgba((56, 44, 46))
    return g


def gen_players():
    for name in FACTIONS:
        base = os.path.join(ROOT, "Assets", "Players", name)
        draw_flag(name).save(os.path.join(base, "flag.png"), 16)
        draw_roundel(name).save(os.path.join(base, "sprite.png"), 8)
        top, bottom, kind = BACKDROPS[name]
        b = draw_backdrop(kind, top, bottom)
        b.save(os.path.join(base, "background.png"), 8)
        b.save(os.path.join(base, "bg.png"), 4)
        print("player", name)


# ====================================================================== UI
def ui_path(name):
    return os.path.join(ROOT, "Assets", "UI", name)


ICONS = {
    "heart": [
        "................",
        "..KKK....KKK....",
        ".KRRRK..KRRRK...",
        "KRWWRRKKRRRRRK..",
        "KRWRRRRRRRRRRK..",
        "KRRRRRRRRRRRRK..",
        "KRRRRRRRRRRReK..",
        ".KRRRRRRRRReK...",
        "..KRRRRRRReK....",
        "...KRRRRReK.....",
        "....KRRReK......",
        ".....KReK.......",
        "......KK........",
    ],
    "bio_icon": [
        "................",
        ".....KKKKKK.....",
        ".....K5445K.....",
        "......K44K......",
        "......K44K......",
        ".....K4444K.....",
        "....K44GG44K....",
        "...K4GGGGGG4K...",
        "..K4GGWGGGGG4K..",
        "..K4GGGGGGGG4K..",
        "..K4GGGGGpGG4K..",
        "..K4GpGGGGGG4K..",
        "...K4pppppp4K...",
        "....KKKKKKKK....",
    ],
    "money_icon": [
        "................",
        "......KKKKK.....",
        ".....KyYYYyK....",
        "....KyYWYYYyK...",
        "....KyYyyyYyK...",
        "....KyYyYYYyK...",
        "....KyYYyyYyK...",
        "....KyYYYyYyK...",
        "....KyYyyyYyK...",
        "....KyYYYYYyK...",
        ".....KyyyyyK....",
        "......KKKKK.....",
    ],
    "income_icon": [
        "................",
        "........K.......",
        ".......KGK......",
        "......KGGGK.....",
        ".....KGGGGGK....",
        "....KKKGGGKKK...",
        "......KGGGK.....",
        "...KKKKGGGKKK...",
        "..KyYYYYYYYYyK..",
        "..KyYWYyyyYYyK..",
        "..KyYYYYYYYYyK..",
        "...KyyyyyyyyK...",
        "....KKKKKKKK....",
    ],
    "influence_icon": [
        "................",
        ".......KK.......",
        "......KYYK......",
        "......KYYK......",
        "..KKKKYWYYKKKK..",
        "..KYYYYWYYYYyK..",
        "...KYYYYYYYyK...",
        "....KYYYYYyK....",
        "....KYYyyYyK....",
        "...KYYyKKyYyK...",
        "...KYyK..KyyK...",
        "...KKK....KKK...",
    ],
    "sword": [
        "................",
        "............KKK.",
        "...........K55K.",
        "..........K54K..",
        ".........K54K...",
        "........K54K....",
        "...KK..K54K.....",
        "...KyKK54K......",
        "....KyY4K.......",
        ".....KyYK.......",
        "....KuKyyK......",
        "...KuK..KK......",
        "..KuK...........",
        "..KK............",
    ],
    "flying_icon": [
        "................",
        "...........KKK..",
        ".........KK555K.",
        ".......KK55544K.",
        ".....KK5554443K.",
        "...KK55544433K..",
        ".KK555444333K...",
        "K555444333KK....",
        "K444333KKK......",
        ".KKKKKK.........",
    ],
    "hasrange_icon": [
        "................",
        ".......KK.......",
        ".....KKRRKK.....",
        "....KRKKKKRK....",
        "...KRK....KRK...",
        "..KRK......KRK..",
        ".KRRK..KK..KRRK.",
        ".KRRK..KK..KRRK.",
        "..KRK......KRK..",
        "...KRK....KRK...",
        "....KRKKKKRK....",
        ".....KKRRKK.....",
        ".......KK.......",
    ],
}


def icon(name):
    g = Pix(16, 16)
    rows = ICONS[name]
    g.stamp(rows, 0, (16 - len(rows)) // 2 + 1)
    return g


def gauge(fill_dark, fill_mid, fill_light, fill_hi):
    """12x64 bezel + matching fill (x3 = 36x192). Same geometry for both so the
    TextureProgressBar can nine-patch them with identical margins (2px sides,
    3px caps in logical pixels)."""
    W, H = 12, 64
    bg = Pix(W, H)
    bg.r(0, 1, W, H - 2, "K")
    bg.r(1, 0, W - 2, H, "K")
    bg.r(1, 1, W - 2, H - 2, "2")
    bg.r(1, 1, W - 2, 1, "4")
    bg.r(1, 1, 1, H - 2, "3")
    bg.r(W - 2, 1, 1, H - 2, "1")
    bg.r(1, H - 2, W - 2, 1, "1")
    bg.r(1, 2, W - 2, 1, "3")
    bg.r(1, H - 3, W - 2, 1, "1")
    for x in (3, W - 4):
        bg.p(x, 1, "5")
        bg.p(x, H - 2, "3")
    bg.r(2, 3, W - 4, H - 6, "n")
    for y in range(8, H - 4, 6):
        bg.r(3, y, W - 6, 1, "k")
        bg.p(2, y, "1")
        bg.p(W - 3, y, "1")
    fill = Pix(W, H)
    for y in range(3, H - 3):
        fill.p(2, y, fill_mid)
        fill.p(3, y, fill_hi)
        fill.r(4, y, 3, 1, fill_light)
        fill.r(7, y, 2, 1, fill_mid)
        fill.p(9, y, fill_dark)
    for y in range(8, H - 4, 6):
        fill.r(2, y, W - 4, 1, fill_dark)
        fill.p(3, y + 1, "W")
    return bg, fill


# ------------------------------------------------------------------ UI kit
# 9-slice pixel buttons and panels (16x16 logical, x3). Texture margins are
# 3 logical px (9 real px) on the sides/top and 4 at the bottom lip.
BUTTON_KINDS = {
    # kind: (body, light, dark, rim, rim_hover)
    "secondary": ((44, 48, 76), (78, 86, 126), (26, 28, 48), (120, 130, 170), (255, 214, 90)),
    "primary": ((196, 134, 34), (246, 196, 84), (120, 74, 18), (255, 232, 150), (255, 250, 210)),
    "selected": ((58, 62, 96), (98, 106, 150), (32, 34, 58), (255, 214, 90), (255, 240, 160)),
    "danger": ((150, 38, 44), (210, 74, 72), (84, 20, 28), (240, 130, 120), (255, 214, 90)),
}


def button_tex(kind, state):
    body, light, dark, rim, rim_h = BUTTON_KINDS[kind]
    if state == "hover":
        body = tuple(min(255, int(c * 1.18) + 6) for c in body)
        light = tuple(min(255, int(c * 1.12) + 6) for c in light)
        rim = rim_h
    if state == "disabled":
        grey = lambda c: (int(sum(c) / 3 * 0.7),) * 3
        body, light, dark, rim = grey(body), grey(light), grey(dark), grey(rim)
    g = Pix(16, 16)
    pressed = state == "pressed"
    top = 1 if pressed else 0
    bottom = 15
    # drop shadow under the lip (not when pressed down)
    if not pressed:
        g.r(1, 15, 14, 1, (0, 0, 0, 90))
        bottom = 14
    g.r(1, top, 14, bottom - top + 1, "K")
    g.r(0, top + 1, 16, bottom - top - 1, "K")
    g.r(1, top + 1, 14, bottom - top - 1, rim)
    g.r(2, top + 2, 12, bottom - top - 3, body)
    g.r(2, top + 2, 12, 1, light)
    g.r(2, top + 2, 1, bottom - top - 4, light)
    if not pressed:
        g.r(2, bottom - 2, 12, 2, dark)
    else:
        g.r(2, bottom - 1, 12, 1, dark)
    g.p(1, top + 1, "K")
    g.p(14, top + 1, "K")
    g.p(1, bottom - 1, "K")
    g.p(14, bottom - 1, "K")
    return g


def panel_tex(rim, alpha=236):
    g = Pix(16, 16)
    g.r(1, 0, 14, 16, "K")
    g.r(0, 1, 16, 14, "K")
    g.r(1, 1, 14, 14, rim)
    g.r(2, 2, 12, 12, (16, 14, 28, alpha))
    g.r(2, 2, 12, 1, (40, 38, 60, alpha))
    for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):
        g.p(x, y, "5")
    return g


THEME_TRES = """[gd_resource type="Theme" load_steps={steps} format=3]

[ext_resource type="FontFile" path="res://Assets/Fonts/PixelifySans.ttf" id="1_body"]
[ext_resource type="FontFile" path="res://Assets/Fonts/PressStart2P.ttf" id="2_title"]
{ext}
[sub_resource type="StyleBoxEmpty" id="focus_empty"]

{subs}
[resource]
default_font = ExtResource("1_body")
default_font_size = 18
Button/colors/font_color = Color(0.95, 0.94, 0.9, 1)
Button/colors/font_hover_color = Color(1, 1, 1, 1)
Button/colors/font_pressed_color = Color(0.9, 0.9, 0.86, 1)
Button/colors/font_focus_color = Color(1, 1, 1, 1)
Button/colors/font_disabled_color = Color(0.62, 0.62, 0.66, 1)
Button/colors/font_outline_color = Color(0.06, 0.05, 0.1, 1)
Button/constants/outline_size = 4
Button/styles/focus = SubResource("focus_empty")
{button_styles}
PrimaryButton/base_type = &"Button"
PrimaryButton/colors/font_color = Color(0.16, 0.08, 0.02, 1)
PrimaryButton/colors/font_hover_color = Color(0.1, 0.05, 0.0, 1)
PrimaryButton/colors/font_pressed_color = Color(0.16, 0.08, 0.02, 1)
PrimaryButton/colors/font_focus_color = Color(0.16, 0.08, 0.02, 1)
PrimaryButton/colors/font_outline_color = Color(1, 0.9, 0.6, 0.6)
PrimaryButton/constants/outline_size = 2
{primary_styles}
SelectedButton/base_type = &"Button"
{selected_styles}
DangerButton/base_type = &"Button"
{danger_styles}
PanelContainer/styles/panel = SubResource("sb_panel")
Panel/styles/panel = SubResource("sb_panel")
GoldPanel/base_type = &"PanelContainer"
GoldPanel/styles/panel = SubResource("sb_panel_gold")
TooltipPanel/styles/panel = SubResource("sb_panel")
TitleLabel/base_type = &"Label"
TitleLabel/fonts/font = ExtResource("2_title")
TitleLabel/colors/font_outline_color = Color(0.06, 0.05, 0.1, 1)
TitleLabel/constants/outline_size = 8
TitleLabel/constants/shadow_offset_x = 3
TitleLabel/constants/shadow_offset_y = 3
TitleLabel/colors/font_shadow_color = Color(0, 0, 0, 0.6)
Label/colors/font_outline_color = Color(0.06, 0.05, 0.1, 1)
"""


def gen_ui_kit():
    kit = ui_path("kit")
    ext, subs, styles = [], [], {}
    rid = 3
    for kind in BUTTON_KINDS:
        for state in ("normal", "hover", "pressed", "disabled"):
            name = "btn_%s_%s" % (kind, state)
            button_tex(kind, state).save(os.path.join(kit, name + ".png"), 3)
            ext.append('[ext_resource type="Texture2D" path="res://Assets/UI/kit/%s.png" id="%d_%s"]' % (name, rid, name))
            subs.append(
                '[sub_resource type="StyleBoxTexture" id="sb_%s"]\n'
                'texture = ExtResource("%d_%s")\n'
                'texture_margin_left = 9.0\ntexture_margin_top = 9.0\n'
                'texture_margin_right = 9.0\ntexture_margin_bottom = 12.0\n'
                'content_margin_left = 16.0\ncontent_margin_top = %s\n'
                'content_margin_right = 16.0\ncontent_margin_bottom = %s\n'
                % (name, rid, name, "11.0" if state == "pressed" else "8.0", "8.0" if state == "pressed" else "11.0"))
            styles.setdefault(kind, []).append((state, "sb_" + name))
            rid += 1
    for name, rim in (("panel", "2"), ("panel_gold", "y")):
        panel_tex(rim).save(os.path.join(kit, name + ".png"), 3)
        ext.append('[ext_resource type="Texture2D" path="res://Assets/UI/kit/%s.png" id="%d_%s"]' % (name, rid, name))
        subs.append(
            '[sub_resource type="StyleBoxTexture" id="sb_%s"]\n'
            'texture = ExtResource("%d_%s")\n'
            'texture_margin_left = 9.0\ntexture_margin_top = 9.0\n'
            'texture_margin_right = 9.0\ntexture_margin_bottom = 9.0\n'
            'content_margin_left = 14.0\ncontent_margin_top = 12.0\n'
            'content_margin_right = 14.0\ncontent_margin_bottom = 12.0\n'
            % (name, rid, name))
        rid += 1

    def style_lines(prefix, kind):
        return "\n".join("%s/styles/%s = SubResource(\"%s\")" % (prefix, st, sid) for st, sid in styles[kind])

    tres = THEME_TRES.format(
        steps=len(ext) + len(subs) + 4,
        ext="\n".join(ext) + "\n",
        subs="\n".join(subs),
        button_styles=style_lines("Button", "secondary"),
        primary_styles=style_lines("PrimaryButton", "primary"),
        selected_styles=style_lines("SelectedButton", "selected"),
        danger_styles=style_lines("DangerButton", "danger"),
    )
    with open(ui_path("retro_theme.tres"), "w") as f:
        f.write(tres)
    print("ui kit done")


def gen_ui():
    for name in ("heart", "bio_icon", "money_icon", "income_icon", "influence_icon", "sword"):
        icon(name).save(ui_path(name + ".png"), 32)
    icon("flying_icon").save(ui_path("flying_icon.png"), 4)
    icon("hasrange_icon").save(ui_path("hasrange_icon.png"), 4)
    for key, cols in (("hp", ("e", "R", (255, 104, 104), (255, 190, 180))),
                      ("bio", ("p", "q", "G", (200, 255, 200))),
                      ("money", ("y", (230, 170, 40), "Y", "W"))):
        bg, fill = gauge(*cols)
        bg.save(ui_path("%s_bg.png" % key), 3)
        fill.save(ui_path("%s_fill.png" % key), 3)
    # tiled game backdrop: dark scorched ground
    t = Pix(16, 16, rgba((30, 28, 40)))
    k = 5
    for _ in range(26):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        t.p(k % 16, (k >> 8) % 16, (38, 36, 50) if k % 3 else (24, 22, 32))
    t.save(ui_path("bg_tile.png"), 8)
    # card back
    cb = Pix(16, 16)
    card_rect(cb, 2, 1, 12, 14)
    cb.outline()
    cb.save(ui_path("card_back.png"), 8)
    # card frame (32x48): steel bezel, dark window
    cf = Pix(32, 48)
    cf.r(0, 0, 32, 48, "K")
    cf.r(1, 1, 30, 46, "3")
    cf.r(1, 1, 30, 1, "5")
    cf.r(2, 2, 28, 44, "2")
    cf.r(3, 3, 26, 42, "n")
    for (x, y) in ((2, 2), (29, 2), (2, 45), (29, 45)):
        cf.p(x, y, "Y")
    cf.save(ui_path("card_frame.png"), 8)
    # board tiles: player turf (grass/dirt) and enemy turf (scorched)
    for key, base, dots, edge_l, edge_d in (
            ("board_tile_player", (58, 74, 44), ((72, 92, 52), (46, 60, 36)), (86, 108, 62), (36, 46, 30)),
            ("board_tile_ai", (58, 40, 40), ((72, 50, 48), (44, 30, 32)), (86, 60, 56), (34, 24, 26))):
        bt = Pix(16, 16, rgba(base))
        k = 11 if key.endswith("player") else 23
        for _ in range(22):
            k = (k * 1103515245 + 12345) & 0x7FFFFFFF
            bt.p(k % 14 + 1, (k >> 8) % 14 + 1, dots[k % 2])
        bt.r(0, 0, 16, 1, edge_l)
        bt.r(0, 0, 1, 16, edge_l)
        bt.r(0, 15, 16, 1, edge_d)
        bt.r(15, 0, 1, 16, edge_d)
        for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):
            bt.p(x, y, edge_d)
        bt.save(ui_path(key + ".png"), 8)
    # legacy building art (kept for completeness)
    blds = {
        "hq_building": lambda: draw_corp(0, False),
        "hospital_building": lambda: _hospital(),
        "graveyard_building": lambda: _pile_still(d_graveyard),
        "waiting_zone_building": lambda: draw_barracks(0, False),
    }
    for name, fn in blds.items():
        fn().save(ui_path(name + ".png"), 16)
    # animated gauge grid backdrop (64x64 x8)
    ggdir = ui_path("gauge_grid_bg")
    for i in list(range(FR)) + [None]:
        gg = Pix(64, 64, rgba((16, 18, 28)))
        for gx in range(0, 64, 8):
            gg.r(gx, 0, 1, 64, (26, 30, 44))
        for gy in range(0, 64, 8):
            gg.r(0, gy, 64, 1, (26, 30, 44))
        if i is not None:
            cy = (i * 64 // FR)
            for dy, c in ((0, (60, 90, 70)), (1, (40, 60, 52)), (2, (30, 42, 40))):
                gg.r(0, (cy - dy) % 64, 64, 1, c)
            gg.save(os.path.join(ggdir, "sprite_%d.png" % i), 8)
        else:
            gg.save(os.path.join(ggdir, "sprite.png"), 8)
    # main menu backdrop: dusk ridge with an armoured column in silhouette
    mm = draw_backdrop("mountains", (24, 20, 56), (230, 120, 80))
    sil = Pix(240, 135)
    for k, (fn, x) in enumerate(((draw_tank, 30), (draw_infantry, 64), (draw_aa, 150), (draw_howitzer, 184))):
        spr = fn(0, False)
        for j in range(32):
            for i2 in range(32):
                c = spr.get(i2, j)
                if c is not None and c[3] > 200:
                    sil.p(x + i2, 96 + j, (22, 16, 30))
    mm.over(sil)
    mm.save(ui_path("main_menu_bg.png"), 8)
    print("ui done")


def _hospital():
    g = Pix(32, 32)
    g.r(4, 10, 24, 18, "4")
    g.r(4, 10, 24, 1, "5")
    g.r(13, 12, 6, 2, "R")
    g.r(15, 10, 2, 6, "R")
    for wx in (6, 22):
        g.r(wx, 18, 4, 3, "g")
    g.r(14, 20, 4, 8, "c")
    g.outline()
    return g


def _pile_still(fn):
    g = Pix(32, 32)
    fn(g, 0)
    return g


# ============================================================== world map
# Terrain tiles are generated at runtime by scripts/tile_art.gd; this
# mirror lets the preview sheet show them too.

GROUPS = {
    "cards": gen_cards,
    "projectiles": gen_projectiles,
    "effects": gen_effects,
    "piles": gen_piles,
    "modifiers": gen_modifiers,
    "players": gen_players,
    "ui": gen_ui,
    "kit": gen_ui_kit,
}


def main(argv):
    groups = argv or list(GROUPS)
    for gname in groups:
        GROUPS[gname]()
    print("retro overhaul complete")


if __name__ == "__main__":
    main(sys.argv[1:])
