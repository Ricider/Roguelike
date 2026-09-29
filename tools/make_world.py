#!/usr/bin/env python3
"""Generate the hex campaign maps (Assets/Maps/<id>.json) from real coastlines.

Land comes from Natural Earth's public-domain 1:110m land polygons
(downloaded once and cached in tools/data/). Each hex samples 7 points
(centre + 6 around it) and is land when 3+ hit land, so thin islands such as
Britain and Japan survive. Terrain is assigned from latitude bands and
hand-placed boxes for real deserts, forests and mountain ranges ('j' tiles
are drawn as dense forest/jungle). Narrow straits are bridged with land hexes
so no capital ends up unreachable; distant islands stay separate and become
unclaimed wilderness.

Projection: equirectangular over each map's lon/lat box; grid sizes are
chosen so shapes keep their proportions at the map's middle latitude. Hexes
are pointy-top in odd-r layout (odd rows shifted half a hex right), matching
MapCampaign. Only the world map wraps east-west (at the Bering Strait).

Every map uses the same 8 factions; the city each one starts from is set per
map in MAPS below (the assignments are arbitrary game labels).

    python3 tools/make_world.py              # all maps
    python3 tools/make_world.py europe       # one map
"""
import json
import math
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tools", "data", "ne_110m_land.geojson")
URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson"
OUT_DIR = os.path.join(ROOT, "Assets", "Maps")

# (lat_min, lat_max, lon_min, lon_max) boxes for terrain, shared by every map
DESERT = [(15, 32, -17, 33), (15, 31, 34, 58), (25, 36, 52, 68), (37, 48, 88, 115), (36, 42, 75, 90),
          (-32, -18, 118, 142), (-28, -17, 12, 24), (28, 37, -118, -103), (-28, -18, -71, -68), (39, 46, 52, 66)]
JUNGLE = [(-14, 5, -76, -45), (-7, 5, 9, 30), (-10, 20, 95, 150), (7, 18, -92, -77), (8, 16, 73, 80), (-24, -12, 44, 51)]
MOUNTAIN = [(27, 37, 72, 100), (-42, -15, -72, -66), (-15, 6, -79, -73), (36, 55, -121, -107), (44, 48, 6, 14),
            (41, 44, 40, 48), (29, 36, 46, 54), (51, 66, 57, 61), (31, 35, -8, 2), (-5, 12, 36, 41), (61, 68, 8, 16),
            (58, 66, -140, -128)]
# extra detail that only shows at regional scale (not used for the world map)
REGIONAL_MOUNTAIN = [(42.3, 43.2, -2, 3), (41.5, 44.2, 12.5, 15.5), (41.5, 45, 16, 21), (47.3, 49.6, 22.3, 26.5),
                     (36.6, 38.4, 30, 37.5), (44.4, 44.9, 33.6, 35.2), (38.5, 41, 39.5, 44), (40.5, 42.5, 22, 26),
                     (34.5, 36.5, 35.5, 36.5), (26, 30, 96, 104), (35, 37.5, 136, 139.5), (37, 39.5, 127.5, 129.5)]
REGIONAL_DESERT = [(29, 31.6, 33.5, 35.5), (31, 36, 36.5, 42)]
REGIONAL_FOREST = [(51, 53.5, 22, 33), (56, 64, 22, 60), (58, 64, 10, 20), (45, 50, 125, 135)]
SNOW_LAT = 64.0

