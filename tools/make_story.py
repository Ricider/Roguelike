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
#   turn=n (n > 1): a reinforcement, landing at the start of that nation's turn in round n
#   (MapWar.arrive_reinforcements; the Forces briefing lists every one in advance).
def ex(nation, card, count, at, hp=None, id=None, turn=None):
    d = {"nation": nation, "card": card, "count": count, "at": at}
    if hp is not None:
        d["hp"] = hp
    if id is not None:
        d["id"] = id
    if turn is not None:
        d["turn"] = turn
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

# ------------------------------------------------------------ chapter forces
# Every chapter after the tutorial is built around an asymmetry: the two sides
# start with different extra cards, different reinforcements on the way ("turn"),
# and sometimes different nation HP / Influence / Money ("setup", MapWar.apply_setup).
# "forces" is the briefing shown on the map when the chapter starts ([brackets]
# are highlighted); the map screen adds the list of reinforcements on the way.
#   setup: {nation: {"max_hp", "influence", "money", "bio"}}, absolute values; factions start
#   differently (State Troops 180 HP / 30 Influence, Horde 200 / 50, Corporate 70 / 60,
#   Peace Keepers 90 / 60, Insurgents 120 / 20, Coalition 120 / 80, Fundamentalists 150 / 40,
#   Mercenaries 130 / 40), so a "bonus" must beat those.
CAIRO, DAMASCUS, ADANA, KARS = (30.04, 31.24), (33.51, 36.29), (37.00, 35.32), (40.60, 43.10)
TRIPOLI, BENGHAZI, MOSCOW = (32.89, 13.19), (32.12, 20.07), (55.76, 37.62)
BRUSSELS, BERLIN, PARIS, LONDON = (50.85, 4.35), (52.52, 13.40), (48.86, 2.35), (51.51, -0.13)
NEW_YORK, HOUSTON, MEXICO_CITY, ATLANTA = (40.71, -74.01), (29.76, -95.37), (19.43, -99.13), (33.75, -84.39)
SAN_FRANCISCO = (37.77, -122.42)
ANCHORAGE, NOME, MAGADAN, PROVIDENIYA = (61.22, -149.90), (64.50, -165.41), (59.56, 150.80), (64.42, -173.23)
BEIJING, ULAANBAATAR, ASTANA, KABUL = (39.90, 116.40), (47.92, 106.92), (51.17, 71.43), (34.53, 69.17)
ROME, NAPLES, PALERMO, MANCHESTER = (41.90, 12.50), (40.85, 14.27), (38.12, 13.36), (53.48, -2.24)
BAGHDAD, ERBIL, TABUK, ALGIERS, SABHA = (33.31, 44.37), (36.19, 44.01), (28.38, 36.57), (36.75, 3.06), (27.04, 14.43)
DIYARBAKIR, INVERNESS, EDINBURGH, DOVER, CALAIS = (37.91, 40.23), (57.48, -4.22), (55.95, -3.19), (51.13, 1.31), (50.95, 1.86)
BANGKOK, HANOI, ADDIS_ABABA, KHARTOUM, ABUJA, AGADEZ = (13.75, 100.50), (21.03, 105.85), (9.03, 38.74), (15.50, 32.56), (9.08, 7.40), (16.97, 7.99)
RANDOM, MOUNTAIN = {"random": True}, {"random": True, "terrain": "mountain"}

