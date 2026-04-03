#!/usr/bin/env python3
"""
World Redesign Script — Renames all zone IDs, zone names, dungeon bases,
and updates cross-references across all .tres data files.

Usage: python3 scripts/tools/rename_world.py [--dry-run]
"""

import os, re, sys, json, shutil

PROJECT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DRY_RUN = '--dry-run' in sys.argv

# ─── ZONE MAPPING ──────────────────────────────────────────────────────────
# (old_id, new_id, new_zone_name, new_description, new_dungeon_base)
# dungeon_base format: "NewPrefix-Dungeons" → prefix extraction: split on "-", lowercase first part
ZONE_MAP = [
    # THE ASHFIELDS (Starting Region)
    ("aria",            "haven",      "Ravenhollow",        "A fortified refugee village — the last safe haven in the Ashfields. Smoke rises from chimneys and guards watch the walls.", "Haven-Dungeons"),
    ("aria-g",          "barrows",    "The Barrows",        "Ancient burial mounds where the dead no longer rest. Green light flickers between crumbling tombstones.", "Barrows-Crypt"),
    ("farm",            "duskfarm",   "Hollow Fields",      "Blighted farmland stretching to the horizon. Crops wither in ashen soil and scarecrows stand crooked in the fog.", "Duskfarm-Dungeons"),
    ("fire_caves",      "embermaw",   "The Embermaw",       "A volcanic fissure torn open during the Sundering. Magma pulses deep below and demonic whispers echo from the depths.", "Ember-Dungeons"),
    ("staging_ground",  "warcamp",    "The Iron March",     "A military staging ground scarred by battle. Broken siege engines and abandoned tents litter the scorched earth.", None),
    ("military_camp",   "bastion",    "Fort Bastion",       "The last military outpost before the corrupted lands. Soldiers here look hollow-eyed and weary.", None),
    ("riverside",       "millcross",  "Millcross",          "A ruined riverside crossing. The old mill wheel still turns, grinding nothing but dust.", None),

    # THE BLIGHTWOOD (Forest Region)
    ("for1",            "rotgrove",   "Rotgrove",           "A decaying forest hub where fungal corruption spreads through ancient trees. Spores drift like snow.", "Rot-Dungeons"),
    ("for2",            "thorndeep",  "Thorndeep",          "Thorny overgrown woods choked with spider silk. The canopy is so thick that daylight never reaches the forest floor.", "Thorn-Dungeons"),
    ("for3",            "shroudwood", "Shroudwood",         "A fog-choked hidden forest where shadows move between the trees. Those who enter rarely find their way out.", "Shroud-Dungeons"),
    ("for4",            "ashglade",   "The Ashglade",       "A burned clearing at the forest's heart — site of an ancient ritual. The ground is still warm.", "Ashglade-Dungeons"),
    ("gomb",            "briarvale",  "Briarvale",          "A fortified town deep within the forest, protected by walls of living thorns. Its people are suspicious of outsiders.", "Briar-Dungeons"),
    ("banditwood",      "cutthroat",  "Cutthroat Hollow",   "An outlaw camp hidden in a ravine. Stolen goods hang from trees like trophies.", None),
    ("millford",        "oldmill",    "Old Millford",       "An abandoned mill town slowly being reclaimed by the forest. Something lurks in the collapsed buildings.", None),
    ("harbormouth",     "fenport",    "Fenport",            "A marshy harbor at the forest edge where smugglers dock under cover of fog.", None),

    # THE WITHERED EXPANSE (Central Wilderness)
    ("wild1",           "wastes",     "The Withered Wastes", "A blasted central wasteland where crossroads meet. The soil is grey and nothing grows. Wind carries the sound of distant screaming.", "Waste-Dungeons"),
    ("camp",            "wardens",    "The Warden's Camp",  "A ranger training ground hidden in the wastes. The Wardens patrol the roads and hunt the corrupted.", "Warden-Dungeons"),
    ("crossroads",      "gallows",    "Gallows Crossing",   "An execution crossroads haunted by the spirits of the hanged. The gibbet cages still swing in the wind.", None),
    ("oldcapital",      "ruincrown",  "Ruincrown",          "Shattered ruins of the old capital city. Grand spires lie toppled and the throne room is open to the sky.", None),
    ("lakeshore",       "deadshore",  "Deadshore",          "The shore of a poisoned lake. Dead fish wash up on grey sand and the water glows faintly at night.", None),
    ("thornfield",      "blightmoor", "Blightmoor",         "Corrupted moorland where the ground squelches with black ichor. Twisted plants reach for anything that moves.", None),
    ("quarry",          "bonequarry", "The Bone Quarry",    "An excavation site where miners unearthed the fossils of ancient beasts — and something worse beneath them.", None),
    ("hinnom",          "gehinnom",   "The Pit of Gehinnom","A cursed sinkhole where demonic whispers rise from impossible depths. The air tastes of copper and ash.", None),

    # THE IRONSPINE (Mountain Region)
    ("mnt1",            "ironspine",  "The Ironspine",      "A jagged mountain range rich with ore and riddled with cave networks. Giants once called these peaks home.", "Iron-Dungeons"),
    ("cold1",           "frostpass",  "Frostbite Pass",     "A treacherous frozen mountain pass where blizzards strike without warning. The bones of failed travelers line the path.", "Frost-Dungeons"),
    ("nord1",           "grimhold",   "Grimhold",           "A northern fortress settlement carved into the mountainside. Its forges burn day and night.", "Grim-Dungeons"),
    ("heim",            "ashheim",    "Ashheim",            "A mountain city built into volcanic rock. Soot coats every surface and the air smells of sulfur.", "Ashheim-Dungeons"),
    ("crt1",            "spire",      "The Black Spire",    "A dark wizard's tower rising from a mountain peak. Lightning strikes its pinnacle even on clear days.", "Spire-Tower"),
    ("cycl",            "giantmaw",   "Giantmaw Ravine",   "A valley littered with the bones of ancient giants. Something massive still moves in the deepest caves.", "Giant-Dungeons"),
    ("highroad",        "kingsroad",  "The King's Road",    "A crumbling elevated highway built by the old empire. Sections have collapsed into the ravine below.", None),

    # THE DROWNED COAST (Coastal Region)
    ("tor1",            "driftport",  "Driftport",          "A pirate-controlled harbor where stolen ships are refitted and renamed. Law holds no power here.", "Drift-Dungeons"),
    ("tor2",            "saltmere",   "Saltmere",           "A decaying coastal city eaten by salt and sea. Grand buildings crumble while the tide creeps ever higher.", "Salt-Dungeons"),
    ("tor3",            "tidegate",   "The Tidegate",       "A flood-prone gate district where residents build on stilts. When the tide comes, the streets become canals.", "Tide-Dungeons"),
    ("tor4",            "scorchgate", "Scorchgate",         "The gate to the badlands — a sun-blasted checkpoint where caravans rest before the crossing.", "Scorch-Dungeons"),
    ("tor5",            "smugglers",  "Smuggler's Grotto",  "A hidden pirate cove concealed behind a waterfall. Stolen treasure glints in the darkness.", "Smuggler-Dungeons"),
    ("tor6",            "wharves",    "The Black Wharves",  "Haunted docklands where ghost ships are said to appear on moonless nights. Dockworkers refuse to work after dark.", "Wharf-Dungeons"),
    ("bch1",            "bleachbone", "Bleachbone Beach",   "A shore littered with whale skeletons and shipwrecks. The sand is white as bone.", "Bleach-Dungeons"),
    ("blf1",            "cliffs",     "The Wailing Cliffs", "Sea cliffs with howling wind caves that produce an eerie wail. Nests of flying creatures dot the cliff face.", "Cliff-Dungeons"),

    # THE SUNKEN REALM (Southern/Plains Region)
    ("plains",          "ashplains",  "The Ashplains",      "Vast scorched flatlands where grass fires sweep across the horizon. Nomadic warbands roam between ruined settlements.", "Plains-Dungeons"),
    ("cennyn",          "cenneth",    "Cenneth Citadel",    "A walled city-state ruled by a paranoid council. Political intrigue festers behind its high walls.", "Cenneth-Dungeons"),
    ("naleg",           "brackwater", "Brackwater",         "A swamp-edge trading post built on rotting stilts. The water is brown and the merchants are desperate.", "Brack-Dungeons"),
    ("swamp",           "miredeep",   "The Miredeep",       "A toxic swampland believed to be the origin of the plague. Bubbles of noxious gas burst from the murk.", "Mire-Dungeons"),
    ("talmita",         "boghollow",  "Boghollow",          "A reclusive swamp settlement whose inhabitants have adapted to the corruption in disturbing ways.", "Bog-Dungeons"),
    ("marshgate",       "rotgate",    "Rotgate",            "A crumbling gate to the marshes. The ironwork is rusted through and the guards abandoned their posts long ago.", None),
    ("peaks",           "stormcrag",  "Stormcrag",          "Lightning-struck mountain peaks where storms gather constantly. The rock itself seems to hum with energy.", "Storm-Dungeons"),
    ("kor",             "kor",        "The Fortress of Kor","An ancient impenetrable fortress whose builders are long forgotten. No army has ever breached its walls.", "Kor-Dungeons"),
    ("cel1",            "moloch",     "Moloch Ruins",       "Ancient temple ruins where dark rituals were once performed. The altars are still stained.", "Moloch-Dungeons"),
    ("brg1",            "dreadbridge","Dreadbridge",        "A massive bridge spanning a bottomless chasm. The chains holding it groan under their own weight.", "Dread-Dungeons"),

    # THE FROZEN WASTES (Arctic/End-game)
    ("tundra",          "permafrost", "The Permafrost",     "An endless frozen tundra where the cold itself seems alive. Explorers report hearing voices in the wind.", "Perma-Dungeons"),
    ("vale",            "hollowvale", "Hollowvale",         "A misty cursed valley where time moves strangely. Travelers emerge days later thinking only hours have passed.", "Hollowvale-Dungeons"),
    ("frozen",          "frostgrave", "Frostgrave",         "A frozen battlefield where two armies perished simultaneously. The dead soldiers still stand, locked in ice.", "Frostgrave-Dungeons"),
    ("thule",           "thule",      "Ultima Thule",       "The edge of the known world. Beyond this point, reality itself begins to fray.", "Thule-Dungeons"),
    ("end1",            "hellgate",   "The Abyssal Gate",   "The final gate — a wound in the earth from which darkness pours. The source of all corruption.", "Abyss-Dungeons"),
    ("jungle1",         "feverjungle","The Feverwild",      "A poisonous jungle where every plant is lethal and plague beasts stalk the undergrowth.", "Fever-Dungeons"),
    ("jungle2",         "deepwild",   "The Deepwild",       "Dense unexplored jungle so thick that sunlight never reaches the ground. Ancient things move in the darkness.", "Deep-Dungeons"),
    ("paititi",         "eldori",     "Eldori Ruins",       "Ruins of a lost civilization consumed by the jungle. Golden spires peek through the canopy.", "Eldori-Dungeons"),

    # THE WESTERN REACHES (Moors/Peripheral)
    ("moors",           "bleakmoor",  "The Bleakmoor",      "Fog-shrouded moorland where will-o-wisps lead travelers to their doom. The ground is soft and treacherous.", "Bleak-Dungeons"),
    ("airlon",          "windhold",   "Windhold",           "An isolated clifftop settlement battered by constant gales. Its people are hardy and unwelcoming.", "Wind-Dungeons"),
    ("clearing",        "witchglade", "The Witchglade",     "A ritual clearing deep in the moors where a coven once gathered. Mushroom rings mark the old circles.", "Witch-Dungeons"),
    ("ynys",            "duskport",   "Duskport",           "A remote western harbor where the sun seems to set earlier than anywhere else. Ships depart but rarely return.", "Dusk-Dungeons"),
    ("island",          "drownisle",  "Drown Isle",         "A cursed island ringed by shipwrecks. The lighthouse still burns but no keeper tends it.", "Drown-Dungeons"),
    ("pst1",            "sanctum",    "The Lost Sanctum",   "Abandoned holy ground where priests once banished evil. The protective wards are failing.", "Sanctum-Dungeons"),
    ("und1",            "undercroft",  "The Undercroft",    "An underground passage network connecting distant parts of the coast. Something has made its home in the dark.", "Under-Dungeons"),

    # REMAINING ZONES
    ("vly1",            "ashvale",    "Ashvale",            "A valley of ash and bone where the Sundering struck hardest. Grey dunes shift in the wind.", "Ashvale-Dungeons"),
    ("sthel",           "mirage",     "The Mirage",         "A desert oasis that shimmers and shifts. Nothing is quite what it seems here.", "Mirage-Dungeons"),
    ("shrine",          "shrine",     "The Shattered Shrine","A broken holy site where divine power once flowed. The altar is cracked and weeping black ichor.", "Shrine-Dungeons"),
    ("talnivek",        "duskwatch",  "Duskwatch",          "A border watchtower settlement keeping vigil against the darkness. The garrison is dangerously thin.", "Duskwatch-Dungeons"),
    ("thicket",         "briarmarsh", "Briarmarsh",         "Dense thorny wetland where visibility drops to nothing. The thorns seem to grow toward warm bodies.", "Briarmarsh-Dungeons"),
    ("thicket2",        "briardeep",  "Briardeep",          "Deeper into the briar where the thorns form tunnels and chambers. Something intelligent tends them.", "Briardeep-Dungeons"),
]

