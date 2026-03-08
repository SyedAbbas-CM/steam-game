#!/usr/bin/env python3
"""
Generate custom zone files for the overworld.

Creates:
  - resources/world/zones/{id}.tres  (LoyZoneData resource)
  - data/maps/{id}.txt               (map tile layout)
  - data/world/zones/{id}.xml        (zone XML for buildings/trees/etc)

Also patches neighboring zone .tres files to add reciprocal exit connections,
and updates the bake script's ZONE_MAP_FILES dictionary.

Usage: python3 scripts/tools/create_custom_zones.py
"""

import os
import re
import textwrap

PROJECT = "/Users/developer-cloudprimero/Desktop/Godot/new-game-project"
LOY_EXPORT = "/Users/developer-cloudprimero/Downloads/legends-of-yore-export"
ZONES_DIR = os.path.join(PROJECT, "resources/world/zones")
MAPS_DIR = os.path.join(LOY_EXPORT, "data/maps")
XML_DIR = os.path.join(LOY_EXPORT, "data/world/zones")
BAKE_SCRIPT = os.path.join(PROJECT, "scripts/tools/bake_full_world.gd")

# ─── Zone Definitions ────────────────────────────────────────────────

CUSTOM_ZONES = [
    {
        "id": "riverside",
        "zone_name": "Riverside",
        "description": "A peaceful riverbank with a fishing dock and herb garden.",
        "tileset": 112,
        "width": 20,
        "height": 15,
        "exits": [
            {"target": "aria", "x": 10, "y": 0, "tx": 12, "ty": 24},      # north to Aria south
            {"target": "camp", "x": 0, "y": 7, "tx": 19, "ty": 10},       # west to Camp east
        ],
        "npcs": [
            {"name": "Brenna", "tile": 160, "portrait": 160, "type": "shop", "shop_id": "riverside-herbs", "x": 14, "y": 8, "message": "Herbs and remedies, fresh from the riverbank!"},
        ],
        "signs": [
            {"message": "Riverside\\nGood fishing here", "x": 9, "y": 1},
            {"message": "To Aria", "x": 10, "y": 1},
        ],
        "spawns": [],  # peaceful zone
        "houses": [
            {"sign": "Brenna's Cottage\\n\\nHerbs and Healing", "x": 12, "y": 6, "width": 5, "height": 4, "dx": -1, "dy": 0},
        ],
        "map": [
            "TTTTTTTTTT TTTTTTTTT",
            "TT                TT",
            "T                  T",
            "T      WWWWWW      T",
            "T     WWWWWWWW     T",
            "T      WWWWWW      T",
            "T       WWWW       T",
            " T      bWWb      T ",
            "T        WW        T",
            "T       WWWW       T",
            "T      WWWWWW      T",
            "T     WWWWWWWW     T",
            "TT     WWWWWW     TT",
            "TTT    WWWWWW    TTT",
            "TTTTTTTTTTTTTTTTTTT ",
        ],
        "trees": [
            {"x": 1, "y": 1, "width": 4, "height": 5},
            {"x": 15, "y": 1, "width": 4, "height": 5},
            {"x": 1, "y": 10, "width": 3, "height": 4},
            {"x": 16, "y": 10, "width": 3, "height": 4},
        ],
    },
    {
        "id": "millford",
        "zone_name": "Millford",
        "description": "A small settlement at the main river ford with a wooden bridge and mill.",
        "tileset": 112,
        "width": 25,
        "height": 20,
        "exits": [
            {"target": "for1", "x": 24, "y": 10, "tx": 1, "ty": 15},   # east to Forest
            {"target": "wild1", "x": 12, "y": 0, "tx": 20, "ty": 49},  # north to Wild1
        ],
        "npcs": [
            {"name": "Old Torrin", "tile": 134, "portrait": 160, "type": "shop", "shop_id": "", "x": 8, "y": 5, "message": "The mill's running again thanks to you!"},
            {"name": "Fern", "tile": 130, "portrait": 146, "type": "message", "x": 3, "y": 10, "message": "Need a ferry ride? I can take you across."},
        ],
        "signs": [
            {"message": "Millford\\nRiver Crossing", "x": 11, "y": 1},
            {"message": "Torrin's Mill\\n\\nFresh Grain Daily", "x": 6, "y": 3},
        ],
        "spawns": [
            {"type": "Thief", "x": 15, "y": 2, "width": 8, "height": 16, "chance": 50},
        ],
        "houses": [
            {"sign": "Torrin's Mill\\n\\nFresh Grain Daily", "x": 5, "y": 3, "width": 6, "height": 5, "dx": 0, "dy": 1},
        ],
        "map": [
            "TTTTTTTTTTTTT TTTTTTTTTTT",
            "TT                     TT",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "TWWWWWWWWWWWWWWWWWWWWWWWT",
            "TWWWWWWWWWWWWWWWWWWWWWWWT",
            " WWWWWWWWWWbbWWWWWWWWWWW ",
            "TWWWWWWWWWWWWWWWWWWWWWWWT",
            "TWWWWWWWWWWWWWWWWWWWWWWWT",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "TT                     TT",
            "TTT                   TTT",
            "TTTTTTTTTTTTTTTTTTTTTTTTT",
        ],
        "trees": [
            {"x": 15, "y": 1, "width": 8, "height": 7},
            {"x": 15, "y": 13, "width": 8, "height": 6},
            {"x": 1, "y": 13, "width": 8, "height": 6},
        ],
    },
    {
        "id": "quarry",
        "zone_name": "The Quarry",
        "description": "An old stone quarry carved into the mountainside. Rich in building stone.",
        "tileset": 240,  # mountain theme
        "width": 15,
        "height": 20,
        "exits": [
            {"target": "mnt1", "x": 7, "y": 0, "tx": 30, "ty": 49},  # north to Mountains
        ],
        "npcs": [],
        "signs": [
            {"message": "Old Kingdom Quarry\\nDANGER - Rock Falls", "x": 6, "y": 1},
        ],
        "spawns": [
            {"type": "Rock Troll", "x": 2, "y": 5, "width": 11, "height": 13, "chance": 80},
        ],
        "houses": [],
        "map": [
            "TTTTTTT TTTTTTT",
            "TT           TT",
            "T             T",
            "T   @@@@@@    T",
            "T  @@@@@@@@@  T",
            "T @@@      @@ T",
            "T @@        @ T",
            "T @    oo    @T",
            "T @   oooo   @T",
            "T @    oo    @T",
            "T @@        @ T",
            "T @@@      @@ T",
            "T  @@@@@@@@@  T",
            "T   @@@@@@    T",
            "T             T",
            "T             T",
            "TT           TT",
            "TTT         TTT",
            "TTTT       TTTT",
            "TTTTTTTTTTTTTTT",
        ],
        "trees": [],
    },
    {
        "id": "thornfield",
        "zone_name": "Thornfield",
        "description": "Wide, flat farmland between Aria's territory and the Ironhide range. Rich soil but exposed.",
        "tileset": 112,
        "width": 25,
        "height": 25,
        "exits": [
            {"target": "wild1", "x": 12, "y": 24, "tx": 25, "ty": 1},  # south to Wild1 north
            {"target": "mnt1", "x": 12, "y": 0, "tx": 25, "ty": 49},   # north to Mountains
        ],
        "npcs": [
            {"name": "Edda", "tile": 160, "portrait": 160, "type": "message", "x": 12, "y": 12, "message": "My husband died defending this land. I won't leave it."},
        ],
        "signs": [
            {"message": "Thornfield\\nThe Old Breadbasket", "x": 11, "y": 23},
        ],
        "spawns": [
            {"type": "Orc", "x": 2, "y": 2, "width": 21, "height": 10, "chance": 100},
            {"type": "Wild Boar", "x": 2, "y": 12, "width": 21, "height": 10, "chance": 60},
        ],
        "houses": [
            {"sign": "Edda's Homestead", "x": 10, "y": 10, "width": 5, "height": 5, "dx": 0, "dy": 1},
        ],
        "map": [
            "TTTTTTTTTTTTT TTTTTTTTTTT",
            "TT                     TT",
            "T                       T",
            "T   nnnnnn   nnnnnn     T",
            "T   nnnnnn   nnnnnn     T",
            "T   nnnnnn   nnnnnn     T",
            "T   nnnnnn   nnnnnn     T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T                       T",
            "T   nnnnnn   nnnnnn     T",
            "T   nnnnnn   nnnnnn     T",
            "T   nnnnnn   nnnnnn     T",
            "T   nnnnnn   nnnnnn     T",
            "T                       T",
            "TT                     TT",
            "TTT                   TTT",
            "TTTT                 TTTT",
            "TTTTTTTTTTTTT TTTTTTTTTTT",
        ],
        "trees": [
            {"x": 18, "y": 1, "width": 5, "height": 6},
            {"x": 18, "y": 16, "width": 5, "height": 6},
        ],
    },
    {
        "id": "harbormouth",
        "zone_name": "Harbormouth",
        "description": "Where the river meets the sea. Marshy delta with fishing shacks.",
        "tileset": 112,
        "width": 20,
        "height": 15,
        "exits": [
            {"target": "gomb", "x": 19, "y": 7, "tx": 1, "ty": 10},   # east to Gomb
            {"target": "for1", "x": 0, "y": 7, "tx": 49, "ty": 25},   # west to Forest
        ],
        "npcs": [],
        "signs": [
            {"message": "Harbormouth\\nRiver Delta", "x": 9, "y": 1},
        ],
        "spawns": [
            {"type": "Snake", "x": 2, "y": 2, "width": 16, "height": 11, "chance": 40},
        ],
        "houses": [],
        "map": [
            "TTTTTTTTTTTTTTTTTTTT",
            "TT                TT",
            "T                  T",
            "T     WWWWW        T",
            "T    WWWWWWWWW     T",
            "T   WWWWWWWWWWWW   T",
            "T  WWWWWWWWWWWWWW  T",
            " WWWWWWWWWWWWWWWWWW ",
            "T  WWWWWWWWWWWWWW  T",
            "T   WWWWWWWWWWWW   T",
            "T    WWWWWWWWW     T",
            "T      WWWWW       T",
            "TT                TT",
            "TTT              TTT",
            "TTTTTTTTTTTTTTTTTTTT",
        ],
        "trees": [
            {"x": 1, "y": 1, "width": 3, "height": 4},
            {"x": 15, "y": 1, "width": 4, "height": 4},
            {"x": 1, "y": 10, "width": 3, "height": 4},
            {"x": 15, "y": 10, "width": 4, "height": 4},
        ],
    },
    {
        "id": "oldcapital",
        "zone_name": "The Old Capital",
        "description": "Crumbling ruins of the kingdom that once ruled these lands. Overgrown and forgotten.",
        "tileset": 112,
        "width": 30,
        "height": 30,
        "exits": [
            {"target": "wild1", "x": 15, "y": 29, "tx": 25, "ty": 1},  # south to Wild1
        ],
        "npcs": [],
        "signs": [
            {"message": "We who guard the deep\\nso the world may sleep", "x": 14, "y": 14},
        ],
        "spawns": [
            {"type": "Spectre", "x": 3, "y": 3, "width": 24, "height": 24, "chance": 60},
            {"type": "Skeleton", "x": 3, "y": 3, "width": 24, "height": 24, "chance": 40},
        ],
        "houses": [
            {"sign": "Throne Room\\n\\nThe seat of power lies broken", "x": 11, "y": 11, "width": 8, "height": 8, "dx": 0, "dy": 1},
        ],
        "map": [
            "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
            "TT                          TT",
            "T                            T",
            "T    @@@@@@@@@@@@@@@@@@@     T",
            "T    @                 @     T",
            "T    @                 @     T",
            "T    @    TTTTTTTT    @     T",
            "T    @   T        T   @     T",
            "T    @   T        T   @     T",
            "T    @   T        T   @     T",
            "T    @    TTTTTTTT    @     T",
            "T    @                 @     T",
            "T    @                 @     T",
            "T    @                 @     T",
            "T    @                 @     T",
            "T    @                 @     T",
            "T    @                 @     T",
            "T    @   T        T   @     T",
            "T    @   T        T   @     T",
            "T    @   T        T   @     T",
            "T    @    TTTTTTTT    @     T",
            "T    @                 @     T",
            "T    @                 @     T",
            "T    @@@@@@@@@@@@@@@@@@@     T",
            "T                            T",
            "T                            T",
            "TT                          TT",
            "TTT                        TTT",
            "TTTT                      TTTT",
            "TTTTTTTTTTTTTTT TTTTTTTTTTTTTT",
        ],
        "trees": [
            {"x": 1, "y": 1, "width": 3, "height": 28},
            {"x": 25, "y": 1, "width": 4, "height": 28},
            {"x": 4, "y": 24, "width": 10, "height": 5},
            {"x": 16, "y": 24, "width": 9, "height": 5},
            {"x": 4, "y": 1, "width": 10, "height": 2},
            {"x": 16, "y": 1, "width": 9, "height": 2},
        ],
    },
    # ─── Wave 2: More expansion zones ──────────────────────────
    {
        "id": "crossroads",
        "zone_name": "The Crossroads",
        "description": "Where the old kingdom's trade roads meet. A crumbling plaza with stone markers.",
        "tileset": 112,
        "width": 15,
        "height": 15,
        "exits": [
            {"target": "wild1", "x": 7, "y": 14, "tx": 25, "ty": 1},  # south into wild1
        ],
        "npcs": [],
        "signs": [
            {"message": "North: Mountains\\nSouth: Aria\\nEast: Forest\\nWest: Valley", "x": 7, "y": 7},
        ],
        "spawns": [],
        "houses": [],
        "map": [
            "TTTTTTT TTTTTTT",
            "TT           TT",
            "T             T",
            "T    ooooo    T",
            "T   ooooooo   T",
            "T  ooo   ooo  T",
            "T  oo  R  oo  T",
            " ooo   o   ooo ",
            "T  oo     oo  T",
            "T  ooo   ooo  T",
            "T   ooooooo   T",
            "T    ooooo    T",
            "T             T",
            "TT           TT",
            "TTTTTTT TTTTTTT",
        ],
        "trees": [
            {"x": 1, "y": 1, "width": 3, "height": 5},
            {"x": 11, "y": 1, "width": 3, "height": 5},
            {"x": 1, "y": 9, "width": 3, "height": 5},
            {"x": 11, "y": 9, "width": 3, "height": 5},
        ],
    },
    {
        "id": "banditwood",
        "zone_name": "Bandit's Wood",
        "description": "Dense forest where a bandit gang has made camp. Stolen goods litter the clearings.",
        "tileset": 112,
        "width": 20,
        "height": 20,
        "exits": [
            {"target": "wild1", "x": 0, "y": 10, "tx": 49, "ty": 15},  # west to wild1 east
            {"target": "for1", "x": 19, "y": 10, "tx": 1, "ty": 10},   # east to forest
        ],
        "npcs": [],
        "signs": [
            {"message": "KEEP OUT\\nOr else", "x": 1, "y": 9},
        ],
        "spawns": [
            {"type": "Thief", "x": 3, "y": 3, "width": 14, "height": 14, "chance": 150},
            {"type": "Robber", "x": 6, "y": 6, "width": 8, "height": 8, "chance": 80},
        ],
        "houses": [
            {"sign": "Bandit Captain's Tent", "x": 8, "y": 8, "width": 4, "height": 4, "dx": 0, "dy": 1},
        ],
        "map": [
            "TTTTTTTTTTTTTTTTTTTT",
            "TTTTTTTTTTTTTTTTTTTT",
            "TTT              TTT",
            "TT                TT",
            "T                  T",
            "T                  T",
            "T                  T",
            "T                  T",
            "T                  T",
            "T                  T",
            "                    ",
            "T                  T",
            "T                  T",
            "T                  T",
            "T                  T",
            "T                  T",
            "T                  T",
            "TT                TT",
            "TTT              TTT",
            "TTTTTTTTTTTTTTTTTTTT",
        ],
        "trees": [
            {"x": 2, "y": 2, "width": 5, "height": 6},
            {"x": 13, "y": 2, "width": 5, "height": 6},
            {"x": 2, "y": 12, "width": 5, "height": 6},
            {"x": 13, "y": 12, "width": 5, "height": 6},
        ],
    },
    {
        "id": "lakeshore",
        "zone_name": "Lakeshore",
        "description": "A tranquil lake between the mountains and the valley. Good fishing, fresh water.",
        "tileset": 112,
        "width": 25,
        "height": 20,
        "exits": [
            {"target": "vly1", "x": 0, "y": 10, "tx": 59, "ty": 12},   # west to valley
            {"target": "wild1", "x": 24, "y": 10, "tx": 1, "ty": 25},  # east to wild1
        ],
        "npcs": [
            {"name": "Old Fisher", "tile": 134, "portrait": 160, "type": "message", "x": 20, "y": 12, "message": "Best fishing in all of Yore right here. Silverscale love this lake."},
        ],
        "signs": [
            {"message": "Lakeshore\\nPeaceful Waters", "x": 12, "y": 1},
        ],
        "spawns": [],
        "houses": [],
        "map": [
            "TTTTTTTTTTTTTTTTTTTTTTTTT",
            "TT                     TT",
            "T                       T",
            "T                       T",
            "T       WWWWWWWWW       T",
            "T      WWWWWWWWWWW      T",
            "T     WWWWWWWWWWWWW     T",
            "T    WWWWWWWWWWWWWWW    T",
            "T    WWWWWWWWWWWWWWW    T",
            "T    WWWWWWWWWWWWWWW    T",
            "     WWWWWWWWWWWWWWW     ",
            "T    WWWWWWWWWWWWWWW    T",
            "T    WWWWWWWWWWWWWWW    T",
            "T    WWWWWWWWWWWWWWW    T",
            "T     WWWWWWWWWWWWW     T",
            "T      WWWWWWWWWWW      T",
            "T       WWWWWWWWW       T",
            "TT                     TT",
            "TTT                   TTT",
            "TTTTTTTTTTTTTTTTTTTTTTTTT",
        ],
        "trees": [
            {"x": 1, "y": 1, "width": 5, "height": 6},
            {"x": 19, "y": 1, "width": 5, "height": 6},
            {"x": 1, "y": 13, "width": 5, "height": 6},
            {"x": 19, "y": 13, "width": 5, "height": 6},
        ],
    },
    {
        "id": "highroad",
        "zone_name": "The High Road",
        "description": "An elevated mountain path connecting the peaks to the northern settlements.",
        "tileset": 240,  # mountain
        "width": 30,
        "height": 10,
        "exits": [
            {"target": "mnt1", "x": 0, "y": 5, "tx": 49, "ty": 25},   # west to mountains
            {"target": "peaks", "x": 29, "y": 5, "tx": 1, "ty": 20},  # east to peaks
        ],
        "npcs": [],
        "signs": [
            {"message": "The High Road\\nWatch your step", "x": 5, "y": 4},
        ],
        "spawns": [
            {"type": "Bear", "x": 5, "y": 2, "width": 20, "height": 6, "chance": 60},
        ],
        "houses": [],
        "map": [
            "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
            "TT@@@@@@@@@@@@@@@@@@@@@@@@@@TT",
            "T@@                        @@T",
            "T@                          @T",
            "T                            T",
            "                              ",
            "T                            T",
            "T@                          @T",
            "TT@@@@@@@@@@@@@@@@@@@@@@@@@@TT",
            "TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
        ],
        "trees": [],
    },
    {
        "id": "marshgate",
        "zone_name": "Marsh Gate",
        "description": "A fortified crossing at the edge of the swamplands. Keeps the swamp creatures out.",
        "tileset": 112,
        "width": 15,
        "height": 20,
        "exits": [
            {"target": "plains", "x": 7, "y": 0, "tx": 25, "ty": 24},   # north to plains
            {"target": "swamp", "x": 7, "y": 19, "tx": 25, "ty": 1},    # south to swamp
        ],
        "npcs": [
            {"name": "Gate Guard", "tile": 149, "portrait": 149, "type": "message", "x": 7, "y": 10, "message": "The swamp beyond is dangerous. Zomboids and worse lurk in the mire."},
        ],
        "signs": [
            {"message": "Marsh Gate\\nLast outpost before the swamp", "x": 6, "y": 1},
        ],
        "spawns": [],
        "houses": [
            {"sign": "Guardhouse", "x": 3, "y": 8, "width": 4, "height": 4, "dx": 1, "dy": 0},
            {"sign": "Supply Shed", "x": 8, "y": 8, "width": 4, "height": 4, "dx": -1, "dy": 0},
        ],
        "map": [
            "TTTTTTT TTTTTTT",
            "TT           TT",
            "T             T",
            "T             T",
            "T             T",
            "T             T",
            "T    FFFFF    T",
            "T    F   F    T",
            "T             T",
            "T             T",
            "T      o      T",
            "T             T",
            "T             T",
            "T    F   F    T",
            "T    FFFFF    T",
            "T             T",
            "T             T",
            "T             T",
            "TT           TT",
            "TTTTTTT TTTTTTT",
        ],
        "trees": [
            {"x": 1, "y": 1, "width": 4, "height": 5},
            {"x": 10, "y": 1, "width": 4, "height": 5},
            {"x": 1, "y": 14, "width": 4, "height": 5},
            {"x": 10, "y": 14, "width": 4, "height": 5},
        ],
    },
]

