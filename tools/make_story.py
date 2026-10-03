#!/usr/bin/env python3
"""Generate the State Troops story campaign maps (Assets/Maps/story_<n>.json).

Each chapter gets its own map file, built on the terrain of a normal map
(make_world.build) and extended with:

  "start_owner": rows of one char per hex: the index (0-9) of the nation in
                 "nations" that owns it at the start of the chapter, or "."
  "void":        rows of one char per hex: "x" = outside this chapter's war
                 (drawn greyed out, never owned or entered), "." = in play

Only the chapter's nations are listed, so nobody else exists on that map.
Territories are lat/lon boxes, so what the State Troops won in one chapter
lines up with what they hold in the next even when the map changes. A claim
is either a list of boxes (minus optional "minus" boxes) or a "share": the
given fraction of a region's hexes furthest along a direction (used for the
Insurgents holding the south-eastern two thirds of Anatolia). Claims are
applied in order, first match wins; active land nobody claims goes to the
"rest" nation if the chapter has one, else to the nearest claimant by land.

    python3 tools/make_story.py          # all chapters
    python3 tools/make_story.py 3        # one chapter
"""
import copy
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_world as MW  # noqa: E402

# --------------------------------------------------------------- regions
# (lat_min, lat_max, lon_min, lon_max)
BALKANS = [(44.0, 45.9, 13.4, 29.9), (45.9, 48.3, 22.0, 30.0), (42.2, 44.0, 15.0, 29.9),
           (39.0, 42.2, 18.9, 29.9), (34.5, 39.0, 19.5, 29.9)]
ANATOLIA = [(36.6, 42.2, 26.0, 41.5), (36.8, 41.3, 41.5, 44.8), (35.8, 36.6, 35.7, 36.7)]
LEVANT_ARABIA = [(24.0, 37.2, 34.2, 48.5)]          # the Fertile Crescent and northern Arabia
ARABIA_FULL = [(12.0, 37.2, 34.2, 48.5), (12.0, 26.0, 48.5, 60.0)]
EGYPT = [(22.0, 31.7, 24.9, 34.2)]
EGYPT_FULL = [(22.0, 31.7, 24.9, 36.0)]
LIBYA = [(19.5, 33.5, 9.6, 24.9)]
RUSSIA_EUROPE = [(60.5, 71.0, 31.0, 60.0), (56.0, 60.5, 28.3, 60.0), (52.3, 56.0, 32.5, 60.0),
                 (50.0, 52.3, 36.8, 60.0), (46.5, 50.0, 40.0, 60.0), (43.3, 46.5, 36.6, 49.0)]
CAUCASUS_RU = [(43.3, 46.5, 36.6, 49.0)]
EU = [(36.0, 43.8, -9.6, 3.4), (42.3, 51.2, -5.0, 6.0), (47.8, 49.0, 6.0, 8.3), (49.0, 55.1, 2.5, 15.0),
      (47.3, 49.0, 6.0, 15.0), (46.4, 49.0, 9.5, 17.2), (36.5, 46.4, 6.6, 18.6), (49.0, 55.0, 12.0, 24.1),
      (45.8, 49.0, 15.0, 22.0), (54.0, 59.7, 21.0, 28.2), (55.3, 69.1, 11.0, 31.6), (54.5, 57.8, 8.0, 12.7),
      (51.4, 55.4, -10.6, -5.9)]
UK = [(49.9, 61.0, -8.3, 1.8)]
SWITZERLAND = [(45.8, 47.8, 5.9, 10.5)]
NW_CORNER = UK + [(48.4, 51.1, -5.2, 3.6)]           # Britain and northern France
ANTARCTICA = [(-90.0, -58.0, -180.0, 180.0)]

_WORLD_CLAIMS = {c[0]: c[1] for c in MW.MAPS["world"]["claims"]}

# A "Europe & Mediterranean" frame at the Europe map's hex scale, reaching south
# to Libya and Egypt and east to the Caucasus (the Europe map stops at 34N).
STORY_MED = {
    "grid": (46, 64), "lon": (-12.0, 52.0), "lat": (71.0, 24.0), "wraps": False, "regional": True,
}