# Build lookup dicts
OLD_TO_NEW = {}       # old_id → (new_id, new_name, new_desc, new_dungeon_base)
OLD_NAME_TO_NEW = {}  # old_zone_name → new_zone_name (for sign/dialogue text)
DUNGEON_BASE_MAP = {} # old_dungeon_base → new_dungeon_base

def build_lookups():
    for old_id, new_id, new_name, new_desc, new_dbase in ZONE_MAP:
        OLD_TO_NEW[old_id] = (new_id, new_name, new_desc, new_dbase)

    # We also need old zone names for text replacement in signs
    # Read existing zone files to get old names
    zones_dir = os.path.join(PROJECT, 'resources', 'world', 'zones')
    for fname in os.listdir(zones_dir):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(zones_dir, fname)
        text = open(path).read()
        m_id = re.search(r'^id = "([^"]*)"', text, re.MULTILINE)
        m_name = re.search(r'^zone_name = "([^"]*)"', text, re.MULTILINE)
        if m_id and m_name:
            old_id = m_id.group(1)
            old_name = m_name.group(1)
            if old_id in OLD_TO_NEW:
                OLD_NAME_TO_NEW[old_name] = OLD_TO_NEW[old_id][1]  # new_name

    # Build dungeon base map from existing zone files
    for fname in os.listdir(zones_dir):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(zones_dir, fname)
        text = open(path).read()
        m_id = re.search(r'^id = "([^"]*)"', text, re.MULTILINE)
        m_db = re.search(r'^dungeon_base = "([^"]*)"', text, re.MULTILINE)
        if m_id and m_db:
            old_id = m_id.group(1)
            old_dbase = m_db.group(1)
            if old_id in OLD_TO_NEW:
                new_dbase = OLD_TO_NEW[old_id][3]
                if new_dbase and old_dbase:
                    DUNGEON_BASE_MAP[old_dbase] = new_dbase