# ─── Generator Functions ─────────────────────────────────────────────

def generate_map_file(zone):
    """Create a map .txt file in LoY format."""
    path = os.path.join(MAPS_DIR, f"{zone['id']}.txt")
    lines = ["end;"]
    for row in zone["map"]:
        # Pad to zone width
        padded = row.ljust(zone["width"])[:zone["width"]]
        lines.append(padded + " ;")

    with open(path, 'w') as f:
        f.write("\n".join(lines) + "\n")
    print(f"  Map: {path}")

def generate_zone_xml(zone):
    """Create a zone .xml file with buildings, trees, spawns."""
    path = os.path.join(XML_DIR, f"{zone['id']}.xml")

    parts = [f'<zone id="{zone["id"]}" name="{zone["zone_name"]}" tileset="{zone["tileset"]}" mx="0" my="0">']

    # Houses
    for h in zone.get("houses", []):
        sign = h.get("sign", "").replace('"', '&quot;')
        parts.append(f'  <house x="{h["x"]}" y="{h["y"]}" width="{h["width"]}" height="{h["height"]}" dx="{h.get("dx",0)}" dy="{h.get("dy",0)}" sign="{sign}" />')

    # Trees
    for t in zone.get("trees", []):
        parts.append(f'  <trees x="{t["x"]}" y="{t["y"]}" width="{t["width"]}" height="{t["height"]}" />')

    # Spawns
    for s in zone.get("spawns", []):
        parts.append(f'  <spawn type="{s["type"]}" x="{s["x"]}" y="{s["y"]}" width="{s["width"]}" height="{s["height"]}" chance="{s["chance"]}" />')

    # Signs
    for s in zone.get("signs", []):
        msg = s["message"].replace('"', '&quot;')
        parts.append(f'  <sign x="{s["x"]}" y="{s["y"]}" message="{msg}" />')

    # NPCs
    for n in zone.get("npcs", []):
        msg = n.get("message", "").replace('"', '&quot;')
        parts.append(f'  <npc name="{n["name"]}" tile="{n["tile"]}" portrait="{n.get("portrait", n["tile"])}" '
                     f'type="{n["type"]}" x="{n["x"]}" y="{n["y"]}" message="{msg}" '
                     f'shop="{n.get("shop_id", "")}" file="" />')

    parts.append('</zone>')

    with open(path, 'w') as f:
        f.write("\n".join(parts) + "\n")
    print(f"  XML: {path}")

