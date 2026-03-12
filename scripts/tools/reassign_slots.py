#!/usr/bin/env python3
"""Reassign slot_type in all EquipmentItem .tres files from old 5-slot enum to new 12-slot enum.

Old enum:  0=WEAPON, 1=ARMOR, 2=ACCESSORY, 3=CONSUMABLE, 4=MATERIAL
New enum:  0=WEAPON_MELEE, 1=WEAPON_RANGED, 2=WEAPON_MAGIC,
           3=HELM, 4=BODY, 5=SHIELD,
           6=BOOTS, 7=GLOVES, 8=RING, 9=CLOAK,
           10=CONSUMABLE, 11=MATERIAL
"""

import os, re, sys

ITEMS_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "resources", "items", "loy")

# Keyword → new slot_type mappings
WEAPON_MELEE_KW = ["sword", "blade", "axe", "dagger", "shiv", "knife", "club", "mace",
                   "hammer", "spear", "cutlass", "cleaver", "flail", "nunchucks", "lance",
                   "scimitar", "rapier", "katana", "halberd", "pike", "saber", "sabre",
                   "trident", "whip", "glaive"]
WEAPON_RANGED_KW = ["bow", "crossbow"]
WEAPON_MAGIC_KW = ["staff", "wand", "book", "sceptre", "ankh", "rod", "tome", "bible",
                    "grimoire", "orb", "crystal ball", "focus"]
HELM_KW = ["helm", "helmet", "hood", "crown", "bandana", "fez", "coif", "patch",
            "antlers", "hat", "tiara", "circlet", "headband", "mask", "cap", "beret"]
BODY_KW = ["armor", "armour", "mail", "plate", "tunic", "robe", "vest", "chainmail",
            "breastplate", "cuirass", "jerkin", "hauberk", "brigandine", "leather"]
SHIELD_KW = ["shield", "buckler"]
BOOTS_KW = ["boot", "sandal", "slipper", "clog", "shoe", "greave", "sabatons"]
GLOVES_KW = ["glove", "gauntlet", "bracer", "claw", "fist", "knuckle", "vambrace"]
RING_KW = ["ring", "band", "amulet", "necklace", "pendant", "charm", "talisman", "trinket", "locket"]
CLOAK_KW = ["cloak", "cape", "mantle", "shroud", "scarf", "shawl"]

def match_keywords(name_lower, keywords):
    for kw in keywords:
        if kw in name_lower:
            return True
    return False

def get_new_slot(old_slot, item_name):
    lower = item_name.lower()

    if old_slot == 0:  # WEAPON
        if match_keywords(lower, WEAPON_RANGED_KW):
            return 1  # WEAPON_RANGED
        if match_keywords(lower, WEAPON_MAGIC_KW):
            return 2  # WEAPON_MAGIC
        return 0  # WEAPON_MELEE (default for weapons)

    if old_slot == 1:  # ARMOR
        if match_keywords(lower, HELM_KW):
            return 3  # HELM
        if match_keywords(lower, SHIELD_KW):
            return 5  # SHIELD
        if match_keywords(lower, BOOTS_KW):
            return 6  # BOOTS
        if match_keywords(lower, GLOVES_KW):
            return 7  # GLOVES
        return 4  # BODY (default for armor)

    if old_slot == 2:  # ACCESSORY
        if match_keywords(lower, BOOTS_KW):
            return 6  # BOOTS
        if match_keywords(lower, GLOVES_KW):
            return 7  # GLOVES
        if match_keywords(lower, CLOAK_KW):
            return 9  # CLOAK
        if match_keywords(lower, RING_KW):
            return 8  # RING
        return 8  # RING (default for accessories)

    if old_slot == 3:  # CONSUMABLE
        # Check if it's actually an arrow/material
        if "arrow" in lower:
            return 11  # MATERIAL
        return 10  # CONSUMABLE

    if old_slot == 4:  # MATERIAL
        return 11  # MATERIAL

    return old_slot  # fallback

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Extract item_name
    name_match = re.search(r'item_name\s*=\s*"([^"]*)"', content)
    if not name_match:
        return None, None, None

    item_name = name_match.group(1)

    # Extract old slot_type
    slot_match = re.search(r'slot_type\s*=\s*(\d+)', content)
    if not slot_match:
        return item_name, None, None

    old_slot = int(slot_match.group(1))
    new_slot = get_new_slot(old_slot, item_name)

    if old_slot != new_slot:
        content = re.sub(r'(slot_type\s*=\s*)\d+', f'\\g<1>{new_slot}', content)
        with open(filepath, 'w') as f:
            f.write(content)

    return item_name, old_slot, new_slot

SLOT_NAMES = {
    0: "WEAPON_MELEE", 1: "WEAPON_RANGED", 2: "WEAPON_MAGIC",
    3: "HELM", 4: "BODY", 5: "SHIELD",
    6: "BOOTS", 7: "GLOVES", 8: "RING", 9: "CLOAK",
    10: "CONSUMABLE", 11: "MATERIAL"
}

def main():
    items_dir = os.path.abspath(ITEMS_DIR)
    if not os.path.isdir(items_dir):
        print(f"ERROR: Items directory not found: {items_dir}")
        sys.exit(1)

    files = sorted([f for f in os.listdir(items_dir) if f.endswith('.tres')])
    print(f"Processing {len(files)} item files in {items_dir}\n")

    changed = 0
    unchanged = 0
    slot_counts = {}

    for fname in files:
        filepath = os.path.join(items_dir, fname)
        item_name, old_slot, new_slot = process_file(filepath)

        if item_name is None:
            print(f"  SKIP {fname} (no item_name)")
            continue

        new_name = SLOT_NAMES.get(new_slot, "?")
        slot_counts[new_name] = slot_counts.get(new_name, 0) + 1

        if old_slot != new_slot:
            print(f"  {item_name}: {old_slot} -> {new_slot} ({new_name})")
            changed += 1
        else:
            unchanged += 1

    print(f"\n--- Summary ---")
    print(f"Changed: {changed}, Unchanged: {unchanged}, Total: {changed + unchanged}")
    print(f"\nSlot distribution:")
    for slot_name in SLOT_NAMES.values():
        count = slot_counts.get(slot_name, 0)
        if count > 0:
            print(f"  {slot_name}: {count}")

if __name__ == "__main__":
    main()
