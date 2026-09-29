"""Nation "kits": the shape language that sets each nation's army apart.

retro_overhaul.py draws every card once; for a nation's version it swaps the
palette (colours) and then calls into this module for everything that changes
the silhouette:

  * parts(nation)         -> replacement tread / wheel helpers (hover sleds for
                             Corporate Troops, big APC wheels for Peace Keepers,
                             cleated heavy tracks for the Horde)
  * shape(g, nation, ...) -> edge treatment of the nation's body colour: sleek
                             wedges (Corporate), hard chamfers (Coalition),
                             rounded corners (Peace Keepers), ragged battle damage
                             (Insurgents)
  * kit(g, nation, ...)   -> bolt-on details per card class: soldiers' kit,
                             vehicle stowage/armour, aircraft paint and gadgets,
                             building rooflines

and draws the nation-themed map props (gen_props) scattered over each nation's
territory on the world map.

Everything is drawn on the 32x32 card grid with retro_overhaul's palette codes
("R"/"e" = the nation's accent, "o p q r" = its body ramp, "1".."5" = steel).
"""
import math
import os

VEHICLES = {"Tank", "Howitzer", "Anti Aircraft", "Artilery", "Rocket Launcher", "Interceptor"}
SOLDIERS = {"Infantry", "Special Ops"}
AIR = {"Drone", "Fighter Jet"}
BUILDINGS = {"Barracks", "Factory", "Housing", "Corporation", "Wall"}
# horizontal extent of each building's roofline (the barracks flag pole is left alone)
ROOF_SPAN = {"Barracks": (2, 26), "Factory": (2, 27), "Housing": (1, 27), "Corporation": (3, 28), "Wall": (2, 29)}


