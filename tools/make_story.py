#!/usr/bin/env python3
"""Generate the State Troops story campaign maps (Assets/Maps/story_<n>.json).

Each chapter gets its own map file, built on the terrain of a normal map
(make_world.build) and extended with:

  "start_owner": rows of one char per hex: the index (0-9) of the nation in
                 "nations" that owns it at the start of the chapter, or "."
  "void":        rows of one char per hex: "x" = outside this chapter's war
                 (drawn greyed out, never owned or entered), "." = in play

  "extras":      cards placed on top of every nation's default starting cards
                 when the chapter starts (see EXTRAS_HELP below)

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
# Georgia, Armenia and Azerbaijan up to the Caucasus ridge: from chapter 3 on the State
# Troops hold it, so their land meets the Horde's North Caucasus on the ground.
TRANSCAUCASUS = [(39.0, 43.3, 40.0, 50.0)]
EU = [(36.0, 43.8, -9.6, 3.4), (42.3, 51.2, -5.0, 6.0), (47.8, 49.0, 6.0, 8.3), (49.0, 55.1, 2.5, 15.0),
      (47.3, 49.0, 6.0, 15.0), (46.4, 49.0, 9.5, 17.2), (36.5, 46.4, 6.6, 18.6), (49.0, 55.0, 12.0, 24.1),
      (45.8, 49.0, 15.0, 22.0), (54.0, 59.7, 21.0, 28.2), (55.3, 69.1, 11.0, 31.6), (54.5, 57.8, 8.0, 12.7),
      (51.4, 55.4, -10.6, -5.9)]
UK = [(49.9, 61.0, -8.3, 1.8)]
SWITZERLAND = [(45.8, 47.8, 5.9, 10.5)]
NW_CORNER = UK + [(48.4, 51.1, -5.2, 3.6)]           # Britain and northern France
ANTARCTICA = [(-90.0, -58.0, -180.0, 180.0)]

_WORLD_CLAIMS = {c[0]: c[1] for c in MW.MAPS["world"]["claims"]}

# Extra frames for the other factions' campaigns, at the same hex scale as Europe
# (about 1.4 degrees of longitude per hex, 0.74 of latitude per row).
STEPPE = {"grid": (34, 38), "lon": (44.0, 92.0), "lat": (56.0, 28.0), "wraps": False, "regional": True}  # Central Asia
SAHEL = {"grid": (50, 35), "lon": (-18.0, 52.0), "lat": (26.0, 0.0), "wraps": False, "regional": True}  # Sahel, Sudan, Horn

# A "Europe & Mediterranean" frame at the Europe map's hex scale, reaching south
# to Libya and Egypt and east to the Caucasus (the Europe map stops at 34N).
STORY_MED = {
    "grid": (46, 64), "lon": (-12.0, 52.0), "lat": (71.0, 24.0), "wraps": False, "regional": True,
}

ST = "State Troops"
ISTANBUL = (41.01, 28.98)
TRABZON = (41.00, 39.72)

# EXTRAS_HELP: {"nation", "card", "count", "hp" (optional: start damaged), "id"
# (optional: name this placement so a later one can stand next to it), "at": ...}
#   {"random": True}                 anywhere in the nation's land
#   {"random_in": boxes}             anywhere in its land inside these lat/lon boxes
#   {"near": (lat, lon)}             the free hexes of its land nearest that point
#   {"border": nation}               random hexes of its land touching that nation
#   {"border": nation, "middle": True}  the hex in the middle of that border
#                                    (+ "room": n: nearest the middle with n free hexes beside it)
#   {"next_to": id}                  free hexes beside an earlier placement
#   ...any of them + "terrain": "mountain"  only on hexes of that terrain
# Placement happens in the game (MapWar.place_extras), so "random" differs per play.
def ex(nation, card, count, at, hp=None, id=None):
    d = {"nation": nation, "card": card, "count": count, "at": at}
    if hp is not None:
        d["hp"] = hp
    if id is not None:
        d["id"] = id
    return d


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
        "extras": [
            ex("Insurgents", "Infantry", 8, {"random": True, "terrain": "mountain"}),  # dug in: 1 less damage per hit
            ex(ST, "Housing", 2, {"near": ISTANBUL}),
            ex(ST, "Housing", 2, {"border": "Insurgents"}, hp=10),
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
        "extras": [
            ex("Fundamentalists", "Barracks", 4, {"random": True}),
            ex(ST, "Infantry", 2, {"border": "Fundamentalists"}),
        ],
    },
    3: {
        "base": "story_med", "name": "Ch. 3: The Puppet Masters",
        "blurb": "The Horde strikes from Russia, its Mercenaries from Libya.",
        "cities": {ST: ("Constantinople", 41.01, 28.98), "Horde": ("Moscow", 55.76, 37.62),
                   "Mercenaries": ("Tripoli", 32.89, 13.19)},
        "active": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT + TRANSCAUCASUS + RUSSIA_EUROPE + LIBYA,
        "claims": [
            {"nation": ST, "boxes": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT + TRANSCAUCASUS},
            {"nation": "Horde", "boxes": RUSSIA_EUROPE},
            {"nation": "Mercenaries", "boxes": LIBYA},
        ],
        "extras": [
            ex("Horde", "Tank", 2, {"random_in": CAUCASUS_RU}),
            ex("Horde", "Special Ops", 2, {"random_in": CAUCASUS_RU}),
            # a Barracks in the middle of Libya's eastern border, an Artilery either side of it
            ex("Mercenaries", "Barracks", 1, {"border": ST, "middle": True, "room": 2}, id="merc_barracks"),
            ex("Mercenaries", "Artilery", 2, {"next_to": "merc_barracks"}),
            ex(ST, "Housing", 3, {"near": ISTANBUL}),
            ex(ST, "Factory", 2, {"near": TRABZON}),
        ],
    },
    4: {
        "base": "story_med", "name": "Ch. 4: Appetite",
        "blurb": "Flush with victory, the State Troops turn on the Coalition.",
        "cities": {ST: ("Constantinople", 41.01, 28.98), "Coalition Army": ("Brussels", 50.85, 4.35)},
        "active": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT + LIBYA + TRANSCAUCASUS + CAUCASUS_RU + EU,
        "minus_active": UK + SWITZERLAND,
        "claims": [
            {"nation": ST, "boxes": BALKANS + ANATOLIA + LEVANT_ARABIA + EGYPT + LIBYA + TRANSCAUCASUS + CAUCASUS_RU},
            {"nation": "Coalition Army", "boxes": EU, "minus": UK + SWITZERLAND},
        ],
        # Britain is outside the EU war, so the "London" Corporation stands on the
        # Coalition hex nearest London, across the Channel.
        "extras": [
            ex("Coalition Army", "Corporation", 1, {"near": (51.51, -0.13)}, id="corp_london"),
            ex("Coalition Army", "Interceptor", 1, {"next_to": "corp_london"}, id="icp_london"),
            ex("Coalition Army", "Fighter Jet", 1, {"next_to": "icp_london"}),
            ex("Coalition Army", "Corporation", 1, {"near": (52.52, 13.40)}, id="corp_berlin"),
            ex("Coalition Army", "Interceptor", 1, {"next_to": "corp_berlin"}, id="icp_berlin"),
            ex("Coalition Army", "Fighter Jet", 1, {"next_to": "icp_berlin"}),
            ex("Coalition Army", "Corporation", 1, {"near": (48.86, 2.35)}, id="corp_paris"),
            ex("Coalition Army", "Interceptor", 1, {"next_to": "corp_paris"}, id="icp_paris"),
            ex("Coalition Army", "Fighter Jet", 1, {"next_to": "icp_paris"}),
            ex(ST, "Tank", 2, {"near": ISTANBUL}),
            ex(ST, "Artilery", 2, {"near": ISTANBUL}),
            ex(ST, "Housing", 2, {"near": ISTANBUL}),
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
            {"nation": ST, "boxes": BALKANS + ANATOLIA + ARABIA_FULL + EGYPT_FULL + LIBYA + TRANSCAUCASUS + CAUCASUS_RU + EU,
             "minus": UK + SWITZERLAND},
            {"nation": "Horde", "boxes": _WORLD_CLAIMS["Horde"]},
            {"nation": "Corporate Troops", "boxes": _WORLD_CLAIMS["Corporate Troops"]},
        ],
        "rest": "Peace Keepers",
    },
}


FRAMES = {"story_med": STORY_MED, "steppe": STEPPE, "sahel": SAHEL}

# ------------------------------------------------------------ other campaigns
# Seven more campaigns tell the rest of the story around the State Troops' war
# (see scripts/story_text.gd for the words and CHRONICLE for the order). Every
# chapter's war covers exactly the land its winner ends up with, so the player's
# victory is always the version of events the other campaigns build on.
CO, HO, CA, FU, ME, IN, PK = "Corporate Troops", "Horde", "Coalition Army", "Fundamentalists", "Mercenaries", "Insurgents", "Peace Keepers"
CAMPAIGN_CHAPTERS = {
    "corporate": [
        {   # Act I: the Corporate Troops take Mexico from the Peace Keepers
            "base": "north_america", "name": "Market Share", "blurb": "The Corporate Troops push the Peace Keepers out of Mexico.",
            "cities": {CO: ("New York", 40.71, -74.01), PK: ("Mexico City", 19.43, -99.13)},
            "active": [(14.0, 49.5, -125.0, -66.0)],
            "claims": [{"nation": CO, "boxes": [(30.5, 49.5, -125.0, -66.0), (25.0, 30.5, -85.0, -79.0)]}],
            "rest": PK,
        },
        {   # Act I: Alaska, taken from the Horde
            "base": "bering_strait", "name": "The Cold Rush", "blurb": "Oil under the tundra, and the Horde already camped on it.",
            "cities": {CO: ("Anchorage", 61.22, -149.90), HO: ("Nome", 64.50, -165.41)},
            "active": [(51.0, 72.0, -170.0, -140.0)],
            "claims": [{"nation": HO, "boxes": [(51.0, 72.0, -170.0, -157.0)]}],
            "rest": CO,
        },
        {   # Act I: the Gulf contractors mutiny and are thrown out (they turn up in Egypt next)
            "base": "north_america", "name": "Hostile Contractors", "blurb": "The Corporate Troops' own Mercenaries seize the Gulf Coast.",
            "cities": {CO: ("Atlanta", 33.75, -84.39), ME: ("Houston", 29.76, -95.37)},
            "active": [(29.0, 40.0, -110.0, -80.0), (25.8, 29.0, -100.0, -89.0)],
            "claims": [{"nation": ME, "boxes": [(29.0, 36.5, -103.0, -89.0), (25.8, 29.0, -100.0, -93.5), (29.0, 33.0, -106.6, -103.0)]}],
            "rest": CO,
        },
    ],
    "horde": [
        {   # Act I: East China, taken from the Peace Keepers
            "base": "east_asia", "name": "Steppe Fire", "blurb": "The Horde rides south out of Mongolia.",
            "cities": {HO: ("Ulaanbaatar", 47.92, 106.92), PK: ("Beijing", 39.90, 116.40)},
            "active": [(41.5, 54.0, 88.0, 135.0), (18.0, 41.5, 98.0, 123.0)],
            "claims": [{"nation": HO, "boxes": [(41.5, 54.0, 88.0, 135.0)]}],
            "rest": PK,
        },
        {   # Act II: Central Asia's Insurgents are beaten, then bought, and sent west
            "base": "steppe", "name": "Bought, Not Broken", "blurb": "The Insurgents of the southern mountains defy the Horde.",
            "cities": {HO: ("Astana", 51.17, 71.43), IN: ("Kabul", 34.53, 69.17)},
            "active": [(35.0, 56.0, 46.0, 82.0), (29.5, 38.5, 60.5, 75.0)],
            "claims": [{"nation": HO, "boxes": [(45.5, 56.0, 46.0, 82.0)]}],
            "rest": IN,
        },
        {   # Act IV: while the Horde licks its wounds, the Corporate Troops try for Chukotka
            "base": "bering_strait", "name": "Wolves at the Strait", "blurb": "The Corporate Troops land on the Horde's side of the strait.",
            "cities": {HO: ("Magadan", 59.56, 150.80), CO: ("Provideniya", 64.42, -173.23)},
            "active": [(50.0, 72.0, 145.0, 180.0), (50.0, 72.0, -180.0, -169.5)],
            "claims": [{"nation": CO, "boxes": [(63.0, 68.5, 178.0, 180.0), (63.0, 68.5, -180.0, -169.5)]}],
            "rest": HO,
        },
    ],
    "coalition": [
        {   # Act I: the Horde is pushed back to Russia's borders
            "base": "europe", "name": "The Eastern Wall", "blurb": "Old Europe unites to stop the Horde at the Vistula.",
            "cities": {CA: ("Berlin", 52.52, 13.40), HO: ("Minsk", 53.90, 27.57)},
            "active": [(47.0, 60.0, 5.0, 40.0)],
            "minus_active": SWITZERLAND,
            "claims": [{"nation": HO, "boxes": [(47.0, 60.0, 23.5, 40.0)]}],
            "rest": CA,
        },
        {   # Act II: Mercenary raiders from Tunisia land in Sicily
            "base": "europe", "name": "Sicilian Vespers", "blurb": "Mercenary raiders land in Sicily and the south of Italy.",
            "cities": {CA: ("Rome", 41.90, 12.50), ME: ("Palermo", 38.12, 13.36)},
            "active": [(36.5, 46.4, 6.6, 18.6), (38.8, 43.1, 8.0, 10.0)],
            "minus_active": SWITZERLAND,
            "claims": [{"nation": ME, "boxes": [(36.5, 41.4, 13.6, 18.6), (38.8, 41.3, 8.0, 10.0)]}],
            "rest": CA,
        },
        {   # Act II: the Corporate Troops' British subsidiaries are thrown out
            "base": "british_isles", "name": "The Channel Trade War", "blurb": "The Corporate Troops' factories in the north refuse the Coalition's embargo.",
            "cities": {CA: ("London", 51.51, -0.13), CO: ("Manchester", 53.48, -2.24)},
            "active": [(49.8, 59.5, -11.0, 3.0)],
            "minus_active": [(49.8, 51.2, 1.4, 3.0)],
            "claims": [{"nation": CO, "boxes": [(53.0, 59.5, -8.0, 2.0)]}],
            "rest": CA,
        },
    ],
    "fundamentalists": [
        {   # Act II: the Insurgents are driven out of Mesopotamia, north into Anatolia
            "base": "byzantium", "name": "Between the Rivers", "blurb": "The Fundamentalists rise in Baghdad; the Insurgents hold the northern hills.",
            "cities": {FU: ("Baghdad", 33.31, 44.37), IN: ("Erbil", 36.19, 44.01)},
            "active": [(29.5, 37.4, 38.5, 48.0)],
            "claims": [{"nation": IN, "boxes": [(35.0, 37.4, 41.5, 48.0)]}],
            "rest": FU,
        },
        {   # Act II: the Levant, taken from the Peace Keepers
            "base": "byzantium", "name": "The Road to Damascus", "blurb": "The Peace Keepers stand between the Fundamentalists and the sea.",
            "cities": {FU: ("Baghdad", 33.31, 44.37), PK: ("Damascus", 33.51, 36.29)},
            "active": [(27.0, 37.2, 34.2, 48.5)],
            "claims": [{"nation": PK, "boxes": [(29.0, 37.2, 34.2, 39.5)]}],
            "rest": FU,
        },
        {   # Act II: Egypt, taken from the Mercenaries (who move on to Libya)
            "base": "story_med", "name": "The Nile", "blurb": "The Mercenaries thrown out of America have dug in along the Nile.",
            "cities": {FU: ("Tabuk", 28.38, 36.57), ME: ("Cairo", 30.04, 31.24)},
            "active": [(24.0, 31.7, 24.9, 35.0), (24.0, 37.2, 34.2, 48.5)],
            "minus_active": ANATOLIA,
            "claims": [{"nation": ME, "boxes": [(24.0, 31.7, 24.9, 32.3)]}],
            "rest": FU,
        },
    ],
    "mercenaries": [
        {   # Act II: Libya, taken from the Peace Keepers
            "base": "story_med", "name": "Landing at Benghazi", "blurb": "Thrown out of Egypt, the Mercenaries need a new home. Libya will do.",
            "cities": {ME: ("Benghazi", 32.12, 20.07), PK: ("Tripoli", 32.89, 13.19)},
            "active": LIBYA,
            "claims": [{"nation": ME, "boxes": [(24.0, 33.5, 19.0, 24.9)]}],
            "rest": PK,
        },
        {   # Act II: a Horde-paid raid on the Coalition's Maghreb depots
            "base": "story_med", "name": "The Atlas Contract", "blurb": "The Horde pays the Mercenaries to burn the Coalition's African depots.",
            "cities": {ME: ("Tripoli", 32.89, 13.19), CA: ("Algiers", 36.75, 3.06)},
            "active": LIBYA + [(27.0, 37.5, -12.0, 11.6)],
            "claims": [{"nation": ME, "boxes": LIBYA}],
            "rest": CA,
        },
        {   # Act III: after the Fundamentalists fall, their remnants hold the Fezzan
            "base": "story_med", "name": "Desert Recruiting", "blurb": "Fundamentalist stragglers have dug into the Libyan desert.",
            "cities": {ME: ("Tripoli", 32.89, 13.19), FU: ("Sabha", 27.04, 14.43)},
            "active": LIBYA,
            "claims": [{"nation": FU, "boxes": [(24.0, 28.5, 9.6, 24.9)]}],
            "rest": ME,
        },
    ],
    "insurgents": [
        {   # Act II: the Insurgents take south-eastern Anatolia from the State Troops (State chapter 1's start)
            "base": "byzantium", "name": "The Mountains Rise", "blurb": "Driven out of Mesopotamia, the Insurgents come down from the Anatolian hills.",
            "cities": {IN: ("Hakkari", 37.57, 43.74), "State Troops": ("Diyarbakir", 37.91, 40.23)},
            "active": ANATOLIA,
            "claims": [
                {"nation": IN, "band": ANATOLIA, "dir": (1.0, 1.0), "range": (0.0, 0.12)},
                {"nation": "State Troops", "band": ANATOLIA, "dir": (1.0, 1.0), "range": (0.12, 0.67)},
            ],
            "unclaimed": "void",
        },
        {   # Act IV: after the Coalition falls, its loyalists hold Britain; the Insurgents land in the Highlands
            "base": "british_isles", "name": "Highlands", "blurb": "The Coalition is gone. Its loyalists still hold Britain.",
            "cities": {IN: ("Inverness", 57.48, -4.22), CA: ("London", 51.51, -0.13)},
            "active": [(49.8, 59.5, -11.0, 3.0)],
            "minus_active": [(49.8, 51.2, 1.4, 3.0)],
            "claims": [{"nation": IN, "boxes": [(56.4, 59.5, -8.0, 0.0)]}],
            "rest": CA,
        },
        {   # Act IV: northern France, taken from the State Troops (State chapter 5's start)
            "base": "europe", "name": "Across the Channel", "blurb": "Britain is free. The State Troops' garrisons in France are next.",
            "cities": {IN: ("London", 51.51, -0.13), "State Troops": ("Paris", 48.86, 2.35)},
            "active": NW_CORNER,
            "claims": [{"nation": IN, "boxes": UK}],
            "rest": "State Troops",
        },
    ],
    "peacekeepers": [
        {   # Act II: Insurgent cells in Indochina
            "base": "east_asia", "name": "The Blue Helmets", "blurb": "Insurgent cells spread through the jungles of Indochina.",
            "cities": {PK: ("Bangkok", 13.75, 100.50), IN: ("Hanoi", 21.03, 105.85)},
            "active": [(8.0, 23.5, 97.0, 110.0)],
            "claims": [{"nation": IN, "boxes": [(17.0, 23.5, 100.0, 110.0)]}],
            "rest": PK,
        },
        {   # Act III: Fundamentalist remnants in Sudan
            "base": "sahel", "name": "Desert Mandate", "blurb": "The last Fundamentalists flee up the Nile into Sudan.",
            "cities": {PK: ("Addis Ababa", 9.03, 38.74), FU: ("Khartoum", 15.50, 32.56)},
            "active": [(3.0, 22.0, 21.8, 52.0)],
            "claims": [{"nation": FU, "boxes": [(12.0, 22.0, 21.8, 38.5)]}],
            "rest": PK,
        },
        {   # Act IV: Mercenary remnants in the Sahel; the world unites
            "base": "sahel", "name": "The Last Contract", "blurb": "Unpaid Mercenaries hold the Sahel. Then the world must choose a side.",
            "cities": {PK: ("Abuja", 9.08, 7.40), ME: ("Agadez", 16.97, 7.99)},
            "active": [(4.0, 26.0, -18.0, 24.0)],
            "claims": [{"nation": ME, "boxes": [(14.0, 26.0, 0.0, 24.0)]}],
            "rest": PK,
        },
    ],
}

# The State Troops' chapters keep their original ids (story_1..5).
ALL_CHAPTERS = {}
for _n, _ch in CHAPTERS.items():
    ALL_CHAPTERS["story_%d" % _n] = dict(_ch, campaign="state", chapter=_n)
for _cid, _chs in CAMPAIGN_CHAPTERS.items():
    for _i, _ch in enumerate(_chs):
        ALL_CHAPTERS["story_%s_%d" % (_cid, _i + 1)] = dict(_ch, campaign=_cid, chapter=_i + 1)

def in_boxes(boxes, lat, lon):
    lon = MW.norm_lon(lon)
    return any(a <= lat <= b and c <= lon <= d for (a, b, c, d) in boxes)


def base_spec(base):
    if base in FRAMES:
        spec = copy.deepcopy(FRAMES[base])
    else:
        spec = copy.deepcopy(MW.MAPS[base])
        spec.pop("claims", None)
        spec.pop("seeds", None)
    return spec


def build_chapter(map_id, polys):
    ch = ALL_CHAPTERS[map_id]
    n = ch["chapter"]
    spec = base_spec(ch["base"])
    spec["name"] = ch["name"]
    spec["blurb"] = ch["blurb"]
    spec["cities"] = ch["cities"]
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
        if "band" in claim:
            # a slice [lo, hi) of the whole region ordered along "dir" (owned hexes keep their owner)
            region = [h for h in land if active(h) and in_boxes(claim["band"], *ll[h])]
            lats = [ll[h][0] for h in region]
            lons = [MW.norm_lon(ll[h][1]) for h in region]
            dx, dy = claim["dir"]

            def bscore(h):
                lat, lon = ll[h]
                fx = (MW.norm_lon(lon) - min(lons)) / max(max(lons) - min(lons), 1e-6)
                fy = (max(lats) - lat) / max(max(lats) - min(lats), 1e-6)
                return (fx * dx + fy * dy, h)
            region.sort(key=bscore, reverse=True)
            lo, hi = claim["range"]
            for h in region[int(round(len(region) * lo)):int(round(len(region) * hi))]:
                owner.setdefault(h, nation)
            continue
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
    if ch.get("unclaimed") == "void":
        pass # the war is exactly what the claims cover: anything else is greyed out below
    elif ch.get("rest"):
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
    data["story_campaign"] = ch["campaign"]
    data["extras"] = ch.get("extras", [])
    with open(os.path.join(MW.OUT_DIR, map_id + ".json"), "w") as f:
        json.dump(data, f, indent=1)
    counts = {nm: sum(1 for o in owner.values() if o == nm) for nm in names}
    print("%-26s %s" % (map_id, ", ".join("%s %d" % kv for kv in counts.items())))
    return data


def main(args):
    polys = MW.load_polys()
    wanted = [("story_%s" % a if a.isdigit() else a) for a in args]
    for map_id in wanted or list(ALL_CHAPTERS):
        build_chapter(map_id, polys)


if __name__ == "__main__":
    main(sys.argv[1:])