def replace_zone_name_in_text(text):
    """Replace old zone names in free text (signs, dialogue)."""
    for old_name, new_name in sorted(OLD_NAME_TO_NEW.items(), key=lambda x: -len(x[0])):
        if old_name in text:
            text = text.replace(old_name, new_name)
    # Also replace "To X" patterns for zone names
    for old_id, (new_id, new_name, _, _) in OLD_TO_NEW.items():
        # Replace ID references in text like "To aria" → "To haven"
        text = text.replace(f'To {old_id}', f'To {new_name}')
    return text


def update_zone_files():
    """Update all zone .tres files."""
    zones_dir = os.path.join(PROJECT, 'resources', 'world', 'zones')
    updated = 0
    renamed = 0
    processed_ids = set()

    for fname in sorted(os.listdir(zones_dir)):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(zones_dir, fname)
        text = open(path).read()
        original = text

        m_id = re.search(r'^id = "([^"]*)"', text, re.MULTILINE)
        if not m_id:
            continue
        old_id = m_id.group(1)
        if old_id not in OLD_TO_NEW:
            print(f"  SKIP {fname}: zone '{old_id}' not in mapping")
            continue

        # Skip duplicate files for the same zone ID (e.g. aria-g.tres vs aria_g.tres)
        if old_id in processed_ids:
            print(f"  SKIP {fname}: duplicate of already-processed zone '{old_id}'")
            if not DRY_RUN:
                os.remove(path)
            continue
        processed_ids.add(old_id)

        new_id, new_name, new_desc, new_dbase = OLD_TO_NEW[old_id]

        # Update id
        text = re.sub(r'^(id = )"[^"]*"', f'\\1"{new_id}"', text, count=1, flags=re.MULTILINE)

        # Update zone_name
        text = re.sub(r'^(zone_name = )"[^"]*"', f'\\1"{new_name}"', text, count=1, flags=re.MULTILINE)

        # Update description
        if new_desc:
            text = re.sub(r'^(description = )"[^"]*"', lambda m: f'{m.group(1)}"{new_desc}"', text, count=1, flags=re.MULTILINE)

        # Update dungeon_base
        if new_dbase:
            text = re.sub(r'^(dungeon_base = )"[^"]*"', f'\\1"{new_dbase}"', text, count=1, flags=re.MULTILINE)

        # Update exit targets
        for exit_old, (exit_new, _, _, _) in OLD_TO_NEW.items():
            text = text.replace(f'"target": "{exit_old}"', f'"target": "{exit_new}"')

        # Update sign messages — replace old zone names
        # Find sign message strings and replace zone names in them
        def replace_sign_msg(m):
            msg = m.group(1)
            msg = replace_zone_name_in_text(msg)
            return f'"message": "{msg}"'
        text = re.sub(r'"message": "([^"]*)"', replace_sign_msg, text)

        # Update NPC file references that contain old zone id (e.g. "scripts/aria-guard.xml")
        # We keep the NPC script filenames as-is since they're internal references
        # But update shop IDs that reference zone names
        for shop_old_id, (shop_new_id, _, _, _) in OLD_TO_NEW.items():
            text = text.replace(f'"shop": "{shop_old_id}-', f'"shop": "{shop_new_id}-')

        if text != original:
            updated += 1
            if not DRY_RUN:
                with open(path, 'w') as f:
                    f.write(text)

        # Rename file if zone id changed
        if old_id != new_id:
            new_path = os.path.join(zones_dir, f'{new_id}.tres')
            if not DRY_RUN:
                os.rename(path if text == original else path, new_path)
            renamed += 1
            print(f"  {fname} → {new_id}.tres")

    print(f"Zones: {updated} updated, {renamed} renamed")