ST = "State Troops"
CHAPTERS = {
    1: {
        "base": "byzantium", "name": "Ch. 1: Smoke Over Anatolia",
        "blurb": "The Balkans and Anatolia. An insurgency rises in the south-east.",
        "cities": {ST: ("Constantinople", 41.01, 28.98), "Insurgents": ("Diyarbakir", 37.91, 40.23)},
        "active": BALKANS + ANATOLIA,
        "claims": [
            {"nation": "Insurgents", "share": ANATOLIA, "dir": (1.0, 1.0), "fraction": 0.67},
            {"nation": ST, "boxes": BALKANS + ANATOLIA},
        ],
    },
    2: {
        "base": "byzantium", "name": "Ch. 2: Fire From the South",
        "blurb": "The Fundamentalists pour out of Arabia and Egypt.",
        "cities": {ST: ("Constantinople", 41.01, 28.98), "Fundamentalists": ("Tabuk", 28.38, 36.57)},
        "active": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT,
        "claims": [
            {"nation": ST, "boxes": BALKANS + ANATOLIA},
            {"nation": "Fundamentalists", "boxes": LEVANT_ARABIA + EGYPT},
        ],
    },
    3: {
        "base": "story_med", "name": "Ch. 3: The Puppet Masters",
        "blurb": "The Horde strikes from Russia, its Mercenaries from Libya.",
        "cities": {ST: ("Constantinople", 41.01, 28.98), "Horde": ("Moscow", 55.76, 37.62),
                   "Mercenaries": ("Tripoli", 32.89, 13.19)},
        "active": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT + RUSSIA_EUROPE + LIBYA,
        "claims": [
            {"nation": ST, "boxes": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT},
            {"nation": "Horde", "boxes": RUSSIA_EUROPE},
            {"nation": "Mercenaries", "boxes": LIBYA},
        ],
    },
    4: {
        "base": "story_med", "name": "Ch. 4: Appetite",
        "blurb": "Flush with victory, the State Troops turn on the Coalition.",
        "cities": {ST: ("Constantinople", 41.01, 28.98), "Coalition Army": ("Brussels", 50.85, 4.35)},
        "active": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT + LIBYA + CAUCASUS_RU + EU,
        "minus_active": UK + SWITZERLAND,
        "claims": [
            {"nation": ST, "boxes": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT + LIBYA + CAUCASUS_RU},
            {"nation": "Coalition Army", "boxes": EU, "minus": UK + SWITZERLAND},
        ],
    },
    5: {
        "base": "world", "name": "Ch. 5: The World Against Us",
        "blurb": "Everyone left alive unites against the State Troops.",
        "cities": {ST: ("Constantinople", 41.01, 28.98), "Horde": ("Moscow", 55.76, 37.62),
                   "Corporate Troops": ("San Francisco", 37.77, -122.42), "Peace Keepers": ("Rio de Janeiro", -22.91, -43.17),
                   "Insurgents": ("London", 51.51, -0.13)},
        "active": None,                       # the whole world...
        "minus_active": ANTARCTICA,           # ...bar the ice
        "claims": [
            {"nation": "Insurgents", "boxes": NW_CORNER},
            {"nation": ST, "boxes": BALKANS + ANATOLIA + ARABIA_FULL + EGYPT_FULL + LIBYA + CAUCASUS_RU + EU,
             "minus": UK + SWITZERLAND},
            {"nation": "Horde", "boxes": _WORLD_CLAIMS["Horde"]},
            {"nation": "Corporate Troops", "boxes": _WORLD_CLAIMS["Corporate Troops"]},
        ],
        "rest": "Peace Keepers",
    },
}


def in_boxes(boxes, lat, lon):
    lon = MW.norm_lon(lon)
    return any(a <= lat <= b and c <= lon <= d for (a, b, c, d) in boxes)


def base_spec(base):
    if base == "story_med":
        spec = copy.deepcopy(STORY_MED)
    else:
        spec = copy.deepcopy(MW.MAPS[base])
        spec.pop("claims", None)
        spec.pop("seeds", None)
    return spec


