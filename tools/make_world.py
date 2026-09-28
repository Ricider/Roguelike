#!/usr/bin/env python3
"""Generate the hex world map (Classes/GameBoard/WorldMap.gd ROWS + capitals)
from real coastlines.

Land comes from Natural Earth's public-domain 1:110m land polygons
(downloaded once and cached in tools/data/). Each hex samples 7 points
(centre + 6 around it) and is land when 3+ hit land, so thin islands such as
Britain and Japan survive. Terrain is assigned from latitude bands and
hand-placed boxes for real deserts, rainforests and mountain ranges.
Narrow straits (Dover, Korea, Bering, the Indonesian chain...) are bridged
with land hexes so no capital ends up unreachable; far islands (New Zealand,
Antarctica) stay separate and become unclaimed wilderness.

Projection: equirectangular. Columns start at LON0 (the Bering Strait, where
the map wraps east-west). Hexes are pointy-top in odd-r layout (odd rows
shifted half a hex right), matching MapCampaign.

    python3 tools/make_world.py            # regenerate WorldMap.gd in place
"""
import json
import math
import os
import re
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tools", "data", "ne_110m_land.geojson")
URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson"
TARGET = os.path.join(ROOT, "Classes", "GameBoard", "WorldMap.gd")

W, H = 90, 40
LON0 = -169.0        # west edge = Bering Strait (map wraps here)
LAT_TOP = 80.0
LAT_BOT = -62.0      # the last row is forced to an Antarctic ice shelf

CAPITALS = {  # name -> (lat, lon)
    "Insurgents": (34.53, 69.17),        # Kabul
    "State Troops": (33.31, 44.36),      # Baghdad
    "Fundamentalists": (51.51, -0.13),   # London
    "Mercenaries": (-4.32, 15.31),       # Kinshasa
    "Peace Keepers": (40.71, -74.01),    # New York
    "Horde": (55.76, 37.62),             # Moscow
    "Coalition Army": (48.86, 2.35),     # Paris
    "Corporate Troops": (35.68, 139.69), # Tokyo
}

# (lat_min, lat_max, lon_min, lon_max) boxes for terrain
DESERT = [(15, 32, -17, 33), (15, 31, 34, 58), (25, 36, 52, 68), (37, 48, 88, 115), (36, 42, 75, 90),
          (-32, -18, 118, 142), (-28, -17, 12, 24), (28, 37, -118, -103), (-28, -18, -71, -68), (39, 46, 52, 66)]
JUNGLE = [(-14, 5, -76, -45), (-7, 5, 9, 30), (-10, 20, 95, 150), (7, 18, -92, -77), (8, 16, 73, 80), (-24, -12, 44, 51)]
MOUNTAIN = [(27, 37, 72, 100), (-42, -15, -72, -66), (-15, 6, -79, -73), (36, 55, -121, -107), (44, 48, 6, 14),
            (41, 44, 40, 48), (29, 36, 46, 54), (51, 66, 57, 61), (31, 35, -8, 2), (-5, 12, 36, 41), (61, 68, 8, 16),
            (58, 66, -140, -128)]
SNOW_LAT = 64.0


def hex_center_latlon(x, y):
    fx = (x + 0.5 * (y & 1) + 0.5) / W
    fy = (y + 0.5) / H
    return LAT_TOP - fy * (LAT_TOP - LAT_BOT), LON0 + fx * 360.0


def latlon_to_hex(lat, lon):
    fy = (LAT_TOP - lat) / (LAT_TOP - LAT_BOT)
    y = min(H - 1, max(0, int(fy * H)))
    fx = ((lon - LON0) % 360.0) / 360.0
    x = int(fx * W - 0.5 * (y & 1)) % W
    return x, y


def norm_lon(lon):
    return (lon + 180.0) % 360.0 - 180.0