def generate_zone_tres(zone):
    """Create a LoyZoneData .tres resource file."""
    path = os.path.join(ZONES_DIR, f"{zone['id']}.tres")

    # Build exits array
    exits_items = []
    for e in zone["exits"]:
        exits_items.append(f'{{\n"target": "{e["target"]}",\n"tx": {e["tx"]},\n"ty": {e["ty"]},\n"x": {e["x"]},\n"y": {e["y"]}\n}}')
    exits_str = ", ".join(exits_items)

    # Build NPCs array
    npc_items = []
    for n in zone.get("npcs", []):
        npc_dict = (f'{{\n"name": "{n["name"]}",\n"tile": {n["tile"]},\n"portrait": {n.get("portrait", n["tile"])},'
                    f'\n"type": "{n["type"]}",\n"x": {n["x"]},\n"y": {n["y"]},'
                    f'\n"message": "{n.get("message", "")}",'
                    f'\n"shop": "{n.get("shop_id", "")}",'
                    f'\n"file": ""\n}}')
        npc_items.append(npc_dict)
    npcs_str = ", ".join(npc_items)

    # Build signs array
    sign_items = []
    for s in zone.get("signs", []):
        sign_items.append(f'{{\n"message": "{s["message"]}",\n"x": {s["x"]},\n"y": {s["y"]}\n}}')
    signs_str = ", ".join(sign_items)

    # Build spawns array
    spawn_items = []
    for s in zone.get("spawns", []):
        spawn_items.append(f'{{\n"type": "{s["type"]}",\n"x": {s["x"]},\n"y": {s["y"]},'
                          f'\n"width": {s["width"]},\n"height": {s["height"]},'
                          f'\n"chance": {s["chance"]}\n}}')
    spawns_str = ", ".join(spawn_items)

    # Build houses array
    house_items = []
    for h in zone.get("houses", []):
        house_items.append(f'{{\n"sign": "{h.get("sign", "")}",\n"x": {h["x"]},\n"y": {h["y"]},'
                          f'\n"width": {h["width"]},\n"height": {h["height"]},'
                          f'\n"dx": {h.get("dx", 0)},\n"dy": {h.get("dy", 0)}\n}}')
    houses_str = ", ".join(house_items)

    content = f'''[gd_resource type="Resource" script_class="LoyZoneData" format=3]

[ext_resource type="Script" path="res://scripts/data/loy_zone_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = "{zone["id"]}"
zone_name = "{zone["zone_name"]}"
tileset = {zone["tileset"]}
width = {zone["width"]}
height = {zone["height"]}
world_pos = Vector2i(0, 0)
dungeon_base = ""
dungeon_count = 0
description = "{zone["description"]}"
baked_offset = Vector2i(-99999, -99999)
exits = Array[Dictionary]([{exits_str}])
npcs = Array[Dictionary]([{npcs_str}])
signs = Array[Dictionary]([{signs_str}])
spawns = Array[Dictionary]([{spawns_str}])
houses = Array[Dictionary]([{houses_str}])
'''

    with open(path, 'w') as f:
        f.write(content)
    print(f"  Tres: {path}")