def update_dungeon_levels():
    """Update dungeon level .tres files — rename IDs and filenames."""
    levels_dir = os.path.join(PROJECT, 'resources', 'levels')
    updated = 0
    renamed = 0

    # Build prefix map: old_prefix → new_prefix
    prefix_map = {}
    for old_dbase, new_dbase in DUNGEON_BASE_MAP.items():
        old_prefix = old_dbase.split('-')[0].lower() if '-' in old_dbase else old_dbase.lower()
        new_prefix = new_dbase.split('-')[0].lower() if '-' in new_dbase else new_dbase.lower()
        prefix_map[old_prefix] = new_prefix

    for fname in sorted(os.listdir(levels_dir)):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(levels_dir, fname)
        text = open(path).read()
        original = text

        # Check if this file's name starts with any old prefix
        fbase = fname[:-5]  # remove .tres
        matched_old = None
        matched_new = None
        for old_p, new_p in sorted(prefix_map.items(), key=lambda x: -len(x[0])):
            if fbase.startswith(old_p):
                matched_old = old_p
                matched_new = new_p
                break

        if not matched_old:
            continue

        # Update the id field inside the file
        m_id = re.search(r'^id = "([^"]*)"', text, re.MULTILINE)
        if m_id:
            old_level_id = m_id.group(1)
            # Map dungeon_base IDs
            if old_level_id in DUNGEON_BASE_MAP:
                new_level_id = DUNGEON_BASE_MAP[old_level_id]
            else:
                # For sub-levels like "Aria-2", map prefix
                new_level_id = old_level_id
                for old_db, new_db in DUNGEON_BASE_MAP.items():
                    old_db_prefix = old_db.split('-')[0]
                    new_db_prefix = new_db.split('-')[0]
                    if old_level_id.startswith(old_db_prefix):
                        new_level_id = new_db_prefix + old_level_id[len(old_db_prefix):]
                        break
            text = re.sub(r'^(id = )"[^"]*"', f'\\1"{new_level_id}"', text, count=1, flags=re.MULTILINE)

        if text != original:
            updated += 1
            if not DRY_RUN:
                with open(path, 'w') as f:
                    f.write(text)

        # Rename file
        new_fname = matched_new + fbase[len(matched_old):] + '.tres'
        if new_fname != fname:
            new_path = os.path.join(levels_dir, new_fname)
            if not DRY_RUN:
                os.rename(path, new_path)
            renamed += 1
            print(f"  {fname} → {new_fname}")

    print(f"Levels: {updated} updated, {renamed} renamed")