FORCES = {
    # ---------------------------------------------------------------- State Troops
    "story_2": {   # many brittle zealots in waves vs. a dug-in line that is slow to get going
        "setup": {FU: {"max_hp": 80}},
        "extras": [
            ex(FU, "Barracks", 4, RANDOM),
            ex(FU, "Infantry", 6, {"border": ST}),
            ex(FU, "Infantry", 4, {"near": CAIRO}, turn=3),
            ex(ST, "Infantry", 2, {"border": FU}),
            ex(ST, "Wall", 3, {"border": FU}),
            ex(ST, "Artilery", 2, {"near": ADANA}),
            ex(ST, "Tank", 2, {"near": ADANA}, turn=4),
        ],
        "forces": {"title": "Zeal Against Discipline", "lines": [
            "The Fundamentalists come in [waves]: a crowd of Infantry on the border now, more marching up the Nile on turn 3. Their [Barracks] make every one of them hit harder.",
            "But zeal is brittle: their nation has only [80 HP]. Every Infantry you destroy costs them its BioCost, so a good killing ground breaks them fast.",
            "Your [Walls] are already on the border and your [Artilery] is in the hills above Adana. Hold the line, and when the [Tanks] arrive on turn 4, go south.",
        ]},
    },
    "story_3": {   # two fronts: a rich, patient Horde and fragile, well-equipped Mercenaries
        "setup": {HO: {"influence": 100}, ME: {"max_hp": 70}},
        "extras": [
            ex(HO, "Tank", 2, {"random_in": CAUCASUS_RU}),
            ex(HO, "Special Ops", 2, {"random_in": CAUCASUS_RU}),
            ex(HO, "Tank", 2, {"random_in": CAUCASUS_RU}, turn=3),
            ex(HO, "Rocket Launcher", 1, {"random_in": CAUCASUS_RU}, turn=3),
            # a Barracks in the middle of Libya's eastern border, an Artilery either side of it
            ex(ME, "Barracks", 1, {"border": ST, "middle": True, "room": 2}, id="merc_barracks"),
            ex(ME, "Artilery", 2, {"next_to": "merc_barracks"}),
            ex(ME, "Fighter Jet", 2, {"near": TRIPOLI}, turn=4),
            ex(ST, "Housing", 3, {"near": ISTANBUL}),
            ex(ST, "Factory", 2, {"near": TRABZON}),
            ex(ST, "Wall", 2, {"border": HO, "terrain": "mountain"}),
            ex(ST, "Anti Aircraft", 1, {"border": ME}, turn=4),
        ],
        "forces": {"title": "Two Fronts", "lines": [
            "The [Horde] is rich: it starts with [100 Influence] to spend and more armour coming through the Caucasus on turn 3. Your [Walls] hold the mountain passes. Make them pay for every hex.",
            "The [Mercenaries] are dangerous but fragile: only [70 HP], and they fight only while the money lasts. Their paid-up [Fighter Jets] land in Tripoli on turn 4.",
            "Knock the Mercenaries out first and you fight one war instead of two. An [Anti Aircraft] gun reaches the Libyan border on turn 4, just in time for those jets.",
        ]},
    },
    "story_4": {   # a fat, air-defended Coalition that mobilises late vs. a ground blitz
        "setup": {ST: {"influence": 70}},
        "extras": [
            # Britain is outside the EU war, so the "London" Corporation stands on the
            # Coalition hex nearest London, across the Channel.
            ex(CA, "Corporation", 1, {"near": LONDON}, id="corp_london"),
            ex(CA, "Interceptor", 1, {"next_to": "corp_london"}, id="icp_london"),
            ex(CA, "Fighter Jet", 1, {"next_to": "icp_london"}),
            ex(CA, "Corporation", 1, {"near": BERLIN}, id="corp_berlin"),
            ex(CA, "Interceptor", 1, {"next_to": "corp_berlin"}, id="icp_berlin"),
            ex(CA, "Fighter Jet", 1, {"next_to": "icp_berlin"}),
            ex(CA, "Corporation", 1, {"near": PARIS}, id="corp_paris"),
            ex(CA, "Interceptor", 1, {"next_to": "corp_paris"}, id="icp_paris"),
            ex(CA, "Fighter Jet", 1, {"next_to": "icp_paris"}),
            ex(CA, "Infantry", 3, {"near": BRUSSELS}, turn=4),
            ex(CA, "Anti Aircraft", 2, {"near": BRUSSELS}, turn=4),
            ex(CA, "Tank", 2, {"near": BERLIN}, turn=6),
            ex(ST, "Tank", 2, {"near": ISTANBUL}),
            ex(ST, "Artilery", 2, {"near": ISTANBUL}),
            ex(ST, "Housing", 2, {"near": ISTANBUL}),
            ex(ST, "Special Ops", 2, {"border": CA}),
        ],
        "forces": {"title": "Blitz", "lines": [
            "The Coalition's cities are rich and guarded from the air: an [Interceptor] beside each [Corporation] halves hits from anything with Range or wings. Your ground troops ignore that shield entirely.",
            "But the Coalition is slow to mobilise. Its army only turns up on [turn 4] and [turn 6]. Every hex you take before then is a hex they have to win back.",
            "You start with [70 Influence] and [Special Ops] on the border, who deal double damage to ground units. Strike before Brussels wakes up.",
        ]},
    },
    "story_5": {   # one empire against everyone: a big HP pool against waves from every side
        "setup": {ST: {"max_hp": 250, "influence": 80}},
        "extras": [
            ex(ST, "Factory", 2, {"near": ISTANBUL}),
            ex(ST, "Howitzer", 2, {"near": ISTANBUL}),
            ex(ST, "Wall", 3, {"border": IN}),
            ex(ST, "Anti Aircraft", 2, {"near": PARIS}),
            ex(IN, "Special Ops", 2, {"near": LONDON}),
            ex(IN, "Infantry", 2, {"near": LONDON}, turn=3),
            ex(HO, "Tank", 3, {"border": ST}),
            ex(HO, "Infantry", 4, {"border": ST}, turn=4),
            ex(CO, "Corporation", 2, {"near": NEW_YORK}),
            ex(CO, "Fighter Jet", 2, {"near": SAN_FRANCISCO}),
            ex(CO, "Drone", 3, {"near": NEW_YORK}, turn=3),
            ex(PK, "Infantry", 4, {"border": ST}),
            ex(PK, "Barracks", 2, {"border": ST}),
            ex(PK, "Infantry", 3, {"border": ST}, turn=5),
            ex(PK, "Rocket Launcher", 1, {"border": ST}, turn=5),
        ],
        "forces": {"title": "The World Against Us", "lines": [
            "An empire is hard to kill: you have [250 HP] and [80 Influence]. But every other army on Earth is coming, and each one keeps sending more.",
            "[Insurgent] saboteurs strike from Britain, [Horde] armour from the east, [Peace Keeper] waves from the south, and the [Corporate Troops'] jets and drones from across the Atlantic.",
            "You cannot hold everywhere. Pick the front that is closest to breaking and finish it, and every enemy you eliminate is one less wave.",
        ]},
    },
    # ---------------------------------------------------------------- Corporate Troops
    "story_corporate_1": {   # money and machines vs. a people's army
        "setup": {CO: {"influence": 120}, PK: {"max_hp": 120}},
        "extras": [
            ex(CO, "Drone", 2, {"border": PK}),
            ex(CO, "Factory", 1, {"near": HOUSTON}),
            ex(CO, "Corporation", 1, {"near": NEW_YORK}),
            ex(PK, "Infantry", 6, {"border": CO}),
            ex(PK, "Housing", 2, {"near": MEXICO_CITY}),
            ex(PK, "Barracks", 1, {"near": MEXICO_CITY}, turn=3),
        ],
        "forces": {"title": "Money Versus Numbers", "lines": [
            "You have the money: [120 Influence], a [Factory] in Houston and a [Corporation] that makes every card cheaper. Spend it.",
            "The Peace Keepers have the people: [120 HP], a wall of [Infantry] on the border and [Housing] around Mexico City to recruit more.",
            "Their Infantry can't dodge, but your [Drones] can: they take half damage from anything without Range. Buy machines, not men.",
        ]},
    },
    "story_corporate_2": {   # air power vs. a dug-in outpost with flak
        "setup": {HO: {"max_hp": 80}},
        "extras": [
            ex(CO, "Drone", 3, {"near": ANCHORAGE}),
            ex(CO, "Fighter Jet", 1, {"near": ANCHORAGE}),
            ex(CO, "Special Ops", 2, {"near": ANCHORAGE}, turn=3),
            ex(HO, "Infantry", 4, MOUNTAIN),
            ex(HO, "Anti Aircraft", 2, {"border": CO}),
        ],
        "forces": {"title": "Flak Over the Tundra", "lines": [
            "Your strike force flies: [Drones] and a [Fighter Jet] can cross anything and take half damage from troops without Range.",
            "But the Horde brought [Anti Aircraft] guns: triple damage to flying units, and no dodging. Fly into them and you will lose your air force on turn one.",
            "The outpost is small ([80 HP]). Use your planes on the Infantry dug into the mountains, and let the [Special Ops] team landing on turn 3 deal with the flak.",
        ]},
    },
    "story_corporate_3": {   # a strong early mutiny vs. an economy that wins the long game
        "setup": {ME: {"max_hp": 70, "money": 80}},
        "extras": [
            ex(ME, "Tank", 2, {"near": HOUSTON}),
            ex(ME, "Artilery", 2, {"near": HOUSTON}),
            ex(ME, "Interceptor", 1, {"near": HOUSTON}),
            ex(CO, "Factory", 2, {"near": ATLANTA}),
            ex(CO, "Wall", 2, {"border": ME}),
            ex(CO, "Howitzer", 2, {"near": ATLANTA}, turn=3),
        ],
        "forces": {"title": "Hostile Contractors", "lines": [
            "The Mercenaries walked off with your own kit: [Tanks], [Artilery] and an [Interceptor] in Houston, and [80 Money] in the bank. Their first turns will hurt.",
            "But nobody pays them any more. They have only [70 HP], and that Interceptor burns 6 Money every time it blocks.",
            "Your two [Factories] pay out every turn. Hold behind your [Walls], let your [Howitzers] arrive on turn 3, and outlast them.",
        ]},
    },
    # ---------------------------------------------------------------- Horde
    "story_horde_1": {   # a fast raiding horde vs. a Great Wall
        "setup": {PK: {"max_hp": 120}},
        "extras": [
            ex(HO, "Infantry", 6, {"border": PK}),
            ex(HO, "Drone", 2, {"near": ULAANBAATAR}),
            ex(HO, "Infantry", 4, {"border": PK}, turn=3),
            ex(PK, "Wall", 5, {"border": HO}),
            ex(PK, "Artilery", 2, {"near": BEIJING}),
        ],
        "forces": {"title": "The Great Wall", "lines": [
            "The Peace Keepers have rebuilt the Great Wall: [Walls] along the whole border, [Artilery] behind them in Beijing, and [120 HP].",
            "Your Infantry shoot the [closest target], and that will be a Wall. Hammering Walls wins nothing.",
            "Fly over them instead. [Drones] cross anything and hit the guns behind. Then walk round the Wall's ends with the second wave on turn 3.",
        ]},
    },
    "story_horde_2": {   # siege guns vs. mountain guerrillas who keep coming back
        "setup": {IN: {"max_hp": 70}},
        "extras": [
            ex(IN, "Infantry", 6, MOUNTAIN),
            ex(IN, "Special Ops", 2, MOUNTAIN),
            ex(IN, "Infantry", 3, MOUNTAIN, turn=4),
            ex(HO, "Artilery", 3, {"border": IN}),
            ex(HO, "Tank", 2, {"border": IN}),
            ex(HO, "Barracks", 1, {"border": IN}),
        ],
        "forces": {"title": "Siege in the Mountains", "lines": [
            "Every Insurgent stands on a [Mountain]: [1 less damage] from every hit. That ruins weapons that fire many small shots, like Rocket Launchers and Howitzers.",
            "Your big guns don't care as much: [Artilery] hits hard once. Line it up behind the [Barracks] for +2 damage a shot.",
            "Their [Special Ops] deal double damage to ground units, so keep your Tanks out of their reach. The Insurgents have only [70 HP], but more fighters come down from the valleys on turn 4.",
        ]},
    },
    "story_horde_3": {   # a tiny high-tech beachhead vs. the home army
        "setup": {CO: {"influence": 100}},
        "extras": [
            ex(CO, "Fighter Jet", 2, {"near": PROVIDENIYA}),
            ex(CO, "Interceptor", 1, {"near": PROVIDENIYA}),
            ex(CO, "Tank", 2, {"near": PROVIDENIYA}, turn=3),
            ex(CO, "Drone", 2, {"near": PROVIDENIYA}, turn=5),
            ex(HO, "Anti Aircraft", 3, {"border": CO}),
            ex(HO, "Housing", 2, {"near": MAGADAN}),
            ex(HO, "Infantry", 4, {"border": CO}),
        ],
        "forces": {"title": "The Beachhead", "lines": [
            "The Corporate Troops hold only a sliver of Chukotka, but they keep [landing more]: Tanks on turn 3, Drones on turn 5, and [100 Influence] to spend.",
            "Their beachhead is guarded by [Fighter Jets] and an [Interceptor]. Your [Anti Aircraft] guns are on the border: triple damage to anything that flies.",
            "Throw them back into the sea [before] the landings pile up.",
        ]},
    },
    # ---------------------------------------------------------------- Coalition Army
    "story_coalition_1": {   # hold the line, then counter-attack with air power
        "setup": {HO: {"influence": 90}},
        "extras": [
            ex(HO, "Tank", 4, {"border": CA}),
            ex(HO, "Infantry", 4, {"border": CA}),
            ex(CA, "Wall", 4, {"border": HO}),
            ex(CA, "Barracks", 2, {"border": HO}),
            ex(CA, "Interceptor", 1, {"near": BERLIN}),
            ex(CA, "Fighter Jet", 2, {"near": BERLIN}, turn=3),
        ],
        "forces": {"title": "Hold the Vistula", "lines": [
            "The Horde opens with [Tanks] and [Infantry] massed on the border and [90 Influence] for more. Everything they have shoots the [closest target].",
            "So give them something to shoot: your [Walls] stand in front, your [Barracks] behind them make every shot of yours +2.",
            "Hold for two turns. On [turn 3] the air wing reaches Berlin, and then you go east.",
        ]},
    },
    "story_coalition_2": {   # hit-and-run raiders vs. flak and garrisons
        "setup": {ME: {"max_hp": 80}},
        "extras": [
            ex(ME, "Special Ops", 3, RANDOM),
            ex(ME, "Drone", 2, {"near": PALERMO}),
            ex(ME, "Infantry", 2, {"near": PALERMO}, turn=3),
            ex(CA, "Anti Aircraft", 2, {"near": NAPLES}),
            ex(CA, "Infantry", 2, {"near": NAPLES}),
        ],
        "forces": {"title": "Raiders", "lines": [
            "The Mercenary raiders are [Special Ops], who deal double damage to ground units, and [Drones] that half-dodge your Infantry's shots.",
            "Your [Anti Aircraft] guns around Naples shred anything that flies. Let the Drones come to them.",
            "The raiders have only [80 HP], but more boats arrive from Tunis on turn 3. Use Walls and Tanks against the Special Ops, not Infantry.",
        ]},
    },
    "story_coalition_3": {   # a rich, growing economy vs. a strike-now army
        "setup": {CO: {"money": 60}},
        "extras": [
            ex(CO, "Factory", 3, {"near": MANCHESTER}),
            ex(CO, "Corporation", 1, {"near": MANCHESTER}),
            ex(CO, "Drone", 2, {"near": MANCHESTER}),
            ex(CO, "Fighter Jet", 2, {"near": MANCHESTER}, turn=4),
            ex(CO, "Tank", 2, {"near": MANCHESTER}, turn=6),
            ex(CA, "Infantry", 3, {"border": CO}),
            ex(CA, "Tank", 2, {"border": CO}),
        ],
        "forces": {"title": "The Clock Is Ticking", "lines": [
            "The Corporate Troops' north is [factories]: three of them plus a [Corporation], all paying out every single turn.",
            "Right now they have almost no army. On [turn 4] the jets roll out, on [turn 6] the tanks.",
            "Every turn you wait, they get richer. Your [Infantry] and [Tanks] are already on the border: [strike now].",
        ]},
    },
    # ---------------------------------------------------------------- Fundamentalists
    "story_fundamentalists_1": {   # a flood of zealots vs. a few hill fighters
        "setup": {IN: {"max_hp": 80}},
        "extras": [
            ex(FU, "Infantry", 6, {"border": IN}),
            ex(FU, "Barracks", 2, {"border": IN}),
            ex(IN, "Infantry", 4, MOUNTAIN),
            ex(IN, "Wall", 2, {"border": FU}),
            ex(IN, "Special Ops", 1, MOUNTAIN, turn=3),
        ],
        "forces": {"title": "The Flood", "lines": [
            "You have [numbers]: a crowd of Infantry on the border, with [Barracks] behind them for +2 damage a shot.",
            "The Insurgents have [the hills]: Infantry on mountains take 1 less damage per hit, and [Walls] soak up your first volleys.",
            "Weight of fire beats cover. Pile shots onto one dug-in fighter at a time. They have only [80 HP].",
        ]},
    },
    "story_fundamentalists_2": {   # a ground army with flak vs. air-backed peacekeepers
        "setup": {PK: {"influence": 100}},
        "extras": [
            ex(PK, "Interceptor", 2, {"near": DAMASCUS}),
            ex(PK, "Fighter Jet", 2, {"near": DAMASCUS}),
            ex(PK, "Wall", 2, {"border": FU}),
            ex(FU, "Anti Aircraft", 3, {"border": PK}),
            ex(FU, "Infantry", 4, {"border": PK}),
            ex(FU, "Rocket Launcher", 2, {"near": BAGHDAD}, turn=3),
        ],
        "forces": {"title": "Guns Against Wings", "lines": [
            "The Peace Keepers fight from the air: [Fighter Jets] over Damascus, and [Interceptors] that halve hits from Range or wings.",
            "You fight on the ground. Your [Anti Aircraft] guns deal triple damage to their jets, and your [Infantry] have no Range, so the Interceptors can't stop them.",
            "Your [Rocket Launchers] arrive on turn 3, but they have Range, so aim them away from the Interceptors.",
        ]},
    },
    "story_fundamentalists_3": {   # a wave assault vs. heavy guns that cost a fortune
        "setup": {ME: {"max_hp": 80, "money": 60}},
        "extras": [
            ex(ME, "Howitzer", 2, {"near": CAIRO}),
            ex(ME, "Tank", 2, {"near": CAIRO}),
            ex(ME, "Barracks", 1, {"near": CAIRO}),
            ex(FU, "Infantry", 4, {"border": ME}),
            ex(FU, "Special Ops", 2, {"border": ME}),
            ex(FU, "Infantry", 4, {"border": ME}, turn=3),
        ],
        "forces": {"title": "Across the Sinai", "lines": [
            "The Mercenaries hold the Nile with [Howitzers] and [Tanks]: four shots a turn from each Howitzer.",
            "But Howitzer shots are [light] and land at random. Spread your troops and the guns waste their fire.",
            "Your [Special Ops] deal double damage to their Tanks. A second wave crosses the Sinai on turn 3. The Mercenaries have only [80 HP].",
        ]},
    },
    # ---------------------------------------------------------------- Mercenaries
    "story_mercenaries_1": {   # a small, rich landing force vs. a big, poor defender
        "setup": {ME: {"influence": 100}, PK: {"max_hp": 120}},
        "extras": [
            ex(ME, "Tank", 2, {"near": BENGHAZI}),
            ex(ME, "Infantry", 2, {"near": BENGHAZI}),
            ex(PK, "Infantry", 4, RANDOM),
            ex(PK, "Housing", 2, {"near": TRIPOLI}),
            ex(PK, "Artilery", 2, {"near": TRIPOLI}, turn=4),
        ],
        "forces": {"title": "The War Chest", "lines": [
            "You landed with little land but a fat [war chest]: [100 Influence] to spend in the Shop from turn one.",
            "The Peace Keepers hold the rest of Libya with [120 HP] and Infantry scattered across the desert. [Artilery] reaches Tripoli on turn 4.",
            "Buy hard, hit fast. Every hex you take pays more Influence.",
        ]},
    },
    "story_mercenaries_2": {   # a raid on depots: targets that pay vs. an air-defended coast
        "setup": {ME: {"influence": 80}},
        "extras": [
            ex(CA, "Factory", 4, RANDOM),
            ex(CA, "Interceptor", 2, {"near": ALGIERS}),
            ex(CA, "Infantry", 3, {"border": ME}),
            ex(ME, "Fighter Jet", 2, {"near": TRIPOLI}),
            ex(ME, "Drone", 2, {"near": TRIPOLI}),
            ex(ME, "Special Ops", 2, {"border": CA}, turn=3),
        ],
        "forces": {"title": "The Atlas Contract", "lines": [
            "The Coalition's African [depots] are four [Factories] scattered across the Maghreb, each one paying them 15 Money a turn. Burn them and their army starves.",
            "You have wings: [Fighter Jets] and [Drones] fly straight over the desert. Keep them away from Algiers, where [Interceptors] halve their hits.",
            "[Special Ops] reach the border on turn 3 to deal with the Infantry.",
        ]},
    },
    "story_mercenaries_3": {   # firepower vs. stragglers who keep coming back
        "setup": {FU: {"max_hp": 70}},
        "extras": [
            ex(FU, "Infantry", 5, RANDOM),
            ex(FU, "Wall", 2, {"near": SABHA}),
            ex(FU, "Infantry", 3, RANDOM, turn=3),
            ex(FU, "Infantry", 3, RANDOM, turn=5),
            ex(ME, "Tank", 2, {"border": FU}),
            ex(ME, "Rocket Launcher", 2, {"border": FU}),
        ],
        "forces": {"title": "Desert Recruiting", "lines": [
            "The Fundamentalist stragglers are [scattered] across the dunes, and more keep wandering in: on turn 3 and turn 5.",
            "Your [Rocket Launchers] fire four shots a turn at random targets of the nearest enemy: perfect for picking off scattered Infantry.",
            "They have only [70 HP]. Finish them before the stragglers regroup.",
        ]},
    },
    # ---------------------------------------------------------------- Insurgents
    "story_insurgents_1": {   # a tiny guerrilla force that grows vs. a big army
        "setup": {IN: {"max_hp": 80}},
        "extras": [
            ex(IN, "Special Ops", 2, MOUNTAIN),
            ex(IN, "Infantry", 3, MOUNTAIN),
            ex(IN, "Infantry", 3, MOUNTAIN, turn=2),
            ex(IN, "Special Ops", 2, MOUNTAIN, turn=4),
            ex(ST, "Tank", 2, {"border": IN}),
            ex(ST, "Wall", 2, {"border": IN}),
            ex(ST, "Housing", 2, {"near": DIYARBAKIR}),
        ],
        "forces": {"title": "The Hills Answer", "lines": [
            "You start with a handful of hexes and [80 HP]. The State Troops have [180 HP], [Tanks] and [Walls].",
            "But the hills are yours. Your fighters stand on [Mountains] (1 less damage per hit), and [Special Ops] deal double damage to Tanks.",
            "Every few turns more volunteers come down from the hills: on turn 2 and turn 4. Survive the first blows, then grow.",
        ]},
    },
    "story_insurgents_2": {   # captured flak vs. the loyalists' air force
        "setup": {CA: {"max_hp": 80}},
        "extras": [
            ex(IN, "Infantry", 3, MOUNTAIN),
            ex(IN, "Barracks", 1, {"near": INVERNESS}),
            ex(IN, "Anti Aircraft", 2, {"near": INVERNESS}, turn=3),
            ex(CA, "Fighter Jet", 2, {"near": LONDON}),
            ex(CA, "Interceptor", 2, {"near": LONDON}),
            ex(CA, "Wall", 2, {"near": EDINBURGH}),
        ],
        "forces": {"title": "Highlands", "lines": [
            "The Coalition loyalists still have their [Fighter Jets] and [Interceptors] around London, and Walls at Edinburgh.",
            "They have only [80 HP] and no reinforcements coming. You have the Highlands, a [Barracks] and, from turn 3, captured [Anti Aircraft] guns.",
            "Let the jets come north into the flak, then march south.",
        ]},
    },
    "story_insurgents_3": {   # an assault across the sea vs. coastal forts
        "extras": [
            ex(IN, "Artilery", 2, {"near": DOVER}),
            ex(IN, "Rocket Launcher", 2, {"near": DOVER}),
            ex(IN, "Drone", 2, {"near": LONDON}),
            ex(IN, "Fighter Jet", 2, {"near": LONDON}, turn=3),
            ex(ST, "Wall", 3, {"near": CALAIS}),
            ex(ST, "Howitzer", 2, {"near": PARIS}),
        ],
        "forces": {"title": "Across the Channel", "lines": [
            "The Channel is between you. Ground troops can't walk across it, so this fight is won by [guns] and [wings].",
            "Your [Artilery] and [Rocket Launchers] at Dover hit anything in France. Their [Howitzers] in Paris answer the same way.",
            "The forts at Calais soak up shots, so let the guns pick targets at random and [fly] over the Walls with Drones, then the [Fighter Jets] arriving on turn 3.",
        ]},
    },
    # ---------------------------------------------------------------- Peace Keepers
    "story_peacekeepers_1": {   # an army vs. insurgent cells that keep reappearing
        "setup": {IN: {"max_hp": 70}},
        "extras": [
            ex(IN, "Infantry", 6, RANDOM),
            ex(IN, "Special Ops", 2, RANDOM),
            ex(IN, "Infantry", 2, RANDOM, turn=3),
            ex(IN, "Infantry", 2, RANDOM, turn=5),
            ex(PK, "Tank", 2, {"border": IN}),
            ex(PK, "Infantry", 2, {"border": IN}),
            ex(PK, "Barracks", 1, {"border": IN}),
        ],
        "forces": {"title": "Cells in the Jungle", "lines": [
            "The Insurgents are [cells] scattered through the jungle, and new ones keep appearing: on turn 3 and turn 5.",
            "Units in [forests] take 1 less damage from flying attackers, so planes are a poor tool here. Go in on the ground.",
            "The Insurgents have only [70 HP]. Take their land fast and the cells have nowhere left to hide.",
        ]},
    },
    "story_peacekeepers_2": {   # air superiority vs. flak that arrives later
        "setup": {FU: {"max_hp": 70}},
        "extras": [
            ex(FU, "Infantry", 4, RANDOM),
            ex(FU, "Barracks", 2, RANDOM),
            ex(FU, "Anti Aircraft", 2, {"border": PK}, turn=3),
            ex(PK, "Fighter Jet", 2, {"near": ADDIS_ABABA}),
            ex(PK, "Drone", 2, {"near": ADDIS_ABABA}),
            ex(PK, "Infantry", 2, {"border": FU}),
        ],
        "forces": {"title": "Air Superiority, For Now", "lines": [
            "You own the sky: [Fighter Jets] and [Drones] fly over the desert, and the Fundamentalists have nothing that can shoot them down.",
            "Yet. Captured [Anti Aircraft] guns reach their border on [turn 3], and then your planes are in trouble.",
            "Use the first two turns. They have only [70 HP]: smash their [Barracks] while you can.",
        ]},
    },
    "story_peacekeepers_3": {   # outgunned but backed by the world vs. an unpaid army
        "setup": {ME: {"max_hp": 70, "money": 0}},
        "extras": [
            ex(ME, "Howitzer", 2, {"near": AGADEZ}),
            ex(ME, "Tank", 2, {"near": AGADEZ}),
            ex(ME, "Fighter Jet", 2, {"near": AGADEZ}),
            ex(PK, "Infantry", 4, {"border": ME}),
            ex(PK, "Wall", 2, {"border": ME}),
            ex(PK, "Fighter Jet", 2, {"near": ABUJA}, turn=3),
            ex(PK, "Infantry", 3, {"near": ABUJA}, turn=5),
            ex(PK, "Tank", 1, {"near": ABUJA}, turn=5),
        ],
        "forces": {"title": "The World Sends Help", "lines": [
            "The Mercenaries have the [better guns]: Howitzers, Tanks and jets. But they are [unpaid]: no Money in the bank and only [70 HP].",
            "You are outgunned at first, but help is coming from every corner of the world: [jets] on turn 3, more [troops] and a Tank on turn 5.",
            "Hold the border behind your [Walls] and let time fight for you.",
        ]},
    },
}

# The State Troops' chapters keep their original ids (story_1..5).
ALL_CHAPTERS = {}
for _n, _ch in CHAPTERS.items():
    ALL_CHAPTERS["story_%d" % _n] = dict(_ch, campaign="state", chapter=_n)
for _cid, _chs in CAMPAIGN_CHAPTERS.items():
    for _i, _ch in enumerate(_chs):
        ALL_CHAPTERS["story_%s_%d" % (_cid, _i + 1)] = dict(_ch, campaign=_cid, chapter=_i + 1)
for _mid, _f in FORCES.items():
    ALL_CHAPTERS[_mid].update(_f)

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
    data["setup"] = ch.get("setup", {})
    data["forces"] = ch.get("forces", {})
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