def h01(x, y, salt=0):
    return (((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0xFFFF) / 65535.0


class Ctx:
    """What a kit needs: the retro module (palette/helpers), the frame, bob offset."""

    def __init__(self, R, card, i, shift):
        self.R, self.card, self.i, self.shift = R, card, i, shift
        self.ramp = [R.rgba(ch) for ch in "opqr"]

    def is_ramp(self, c):
        return c in self.ramp

    def ramp_top(self, g, x, y_min=0):
        """First body-coloured pixel in column x (scanning down), or None."""
        for y in range(y_min, g.h):
            c = g.get(x, y)
            if c is not None and c in self.ramp:
                return y
        return None

    def ramp_bottom(self, g, x):
        for y in range(g.h - 1, -1, -1):
            c = g.get(x, y)
            if c is not None and c in self.ramp:
                return y
        return None

    def top(self, g, x):
        for y in range(g.h):
            if g.get(x, y) is not None:
                return y
        return None

    def ramp_cols(self, g):
        return [x for x in range(g.w) if self.ramp_top(g, x) is not None]


# ================================================================ parts
def parts(R, nation):
    """{name: replacement} for retro_overhaul's module-level helpers."""
    orig_treads, orig_wheel = R.treads, R.wheel

    def hover_sled(g, x0, x1, y, phase):
        # a floating slab with a glowing underside instead of tracks
        g.r(x0 + 2, y, x1 - x0 - 3, 1, "3")
        g.r(x0 + 1, y + 1, x1 - x0 - 1, 2, "2")
        g.r(x0 + 3, y + 3, x1 - x0 - 5, 1, "1")
        for k, x in enumerate(range(x0 + 4, x1 - 2, 5)):
            on = (k + phase) % 3 != 0
            g.r(x, y + 4, 2, 1, "R" if on else "e")

    def hover_pad(g, cx, cy, rad, spin=0):
        g.r(int(cx - rad), int(cy - 1), int(rad * 2) + 1, 2, "1")
        g.p(int(cx), int(cy), "R" if spin % 2 == 0 else "C")
        g.p(int(cx) - 1, int(cy) + 1, "e")
        g.p(int(cx) + 1, int(cy) + 1, "e")

    def apc_wheels(g, x0, x1, y, phase):
        # rounded armoured skirt over four big road wheels
        g.r(x0 + 1, y, x1 - x0 - 1, 2, "p")
        g.r(x0 + 1, y, x1 - x0 - 1, 1, "q")
        for wx in range(x0 + 4, x1 - 1, 7):
            orig_wheel(g, wx, y + 4, 3.1, phase)

    def heavy_tracks(g, x0, x1, y, phase):
        orig_treads(g, x0, x1, y, phase)
        for x in range(x0 + 1, x1, 3):          # grouser cleats biting the ground
            g.p(x + (phase % 3 == 0), y + 7, "1")

    def technical_wheel(g, cx, cy, rad, spin=0):
        orig_wheel(g, cx, cy, rad, spin)
        g.p(int(cx), int(cy), "v")              # mismatched rims

    return {
        "Corporate Troops": {"treads": hover_sled, "wheel": hover_pad},
        "Peace Keepers": {"treads": apc_wheels},
        "Horde": {"treads": heavy_tracks},
        "Insurgents": {"wheel": technical_wheel},
    }.get(nation, {})


# ================================================================ shape
def _corner_cut(g, ctx, passes, need_diag_empty):
    for _ in range(passes):
        cut = []
        for y in range(g.h):
            for x in range(g.w):
                c = g.get(x, y)
                if c is None or not ctx.is_ramp(c):
                    continue
                if g.get(x, y + 1) is None:
                    continue                    # keep 1px bits and bottoms intact
                up = g.get(x, y - 1) is None
                for side in (-1, 1):
                    if up and g.get(x + side, y) is None and (not need_diag_empty or g.get(x + side, y - 1) is None):
                        cut.append((x, y))
                        break
        for (x, y) in cut:
            g.px[y * g.w + x] = None


def shape(g, nation, ctx):
    card = ctx.card
    if card in SOLDIERS or card in BUILDINGS:
        return
    if nation == "Corporate Troops":
        _corner_cut(g, ctx, 3, False)          # sleek wedges
    elif nation == "Coalition Army":
        _corner_cut(g, ctx, 2, False)          # hard chamfers
    elif nation == "Peace Keepers":
        _corner_cut(g, ctx, 1, True)           # soft rounded corners
    elif nation == "Insurgents":
        for x in range(g.w):                   # dents and missing chunks along the top
            t = ctx.ramp_top(g, x)
            if t is not None and h01(x, 5) < 0.22 and g.get(x, t + 1) is not None:
                g.px[t * g.w + x] = None


# ================================================================ kits
def kit(g, nation, ctx):
    card = ctx.card
    fn = None
    if card in SOLDIERS:
        fn = SOLDIER_KITS.get(nation)
    elif card in VEHICLES:
        fn = VEHICLE_KITS.get(nation)
    elif card in AIR:
        fn = AIR_KITS.get(nation)
    elif card in BUILDINGS:
        fn = BUILDING_KITS.get(nation)
    if fn:
        fn(g, ctx)


# ------------------------------------------------------------ soldiers
# soldier grid: head ~y7-15, torso y16-20, gun row y18 (x16-25), legs y21-26 (x10-18)
def _s(ctx, y):
    return y + ctx.shift


def sol_state(g, c):
    g.r(6, _s(c, 16), 3, 5, "p")               # field pack + bedroll
    g.r(7, _s(c, 16), 1, 4, "q")
    g.r(6, _s(c, 15), 3, 1, "v")
    g.p(9, _s(c, 17), "u")


def sol_insurgents(g, c):
    g.ln(5, _s(c, 24), 11, _s(c, 13), "t")    # RPG slung across the back
    g.r(10, _s(c, 11), 2, 2, "p")
    g.p(11, _s(c, 10), "q")
    g.p(10, _s(c, 13), "k")
    g.r(10, 26, 3, 1, "u")                     # sandals
    g.r(16, 26, 3, 1, "u")


def sol_fund(g, c):
    g.r(9, 21, 10, 3, "q")                     # long tunic over the legs
    g.r(9, 23, 10, 1, "p")
    g.r(9, 21, 1, 3, "p")
    g.ln(10, _s(c, 16), 15, _s(c, 20), "y")    # bandolier
    for k in range(0, 6, 2):
        g.p(10 + k, _s(c, 16) + k * 4 // 5, "k")
    g.r(17, _s(c, 18), 2, 1, "t")              # wooden stock


def sol_merc(g, c):
    g.r(10, _s(c, 17), 6, 3, "n")              # plate carrier with pouches
    g.r(11, _s(c, 19), 2, 2, "k")
    g.r(14, _s(c, 19), 2, 2, "k")
    g.p(12, _s(c, 17), "R")
    g.r(26, _s(c, 18), 3, 1, "1")              # suppressor
    g.r(12, 22, 1, 3, "k")                     # leg knife
    g.p(12, 22, "3")


def sol_pk(g, c):
    for y in range(_s(c, 16), _s(c, 21)):      # UN-blue flak vest
        for x in range(9, 17):
            p = g.get(x, y)
            if p is not None and c.is_ramp(p):
                g.p(x, y, "R" if p in c.ramp[2:] else "e")
    g.ln(8, _s(c, 16), 8, _s(c, 9), "2")        # radio whip
    g.p(8, _s(c, 8), "R")


def sol_horde(g, c):
    g.r(9, 21, 10, 4, "p")                     # greatcoat skirt
    g.r(9, 21, 10, 1, "q")
    g.r(13, 21, 2, 4, "o")
    g.r(10, _s(c, 16), 6, 1, "u")              # fur collar
    for x in (10, 12, 14):
        g.p(x, _s(c, 16), "v")
    g.p(19, _s(c, 19), "k")                    # banana magazine
    g.p(19, _s(c, 20), "k")
    g.p(20, _s(c, 21), "k")


def sol_coalition(g, c):
    g.r(19, _s(c, 17), 3, 1, "1")              # optic
    g.p(22, _s(c, 17), "g")
    g.r(10, 23, 2, 1, "k")                     # knee pads
    g.r(16, 23, 2, 1, "k")
    g.r(7, _s(c, 16), 2, 4, "p")               # hydration pack
    g.p(7, _s(c, 16), "q")


def sol_corp(g, c):
    g.disc(11, _s(c, 16), 2.2, "q")            # power-armour pauldron
    g.p(10, _s(c, 15), "r")
    g.p(12, _s(c, 17), "R")
    for x in range(16, 26):                    # energy rifle
        p = g.get(x, _s(c, 18))
        if p is not None and p not in (c.R.rgba("s"),):
            g.p(x, _s(c, 18), "e")
    g.p(25, _s(c, 18), "R")
    g.p(26, _s(c, 18), "W" if c.i % 4 < 2 else "R")
    g.r(6, _s(c, 16), 3, 4, "1")               # reactor pack
    g.p(7, _s(c, 17), "R" if c.i % 6 < 3 else "C")
    g.p(7, _s(c, 18), "R")


SOLDIER_KITS = {
    "State Troops": sol_state, "Insurgents": sol_insurgents, "Fundamentalists": sol_fund,
    "Mercenaries": sol_merc, "Peace Keepers": sol_pk, "Horde": sol_horde,
    "Coalition Army": sol_coalition, "Corporate Troops": sol_corp,
}


# ------------------------------------------------------------ vehicles
def _hull_span(g, c):
    cols = c.ramp_cols(g)
    return (min(cols), max(cols)) if cols else (4, 26)


def _highest_col(g, c):
    best, bx = 99, 15
    for x in c.ramp_cols(g):
        t = c.ramp_top(g, x)
        if t < best:
            best, bx = t, x
    return bx, best


def veh_state(g, c):
    x0, _ = _hull_span(g, c)
    t = c.ramp_top(g, x0 + 1)
    if t is not None:                          # jerrycans on the back deck
        for k in (0, 3):
            g.r(x0 + 1 + k, t - 3, 2, 3, "p")
            g.p(x0 + 1 + k, t - 3, "q")
    bx, bt = _highest_col(g, c)
    g.ln(bx - 3, bt - 1, bx - 3, bt - 5, "2")  # whip antenna with a gold tip
    g.p(bx - 3, bt - 6, "R")


def veh_insurgents(g, c):
    x0, x1 = _hull_span(g, c)
    for k, x in enumerate(range(x1 - 7, x1 - 1, 2)):    # sandbags on the front
        t = c.ramp_top(g, x)
        if t is not None:
            g.r(x, t - 2, 3, 2, "v")
            g.p(x, t - 2, "w")
            g.p(x + 2, t - 1, "u")
    t = c.ramp_top(g, x0 + 2)
    if t is not None:                          # spare tyre + rag flag at the back
        g.disc(x0 + 2, t - 2, 1.8, "k")
        g.p(x0 + 2, t - 2, "2")
        g.ln(x0 + 4, t - 1, x0 + 4, t - 8, "t")
        wav = (0, 1, 0, -1)[(c.i // 3) % 4]
        g.r(x0 + 5, t - 8 + wav, 3, 2, "R")
        g.p(x0 + 7, t - 7 + wav, "e")
    for x in range(x0, x1 + 1):                # welded scrap plates
        for y in range(g.h):
            p = g.get(x, y)
            if p is not None and c.is_ramp(p) and h01(x // 3, y // 2, 9) < 0.08:
                g.p(x, y, "u")


def veh_fund(g, c):
    for y in range(g.h):                       # riveted retro plating
        for x in range(g.w):
            p = g.get(x, y)
            if p is not None and c.is_ramp(p) and x % 3 == 0 and (y - c.shift) % 3 == 1:
                g.p(x, y, "o")
    bx, bt = _highest_col(g, c)
    g.r(bx - 2, bt - 2, 4, 2, "q")             # round cupola
    g.r(bx - 1, bt - 3, 2, 1, "r")
    x0, _ = _hull_span(g, c)
    t = c.ramp_top(g, x0 + 1)
    if t is not None:                          # long pennant
        g.ln(x0 + 1, t - 1, x0 + 1, t - 10, "2")
        for k in range(6):
            dy = (0, 1, 1, 0)[(k + c.i // 2) % 4]
            g.p(x0 + 2 + k, t - 10 + dy + k // 3, "R")
            if k < 4:
                g.p(x0 + 2 + k, t - 9 + dy + k // 3, "e")


def veh_merc(g, c):
    for x in range(g.w):                       # slat cage armour on the lower hull
        if x % 3 != 0:
            continue
        b = c.ramp_bottom(g, x)
        if b is None:
            continue
        for y in range(b - 4, b + 1):
            p = g.get(x, y)
            if p is not None and c.is_ramp(p):
                g.p(x, y, "3" if y % 2 else "2")
    for x in range(g.w):                       # olive camo netting draped on top
        t = c.ramp_top(g, x)
        if t is not None and h01(x, 3, 4) < 0.5 and g.get(x, t - 1) is None:
            g.p(x, t - 1, (78, 92, 50))
            if h01(x, 7, 4) < 0.4:
                g.p(x, t, (58, 70, 38))
    bx, bt = _highest_col(g, c)
    g.r(bx, bt - 2, 5, 1, "1")                 # pintle machine gun
    g.p(bx, bt - 1, "1")


def veh_pk(g, c):
    bx, bt = _highest_col(g, c)
    on = (c.i // 3) % 2
    g.r(bx - 2, bt - 1, 5, 1, "2")             # light bar
    g.r(bx - 2, bt - 2, 2, 1, "R" if on else "c")
    g.r(bx + 1, bt - 2, 2, 1, "c" if on else "R")
    for x in range(g.w):                       # blue band along the lower hull
        b = c.ramp_bottom(g, x)
        if b is not None and g.get(x, b - 2) is not None and c.is_ramp(g.get(x, b - 2)):
            g.p(x, b - 2, "R")


def veh_horde(g, c):
    for x in range(g.w):                       # spikes along every top edge
        t = c.ramp_top(g, x)
        if t is not None and x % 3 == 1 and g.get(x, t - 1) is None:
            g.p(x, t - 1, "4")
            g.p(x, t - 2, "5")
    x0, x1 = _hull_span(g, c)
    b = c.ramp_bottom(g, x1)
    if b is not None:                          # dozer ram on the nose
        g.ln(x1 + 1, b, x1 + 3, b - 5, "3", 2)
        for k in range(0, 6, 2):
            g.p(x1 + 3, b - k, "4")
    g.r(x0 + 1, (c.ramp_top(g, x0 + 1) or 20) + 1, 2, 3, "R")   # war banner


def veh_coalition(g, c):
    x0, x1 = _hull_span(g, c)
    for cx in (x0 + (x1 - x0) // 3, x0 + 2 * (x1 - x0) // 3):   # green chevron markings
        b = c.ramp_bottom(g, cx)
        if b is None:
            continue
        for d in range(3):
            for sx in (-d, d):
                p = g.get(cx + sx, b - 3 + d)
                if p is not None and c.is_ramp(p):
                    g.p(cx + sx, b - 3 + d, "R")
    bx, bt = _highest_col(g, c)
    g.r(bx - 1, bt - 3, 3, 3, "1")             # sensor pod
    g.p(bx, bt - 2, "g")
    g.p(bx + 1, bt - 3, "h")
    g.ln(bx - 4, bt - 1, bx - 4, bt - 6, "2")
    g.p(bx - 4, bt - 7, "G" if c.i % 4 < 2 else "R")
    for y in range(g.h):                       # ERA tiles on the upper armour
        for x in range(g.w):
            p = g.get(x, y)
            if p is not None and c.is_ramp(p) and x % 4 == 0 and (y - c.shift) % 3 == 0 and y < 19 + c.shift:
                g.p(x, y, "o")
                if g.get(x + 1, y) is not None and c.is_ramp(g.get(x + 1, y)):
                    g.p(x + 1, y, "r")


def veh_corp(g, c):
    for x in range(g.w):                       # neon trim running along the top edge
        t = c.ramp_top(g, x)
        if t is not None:
            g.p(x, t, "R" if (x + c.i) % 9 else "W")
    x0, x1 = _hull_span(g, c)
    b = c.ramp_bottom(g, (x0 + x1) // 2)
    if b is not None:                          # holo stripe
        g.r(x0 + 3, b - 2, max(1, x1 - x0 - 6), 1, "e")


VEHICLE_KITS = {
    "State Troops": veh_state, "Insurgents": veh_insurgents, "Fundamentalists": veh_fund,
    "Mercenaries": veh_merc, "Peace Keepers": veh_pk, "Horde": veh_horde,
    "Coalition Army": veh_coalition, "Corporate Troops": veh_corp,
}


# ------------------------------------------------------------ aircraft
# drone: body x5-25, y = 9 + hover (+2..+6 rows), rotor arms at y+3
# jet: stamp at (1, 8 + hover): tail x3-7 y+0..3, fuselage y+4..7, nose x28-30
def _air_y(c):
    return 9 + c.shift if c.card == "Drone" else 8 + c.shift


def air_state(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        g.ln(15, y + 1, 15, y - 2, "2")
        g.p(15, y - 3, "R")
    else:
        g.r(27, y + 5, 3, 2, "R")              # painted nose cone
        g.r(9, y + 5, 12, 1, "R")              # cheat line


def air_insurgents(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        g.ln(15, y + 7, 15, y + 9, "3")        # taped grenade
        g.disc(15, y + 11, 1.3, "p")
        g.p(15, y + 10, "v")
    else:
        for (x, dy) in ((8, 5), (15, 6), (21, 5)):
            g.r(x, y + dy, 3, 2, "u")
            g.p(x, y + dy, "k")


def air_fund(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        for k in range(6):                     # streamers
            dy = (0, 1, 0, -1)[(k + c.i // 2) % 4]
            g.p(4 - k // 2, y + 5 + dy + k // 2, "R")
    else:
        g.disc(29, y + 5, 1.8, "q")            # retro radial cowling + propeller
        blade = c.i % 3
        if blade == 0:
            g.ln(31, y + 1, 31, y + 9, "3")
        elif blade == 1:
            g.ln(30, y + 2, 31, y + 8, "3")
        else:
            g.ln(31, y + 3, 30, y + 7, "3")
        g.p(31, y + 5, "R")


def air_merc(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        for cx in (1, 30):                     # hex-copter outriggers
            g.ln(5 if cx == 1 else 26, y + 3, cx, y + 2, "1")
            g.r(cx - 1, y + 1, 3, 1, "3" if c.i % 2 else "4")
    else:
        for k, x in enumerate(range(24, 30)):  # shark mouth
            g.p(x, y + 7, "R")
            if k % 2 == 0:
                g.p(x, y + 6, "W")


def air_pk(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        g.p(15, y + 1, "R" if c.i % 4 < 2 else "C")
        g.p(16, y + 1, "e")
    else:
        g.r(3, y, 4, 4, "R")                   # blue tail
        g.r(6, y + 5, 20, 1, "R")


def air_horde(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        g.ellipse(15, y + 10, 2.5, 1.5, "k")   # slung bomb
        g.p(13, y + 10, "1")
        g.p(15, y + 9, "R")
        g.ln(15, y + 7, 15, y + 8, "3")
    else:
        for x in range(9, 27, 4):              # flame teeth livery
            g.p(x, y + 6, "R")
            g.p(x + 1, y + 5, "R")
            g.p(x + 2, y + 6, "e")
        for x in range(10, 24, 3):             # dorsal spikes
            if g.get(x, y + 3) is None and g.get(x, y + 4) is not None:
                g.p(x, y + 3, "4")


def air_coalition(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        g.r(8, y + 4, 16, 1, "p")              # fixed wings
        g.ln(8, y + 4, 5, y + 6, "p")
        g.ln(23, y + 4, 26, y + 6, "p")
    else:
        g.ln(21, y + 3, 24, y + 2, "2", 1)     # canards
        g.ln(12, y + 8, 18, y + 10, "2")       # ventral fin


def air_corp(g, c):
    y = _air_y(c)
    if c.card == "Drone":
        for k in range(0, 26):                 # neon saucer ring
            a = k / 26 * 2 * math.pi
            x = int(round(15.5 + math.cos(a) * 11))
            yy = int(round(y + 4 + math.sin(a) * 2))
            if g.get(x, yy) is None and (k + c.i) % 3:
                g.p(x, yy, "R")
    else:
        g.r(6, y + 5, 22, 1, "R")              # neon spine
        g.p(6 + (c.i * 2) % 22, y + 5, "W")


AIR_KITS = {
    "State Troops": air_state, "Insurgents": air_insurgents, "Fundamentalists": air_fund,
    "Mercenaries": air_merc, "Peace Keepers": air_pk, "Horde": air_horde,
    "Coalition Army": air_coalition, "Corporate Troops": air_corp,
}


# ------------------------------------------------------------ buildings
def _roof(g, c):
    x0, x1 = ROOF_SPAN[c.card]
    out = {}
    for x in range(x0, x1 + 1):
        t = c.top(g, x)
        if t is not None and t < 27:
            out[x] = t
    return out


def _peak(roof):
    x = min(roof, key=lambda k: (roof[k], abs(k - 15)))
    return x, roof[x]


def bld_state(g, c):
    roof = _roof(g, c)
    px, pt = _peak(roof)
    g.ln(px, pt - 1, px, pt - 6, "2")          # loudspeaker mast
    g.r(px + 1, pt - 6, 2, 2, "3")
    g.p(px + 3, pt - 6, "4")
    xs = sorted(roof)
    mid = xs[len(xs) // 3]
    g.r(mid, roof[mid] + 3, 3, 3, "R")         # gold star plaque
    g.p(mid + 1, roof[mid] + 4, "W")


def bld_insurgents(g, c):
    roof = _roof(g, c)
    for k, x in enumerate(sorted(roof)):       # cracks and patched boards
        if h01(x, 2, 7) < 0.12:
            t = roof[x] + 2
            for d in range(4):
                g.p(x + (d % 2), t + d, "n")
        if h01(x, 8, 3) < 0.07:
            g.r(x, roof[x] + 4, 3, 2, "u")
            g.p(x, roof[x] + 4, "k")
    for x in range(1, 31):                     # rubble at the foot
        if h01(x, 1, 11) < 0.35 and g.get(x, 27) is None:
            g.p(x, 27, "u" if h01(x, 4) < 0.5 else "3")
    xs = sorted(roof)
    a, b = xs[1], xs[-2]                        # washing line
    for x in range(a, b + 1, 1):
        if x % 7 == 3:
            g.r(x, min(roof[a], roof[b]) - 2, 2, 2, "R" if x % 2 else "w")


def bld_fund(g, c):
    roof = _roof(g, c)
    for x, t in roof.items():                  # crenellated stone parapet
        if (x // 2) % 2 == 0 and g.get(x, t - 1) is None:
            g.r(x, t - 2, 1, 2, "B")
            g.p(x, t - 2, "v")
    xs = sorted(roof)
    for bx in (xs[len(xs) // 4], xs[3 * len(xs) // 4]):
        t = roof[bx] + 1                        # hanging banners
        g.r(bx, t, 2, 5, "R")
        g.p(bx, t + 5, "e")
        g.p(bx + 1, t + 2, "e")


def bld_merc(g, c):
    roof = _roof(g, c)
    for x, t in roof.items():                  # razor wire
        yy = t - 2 - (1 if x % 3 == 0 else 0)
        if g.get(x, yy) is None:
            g.p(x, yy, "3")
    px, pt = _peak(roof)
    g.r(px - 1, pt - 3, 3, 2, "1")             # searchlight
    g.p(px + 1, pt - 3, "Y" if c.i % 8 < 5 else "W")
    for x in range(1, 9, 3):                   # sandbag heap
        g.r(x, 25, 3, 2, "v")
        g.p(x, 25, "w")


def bld_pk(g, c):
    roof = _roof(g, c)
    for x, t in roof.items():                  # blue awning stripe under the roof
        yy = t + 3
        p = g.get(x, yy)
        if p is not None and p not in (c.R.rgba("Y"), c.R.rgba("O"), c.R.rgba("n")):
            g.p(x, yy, "R")
    px, pt = _peak(roof)
    g.ln(px + 2, pt - 1, px + 2, pt - 3, "2")  # satellite dish
    g.r(px + 1, pt - 5, 4, 1, "4")
    g.r(px + 2, pt - 4, 2, 1, "5")


def bld_horde(g, c):
    roof = _roof(g, c)
    for x, t in roof.items():                  # iron spikes
        if x % 3 == 0 and g.get(x, t - 1) is None:
            g.p(x, t - 1, "4")
            g.p(x, t - 2, "5")
    xs = sorted(roof)
    for bx in (xs[len(xs) // 3], xs[2 * len(xs) // 3]):
        t = roof[bx] + 1                        # red war banners
        g.r(bx, t, 2, 6, "R")
        g.p(bx, t + 6, "R")
        g.r(bx, t + 2, 2, 1, "K")


def bld_coalition(g, c):
    roof = _roof(g, c)
    xs = sorted(roof)
    for x in xs[len(xs) // 4: 3 * len(xs) // 4]:  # solar panels
        t = roof[x]
        if g.get(x, t - 1) is None:
            g.p(x, t - 1, "c" if x % 3 else "g")
            g.p(x, t - 2, "1" if x % 3 == 0 else "c")
    px, pt = _peak(roof)
    g.ln(px, pt - 1, px, pt - 5, "2")          # small wind mast
    blade = c.i % 3
    tips = ((-2, -1), (2, -1), (0, 2)) if blade == 0 else (((-1, -2), (2, 0), (-1, 2)) if blade == 1 else ((1, -2), (1, 2), (-2, 0)))
    for dx, dy in tips:
        g.ln(px, pt - 6, px + dx, pt - 6 + dy, "4")


def bld_corp(g, c):
    roof = _roof(g, c)
    for x, t in roof.items():                  # neon roofline
        g.p(x, t, "R" if (x + c.i) % 7 else "W")
    xs = sorted(roof)
    hx = xs[0]
    ht = roof[hx]
    on = c.i % 10 < 7                           # holo billboard on a mast
    g.ln(hx + 1, ht - 1, hx + 1, ht - 3, "2")
    g.r(hx - 1, ht - 8, 7, 5, "e" if on else "1")
    g.r(hx, ht - 7, 5, 3, "C" if on else "2")
    if on:
        g.r(hx + 1, ht - 6, 3, 1, "W")


BUILDING_KITS = {
    "State Troops": bld_state, "Insurgents": bld_insurgents, "Fundamentalists": bld_fund,
    "Mercenaries": bld_merc, "Peace Keepers": bld_pk, "Horde": bld_horde,
    "Coalition Army": bld_coalition, "Corporate Troops": bld_corp,
}


# ================================================================ map props
# Three landmarks per nation, 4-frame loops, drawn over its territory by the map
# view (scripts/world_map_view.gd). 32x32 grid, sitting on the bottom rows.
PROP_FRAMES = 4


def _fire(g, x, y, i):
    h = (3, 4, 3, 5)[i % 4]
    g.r(x - 1, y - 1, 3, 2, "O")
    g.ln(x, y - 1, x, y - h, "Y")
    g.p(x + (i % 2) * 2 - 1, y - h + 1, "O")
    g.r(x - 2, y + 1, 5, 1, "t")


def p_state(g, k, i):
    if k == 0:   # watchtower
        g.ln(10, 28, 13, 12, "t", 1); g.ln(22, 28, 19, 12, "t", 1)
        g.ln(11, 22, 21, 22, "u"); g.ln(12, 17, 20, 17, "u")
        g.r(10, 7, 13, 6, "p"); g.r(10, 7, 13, 1, "q"); g.r(12, 9, 9, 2, "n")
        g.r(9, 5, 15, 2, "o")
        g.r(15, 9, 3, 2, "R")
        g.p(16, 3 - (i % 2), "R")
    elif k == 1:  # statue on a plinth
        g.r(10, 23, 12, 5, "3"); g.r(10, 23, 12, 1, "4"); g.r(12, 21, 8, 2, "2")
        g.r(14, 11, 4, 10, "2"); g.r(14, 11, 1, 10, "3")
        g.disc(16, 9, 2, "2"); g.ln(17, 13, 22, 6, "2", 1)
        g.p(22, 5, "R")
    else:        # radio mast
        for y in range(4, 28):
            g.p(15 + (y % 4 == 0), y, "2"); g.p(17 - (y % 4 == 0), y, "2")
        g.ln(16, 6, 9, 28, "1"); g.ln(16, 6, 23, 28, "1")
        g.p(16, 3, "R" if i % 2 else "e")


def p_insurgents(g, k, i):
    if k == 0:   # ruined wall
        g.r(6, 16, 20, 11, "B")
        for y in range(17, 27, 2):
            for x in range(6 + (y % 4 == 1) * 2, 26, 4):
                g.r(x, y, 3, 1, "b")
        for x in range(6, 26):
            t = 16 + int(h01(x, 2) * 6) if 11 < x < 22 else 16
            g.r(x, 16, 1, t - 16, None)
        g.r(9, 20, 3, 4, "n")
        for x in range(4, 29, 2):
            g.p(x, 27, "u" if x % 4 else "3")
    elif k == 1:  # tent + campfire
        for d in range(9):
            g.r(4 + d, 27 - d * 2, 18 - 2 * d, 2, "v" if d % 3 else "u")
        g.r(11, 21, 4, 6, "n")
        g.r(12, 13, 2, 1, "R")
        _fire(g, 25, 26, i)
    else:        # burnt-out car
        g.r(5, 20, 22, 5, "k"); g.r(9, 15, 12, 5, "n"); g.r(10, 16, 4, 3, "1"); g.r(16, 16, 4, 3, "1")
        g.disc(9, 26, 2.3, "K"); g.disc(22, 26, 2.3, "K")
        g.p(12, 14 - i % 3, "3"); g.p(14, 12 - i % 3, "2")


def p_fund(g, k, i):
    if k == 0:   # stone arch gate
        g.r(6, 10, 20, 18, "B")
        g.r(6, 10, 20, 1, "v")
        for x in range(6, 26, 3):
            g.r(x, 8, 2, 2, "B")
        g.ellipse(16, 20, 5, 8, "n")
        g.r(11, 20, 11, 8, "n")
        g.r(14, 12, 4, 2, "R")
    elif k == 1:  # well
        g.ellipse(16, 24, 9, 3, "B"); g.ellipse(16, 23, 7, 2, "n")
        g.r(8, 12, 1, 12, "t"); g.r(23, 12, 1, 12, "t"); g.r(7, 11, 18, 2, "u")
        g.ln(16, 13, 16, 17 + i % 2, "3"); g.r(15, 18 + i % 2, 3, 2, "2")
    else:        # banner poles
        for x, h in ((8, 6), (16, 3), (24, 7)):
            g.r(x, h, 1, 28 - h, "2")
            wav = (0, 1, 0, -1)[(i + x) % 4]
            g.r(x + 1, h + wav, 4, 7, "R"); g.p(x + 4, h + 7 + wav, "e"); g.r(x + 1, h + 2 + wav, 4, 1, "e")


def p_merc(g, k, i):
    if k == 0:   # crate stack
        for (x, y) in ((6, 19), (15, 19), (10, 11)):
            g.r(x, y, 9, 8, "u"); g.r(x, y, 9, 1, "v"); g.ln(x, y, x + 8, y + 7, "t"); g.ln(x + 8, y, x, y + 7, "t")
            g.r(x + 3, y + 3, 3, 2, "R")
    elif k == 1:  # helipad
        g.ellipse(16, 24, 12, 4, "1"); g.ellipse(16, 24, 10, 3, "2")
        g.r(12, 22, 1, 5, "Y"); g.r(19, 22, 1, 5, "Y"); g.r(12, 24, 8, 1, "Y")
        for x in (5, 27):
            g.p(x, 24, "R" if i % 2 else "e")
    else:        # razor-wire fence
        for x in (4, 12, 20, 28):
            g.r(x, 12, 1, 16, "t")
        for x in range(4, 29):
            g.p(x, 14 + (x % 3 == 0), "3"); g.p(x, 20 + (x % 3 == 1), "3")
            if x % 4 == 0:
                g.p(x, 13, "4")


def p_pk(g, k, i):
    if k == 0:   # field tent
        g.r(5, 17, 22, 10, "r"); g.r(5, 17, 22, 1, "5")
        for d in range(6):
            g.r(5 + d, 17 - d, 22 - 2 * d, 1, "q")
        g.r(5, 22, 22, 2, "R"); g.r(14, 20, 4, 7, "n")
    elif k == 1:  # supply depot
        for (x, y) in ((4, 20), (13, 20), (22, 20), (8, 13), (17, 13)):
            g.r(x, y, 8, 7, "r"); g.r(x, y, 8, 1, "5"); g.r(x + 3, y, 2, 7, "R")
    else:        # satellite dish
        g.r(14, 20, 4, 8, "3")
        g.ellipse(14, 13, 8, 5, "4"); g.ellipse(15, 13, 6, 3, "5")
        g.ln(14, 13, 21, 8, "2"); g.p(21, 7, "R" if i % 2 else "c")


def p_horde(g, k, i):
    if k == 0:   # yurt
        g.ellipse(16, 22, 11, 6, "v"); g.r(5, 22, 23, 6, "v")
        g.ellipse(16, 17, 8, 4, "R"); g.p(16, 12, "e")
        for x in range(6, 27, 4):
            g.r(x, 23, 1, 4, "u")
        g.r(14, 22, 5, 6, "n")
    elif k == 1:  # spiked palisade
        for x in range(4, 29, 3):
            h = 12 + int(h01(x, 6) * 5)
            g.r(x, h, 2, 28 - h, "u"); g.p(x, h - 1, "t"); g.p(x, h - 2, "4")
        g.r(4, 20, 26, 1, "t")
    else:        # bonfire totem
        g.r(14, 6, 4, 17, "t"); g.r(13, 8, 6, 3, "R"); g.r(14, 9, 1, 1, "Y"); g.r(17, 9, 1, 1, "Y")
        g.r(12, 14, 8, 2, "u")
        _fire(g, 16, 27, i)


def p_coalition(g, k, i):
    if k == 0:   # wind turbine
        g.ln(16, 28, 16, 10, "4", 2)
        a = i * math.pi / 6
        for b in range(3):
            ang = a + b * 2 * math.pi / 3
            g.ln(16, 9, int(round(16 + math.cos(ang) * 8)), int(round(9 + math.sin(ang) * 8)), "5")
        g.p(16, 9, "R")
    elif k == 1:  # radar dome
        g.r(9, 21, 14, 7, "3"); g.r(9, 21, 14, 1, "4")
        g.ellipse(16, 17, 7, 7, "5"); g.ellipse(14, 15, 3, 3, "W")
        for x in range(10, 23, 3):
            g.p(x, 17, "4")
        g.p(16, 9, "R" if i % 2 else "e")
    else:        # solar field
        for row, y in enumerate((14, 20)):
            for x0 in (3, 17):
                for d in range(4):
                    g.r(x0 + d, y + d, 12, 1, "c" if (d + row) % 2 else "g")
                g.r(x0 + 5, y + 4, 1, 4, "2")


def p_corp(g, k, i):
    if k == 0:   # neon pylon tower
        g.r(13, 6, 6, 22, "1"); g.r(13, 6, 2, 22, "2")
        for y in range(8, 27, 3):
            g.r(13, y, 6, 1, "R" if (y // 3 + i) % 3 else "W")
        g.r(15, 2, 2, 4, "2"); g.p(15, 1, "R" if i % 2 else "C")
    elif k == 1:  # holo billboard
        g.r(15, 16, 2, 12, "1")
        g.r(5, 4, 22, 13, "1"); g.r(6, 5, 20, 11, "e" if i % 4 else "1")
        g.r(8, 7, 7, 2, "C"); g.r(8, 10, 14, 1, "R"); g.r(8, 12, 10, 1, "R")
        g.p(22, 7, "W" if i % 2 else "C")
    else:        # data-centre dome
        g.r(5, 21, 22, 7, "1"); g.r(5, 21, 22, 1, "2")
        g.ellipse(16, 20, 9, 7, "2"); g.r(7, 20, 18, 1, "R")
        for x in range(8, 25, 3):
            g.p(x, 24, "R" if (x + i) % 2 else "C")


PROPS = {
    "State Troops": p_state, "Insurgents": p_insurgents, "Fundamentalists": p_fund,
    "Mercenaries": p_merc, "Peace Keepers": p_pk, "Horde": p_horde,
    "Coalition Army": p_coalition, "Corporate Troops": p_corp,
}


def gen_props(R, nations_pal):
    """Assets/Props/<nation>/prop_<k>_<frame>.png (128px), drawn in the nation's palette."""
    sheet = []
    for nation, fn in PROPS.items():
        saved = dict(R.PAL)
        try:
            R.PAL.update(nations_pal[nation])
            for k in range(3):
                for i in range(PROP_FRAMES):
                    g = R.Pix(32, 32)
                    R.shadow(g, 16, 28, 11, 70)
                    body = R.Pix(32, 32)
                    fn(body, k, i)
                    body.outline()
                    g.over(body)
                    out = os.path.join(R.ROOT, "Assets", "Props", nation)
                    os.makedirs(out, exist_ok=True)
                    g.save(os.path.join(out, "prop_%d_%d.png" % (k, i)), 4)
                    if i == 0:
                        sheet.append(g)
        finally:
            R.PAL.clear()
            R.PAL.update(saved)
        print("props", nation)
    return sheet