def update_quests():
    """Update quest .tres files — location and target_location zone IDs + text."""
    quests_dir = os.path.join(PROJECT, 'resources', 'quests')
    updated = 0

    for fname in sorted(os.listdir(quests_dir)):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(quests_dir, fname)
        text = open(path).read()
        original = text

        # Update location = "old_id" → "new_id"
        for old_id, (new_id, _, _, _) in OLD_TO_NEW.items():
            text = re.sub(
                rf'^(location = )"{re.escape(old_id)}"',
                f'\\1"{new_id}"',
                text, flags=re.MULTILINE
            )
            text = re.sub(
                rf'^(target_location = )"{re.escape(old_id)}"',
                f'\\1"{new_id}"',
                text, flags=re.MULTILINE
            )
            # Also update zone references in quest event params
            text = text.replace(f'"param": "{old_id}"', f'"param": "{new_id}"')
            text = text.replace(f'"zone": "{old_id}"', f'"zone": "{new_id}"')

        # Replace zone names in quest summary and dialogue text
        text = replace_zone_name_in_text(text)

        if text != original:
            updated += 1
            if not DRY_RUN:
                with open(path, 'w') as f:
                    f.write(text)
            print(f"  {fname}: updated")

    print(f"Quests: {updated} updated")


def update_npc_scripts():
    """Update NPC script .tres files."""
    scripts_dir = os.path.join(PROJECT, 'resources', 'npcs', 'scripts')
    if not os.path.isdir(scripts_dir):
        print("NPC scripts dir not found, skipping")
        return
    updated = 0

    for fname in sorted(os.listdir(scripts_dir)):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(scripts_dir, fname)
        text = open(path).read()
        original = text

        # Update zone references
        for old_id, (new_id, _, _, _) in OLD_TO_NEW.items():
            text = text.replace(f'"zone": "{old_id}"', f'"zone": "{new_id}"')

        # Replace zone names in dialogue text
        text = replace_zone_name_in_text(text)

        if text != original:
            updated += 1
            if not DRY_RUN:
                with open(path, 'w') as f:
                    f.write(text)
            print(f"  {fname}: updated")

    print(f"NPC scripts: {updated} updated")