MAPS = {
    "world": {
        "name": "World", "blurb": "The whole Earth. Wraps east-west at the Bering Strait.",
        "grid": (90, 40), "lon": (-169.0, 191.0), "lat": (80.0, -62.0), "wraps": True,
        "antarctica": True, "americas_split": True, "regional": False,
        "cities": {
            "Insurgents": ("Kabul", 34.53, 69.17), "State Troops": ("Baghdad", 33.31, 44.36),
            "Fundamentalists": ("Timbuktu", 16.77, -3.01), "Mercenaries": ("Kinshasa", -4.32, 15.31),
            "Peace Keepers": ("Rio de Janeiro", -22.91, -43.17), "Horde": ("Moscow", 55.76, 37.62),
            "Coalition Army": ("Paris", 48.86, 2.35), "Corporate Troops": ("San Francisco", 37.77, -122.42),
        },
        # Sulawesi -> New Guinea: joins Australia/New Guinea to Asia so every
        # territory there can be fought over (the gap is too wide to auto-bridge).
        "bridges": [(-2.0, 121.0, -2.5, 133.5)],
        # Extra starting cities for nations spread over more than one area.
        "seeds": {
            "Peace Keepers": [("Sydney", -33.87, 151.21)],
            "Horde": [("Beijing", 39.90, 116.40)],
        },
        # Starting territory claims, first match wins: (lat_min, lat_max, lon_min, lon_max)
        # in -180..180 longitudes. Land nobody claims (and claim fragments cut off from
        # a nation's cities) goes to the nearest territory, as on the other maps.
        "claims": [
            ("Fundamentalists", [(0, 37.2, -18, 11.5)]),                           # West & North-West Africa
            ("Corporate Troops", [(8.5, 84, -170, -52), (59, 84, -75, -20)]),       # North America + Greenland
            ("Peace Keepers", [(-60, 8.5, -95, -30), (-45, -9, 110, 156)]),         # South America + Australia
            ("Coalition Army", [(43, 72, -25, 28.5), (36, 44, -10, 28.5), (59.5, 71, 20, 32),
                                (44, 53, 22, 40.5), (51, 57, 22, 32.5)]),           # all of Europe
            ("Horde", [(50, 82, 27, 180), (50, 82, -180, -168), (41, 50, 36, 50), (42, 50, 127, 142),
                       (18, 42, 108, 123), (40, 54, 115, 135)]),                    # Russia + eastern China
        ],
    },
    "europe": {
        "name": "Europe", "blurb": "From Iberia to the Urals, Scandinavia to the North African coast.",
        "grid": (43, 50), "lon": (-12.0, 48.0), "lat": (71.0, 34.0), "wraps": False, "regional": True,
        "cities": {
            "Fundamentalists": ("London", 51.51, -0.13), "Coalition Army": ("Paris", 48.86, 2.35),
            "State Troops": ("Berlin", 52.52, 13.40), "Mercenaries": ("Madrid", 40.42, -3.70),
            "Peace Keepers": ("Rome", 41.90, 12.50), "Horde": ("Moscow", 55.76, 37.62),
            "Corporate Troops": ("Stockholm", 59.33, 18.07), "Insurgents": ("Athens", 37.98, 23.73),
        },
    },
    "byzantium": {
        "name": "Byzantium", "blurb": "The Eastern Mediterranean of the old empire: Balkans, Anatolia, the Levant and Egypt.",
        "grid": (53, 38), "lon": (8.0, 48.0), "lat": (47.0, 27.0), "wraps": False, "regional": True,
        "cities": {
            "State Troops": ("Constantinople", 41.01, 28.98), "Coalition Army": ("Rome", 41.90, 12.50),
            "Mercenaries": ("Carthage", 36.85, 10.32), "Corporate Troops": ("Alexandria", 31.20, 29.92),
            "Horde": ("Trebizond", 41.00, 39.72), "Insurgents": ("Antioch", 36.20, 36.16),
            "Fundamentalists": ("Athens", 37.98, 23.73), "Peace Keepers": ("Jerusalem", 31.77, 35.21),
        },
    },
    "east_asia": {
        "name": "East Asia", "blurb": "China, Mongolia, Korea, Japan, Southeast Asia and the Philippines.",
        "grid": (45, 50), "lon": (88.0, 148.0), "lat": (54.0, 4.0), "wraps": False, "regional": True,
        "bridges": [(22.0, 120.7, 18.4, 121.0)],  # Taiwan -> Luzon (Luzon Strait is too wide to auto-bridge)
        "cities": {
            "Corporate Troops": ("Tokyo", 35.68, 139.69), "State Troops": ("Beijing", 39.90, 116.40),
            "Coalition Army": ("Seoul", 37.57, 126.98), "Peace Keepers": ("Manila", 14.60, 120.98),
            "Mercenaries": ("Bangkok", 13.75, 100.50), "Insurgents": ("Hanoi", 21.03, 105.85),
            "Horde": ("Ulaanbaatar", 47.92, 106.92), "Fundamentalists": ("Shanghai", 31.23, 121.47),
        },
    },
}


