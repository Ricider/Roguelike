#!/usr/bin/env python3
"""StarCraft: Brood War-inspired 8-bit pixel-art overhaul generator.

Regenerates every sprite in Assets/ with a consistent Terran-military look:
heavy 1px outlines, metallic shading with top-edge highlights, blinking
team-color lights, ground shadows, transparent backgrounds, and 20-frame
idle / 20-frame attack animations for all cards.

Pure stdlib (struct/zlib) - no dependencies. Art is drawn on a small
logical grid (e.g. 64x64) and upscaled with NEAREST so the 8-bit pixels
stay crisp. Run:  python3 tools/bw_overhaul.py
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FR = 20  # idle / attack frames per card (matches game code)

# ---------------------------------------------------------------- palette
# Brood War Terran: gunmetal armor, dark outlines, glowing visors/lights.
OUT = (11, 13, 19, 255)      # near-black outline
ARM_D = (47, 57, 75, 255)    # armor shadow
ARM_M = (96, 110, 134, 255)  # armor mid
ARM_L = (172, 186, 202, 255)  # armor top highlight
ARM_XL = (219, 227, 236, 255)  # rare specular dot
GUN_D = (26, 30, 39, 255)
GUN_M = (74, 84, 102, 255)
DARK = (20, 22, 30, 255)     # vents / deep shadow
TEAM = (43, 111, 242, 255)   # terran team blue
VISOR = (57, 230, 255, 255)  # visor / engine cyan
RED = (255, 59, 48, 255)
GRN = (57, 211, 83, 255)
AMB = (255, 176, 46, 255)
YLW = (255, 217, 77, 255)
WHT = (240, 244, 248, 255)
RUST = (122, 59, 30, 255)
TAN_D = (74, 58, 40, 255)    # building walls shadow
TAN_M = (138, 111, 77, 255)  # building walls mid
TAN_L = (196, 172, 130, 255)  # building walls light
WIN = (255, 205, 90, 255)    # lit windows
F_W = (255, 243, 207, 255)   # muzzle/explosion core
F_Y = (255, 201, 60, 255)
F_O = (255, 123, 28, 255)
F_R = (214, 60, 20, 255)
SMK = (85, 85, 94, 255)
SMK_D = (51, 51, 58, 255)
SHD = (0, 0, 0, 90)          # ground shadow
CLR = (0, 0, 0, 0)           # transparent


def png_write(path, rgba, w, h):
    """Write an RGBA bytes buffer as a PNG file (stdlib only)."""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw.extend(rgba[y * w * 4:(y + 1) * w * 4])

    def chunk(ctype, data):
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


class Pix:
    """Tiny pixel canvas on a logical grid; upscales NEAREST to PNG."""

    def __init__(self, w, h, bg=CLR):
        self.w = w
        self.h = h
        self.px = [bg] * (w * h)

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = c

    def r(self, x, y, w, h, c):
        for j in range(max(y, 0), min(y + h, self.h)):
            base = j * self.w
            for i in range(max(x, 0), min(x + w, self.w)):
                self.px[base + i] = c

    def hl(self, x, y, w, c=ARM_XL):
        """1px top-edge specular highlight."""
        for i in range(w):
            self.p(x + i, y, c)

    def box(self, x, y, w, h, fill, edge=True, top_light=True):
        """Outlined metal box with top highlight and dark bottom shade."""
        self.r(x, y, w, h, OUT)
        self.r(x + 1, y + 1, w - 2, h - 2, fill)
        if top_light and h > 2:
            self.r(x + 1, y + 1, w - 2, 1, ARM_L if fill in (ARM_M, ARM_D, GUN_M, GUN_D) else TAN_L if fill in (TAN_M, TAN_D) else fill)
        if h > 3:
            self.r(x + 1, y + h - 2, w - 2, 1, ARM_D if fill in (ARM_M, ARM_L) else TAN_D if fill in (TAN_M, TAN_L) else DARK if fill in (GUN_M,) else fill)

    def ln(self, x0, y0, x1, y1, c, th=1):
        """Stepped thick line (for angled barrels / wings)."""
        dx = x1 - x0
        dy = y1 - y0
        steps = max(abs(dx), abs(dy)) + 1
        for s in range(steps):
            t = s / max(steps - 1, 1)
            cx = int(round(x0 + dx * t))
            cy = int(round(y0 + dy * t))
            self.r(cx - th // 2, cy - th // 2, th, th, c)

    def disc(self, cx, cy, rad, c):
        rsq = rad * rad + rad
        for j in range(cy - rad - 1, cy + rad + 2):
            for i in range(cx - rad - 1, cx + rad + 2):
                if (i - cx) ** 2 + (j - cy) ** 2 <= rsq:
                    self.p(i, j, c)

    def ring(self, cx, cy, rad, c, th=1):
        for a in range(360):
            r_ = rad + (a % 3 == 0) * 0  # keep round on the grid
            i = int(round(cx + r_ * math.cos(math.radians(a))))
            j = int(round(cy + r_ * math.sin(math.radians(a))))
            self.r(i - th // 2, j - th // 2, th, th, c)

    def shadow(self, cx, gy, hw, faint=False):
        """Ground shadow ellipse."""
        c = (0, 0, 0, 45) if faint else SHD
        for k in range(3):
            self.r(cx - hw + k, gy + k, (hw - k) * 2, 1, c)

    def rivets(self, x, y, w, c=ARM_XL):
        for i in range(x + 1, x + w - 1, 3):
            self.p(i, y, c)

    def save(self, path, scale):
        W, H = self.w * scale, self.h * scale
        buf = bytearray(W * H * 4)
        for y in range(self.h):
            row = bytearray()
            for x in range(self.w):
                row.extend(bytes(self.px[y * self.w + x]))
            big = bytearray()
            for k in range(0, len(row), 4):
                big.extend(row[k:k + 4] * scale)
            for _ in range(scale):
                yy = y * scale + _
                buf[yy * W * 4:(yy + 1) * W * 4] = big
        png_write(path, bytes(buf), W, H)


# ------------------------------------------------------- animation helpers
def bob(i, amp=1):
    """Loop-safe vertical bob offset in grid px (-amp..amp)."""
    return int(round(math.sin(i / FR * 2 * math.pi) * amp))


def blink(i, phase=0, period=5):
    """Loop-safe 2-state blinker (FR=20 divisible by common periods)."""
    return ((i // period + phase) % 2) == 0


def recoil(i):
    """Attack recoil in grid px: kick on frames 2-4, ease back by 9."""
    if 2 <= i <= 4:
        return -2
    if 5 <= i <= 8:
        return -1
    return 0


def flash_on(i):
    return 2 <= i <= 7


def muzzle(g, x, y, big=False):
    """Brood War muzzle flash: white core, yellow cross, orange tips."""
    r = 4 if big else 3
    g.disc(x, y, 1, F_W)
    g.r(x - r, y, r * 2 + 1, 1, F_Y)
    g.r(x, y - r, 1, r * 2 + 1, F_Y)
    g.r(x - r - 1, y, 1, 1, F_O)
    g.r(x + r + 1, y, 1, 1, F_O)
    g.r(x, y - r - 1, 1, 1, F_O)
    g.r(x, y + r + 1, 1, 1, F_O)
    g.p(x - 2, y - 2, F_O)
    g.p(x + 2, y - 2, F_O)
    g.p(x - 2, y + 2, F_O)
    g.p(x + 2, y + 2, F_O)
    if big:
        g.p(x - 4, y - 3, F_R)
        g.p(x + 4, y + 3, F_R)
        g.p(x + 3, y - 4, F_R)
        g.p(x - 3, y + 4, F_R)


def tread(g, x, y, w, wheels, i):
    """Tank tread with animated link offset."""
    g.box(x, y, w, 10, DARK, edge=True, top_light=False)
    g.r(x + 1, y + 1, w - 2, 1, GUN_M)
    for n in range(wheels):
        wx = x + 2 + n * ((w - 4) // max(wheels - 1, 1))
        g.box(wx, y + 2, 5, 6, ARM_M)
        g.p(wx + 2, y + 4, RUST)
    off = i % 3
    for lx in range(x + 1 + off, x + w - 1, 3):
        g.p(lx, y + 8, GUN_M)


def window_lit(g, x, y, w=4, h=4, warm=True):
    g.box(x, y, w, h, WIN if warm else VISOR)
    g.p(x + 1, y + 1, WHT)


def antenna(g, x, ybase, h, i, phase=0):
    g.r(x, ybase - h, 1, h, GUN_M)
    g.p(x, ybase - h - 1, RED if blink(i, phase) else DARK)


def engine_flame(g, x, y, i, seed=0):
    ln = (2, 3, 4, 3)[(i + seed) % 4]  # 4-state cycle divides FR=20: loops cleanly
    g.r(x - ln, y, ln, 1, F_Y)
    g.r(x - ln, y - 1, 1, 1, F_O)
    g.r(x - ln, y + 1, 1, 1, F_O)
    g.p(x - ln - 1, y, F_O if (i + seed) % 2 else F_R)


# ================================================================== UNITS
# All units face right, feet / hull baseline near GY, ground shadow first.
GY = 52


def d_infantry(g, i, atk):
    """Terran Marine: bulky armor, cyan visor, gauss rifle."""
    yo = bob(i)
    rx = recoil(i) if atk else 0
    visor = VISOR if blink(i) else (23, 120, 150, 255)
    g.shadow(33, GY, 14)
    # legs + boots
    g.box(27, 43 + yo, 5, 8, ARM_D)
    g.box(34, 43 + yo, 5, 8, ARM_D)
    g.r(28, 45 + yo, 3, 4, ARM_M)
    g.r(35, 45 + yo, 3, 4, ARM_M)
    g.r(27, 49 + yo, 5, 2, DARK)
    g.r(34, 49 + yo, 5, 2, DARK)
    # torso armor
    g.box(26, 30 + yo, 13, 13, ARM_M)
    g.r(27, 31 + yo, 11, 1, ARM_L)
    g.r(28, 34 + yo, 9, 1, ARM_L)
    g.r(28, 38 + yo, 9, 1, ARM_D)
    g.box(30, 35 + yo, 5, 4, OUT)  # chest plate
    g.r(31, 36 + yo, 3, 2, TEAM)
    # shoulder pads overlapping torso (team color)
    g.box(22, 30 + yo, 5, 7, TEAM)
    g.box(39, 30 + yo, 5, 7, TEAM)
    g.r(23, 31 + yo, 3, 1, ARM_XL)
    g.r(40, 31 + yo, 3, 1, ARM_XL)
    # backpack vents
    g.box(23, 34 + yo, 3, 6, GUN_D)
    g.r(23, 34 + yo, 3, 1, GUN_M)
    # firing arm + heavy gauss rifle
    g.r(39, 35 + yo, 6, 4, ARM_M)
    g.box(44 + rx, 34 + yo, 13, 4, GUN_D)
    g.r(44 + rx, 34 + yo, 13, 1, GUN_M)
    g.p(55 + rx, 35 + yo, YLW)
    g.box(48 + rx, 32 + yo, 5, 2, GUN_M)  # scope
    g.p(50 + rx, 32 + yo, VISOR if blink(i) else DARK)
    # helmet with white stripe + glowing visor
    g.box(27, 21 + yo, 11, 9, ARM_M)
    g.r(27, 21 + yo, 11, 2, ARM_L)
    g.p(29, 21 + yo, WHT)
    g.p(30, 21 + yo, WHT)
    g.box(28, 24 + yo, 9, 4, OUT)
    g.r(29, 25 + yo, 7, 2, visor)
    g.p(30, 25 + yo, WHT)
    mx, my = 58 + rx, 36 + yo
    if atk and flash_on(i):
        muzzle(g, mx + 2, my)
    return mx, my


def d_specialops(g, i, atk):
    """Ghost operative: dark stealth suit, red visor, long rifle."""
    SUIT = (34, 38, 54, 255)
    SUIT_L = (62, 68, 92, 255)
    yo = bob(i)
    rx = recoil(i) if atk else 0
    g.shadow(33, GY, 11)
    g.box(29, 43 + yo, 3, 8, SUIT)
    g.box(35, 43 + yo, 3, 8, SUIT)
    g.r(29, 49 + yo, 3, 2, DARK)
    g.r(35, 49 + yo, 3, 2, DARK)
    g.box(27, 30 + yo, 12, 13, SUIT)
    g.r(28, 31 + yo, 10, 1, SUIT_L)
    g.r(31, 34 + yo, 4, 5, DARK)  # chest rig
    g.p(32, 35 + yo, RED if blink(i, 1) else DARK)
    # long rifle with scope
    g.box(38 + rx, 34 + yo, 19, 2, GUN_D)
    g.r(38 + rx, 34 + yo, 19, 1, GUN_M)
    g.box(44 + rx, 31 + yo, 5, 3, GUN_M)  # scope
    g.p(46 + rx, 32 + yo, VISOR if blink(i) else DARK)
    # hood + red visor
    g.box(28, 22 + yo, 10, 8, SUIT)
    g.r(30, 25 + yo, 6, 2, RED if blink(i) else (120, 20, 20, 255))
    g.r(28, 22 + yo, 10, 1, SUIT_L)
    # cloak shimmer pixels (periods divide FR=20: loops seamlessly)
    for k in range(3):
        sx = 26 + (i * 4 + k * 7) % 16
        sy = 32 + yo + (i * 2 + k * 5) % 8
        g.p(sx, sy, SUIT_L)
    mx, my = 58 + rx, 35 + yo
    if atk and flash_on(i):
        muzzle(g, mx + 1, my)
    return mx, my


def d_aa(g, i, atk):
    """Goliath walker: twin flak cannons angled skyward."""
    yo = bob(i)
    rx = recoil(i) if atk else 0
    g.shadow(32, GY, 15)
    # piston legs, wide stance
    g.box(20, 38 + yo, 6, 13, ARM_D)
    g.box(38, 38 + yo, 6, 13, ARM_D)
    g.r(22, 40 + yo, 2, 9, GUN_M)
    g.r(40, 40 + yo, 2, 9, GUN_M)
    g.r(20, 49 + yo, 6, 2, DARK)
    g.r(38, 49 + yo, 6, 2, DARK)
    # torso + cockpit
    g.box(22, 26 + yo, 20, 13, ARM_M)
    g.r(24, 29 + yo, 8, 4, VISOR if blink(i) else (23, 120, 150, 255))
    g.box(23, 28 + yo, 10, 6, OUT)
    g.r(24, 29 + yo, 8, 4, VISOR if blink(i) else (23, 120, 150, 255))
    g.p(36, 27 + yo, TEAM)
    g.p(37, 27 + yo, TEAM)
    antenna(g, 40, 26 + yo, 8, i)
    # twin angled cannons
    g.ln(30 + rx, 27 + yo, 46 + rx, 11 + yo, GUN_D, 3)
    g.ln(30 + rx, 27 + yo, 46 + rx, 11 + yo, GUN_M, 1)
    g.ln(35 + rx, 27 + yo, 51 + rx, 13 + yo, GUN_D, 3)
    g.ln(35 + rx, 27 + yo, 51 + rx, 13 + yo, GUN_M, 1)
    if atk and flash_on(i):
        muzzle(g, 47 + rx, 10 + yo)
        muzzle(g, 52 + rx, 12 + yo)
    return 50 + rx, 11 + yo


def d_tank(g, i, atk):
    """Siege tank: wide treads, turret, 90mm cannon."""
    yo = bob(i)
    rx = recoil(i) if atk else 0
    g.shadow(32, GY, 19)
    tread(g, 13, 42 + yo, 38, 5, i)
    # hull with hazard stripe
    g.box(17, 34 + yo, 30, 9, ARM_M)
    for s in range(4):
        g.p(42 - s * 2, 35 + yo, YLW)
        g.p(42 - s * 2, 36 + yo, DARK)
    g.p(20, 35 + yo, TEAM)
    g.p(20, 36 + yo, TEAM)
    # turret + cannon
    g.box(24, 27 + yo, 14, 8, ARM_M)
    g.p(26, 28 + yo, ARM_XL)
    g.box(36 + rx, 29 + yo, 18, 3, GUN_D)
    g.r(36 + rx, 29 + yo, 18, 1, GUN_M)
    antenna(g, 26, 27 + yo, 7, i, 1)
    mx, my = 55 + rx, 30 + yo
    if atk and flash_on(i):
        muzzle(g, mx + 2, my, big=True)
    return mx, my


def d_artillery(g, i, atk):
    """Sieged artillery: long shock cannon, stabilizer spades."""
    yo = 0  # emplaced, no bob
    rx = recoil(i) if atk else 0
    g.shadow(32, GY, 20)
    tread(g, 13, 43, 36, 5, i)
    g.box(17, 36, 28, 8, ARM_D)
    # stabilizer spades dug in
    g.ln(17, 44, 9, 51, GUN_M, 2)
    g.ln(45, 44, 53, 51, GUN_M, 2)
    # low turret + long cannon with muzzle brake
    g.box(24, 29, 13, 8, ARM_M)
    g.box(35 + rx, 30, 22, 4, GUN_D)
    g.r(35 + rx, 30, 22, 1, GUN_M)
    g.box(55 + rx, 29, 3, 6, GUN_M)  # muzzle brake
    g.p(30, 30, TEAM)
    antenna(g, 26, 29, 6, i, 2)
    mx, my = 59 + rx, 32
    if atk and flash_on(i):
        muzzle(g, mx + 1, my, big=True)
    return mx, my


def d_rocket(g, i, atk):
    """Missile buggy: light frame, triple rocket tubes, big wheels."""
    yo = bob(i)
    rx = recoil(i) if atk else 0
    g.shadow(32, GY, 17)
    # wheels
    for wx in (18, 42):
        g.disc(wx + 2, 47 + yo, 5, DARK)
        g.disc(wx + 2, 47 + yo, 3, ARM_D)
        g.p(wx + 2, 47 + yo, RUST)
    # frame + cab
    g.box(22, 38 + yo, 22, 5, ARM_M)
    g.box(24, 31 + yo, 9, 8, ARM_M)
    g.r(26, 33 + yo, 5, 3, VISOR if blink(i) else (23, 120, 150, 255))
    # triple tubes aimed up-right (thin, spaced so they read as 3 barrels)
    for t in range(3):
        g.ln(32 + t * 4 + rx, 38 + yo, 46 + t * 4 + rx, 22 + yo - t * 4, GUN_D, 2)
        g.ln(32 + t * 4 + rx, 38 + yo, 46 + t * 4 + rx, 22 + yo - t * 4, GUN_M, 1)
        g.p(46 + t * 4 + rx, 22 + yo - t * 4, DARK)
    g.p(36, 39 + yo, TEAM)
    if atk and flash_on(i):
        # ripple fire: tubes flash in sequence across the 6 flash frames
        k = (i - 2) % 3
        muzzle(g, 47 + k * 4 + rx, 21 + yo - k * 4)
    return 55 + rx, 16 + yo


def d_howitzer(g, i, atk):
    """Emplaced heavy gun: shield plate, split trails, huge barrel."""
    rx = recoil(i) if atk else 0
    g.shadow(32, GY, 21)
    # base platform + split trails
    g.box(14, 46, 36, 6, ARM_D)
    g.rivets(14, 46, 36)
    g.ln(18, 46, 8, 52, GUN_M, 3)
    g.ln(46, 46, 56, 52, GUN_M, 3)
    # pivot + shield
    g.box(28, 36, 9, 11, GUN_D)
    g.box(31, 28, 5, 12, ARM_M)
    g.p(32, 29, TEAM)
    # huge barrel
    g.box(36 + rx, 30, 20, 4, GUN_D)
    g.r(36 + rx, 30, 20, 1, GUN_M)
    g.box(54 + rx, 29, 4, 6, GUN_M)
    mx, my = 59 + rx, 32
    if atk and flash_on(i):
        muzzle(g, mx + 1, my, big=True)
    return mx, my


def d_drone(g, i, atk):
    """Hover drone: quad rotors, blinking nav lights, blue underglow."""
    yo = bob(i, amp=2)
    g.shadow(32, GY, 12, faint=True)
    # rotor arms
    g.r(20, 28 + yo, 24, 2, GUN_D)
    # spinning rotors: alternate horizontal disc / angled ticks
    if i % 2 == 0:
        g.r(14, 26 + yo, 12, 1, ARM_L)
        g.r(38, 26 + yo, 12, 1, ARM_L)
    else:
        g.r(16, 25 + yo, 8, 1, ARM_L)
        g.r(40, 25 + yo, 8, 1, ARM_L)
        g.p(20, 26 + yo, ARM_L)
        g.p(44, 26 + yo, ARM_L)
    for mx_ in (20, 44):
        g.box(mx_ - 2, 27 + yo, 5, 4, GUN_M)
    # central body
    g.box(25, 30 + yo, 14, 9, ARM_M)
    g.r(27, 32 + yo, 4, 3, VISOR if blink(i) else (23, 120, 150, 255))
    g.p(36, 31 + yo, RED if blink(i, 1) else DARK)
    g.p(36, 37 + yo, GRN if blink(i, 2) else DARK)
    # underglow + sensor
    g.p(30, 40 + yo, VISOR)
    g.p(33, 40 + yo, VISOR if i % 2 == 0 else DARK)
    mx, my = 40, 34 + yo
    if atk and flash_on(i):
        muzzle(g, mx + 2, my)
    return mx, my


def d_fighter(g, i, atk):
    """Wraith fighter: angular dart, twin engines, burst lasers."""
    yo = bob(i, amp=2)
    g.shadow(32, GY, 14, faint=True)
    # swept wings
    g.ln(30, 32 + yo, 16, 42 + yo, ARM_D, 4)
    g.ln(30, 32 + yo, 16, 42 + yo, ARM_M, 2)
    g.ln(34, 32 + yo, 24, 24 + yo, ARM_D, 4)
    g.ln(34, 32 + yo, 24, 24 + yo, ARM_M, 2)
    # fuselage
    g.box(14, 29 + yo, 38, 6, ARM_M)
    g.r(14, 29 + yo, 38, 1, ARM_L)
    g.ln(52, 30 + yo, 58, 32 + yo, ARM_M, 3)  # nose
    g.p(57, 31 + yo, ARM_L)
    # cockpit
    g.box(30, 26 + yo, 9, 4, OUT)
    g.r(31, 27 + yo, 7, 2, VISOR if blink(i) else (23, 120, 150, 255))
    # tail fins + team stripe
    g.box(16, 23 + yo, 3, 7, ARM_D)
    g.r(16, 23 + yo, 3, 1, TEAM)
    g.p(44, 30 + yo, RED if blink(i, 1) else DARK)
    g.p(22, 34 + yo, GRN if blink(i, 2) else DARK)
    # twin engine flames (animated)
    engine_flame(g, 14, 30 + yo, i)
    engine_flame(g, 14, 33 + yo, i, 1)
    mx, my = 59, 32 + yo
    if atk and flash_on(i):
        # twin burst-laser flashes under the nose
        muzzle(g, 52, 35 + yo)
        muzzle(g, 56, 35 + yo)
    return mx, my


def d_interceptor(g, i, atk):
    """Scout interceptor: tiny fast tri-dart, single engine."""
    yo = bob(i, amp=2)
    g.shadow(32, GY, 9, faint=True)
    # delta wings
    g.ln(30, 31 + yo, 20, 38 + yo, ARM_D, 3)
    g.ln(30, 31 + yo, 20, 38 + yo, ARM_M, 1)
    g.ln(32, 31 + yo, 26, 25 + yo, ARM_D, 3)
    g.ln(32, 31 + yo, 26, 25 + yo, ARM_M, 1)
    # dart body
    g.box(22, 29 + yo, 22, 5, ARM_M)
    g.r(22, 29 + yo, 22, 1, ARM_L)
    g.ln(44, 30 + yo, 50, 31 + yo, ARM_M, 3)
    g.p(49, 31 + yo, ARM_XL)
    g.box(28, 27 + yo, 6, 3, OUT)
    g.r(29, 28 + yo, 4, 1, VISOR if blink(i) else (23, 120, 150, 255))
    g.p(36, 30 + yo, TEAM)
    g.p(24, 33 + yo, RED if blink(i, 1) else DARK)
    engine_flame(g, 22, 31 + yo, i, 2)
    mx, my = 51, 31 + yo
    if atk and flash_on(i):
        muzzle(g, mx + 1, my)
    return mx, my


# ---------------------------------------------------------------- BUILDINGS
def d_wall(g, i, atk):
    """Perimeter bunker wall: plated barrier, hazard stripe, lamp."""
    g.shadow(32, GY, 22)
    g.box(9, 36, 46, 15, ARM_D)
    # armor plates
    for px in range(11, 52, 8):
        g.box(px, 38, 6, 11, ARM_M)
        g.r(px + 1, 39, 1, 9, ARM_L)
    # hazard stripe along the top
    for s in range(11):
        g.p(11 + s * 4, 36, YLW if s % 2 == 0 else DARK)
        g.p(12 + s * 4, 36, YLW if s % 2 == 0 else DARK)
    g.r(9, 37, 46, 1, ARM_L)
    # lamp post with blinking lamp
    g.r(30, 28, 2, 9, GUN_M)
    g.box(28, 25, 6, 4, GUN_D)
    g.p(30, 26, AMB if blink(i) else DARK)
    g.p(31, 26, AMB if blink(i) else DARK)
    if atk and flash_on(i):
        muzzle(g, 32, 22)
    return 32, 22


def d_barracks(g, i, atk):
    """Terran barracks: wide hall, glowing windows, antenna."""
    g.shadow(32, GY, 25)
    g.box(8, 32, 48, 19, TAN_M)
    g.r(8, 32, 48, 2, TAN_L)      # roof edge
    g.r(8, 32, 48, 1, ARM_XL)
    g.r(8, 49, 48, 2, TAN_D)      # foundation shade
    # panel seams + rivets
    for px in (18, 28, 38, 48):
        g.r(px, 34, 1, 15, TAN_D)
    g.rivets(8, 32, 48)
    # door + windows
    g.box(28, 39, 8, 12, DARK)
    g.r(29, 40, 6, 1, TAN_L)
    window_lit(g, 13, 38)
    window_lit(g, 47, 38)
    # team stripe + blinking roof light
    g.r(8, 35, 48, 1, TEAM)
    g.p(32, 30, RED if blink(i) else DARK)
    antenna(g, 52, 32, 12, i, 1)
    if atk and flash_on(i):
        muzzle(g, 32, 28)
    return 32, 28


def d_factory(g, i, atk):
    """Factory: assembly hall, chimney with animated smoke, crane."""
    g.shadow(32, GY, 25)
    g.box(8, 36, 44, 15, ARM_M)
    g.r(8, 36, 44, 1, ARM_L)
    for px in (18, 30, 42):
        g.r(px, 37, 1, 14, ARM_D)
    # big assembly door
    g.box(24, 40, 14, 11, DARK)
    g.r(25, 41, 12, 1, GUN_M)
    g.p(30, 42, AMB if blink(i) else DARK)
    # chimney + rising smoke (loop-safe 10-frame cycle)
    g.box(44, 14, 6, 24, ARM_D)
    g.r(44, 14, 6, 1, ARM_L)
    g.r(45, 15, 4, 2, F_R if blink(i, 0, 2) else DARK)  # furnace glow
    cyc = i % 10
    for s in range(3):
        age = (cyc + s * 3) % 10
        g.disc(47, 12 - age * 2, 1 + age // 3, SMK if age > 4 else (120, 120, 128, 255))
    # crane arm + hook light
    g.r(8, 30, 30, 2, GUN_M)
    g.r(12, 32, 1, 5, GUN_M)
    g.p(12, 37, YLW if blink(i, 1) else DARK)
    g.r(8, 33, 44, 1, TEAM)
    if atk and flash_on(i):
        muzzle(g, 32, 26)
    return 32, 26


def d_housing(g, i, atk):
    """Supply depot: squat shelter, roof team stripe, warm door."""
    g.shadow(32, GY, 19)
    g.box(14, 38, 36, 13, TAN_M)
    g.box(12, 34, 40, 5, ARM_M)   # roof cap
    g.r(12, 34, 40, 1, ARM_L)
    g.r(14, 38, 36, 1, TEAM)      # team stripe
    g.r(14, 49, 36, 2, TAN_D)
    g.box(28, 41, 8, 10, DARK)
    g.r(29, 42, 6, 6, WIN if blink(i, 0, 10) else TAN_D)
    window_lit(g, 17, 41, 3, 3)
    window_lit(g, 44, 41, 3, 3)
    if atk and flash_on(i):
        muzzle(g, 32, 31)
    return 32, 31


def d_corp(g, i, atk):
    """Command center: HQ block, comms dish, lit tower."""
    g.shadow(32, GY, 26)
    # main block + upper deck
    g.box(7, 36, 50, 15, ARM_M)
    g.box(14, 28, 30, 9, ARM_D)
    g.r(14, 28, 30, 1, ARM_L)
    g.r(7, 36, 50, 1, ARM_L)
    g.r(7, 49, 50, 2, DARK)
    for px in (17, 27, 37, 47):
        g.r(px, 37, 1, 12, ARM_D)
    # window rows (alternate phases: half lit on any frame, like busy terminals)
    for idx, wx in enumerate((10, 16, 22, 34, 40, 46)):
        g.box(wx, 39, 4, 4, OUT)
        on = blink(i, idx % 2, 5)
        g.r(wx + 1, 40, 2, 2, WIN if on else DARK)
    # comms dish (animated sweep dot)
    g.ln(44, 28, 52, 18, GUN_M, 2)
    g.disc(53, 17, 3, ARM_L)
    g.disc(53, 17, 2, ARM_M)
    sweep = (i // 2) % 10  # 10 states x 2 frames = seamless 20-frame loop
    g.p(51 + (sweep % 3), 15 + (sweep // 3), VISOR)
    # tower beacon
    antenna(g, 12, 28, 10, i)
    g.r(7, 33, 50, 1, TEAM)
    if atk and flash_on(i):
        muzzle(g, 53, 14)
    return 53, 14


CARDS = {
    "Infantry": d_infantry,
    "Special Ops": d_specialops,
    "Anti Aircraft": d_aa,
    "Tank": d_tank,
    "Artilery": d_artillery,
    "Rocket Launcher": d_rocket,
    "RocketLauncher": d_rocket,   # legacy alias folder, same art
    "Howitzer": d_howitzer,
    "Drone": d_drone,
    "Fighter Jet": d_fighter,
    "Interceptor": d_interceptor,
    "Wall": d_wall,
    "Barracks": d_barracks,
    "Factory": d_factory,
    "Housing": d_housing,
    "Corporation": d_corp,
}


def gen_cards():
    for name, fn in CARDS.items():
        base = os.path.join(ROOT, "Assets", "Cards", name)
        for i in range(FR):
            g = Pix(64, 64)
            fn(g, i, False)
            g.save(os.path.join(base, "sprite_%d.png" % i), 8)
            g2 = Pix(64, 64)
            fn(g2, i, True)
            p = os.path.join(base, "attack_sprite_%d.png" % i)
            g2.save(p, 8)
            # attack/ subfolder mirrors the attack frames (projectile fallback)
            g2.save(os.path.join(base, "attack", "sprite_%d.png" % i), 8)
        # static sprite = frame 0 (bob rest pose, primary lights bright)
        g = Pix(64, 64)
        fn(g, 0, False)
        g.save(os.path.join(base, "sprite.png"), 8)
        g.save(os.path.join(base, "attack", "sprite.png"), 8)
        print("card", name)


# ------------------------------------------------------------- projectiles
# 128px files: drawn on a 16-grid x8 (same chunk size as cards).
def p_tracer(g, i):
    g.r(4, 7, 8, 2, F_Y)
    g.r(5, 7, 5, 2, F_W)
    g.r(3, 7, 1, 2, F_O)


def p_shell(g, i):
    g.box(4, 6, 6, 4, GUN_M)
    g.p(8, 7, ARM_L)
    g.p(9, 7, F_Y)
    g.p(9, 6, F_O)
    g.p(9, 8, F_O)


def p_rocket(g, i):
    g.box(4, 6, 6, 4, ARM_L)
    g.p(9, 7, RED)
    g.p(9, 8, RED)
    ln = (2, 3, 2, 4)[i % 4]
    g.r(4 - ln, 7, ln, 2, F_Y)
    g.r(4 - ln, 7, 1, 2, F_O)


def p_plasma(g, i):
    g.disc(8, 8, 2, VISOR)
    g.p(8, 8, WHT)
    if i % 2 == 0:
        g.r(3, 8, 3, 1, VISOR)
        g.r(10, 8, 3, 1, VISOR)
    else:
        g.r(4, 8, 2, 1, VISOR)
        g.r(10, 8, 2, 1, VISOR)


def p_flak(g, i):
    g.r(5, 7, 5, 2, F_W)
    g.r(4, 6, 1, 4, F_O)
    g.r(10, 6, 1, 4, F_O)


PROJECTILES = {
    "Infantry": p_tracer,
    "Special Ops": p_tracer,
    "Anti Aircraft": p_flak,
    "Artilery": p_shell,
    "Howitzer": p_shell,
    "Tank": p_shell,
    "Drone": p_plasma,
    "Fighter Jet": p_plasma,
    "Interceptor": p_tracer,
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


# ----------------------------------------------------------------- effects
# 256px files: 32-grid x8, 8 frames + base copy.
def e_explosion(g, j):
    cx, cy = 16, 16
    r = 3 + j
    outer = (F_R, F_R, F_O, F_O, F_Y, F_Y, F_W, SMK)[j]
    mid = (F_O, F_Y, F_Y, F_W, F_W, F_W, F_Y, SMK_D)[j]
    g.disc(cx, cy, r, outer)
    g.disc(cx, cy, max(r - 2, 1), mid)
    g.disc(cx, cy, max(r - 4, 0), F_W if j < 6 else SMK)
    # flying sparks
    for k in range(6):
        a = math.radians(k * 60 + j * 12)
        d = r + 2 + (j % 3)
        g.p(int(round(cx + d * math.cos(a))), int(round(cy + d * math.sin(a))),
            F_Y if j < 5 else SMK)


def e_splash(g, j):
    cx, cy = 16, 16
    g.ring(cx, cy, 3 + j, VISOR if j < 4 else ARM_L)
    for k in range(8):
        a = math.radians(k * 45 + j * 9)
        d = 2 + j * 2
        x = int(round(cx + d * math.cos(a)))
        y = int(round(cy + d * math.sin(a)))
        g.p(x, y, WHT if j < 3 else VISOR)
        g.p(x + 1, y, VISOR if j < 5 else ARM_M)


def e_aura(g, j):
    cx, cy = 16, 16
    g.ring(cx, cy, 10 + (j % 3), AMB)
    g.ring(cx, cy, 7, YLW if j % 2 == 0 else AMB)
    # rotating ticks (8 states = seamless)
    for k in range(4):
        a = math.radians(k * 90 + j * 45)
        x = int(round(cx + 12 * math.cos(a)))
        y = int(round(cy + 12 * math.sin(a)))
        g.r(x - 1, y - 1, 3, 3, YLW)


def e_bio(g, j):
    cx, cy = 16, 14 + (0 if j % 2 == 0 else 1)
    g.disc(cx, cy, 6, (34, 120, 60, 255))
    g.disc(cx - 1, cy - 1, 4, (57, 211, 83, 255))
    g.p(cx - 2, cy - 2, WHT)
    g.p(cx + 1, cy - 3, WHT if j % 2 == 0 else GRN)
    g.ring(cx, cy, 9 + (j % 2), GRN)


def e_money(g, j):
    cx, cy = 16, 15 + (0 if (j // 2) % 2 == 0 else 1)
    w = (6, 4, 2, 4, 6, 4, 2, 4)[j]  # coin spin
    g.disc(cx, cy, 6, (120, 80, 20, 255))
    g.r(cx - w, cy - 5, w * 2, 10, (255, 201, 60, 255))
    g.r(cx - w, cy - 5, w * 2, 1, (255, 243, 207, 255))
    g.p(cx - 1, cy - 2, WHT)
    g.p(cx, cy + 3, (160, 100, 30, 255))


def e_intercept(g, j):
    cx, cy = 16, 16
    g.ring(cx, cy, 4 + j, VISOR)
    for s in (-1, 1):
        for d in range(-8 + j, 9 - j):
            g.p(cx + d, cy + s * d // 2, WHT if abs(d) < 4 else VISOR)
    if j % 2 == 0:
        g.p(cx - 6, cy - 6, WHT)
        g.p(cx + 6, cy + 6, WHT)


EFFECTS = {
    "barracks_aura": e_aura,
    "fighter_jet_splash": e_splash,
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


# ------------------------------------------------------------------- piles
def pile_plate(g, edge):
    g.box(6, 6, 52, 52, ARM_D)
    g.r(6, 6, 52, 1, edge)
    g.rivets(6, 6, 52)


def d_pile_draw(g, i):
    pile_plate(g, TEAM if blink(i) else ARM_M)
    # stacked deck, top card with star
    for s in range(3):
        g.box(18 + s * 3, 16 + s * 3, 26, 34, GUN_D)
    g.box(24, 22, 26, 34, (36, 60, 120, 255))
    g.r(24, 22, 26, 1, ARM_L)
    cx, cy = 37, 39
    g.p(cx, cy - 3, WHT if blink(i, 1) else ARM_L)
    g.r(cx - 2, cy - 1, 5, 1, WHT if blink(i, 1) else ARM_L)
    g.p(cx - 1, cy, WHT if blink(i, 1) else ARM_L)
    g.p(cx + 1, cy, WHT if blink(i, 1) else ARM_L)
    g.p(cx, cy + 1, WHT if blink(i, 1) else ARM_L)


def d_pile_discard(g, i):
    pile_plate(g, ARM_M)
    # fanned spent cards
    g.box(16, 24, 22, 28, (70, 72, 80, 255))
    g.box(26, 20, 22, 28, (88, 90, 100, 255))
    g.box(22, 28, 22, 24, GUN_D)
    g.r(22, 28, 22, 1, ARM_L if blink(i) else GUN_M)
    g.p(32, 38, RED if blink(i, 1) else DARK)


def d_pile_graveyard(g, i):
    pile_plate(g, SMK if blink(i) else DARK)
    # dark memorial slab + marker
    g.box(20, 30, 24, 22, (28, 28, 34, 255))
    g.r(20, 30, 24, 1, ARM_M)
    g.r(30, 22, 4, 22, (60, 60, 68, 255))
    g.r(24, 28, 16, 4, (60, 60, 68, 255))
    g.p(31, 23, WHT if blink(i, 1) else ARM_M)
    # cracks
    g.p(24, 44, DARK)
    g.p(25, 45, DARK)
    g.p(38, 46, DARK)


PILES = {"Draw": d_pile_draw, "Discard": d_pile_discard, "Graveyard": d_pile_graveyard}


def gen_piles():
    for name, fn in PILES.items():
        base = os.path.join(ROOT, "Assets", "Piles", name)
        for i in range(FR):
            g = Pix(64, 64)
            fn(g, i)
            g.save(os.path.join(base, "sprite_%d.png" % i), 8)
        g = Pix(64, 64)
        fn(g, 0)
        g.save(os.path.join(base, "sprite.png"), 8)
        print("pile", name)


# --------------------------------------------------------------- modifiers
MOD_COLORS = {
    "Conscription": (48, 150, 60, 255),
    "Guerilla Warfare": (170, 120, 50, 255),
    "State of emergency": (210, 40, 40, 255),
    "Fanaticism": (240, 110, 20, 255),
    "Corruption": (120, 50, 170, 255),
    "Advanced Robotics": (50, 120, 200, 255),
    "Aerial Supremacy": (60, 190, 225, 255),
    "Defensive Doctrine": (100, 120, 160, 255),
}


def m_chev(g, c):  # Conscription chevrons
    for s in range(3):
        y = 24 + s * 7
        for d in range(7):
            g.p(32 - 6 + d, y + d // 2, c)
            g.p(32 + 6 - d, y + d // 2, c)


def m_leaf(g, c):  # Guerilla leaf
    g.disc(32, 34, 8, c)
    g.disc(30, 32, 5, (120, 200, 120, 255))
    g.ln(32, 26, 32, 46, (40, 80, 40, 255), 1)


def m_cross(g, c):  # emergency cross
    g.r(28, 20, 8, 24, c)
    g.r(20, 28, 24, 8, c)
    g.r(28, 20, 8, 2, WHT)


def m_flame(g, c):  # fanaticism flame
    g.ln(32, 46, 24, 30, c, 5)
    g.ln(32, 46, 40, 30, c, 5)
    g.ln(32, 46, 32, 20, c, 4)
    g.ln(32, 46, 32, 30, F_Y, 3)
    g.p(32, 40, F_W)


def m_diamond(g, c):  # corruption diamond
    for d in range(9):
        g.r(32 - d, 24 + d, d * 2 + 1, 1, c)
    for d in range(9):
        g.r(32 - 8 + d, 33 + d, (8 - d) * 2 + 1, 1, c)
    g.p(30, 28, WHT)


def m_gear(g, c):  # robotics gear
    g.disc(32, 34, 9, c)
    g.disc(32, 34, 5, DARK)
    for k in range(8):
        a = math.radians(k * 45)
        g.p(int(round(32 + 10 * math.cos(a))), int(round(34 + 10 * math.sin(a))), c)
    g.p(32, 34, WHT)


def m_wings(g, c):  # aerial wings
    g.ln(32, 40, 18, 24, c, 4)
    g.ln(32, 40, 46, 24, c, 4)
    g.ln(32, 40, 32, 26, c, 4)
    g.p(32, 26, WHT)


def m_shield(g, c):  # defensive shield
    g.box(24, 22, 16, 14, c)
    for d in range(8):
        g.r(24 + d, 36 + d // 2, 16 - d * 2, 1, c)
    g.p(32, 28, WHT)
    g.r(30, 30, 5, 6, (60, 70, 100, 255))


MOD_GLYPHS = {
    "Conscription": m_chev,
    "Guerilla Warfare": m_leaf,
    "State of emergency": m_cross,
    "Fanaticism": m_flame,
    "Corruption": m_diamond,
    "Advanced Robotics": m_gear,
    "Aerial Supremacy": m_wings,
    "Defensive Doctrine": m_shield,
}


def gen_modifiers():
    for name, col in MOD_COLORS.items():
        base = os.path.join(ROOT, "Assets", "Modifiers", name)
        for i in range(FR):
            g = Pix(64, 64)
            g.box(6, 6, 52, 52, ARM_D)
            g.box(9, 9, 46, 46, (26, 28, 36, 255))
            edge = col if blink(i) else ARM_M
            g.r(6, 6, 52, 1, edge)
            g.r(6, 57, 52, 1, edge)
            g.r(6, 6, 1, 52, edge)
            g.r(57, 6, 1, 52, edge)
            MOD_GLYPHS[name](g, col)
            g.save(os.path.join(base, "sprite_%d.png" % i), 8)
        g = Pix(64, 64)
        g.box(6, 6, 52, 52, ARM_D)
        MOD_GLYPHS[name](g, col)
        g.save(os.path.join(base, "sprite.png"), 8)
        print("modifier", name)


# ----------------------------------------------------------------- players
FACTIONS = {
    "State Troops": ((20, 30, 60, 255), (255, 217, 77, 255), "star"),
    "Euro Army": ((30, 60, 140, 255), (255, 217, 77, 255), "circle"),
    "Insurgents": ((90, 20, 20, 255), (196, 172, 130, 255), "chevron"),
    "Fundamentalists": ((20, 90, 50, 255), (240, 244, 248, 255), "diamond"),
    "Mercenaries": ((80, 80, 40, 255), (20, 20, 22, 255), "bars"),
    "Peace Keepers": ((200, 205, 215, 255), (43, 111, 242, 255), "cross"),
    "Horde": ((15, 15, 18, 255), (255, 59, 48, 255), "diamond"),
    "Coalition Army": ((60, 70, 90, 255), (240, 244, 248, 255), "star"),
    "Corporate Troops": ((70, 30, 110, 255), (255, 217, 77, 255), "diamond"),
    "JohnDoe": ((90, 95, 105, 255), (43, 111, 242, 255), "circle"),
}


def emblem(g, kind, cx, cy, c):
    if kind == "star":
        g.p(cx, cy - 4, c)
        g.r(cx - 3, cy - 1, 7, 1, c)
        g.p(cx - 2, cy, c)
        g.p(cx + 2, cy, c)
        g.p(cx - 1, cy + 1, c)
        g.p(cx + 1, cy + 1, c)
        g.p(cx, cy + 2, c)
    elif kind == "circle":
        g.ring(cx, cy, 4, c, 2)
        g.p(cx, cy, c)
    elif kind == "diamond":
        for d in range(5):
            g.r(cx - d, cy - 4 + d, d * 2 + 1, 1, c)
        for d in range(5):
            g.r(cx - 4 + d, cy + d, (4 - d) * 2 + 1, 1, c)
    elif kind == "chevron":
        for s in range(2):
            y = cy - 2 + s * 4
            for d in range(5):
                g.p(cx - 4 + d, y + d // 2, c)
                g.p(cx + 4 - d, y + d // 2, c)
    elif kind == "bars":
        g.r(cx - 4, cy - 3, 9, 2, c)
        g.r(cx - 4, cy + 1, 9, 2, c)
    elif kind == "cross":
        g.r(cx - 1, cy - 4, 3, 9, c)
        g.r(cx - 4, cy - 1, 9, 3, c)


def night_base(g, W, H, accent):
    """Brood War menu backdrop: night sky, planet limb, lit base."""
    for y in range(H):
        t = y / max(H - 1, 1)
        c = (int(8 - 6 * t), int(10 - 8 * t), int(22 - 16 * t), 255)
        g.r(0, y, W, 1, c)
    # stars (xor-hash: no diagonal banding)
    for y in range(H):
        for x in range(W):
            if ((x * 37) ^ (y * 91) ^ (x * y * 13)) % 23 == 0 and y < H * 2 // 3:
                g.p(x, y, WHT if (x + y) % 5 == 0 else ARM_M)
    # planet limb bottom-right (lifted so the disc reads against space)
    pcx, pcy, pr = int(W * 0.80), int(H * 1.22), int(H * 0.62)
    for y in range(H):
        for x in range(W):
            d2 = (x - pcx) ** 2 + (y - pcy) ** 2
            if d2 <= pr * pr:
                edge = pr - math.sqrt(d2)
                if edge < 2:
                    g.p(x, y, accent)
                elif (x * 3 + y) % 7 == 0:
                    g.p(x, y, (88, 84, 96, 255))
                else:
                    g.p(x, y, (58, 54, 68, 255))
    # horizon glow + ground grid
    hy = int(H * 0.70)
    g.r(0, hy, W, 1, (150, 80, 30, 255))
    g.r(0, hy + 1, W, 1, (80, 45, 20, 255))
    for y in range(hy + 3, H, 4):
        g.r(0, y, W, 1, (16, 18, 26, 255))
    # base silhouette with lit windows
    for bx, bw, bh in ((8, 30, 12), (W - 44, 36, 16), (W // 2 - 14, 28, 9)):
        by = hy - bh
        g.r(bx, by, bw, bh, (10, 11, 16, 255))
        g.r(bx, by, bw, 1, (40, 44, 58, 255))
        for wx in range(bx + 2, bx + bw - 2, 4):
            if (wx * 7) % 3:
                g.p(wx, by + bh - 3, WIN)
        g.p(bx + bw // 2, by - 1, RED)  # beacon
    # soft vignette (dark navy, keeps planet limb visible)
    for y in range(H):
        for x in range(W):
            ex = min(x, W - 1 - x) / (W / 2)
            ey = min(y, H - 1 - y) / (H / 2)
            if ex < 0.15 or ey < 0.15:
                g.p(x, y, (4, 5, 10, 255))


def gen_players():
    for name, (field, accent, ekind) in FACTIONS.items():
        base = os.path.join(ROOT, "Assets", "Players", name)
        # flag banner
        g = Pix(64, 64)
        g.box(4, 4, 56, 56, field)
        g.r(4, 4, 56, 3, accent)
        g.r(4, 57, 56, 3, accent)
        emblem(g, ekind, 32, 32, accent)
        g.save(os.path.join(base, "flag.png"), 8)
        # roundel sprite
        s = Pix(16, 16)
        s.disc(8, 8, 7, field)
        s.ring(8, 8, 7, accent)
        s.p(8, 8, accent)
        s.save(os.path.join(base, "sprite.png"), 8)
        # backdrops (shared night scene, faction accent)
        b = Pix(240, 135)
        night_base(b, 240, 135, accent)
        b.save(os.path.join(base, "background.png"), 8)
        b.save(os.path.join(base, "bg.png"), 4)
        print("player", name)


# --------------------------------------------------------------------- UI
def ui_path(name):
    return os.path.join(ROOT, "Assets", "UI", name)


def gen_ui():
    # battlefield tile: dark riveted metal plate
    t = Pix(16, 16)
    t.box(0, 0, 16, 16, (26, 28, 36, 255))
    t.r(0, 0, 16, 1, (52, 58, 74, 255))
    t.p(1, 1, ARM_XL)
    t.p(14, 1, ARM_XL)
    t.p(1, 14, ARM_XL)
    t.p(14, 14, ARM_XL)
    t.r(0, 15, 16, 1, DARK)
    t.r(15, 0, 1, 16, DARK)
    t.save(ui_path("bg_tile.png"), 8)

    # gauge tracks (8x64 grid -> 64x512) + fills (6x62 -> 48x496)
    for bg_name in ("hp_bg.png", "bio_bg.png", "money_bg.png"):
        b = Pix(8, 64)
        b.r(0, 0, 8, 64, (18, 20, 28, 255))
        b.r(0, 0, 1, 64, ARM_M)
        b.r(7, 0, 1, 64, ARM_M)
        b.r(0, 0, 8, 1, ARM_L)
        for y in range(4, 64, 8):
            b.p(0, y, ARM_XL)
            b.p(7, y, ARM_XL)
        b.save(ui_path(bg_name), 8)
    fills = {"hp_fill.png": ((80, 220, 110), (20, 120, 55)),
             "bio_fill.png": ((70, 230, 200), (20, 120, 105)),
             "money_fill.png": ((255, 205, 80), (150, 100, 25))}
    for fname, (top, bot) in fills.items():
        f = Pix(6, 62)
        for y in range(62):
            t_ = y / 61
            c = tuple(int(top[k] + (bot[k] - top[k]) * t_) for k in range(3)) + (255,)
            f.r(0, y, 6, 1, c)
        f.r(0, 0, 1, 62, WHT)
        for y in range(0, 62, 8):
            f.r(0, y, 6, 1, DARK)
        f.save(ui_path(fname), 8)

    # stat icons (64-grid, transparent)
    h = Pix(64, 64)  # heart (solid shape, outline behind)
    rows = [(22, 26, 38), (23, 23, 41)]
    for y in range(24, 30):
        rows.append((y, 20, 44))
    for y in range(30, 49):
        half = 12 - (y - 30) * 12 // 18
        rows.append((y, 32 - half, 32 + half))
    for y, x0, x1 in rows:  # outline layer
        h.r(x0 - 1, y, x1 - x0 + 3, 1, OUT)
    h.r(26, 21, 13, 1, OUT)
    h.r(31, 49, 3, 1, OUT)
    for y, x0, x1 in rows:  # red fill
        h.r(x0, y, x1 - x0 + 1, 1, (220, 50, 50, 255))
    h.r(20, 24, 24, 1, (235, 80, 80, 255))  # upper sheen
    h.p(26, 26, WHT)
    h.p(27, 27, WHT)
    h.p(25, 27, WHT)
    h.save(ui_path("heart.png"), 8)

    s = Pix(64, 64)  # crosshair (was sword)
    s.ring(32, 32, 15, OUT, 4)
    s.ring(32, 32, 15, AMB, 2)
    for dx, dy in ((0, -20), (0, 20), (-20, 0), (20, 0)):
        s.r(32 + dx - (1 if dx == 0 else 0), 32 + dy - (1 if dy == 0 else 0),
            1 if dx == 0 else 3, 3 if dx == 0 else 1, AMB)
    s.disc(32, 32, 3, RED)
    s.p(32, 32, WHT)
    s.save(ui_path("sword.png"), 8)

    ii = Pix(64, 64)  # income: gold chevrons up
    for s_ in range(3):
        y = 40 - s_ * 10
        for d in range(13):
            ii.p(32 - 12 + d, y + d // 2, YLW)
            ii.p(32 + 12 - d, y + d // 2, YLW)
        ii.p(32, y - 1, WHT)
    ii.save(ui_path("income_icon.png"), 8)

    m = Pix(64, 64)  # money: blue mineral crystal
    for d in range(13):
        m.r(32 - d, 16 + d, d * 2 + 1, 1, (60, 140, 220, 255))
    for d in range(13):
        m.r(32 - 12 + d, 29 + d, (12 - d) * 2 + 1, 1, (35, 90, 160, 255))
    m.ln(28, 18, 28, 44, (150, 210, 255, 255), 1)
    m.p(27, 22, WHT)
    m.p(27, 24, WHT)
    m.save(ui_path("money_icon.png"), 8)

    bo = Pix(64, 64)  # bio: green cell
    bo.disc(32, 32, 14, (30, 110, 60, 255))
    bo.disc(29, 29, 10, GRN)
    bo.disc(29, 29, 5, (120, 230, 150, 255))
    bo.p(25, 24, WHT)
    bo.p(26, 25, WHT)
    bo.save(ui_path("bio_icon.png"), 8)

    inf = Pix(64, 64)  # influence: orange star
    emblem(inf, "star", 32, 32, AMB)
    for d in range(9):
        inf.p(32 - 8 + d, 32 - 8 + d // 3, YLW)
        inf.p(32 + 8 - d, 32 - 8 + d // 3, YLW)
    emblem(inf, "star", 32, 30, F_Y)
    inf.save(ui_path("influence_icon.png"), 8)

    # card back: blue metal + star
    cb = Pix(16, 16)
    cb.box(0, 0, 16, 16, (36, 60, 120, 255))
    cb.r(2, 2, 12, 12, OUT)
    cb.r(3, 3, 10, 10, (60, 90, 160, 255))
    emblem(cb, "star", 8, 8, WHT)
    cb.save(ui_path("card_back.png"), 8)

    # card frame: riveted border, transparent middle (32x48 -> 256x384)
    cf = Pix(32, 48)
    cf.box(0, 0, 32, 48, ARM_M)
    for x in range(4, 28):
        for y in range(4, 44):
            cf.p(x, y, CLR)
    for x in range(2, 30, 4):
        cf.p(x, 1, ARM_XL)
        cf.p(x, 46, ARM_XL)
    for y in range(2, 46, 4):
        cf.p(1, y, ARM_XL)
        cf.p(30, y, ARM_XL)
    cf.r(0, 3, 32, 1, TEAM)
    cf.save(ui_path("card_frame.png"), 8)

    # building glyphs
    hq = Pix(64, 64)
    hq.box(10, 30, 44, 21, ARM_M)
    hq.box(18, 22, 24, 9, ARM_D)
    window_lit(hq, 14, 36)
    window_lit(hq, 24, 36)
    window_lit(hq, 34, 36)
    window_lit(hq, 44, 36)
    antenna(hq, 50, 22, 10, 3)
    hq.save(ui_path("hq_building.png"), 8)

    hp = Pix(64, 64)
    hp.box(12, 32, 40, 19, ARM_M)
    hp.box(24, 24, 16, 12, WHT)
    hp.r(29, 26, 6, 16, RED)
    hp.r(26, 29, 12, 6, RED)
    hp.save(ui_path("hospital_building.png"), 8)

    gy = Pix(64, 64)
    gy.box(14, 34, 36, 17, (28, 28, 34, 255))
    gy.r(14, 34, 36, 1, ARM_M)
    gy.r(29, 24, 6, 20, (70, 70, 80, 255))
    gy.r(21, 30, 22, 5, (70, 70, 80, 255))
    gy.save(ui_path("graveyard_building.png"), 8)

    wz = Pix(64, 64)
    wz.box(12, 36, 40, 15, TAN_M)
    wz.box(24, 16, 16, 8, ARM_M)
    for d in range(8):
        wz.r(26 + d // 2, 26 + d, 12 - d, 1, YLW)
    for d in range(6):
        wz.r(28 + d // 2, 40 - d, 8 - d, 1, YLW)
    wz.save(ui_path("waiting_zone_building.png"), 8)

    # small badges (16-grid -> 64px)
    fl = Pix(16, 16)
    for s_ in range(2):
        y = 11 - s_ * 4
        for d in range(5):
            fl.p(8 - 4 + d, y + d // 3, WHT)
            fl.p(8 + 4 - d, y + d // 3, WHT)
    fl.save(ui_path("flying_icon.png"), 4)

    hr = Pix(16, 16)
    hr.ring(8, 8, 5, AMB, 1)
    hr.p(8, 8, RED)
    hr.p(8, 2, AMB)
    hr.p(8, 14, AMB)
    hr.p(2, 8, AMB)
    hr.p(14, 8, AMB)
    hr.save(ui_path("hasrange_icon.png"), 4)

    # gauge backdrop: dark panel + slow glow sweep (seamless sine loop)
    ggdir = os.path.join(ROOT, "Assets", "UI", "gauge_grid_bg")
    for i in range(FR):
        gg = Pix(64, 64)
        gg.r(0, 0, 64, 64, (16, 18, 28, 255))
        for gx in range(0, 64, 8):
            gg.r(gx, 0, 1, 64, (24, 27, 38, 255))
        for gy_ in range(0, 64, 8):
            gg.r(0, gy_, 64, 1, (24, 27, 38, 255))
        cy = int(round(32 + 24 * math.sin(i / FR * 2 * math.pi)))
        for dy in (-2, -1, 0, 1, 2):
            gg.r(0, cy + dy, 64, 1, (30, 42, 66, 255) if abs(dy) == 2 else (38, 58, 92, 255))
        gg.r(0, 0, 64, 1, TEAM if blink(i) else ARM_M)
        gg.save(os.path.join(ggdir, "sprite_%d.png" % i), 8)
    gg = Pix(64, 64)
    gg.r(0, 0, 64, 64, (16, 18, 28, 255))
    gg.save(os.path.join(ggdir, "sprite.png"), 8)

    # main menu backdrop
    mm = Pix(240, 135)
    night_base(mm, 240, 135, TEAM)
    mm.save(ui_path("main_menu_bg.png"), 8)
    print("ui done")


def main():
    gen_cards()
    gen_projectiles()
    gen_effects()
    gen_piles()
    gen_modifiers()
    gen_players()
    gen_ui()
    print("BW overhaul complete")


if __name__ == "__main__":
    main()