def build_chapter(n, polys):
    ch = CHAPTERS[n]
    spec = base_spec(ch["base"])
    spec["name"] = ch["name"]
    spec["blurb"] = ch["blurb"]
    spec["cities"] = ch["cities"]
    map_id = "story_%d" % n
    data = MW.build(map_id, spec, polys)
    g = MW.Grid(spec)
    W, H = g.W, g.H
    rows = data["rows"]
    names = [nd["name"] for nd in data["nations"]]
    land = {(x, y) for y in range(H) for x in range(W) if rows[y][x] != "."}
    ll = {(x, y): g.center(x, y) for y in range(H) for x in range(W)}

    def active(h):
        lat, lon = ll[h]
        if ch.get("active") is not None and not in_boxes(ch["active"], lat, lon):
            return False
        return not in_boxes(ch.get("minus_active", []), lat, lon)

    owner = {}
    for claim in ch["claims"]:
        nation = claim["nation"]
        if "share" in claim:
            cand = [h for h in land if h not in owner and active(h) and in_boxes(claim["share"], *ll[h])]
            lats = [ll[h][0] for h in cand]
            lons = [MW.norm_lon(ll[h][1]) for h in cand]
            dx, dy = claim["dir"]

            def score(h):
                lat, lon = ll[h]
                fx = (MW.norm_lon(lon) - min(lons)) / max(max(lons) - min(lons), 1e-6)
                fy = (max(lats) - lat) / max(max(lats) - min(lats), 1e-6)
                return fx * dx + fy * dy
            cand.sort(key=score, reverse=True)
            for h in cand[:int(round(len(cand) * claim["fraction"]))]:
                owner[h] = nation
            continue
        for h in land:
            if h in owner or not active(h):
                continue
            lat, lon = ll[h]
            if in_boxes(claim["boxes"], lat, lon) and not in_boxes(claim.get("minus", []), lat, lon):
                owner[h] = nation
    # unclaimed land in play: the "rest" nation, else the nearest claimant by land
    leftover = [h for h in land if h not in owner and active(h)]
    if ch.get("rest"):
        for h in leftover:
            owner[h] = ch["rest"]
    else:
        queue = list(owner.keys())
        head = 0
        while head < len(queue):
            cur = queue[head]
            head += 1
            for nb in g.neighbors(*cur):
                if nb in land and nb not in owner and active(nb):
                    owner[nb] = owner[cur]
                    queue.append(nb)
    # capitals: the owned hex nearest the real city
    for nd in data["nations"]:
        city, lat, lon = ch["cities"][nd["name"]]
        mine = [h for h, o in owner.items() if o == nd["name"]]
        if not mine:
            raise SystemExit("chapter %d: %s owns no land" % (n, nd["name"]))

        def geo_d(h):
            hlat, hlon = ll[h]
            dlon2 = (hlon - lon + 180.0) % 360.0 - 180.0
            return math.hypot(hlat - lat, dlon2 * math.cos(math.radians(lat)))
        best = min(mine, key=geo_d)
        nd["x"], nd["y"] = best
    # anything not in play (and not owned) is greyed out
    data["start_owner"] = ["".join(str(names.index(owner[(x, y)])) if (x, y) in owner else "." for x in range(W)) for y in range(H)]
    data["void"] = ["".join("." if ((x, y) in owner or (active((x, y)) and (x, y) not in land)) else "x" for x in range(W)) for y in range(H)]
    data["story_chapter"] = n
    with open(os.path.join(MW.OUT_DIR, map_id + ".json"), "w") as f:
        json.dump(data, f, indent=1)
    counts = {nm: sum(1 for o in owner.values() if o == nm) for nm in names}
    print("story_%d  %s" % (n, ", ".join("%s %d" % kv for kv in counts.items())))
    return data


def main(args):
    polys = MW.load_polys()
    for n in [int(a) for a in args] or sorted(CHAPTERS):
        build_chapter(n, polys)


if __name__ == "__main__":
    main(sys.argv[1:])