class Grid:
    def __init__(self, spec):
        self.W, self.H = spec["grid"]
        self.lon0, self.lon1 = spec["lon"]
        self.lat_top, self.lat_bot = spec["lat"]
        self.wraps = spec["wraps"]
        self.span = self.lon1 - self.lon0

    def center(self, x, y):
        fx = (x + 0.5 * (y & 1) + 0.5) / self.W
        fy = (y + 0.5) / self.H
        return self.lat_top - fy * (self.lat_top - self.lat_bot), self.lon0 + fx * self.span

    def neighbors(self, x, y):
        dirs = [(1, 0), (1, 1), (0, 1), (-1, 0), (0, -1), (1, -1)] if y & 1 else \
               [(1, 0), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1)]
        for dx, dy in dirs:
            nx, ny = x + dx, y + dy
            if not 0 <= ny < self.H:
                continue
            if self.wraps:
                nx %= self.W
            elif not 0 <= nx < self.W:
                continue
            yield nx, ny

    def dist(self, a, b):
        best = 10 ** 9
        for shift in ((-self.W, 0, self.W) if self.wraps else (0,)):
            ax, ay = a
            bx, by = b[0] + shift, b[1]
            aq = ax - (ay - (ay & 1)) // 2
            bq = bx - (by - (by & 1)) // 2
            dq, dr = aq - bq, ay - by
            best = min(best, (abs(dq) + abs(dr) + abs(dq + dr)) // 2)
        return best

    def line(self, a, b):
        """Hexes on the straight line a->b (cube lerp), the short way round when wrapping."""
        ax, ay = a
        bx, by = b
        if self.wraps:
            if bx - ax > self.W // 2:
                bx -= self.W
            elif ax - bx > self.W // 2:
                bx += self.W
        aq, ar = ax - (ay - (ay & 1)) // 2, ay
        bq, br = bx - (by - (by & 1)) // 2, by
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
            out.append((x % self.W if self.wraps else x, rr))
        return [h for h in out if 0 <= h[0] < self.W]


def norm_lon(lon):
    return (lon + 180.0) % 360.0 - 180.0


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
    j = len(ring) - 1
    for i in range(len(ring)):
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


def in_boxes(boxes, lat, lon, ragged=None):
    """True if (lat, lon) is in any box. With ragged=(x, y), hexes near a box
    edge drop out pseudo-randomly so regional terrain has natural outlines."""
    lon = norm_lon(lon)
    for a, b, c, d in boxes:
        if a <= lat <= b and c <= lon <= d:
            if ragged is None:
                return True
            edge = min((lat - a) / max(b - a, 1e-6), (b - lat) / max(b - a, 1e-6),
                       (lon - c) / max(d - c, 1e-6), (d - lon) / max(d - c, 1e-6))
            x, y = ragged
            noise = ((x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995) % 1000 / 1000.0
            if edge > 0.18 or noise < 0.55 + edge * 2.0:
                return True
    return False


def components(g, land):
    seen = {}
    comps = []
    for h in land:
        if h in seen:
            continue
        stack = [h]
        seen[h] = len(comps)
        comp = []
        while stack:
            c = stack.pop()
            comp.append(c)
            for n in g.neighbors(*c):
                if n in land and n not in seen:
                    seen[n] = len(comps)
                    stack.append(n)
        comps.append(comp)
    return comps, seen


def build(map_id, spec, polys):
    g = Grid(spec)
    W, H = g.W, g.H
    rows_last = H - 1 if spec.get("antarctica") else H
    land = set()
    dlat = abs(g.lat_top - g.lat_bot) / H * 0.33
    dlon = g.span / W * 0.33
    for y in range(rows_last):
        for x in range(W):
            lat, lon = g.center(x, y)
            pts = [(lat, lon)] + [(lat + dlat * math.sin(a), lon + dlon * math.cos(a)) for a in [k * math.pi / 3 for k in range(6)]]
            if sum(1 for p in pts if is_land(polys, *p)) >= 3:
                land.add((x, y))
    # Hand-placed bridges for straits too wide to auto-bridge
    def to_hex(lat, lon):
        fy = (g.lat_top - lat) / (g.lat_top - g.lat_bot)
        y = min(H - 1, max(0, int(fy * H)))
        x = int(((lon - g.lon0) / g.span) * W - 0.5 * (y & 1))
        return min(W - 1, max(0, x)), y
    for (la1, lo1, la2, lo2) in spec.get("bridges", []):
        for h in g.line(to_hex(la1, lo1), to_hex(la2, lo2)):
            land.add(h)
    # Bridge narrow straits: join every sizeable landmass to its nearest
    # neighbour when the water gap is at most 3 hexes. Far islands stay separate.
    for _ in range(40):
        comps, owner = components(g, land)
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
                    d = g.dist(a, b)
                    if d <= 3 and (best is None or d < best[0]):
                        best = (d, a, b)
            if best is not None:
                for h in g.line(best[1], best[2]):
                    land.add(h)
                joined = True
                break
        if not joined:
            break
    mountains = MOUNTAIN + (REGIONAL_MOUNTAIN if spec.get("regional") else [])
    deserts = DESERT + (REGIONAL_DESERT if spec.get("regional") else [])
    forests = JUNGLE + (REGIONAL_FOREST if spec.get("regional") else [])
    grid = [["." for _ in range(W)] for _ in range(H)]
    for (x, y) in land:
        lat, lon = g.center(x, y)
        rag = (x, y) if spec.get("regional") else None
        if abs(lat) >= SNOW_LAT or in_boxes([(58, 84, -60, -18)], lat, lon):
            t = "s"
        elif in_boxes(mountains, lat, lon, rag):
            t = "m"
        elif in_boxes(deserts, lat, lon, rag):
            t = "d"
        elif in_boxes(forests, lat, lon, rag):
            t = "j"
        else:
            t = "g"
        grid[y][x] = t
    if spec.get("antarctica"):
        for x in range(W):
            if 8 <= x <= W - 10:
                grid[H - 1][x] = "s"
    # Capitals: the free land hex whose centre is nearest the real city
    nations = []
    taken = set()
    for name, (city, lat, lon) in spec["cities"].items():
        def geo_d(h):
            hlat, hlon = g.center(*h)
            dlon2 = (hlon - lon + 180.0) % 360.0 - 180.0
            return math.hypot(hlat - lat, dlon2 * math.cos(math.radians(lat)))
        best = min((h for h in land if h not in taken), key=geo_d)
        taken.add(best)
        nations.append({"name": name, "capital": city, "x": best[0], "y": best[1], "seeds": []})
    for n in nations:
        for (city, lat, lon) in spec.get("seeds", {}).get(n["name"], []):
            def geo_d2(h):
                hlat, hlon = g.center(*h)
                dlon2 = (hlon - lon + 180.0) % 360.0 - 180.0
                return math.hypot(hlat - lat, dlon2 * math.cos(math.radians(lat)))
            best = min((h for h in land if h not in taken), key=geo_d2)
            taken.add(best)
            n["seeds"].append({"city": city, "x": best[0], "y": best[1]})
    comps, owner = components(g, land)
    main = max(comps, key=len)
    print("%-10s grid %dx%d, land %d, landmasses %d" % (map_id, W, H, len(land), len(comps)))
    for n in nations:
        size = len(comps[owner[(n["x"], n["y"])]])
        flag = "" if size == len(main) else "   <-- not on the main landmass!"
        print("   %-17s %-15s (%d,%d)%s" % (n["name"], n["capital"], n["x"], n["y"], flag))
    data = {
        "id": map_id, "name": spec["name"], "blurb": spec["blurb"],
        "grid_w": W, "grid_h": H, "wraps": g.wraps,
        "lon0": g.lon0, "lon_span": g.span, "lat_top": g.lat_top, "lat_bot": g.lat_bot,
        "americas_split": bool(spec.get("americas_split", False)),
        "rows": ["".join(r) for r in grid],
        "nations": nations,
        "claims": [{"nation": n, "boxes": [list(b) for b in boxes]} for (n, boxes) in spec.get("claims", [])],
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, map_id + ".json"), "w") as f:
        json.dump(data, f, indent=1)
    return data


def main(ids):
    polys = load_polys()
    for map_id in ids or list(MAPS):
        build(map_id, MAPS[map_id], polys)


if __name__ == "__main__":
    main(sys.argv[1:])