# --------------------------------------------------------------- geometry
def load_polys():
    if not os.path.exists(DATA):
        os.makedirs(os.path.dirname(DATA), exist_ok=True)
        print("downloading", URL)
        urllib.request.urlretrieve(URL, DATA)
    gj = json.load(open(DATA))
    polys = []
    for f in gj["features"]:
        g = f["geometry"]
        parts = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        for poly in parts:
            ring = poly[0]
            xs = [p[0] for p in ring]
            ys = [p[1] for p in ring]
            polys.append((min(xs), max(xs), min(ys), max(ys), ring))
    return polys


def inside(ring, lon, lat):
    c = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi:
            c = not c
        j = i
    return c


def is_land(polys, lat, lon):
    lon = norm_lon(lon)
    for x0, x1, y0, y1, ring in polys:
        if x0 <= lon <= x1 and y0 <= lat <= y1 and inside(ring, lon, lat):
            return True
    return False


def in_boxes(boxes, lat, lon):
    lon = norm_lon(lon)
    return any(a <= lat <= b and c <= lon <= d for a, b, c, d in boxes)


# -------------------------------------------------------------- hex grid
DIRS_EVEN = [(1, 0), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1)]
DIRS_ODD = [(1, 0), (1, 1), (0, 1), (-1, 0), (0, -1), (1, -1)]


def neighbors(x, y):
    for dx, dy in (DIRS_ODD if y & 1 else DIRS_EVEN):
        ny = y + dy
        if 0 <= ny < H:
            yield (x + dx) % W, ny


def components(land):
    seen = {}
    comps = []
    for (x, y) in land:
        if (x, y) in seen:
            continue
        stack = [(x, y)]
        seen[(x, y)] = len(comps)
        comp = []
        while stack:
            c = stack.pop()
            comp.append(c)
            for n in neighbors(*c):
                if n in land and n not in seen:
                    seen[n] = len(comps)
                    stack.append(n)
        comps.append(comp)
    return comps, seen


def hex_line(a, b):
    """Hexes on the straight line a->b (cube lerp), wrapping east-west the short way."""
    def to_cube(x, y):
        q = x - (y - (y & 1)) // 2
        return q, y
    ax, ay = a
    bx, by = b
    if bx - ax > W // 2:
        bx -= W
    elif ax - bx > W // 2:
        bx += W
    aq, ar = to_cube(ax, ay)
    bq, br = to_cube(bx, by)
    n = max(abs(aq - bq), abs(ar - br), abs((aq + ar) - (bq + br)))
    out = []
    for i in range(n + 1):
        t = i / max(n, 1)
        q = aq + (bq - aq) * t
        r = ar + (br - ar) * t
        s = -q - r
        rq, rr, rs = round(q), round(r), round(s)
        dq, dr, ds = abs(rq - q), abs(rr - r), abs(rs - s)
        if dq > dr and dq > ds:
            rq = -rr - rs
        elif dr > ds:
            rr = -rq - rs
        x = rq + (rr - (rr & 1)) // 2
        out.append((x % W, rr))
    return out