def add_reciprocal_exits(zone):
    """Add exit entries in neighboring zone .tres files pointing back to this zone."""
    for exit_data in zone["exits"]:
        target_id = exit_data["target"]
        target_path = os.path.join(ZONES_DIR, f"{target_id}.tres")
        if not os.path.exists(target_path):
            print(f"  WARNING: Target zone {target_id} not found, skipping reciprocal exit")
            continue

        with open(target_path, 'r') as f:
            content = f.read()

        # Check if this zone already has an exit to us
        if f'"target": "{zone["id"]}"' in content:
            print(f"  Reciprocal exit {target_id} → {zone['id']} already exists")
            continue

        # Build the new exit entry
        new_exit = f'{{\n"target": "{zone["id"]}",\n"tx": {exit_data["x"]},\n"ty": {exit_data["y"]},\n"x": {exit_data["tx"]},\n"y": {exit_data["ty"]}\n}}'

        # Find the exits array and append to it
        # Pattern: exits = Array[Dictionary]([...])
        match = re.search(r'(exits = Array\[Dictionary\]\(\[)(.*?)(\]\))', content, re.DOTALL)
        if match:
            existing = match.group(2).strip()
            if existing:
                new_exits = f"{existing}, {new_exit}"
            else:
                new_exits = new_exit
            content = content[:match.start()] + f'exits = Array[Dictionary]([{new_exits}])' + content[match.end():]

            with open(target_path, 'w') as f:
                f.write(content)
            print(f"  Added reciprocal exit: {target_id} → {zone['id']}")
        else:
            print(f"  WARNING: Could not find exits array in {target_path}")