def update_shops():
    """Update shop .tres files — rename IDs with zone prefixes."""
    shops_dir = os.path.join(PROJECT, 'resources', 'shops')
    updated = 0
    renamed = 0

    for fname in sorted(os.listdir(shops_dir)):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(shops_dir, fname)
        text = open(path).read()
        original = text

        # Update shop id field if it starts with an old zone id
        m_id = re.search(r'^id = "([^"]*)"', text, re.MULTILINE)
        if not m_id:
            continue

        shop_id = m_id.group(1)
        new_shop_id = shop_id
        matched = False
        for old_id, (new_id, _, _, _) in sorted(OLD_TO_NEW.items(), key=lambda x: -len(x[0])):
            if shop_id.startswith(old_id + '-') or shop_id.startswith(old_id + '_'):
                sep = shop_id[len(old_id)]
                suffix = shop_id[len(old_id)+1:]
                new_shop_id = f'{new_id}{sep}{suffix}'
                matched = True
                break
            elif shop_id == old_id:
                new_shop_id = new_id
                matched = True
                break

        if matched:
            text = re.sub(r'^(id = )"[^"]*"', f'\\1"{new_shop_id}"', text, count=1, flags=re.MULTILINE)

        # Replace zone names in welcome/dialogue text
        text = replace_zone_name_in_text(text)

        if text != original:
            updated += 1
            if not DRY_RUN:
                with open(path, 'w') as f:
                    f.write(text)

        # Rename file if shop id changed
        if matched and new_shop_id != shop_id:
            new_fname = fname.replace(shop_id, new_shop_id) if shop_id in fname else fname
            if new_fname != fname:
                new_path = os.path.join(shops_dir, new_fname)
                if not DRY_RUN:
                    os.rename(path, new_path)
                renamed += 1
                print(f"  {fname} → {new_fname}")

    print(f"Shops: {updated} updated, {renamed} renamed")