def hex_dist(a, b):
    best = 10 ** 9
    for shift in (-W, 0, W):
        ax, ay = a
        bx, by = b[0] + shift, b[1]
        aq = ax - (ay - (ay & 1)) // 2
        bq = bx - (by - (by & 1)) // 2
        dq, dr = aq - bq, ay - by
        best = min(best, (abs(dq) + abs(dr) + abs(dq + dr)) // 2)
    return best


def main():
    polys = load_polys()
    grid = [["." for _ in range(W)] for _ in range(H)]
    land = set()
    for y in range(H - 1):
        for x in range(W):
            lat, lon = hex_center_latlon(x, y)
            dlat = (LAT_TOP - LAT_BOT) / H * 0.33
            dlon = 360.0 / W * 0.33
            pts = [(lat, lon)] + [(lat + dlat * math.sin(a), lon + dlon * math.cos(a)) for a in [k * math.pi / 3 for k in range(6)]]
            hits = sum(1 for p in pts if is_land(polys, *p))
            if hits >= 3:
                land.add((x, y))
    # Bridge narrow straits: join every sizeable landmass to its nearest
    # neighbour when the water gap is at most 2 hexes (Dover, Korea, Bering,
    # Gibraltar, the Indonesian chain...). Distant islands stay separate.
    for _ in range(12):
        comps, owner = components(land)
        comps.sort(key=len, reverse=True)
        joined = False
        for comp in comps[1:]:
            if len(comp) < 2:
                continue
            cid = owner[comp[0]]
            best = None
            for a in comp:
                for b in land:
                    if owner[b] == cid:
                        continue
                    d = hex_dist(a, b)
                    if d <= 3 and (best is None or d < best[0]):
                        best = (d, a, b)
            if best is not None:
                for h in hex_line(best[1], best[2]):
                    land.add(h)
                joined = True
                break
        if not joined:
            break
    # Terrain
    for (x, y) in land:
        lat, lon = hex_center_latlon(x, y)
        if abs(lat) >= SNOW_LAT or (in_boxes([(58, 84, -60, -18)], lat, lon)):
            t = "s"
        elif in_boxes(MOUNTAIN, lat, lon):
            t = "m"
        elif in_boxes(DESERT, lat, lon):
            t = "d"
        elif in_boxes(JUNGLE, lat, lon):
            t = "j"
        else:
            t = "g"
        grid[y][x] = t
    # Antarctic ice shelf along the bottom row (unreachable wilderness)
    for x in range(W):
        if 8 <= x <= W - 10:
            grid[H - 1][x] = "s"
    # Capitals: the free land hex whose centre is nearest the real coordinates
    # (at 4 degrees per hex London and Paris would otherwise share a hex).
    caps = {}
    taken = set()
    for name, (lat, lon) in CAPITALS.items():
        def geo_d(h):
            hlat, hlon = hex_center_latlon(*h)
            dlon = (hlon - lon + 180.0) % 360.0 - 180.0
            return math.hypot(hlat - lat, dlon * math.cos(math.radians(lat)))
        cands = sorted((h for h in land if h not in taken), key=geo_d)
        caps[name] = cands[0]
        taken.add(cands[0])
    rows = ["".join(r) for r in grid]
    # report connectivity of capitals
    comps, owner = components(land)
    print("grid %dx%d, land hexes %d, landmasses %d" % (W, H, len(land), len(comps)))
    for name, c in caps.items():
        print("  %-17s %s  landmass size %d" % (name, c, len(comps[owner[c]])))
    write_gd(rows, caps)


def write_gd(rows, caps):
    src = open(TARGET).read()
    src = re.sub(r"const GRID_W: int = \d+", "const GRID_W: int = %d" % W, src)
    src = re.sub(r"const GRID_H: int = \d+", "const GRID_H: int = %d" % H, src)
    body = "const ROWS: Array[String] = [\n" + "".join('\t"%s",\n' % r for r in rows) + "]"
    src = re.sub(r"const ROWS: Array\[String\] = \[.*?\n\]", lambda _: body, src, flags=re.S)
    for name, (x, y) in caps.items():
        pat = r'("name": "%s",[^}]*?"x": )\d+(, "y": )\d+' % re.escape(name)
        src, n = re.subn(pat, lambda m: "%s%d%s%d" % (m.group(1), x, m.group(2), y), src, flags=re.S)
        assert n == 1, name
    geo = ("const LON0: float = %.1f # west edge (Bering Strait); the map wraps east-west here\n"
           "const LAT_TOP: float = %.1f\nconst LAT_BOT: float = %.1f\n" % (LON0, LAT_TOP, LAT_BOT))
    if "const LON0" in src:
        src = re.sub(r"const LON0: float = .*?\nconst LAT_TOP: float = .*?\nconst LAT_BOT: float = .*?\n", lambda _: geo, src, flags=re.S)
    else:
        src = src.replace("const OCEAN: String", geo + "\nconst OCEAN: String", 1)
    open(TARGET, "w").write(src)
    print("wrote", TARGET)


if __name__ == "__main__":
    main()