def update_bake_script(zones):
    """Add new zone IDs to ZONE_MAP_FILES in the bake script."""
    with open(BAKE_SCRIPT, 'r') as f:
        content = f.read()

    for zone in zones:
        zone_id = zone["id"]
        if f'"{zone_id}"' in content:
            print(f"  Bake script already has {zone_id}")
            continue

        # Add to ZONE_MAP_FILES dictionary - insert before the closing }
        # Find the last entry line before the closing }
        pattern = r'(var ZONE_MAP_FILES: Dictionary = \{[^}]*?)([\n\s]*\})'
        match = re.search(pattern, content, re.DOTALL)
        if match:
            existing = match.group(1).rstrip()
            # Add comma if needed
            if not existing.endswith(','):
                existing += ','
            content = content[:match.start()] + existing + f'\n\t"{zone_id}": "{zone_id}",' + match.group(2) + content[match.end():]
            print(f"  Added {zone_id} to ZONE_MAP_FILES")

    with open(BAKE_SCRIPT, 'w') as f:
        f.write(content)

# ─── Main ─────────────────────────────────────────────────────────────

def main():
    os.makedirs(MAPS_DIR, exist_ok=True)
    os.makedirs(XML_DIR, exist_ok=True)
    os.makedirs(ZONES_DIR, exist_ok=True)

    print(f"Generating {len(CUSTOM_ZONES)} custom zones...\n")

    for zone in CUSTOM_ZONES:
        print(f"Zone: {zone['id']} ({zone['zone_name']}) {zone['width']}x{zone['height']}")
        generate_map_file(zone)
        generate_zone_xml(zone)
        generate_zone_tres(zone)
        # Skip reciprocal exits - BFS handles bidirectional placement via reverse_connections
        print()

    # NOTE: We no longer add reciprocal exits to LoY zones.
    # The bake script's BFS uses reverse_connections to handle bidirectional
    # placement automatically. Adding reciprocal exits was causing BFS order
    # changes that shifted the original LoY world layout.

    print("Updating bake script...")
    update_bake_script(CUSTOM_ZONES)

    print(f"\nDone! {len(CUSTOM_ZONES)} zones created.")
    print("Next steps:")
    print("  1. Review the generated files")
    print("  2. Run the bake script to place zones on the overworld:")
    print("     /Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot --headless --script scripts/tools/bake_full_world.gd")
    print("  3. Fix format if needed:")
    print("     python3 -c \"import re; ...")

if __name__ == "__main__":
    main()