def update_overworld_code():
    """Update hardcoded zone ID references in game scripts."""
    updated = 0

    # Find all .gd files that reference zone IDs
    for root, dirs, files in os.walk(os.path.join(PROJECT, 'scripts')):
        for fname in files:
            if not fname.endswith('.gd'):
                continue
            path = os.path.join(root, fname)
            text = open(path).read()
            original = text

            for old_id, (new_id, _, _, _) in OLD_TO_NEW.items():
                # Replace quoted zone ID references
                text = text.replace(f'"{old_id}"', f'"{new_id}"')

            if text != original:
                updated += 1
                if not DRY_RUN:
                    with open(path, 'w') as f:
                        f.write(text)
                relpath = os.path.relpath(path, PROJECT)
                print(f"  {relpath}: updated")

    # Also check scene files
    for root, dirs, files in os.walk(os.path.join(PROJECT, 'scenes')):
        for fname in files:
            if not fname.endswith('.tscn'):
                continue
            path = os.path.join(root, fname)
            text = open(path).read()
            original = text

            for old_id, (new_id, _, _, _) in OLD_TO_NEW.items():
                text = text.replace(f'"{old_id}"', f'"{new_id}"')

            if text != original:
                updated += 1
                if not DRY_RUN:
                    with open(path, 'w') as f:
                        f.write(text)
                relpath = os.path.relpath(path, PROJECT)
                print(f"  {relpath}: updated")

    print(f"Code/scenes: {updated} files updated")


def update_chunk_metadata():
    """Update zone ID references in chunk metadata if any exist."""
    # Chunks don't contain zone IDs — they're purely tile data
    # But chunks2 dir may have zone references in overworld2 scene
    print("Chunks: no zone ID references (tile data only)")


if __name__ == '__main__':
    if DRY_RUN:
        print("=== DRY RUN — no files will be modified ===\n")

    print("=== World Redesign: Dark Fantasy Re-theming ===\n")

    print("Building lookups...")
    build_lookups()
    print(f"  {len(OLD_TO_NEW)} zone mappings")
    print(f"  {len(OLD_NAME_TO_NEW)} name mappings")
    print(f"  {len(DUNGEON_BASE_MAP)} dungeon base mappings")

    print("\n--- Zone Files ---")
    update_zone_files()

    print("\n--- Dungeon Levels ---")
    update_dungeon_levels()

    print("\n--- Quest Files ---")
    update_quests()

    print("\n--- NPC Scripts ---")
    update_npc_scripts()

    print("\n--- Shop Files ---")
    update_shops()

    print("\n--- Game Code ---")
    update_overworld_code()

    print("\n--- Chunks ---")
    update_chunk_metadata()

    print("\n=== Done! ===")
    if DRY_RUN:
        print("(dry run — no files were modified)")
