#!/usr/bin/env python3
"""
Auto-classify weapons by name into weapon_type categories.
Reads items.csv, assigns weapon_type based on item name patterns, writes back.

Run: python3 scripts/tools/export_items_csv.py   (first, to get fresh CSV)
     python3 scripts/tools/classify_weapons.py
     python3 scripts/tools/import_items_csv.py    (to write back to .tres)
"""
import os, csv, re

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')
CSV_PATH = os.path.join(ITEM_DIR, 'items.csv')

# Name patterns → weapon_type (checked in order, first match wins)
# Each entry: (regex_pattern, weapon_type, slot_filter)
# slot_filter: None = any weapon slot, or specific slot name
CLASSIFY_RULES = [
    # Melee weapons
    (r'(?i)\b(dagger|knife|shiv|stiletto)\b', 'dagger', 'MELEE'),
    (r'(?i)\b(axe|hatchet|cleaver|battleaxe)\b', 'axe', 'MELEE'),
    (r'(?i)\b(club|mace|cudgel)\b', 'club', 'MELEE'),
    (r'(?i)\b(hammer|warhammer|maul|sledge)\b', 'hammer', 'MELEE'),
    (r'(?i)(flail|nunchuck|nunchuk|juggling|morning\s*star)', 'flail', 'MELEE'),
    (r'(?i)\b(spear|trident|lance|pike|javelin|halberd|glaive|polearm)\b', 'spear', 'MELEE'),
    (r'(?i)\b(star|throwing|shuriken|ronia)\b', 'throwing', 'MELEE'),
    # Ranged weapons
    (r'(?i)\b(crossbow|xbow)\b', 'crossbow', 'RANGED'),
    (r'(?i)\bshort\s*bow\b', 'short_bow', 'RANGED'),
    # Magic weapons — wands/sceptres are staff class
    (r'(?i)\b(wand|sceptre|scepter|ankh|orb|rod)\b', 'staff', 'MAGIC'),
]


def classify(name, slot):
    """Classify a weapon item by name and slot."""
    if slot not in ('MELEE', 'RANGED', 'MAGIC'):
        return ''

    for pattern, wtype, slot_filter in CLASSIFY_RULES:
        if slot_filter and slot != slot_filter:
            continue
        if re.search(pattern, name):
            return wtype

    # Defaults by slot
    if slot == 'MELEE':
        return 'sword'
    if slot == 'RANGED':
        return 'bow'
    if slot == 'MAGIC':
        return 'staff'
    return ''


def main():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: {CSV_PATH} not found. Run export_items_csv.py first.")
        return

    with open(CSV_PATH, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames

    if 'weapon_type' not in fieldnames:
        print("ERROR: weapon_type column not in CSV. Re-run export_items_csv.py first.")
        return

    classified = 0
    skipped = 0
    for row in rows:
        slot = row.get('slot', '')
        name = row.get('item_name', '')

        # Only classify weapon slots
        if slot not in ('MELEE', 'RANGED', 'MAGIC'):
            skipped += 1
            continue

        # Don't overwrite manually set types
        if row.get('weapon_type', '').strip():
            skipped += 1
            continue

        wtype = classify(name, slot)
        if wtype:
            row['weapon_type'] = wtype
            classified += 1
            print(f"  {name:30s} ({slot:6s}) → {wtype}")

    with open(CSV_PATH, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nClassified {classified} weapons ({skipped} skipped)")
    print(f"Review the CSV, then run: python3 scripts/tools/import_items_csv.py")


if __name__ == '__main__':
    main()
