#!/usr/bin/env python3
"""
Fix broken consumables in items.csv by assigning correct use_effect / heal values.
Run after export_items_csv.py, before import_items_csv.py.
"""
import os, csv

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')
CSV_PATH = os.path.join(ITEM_DIR, 'items.csv')

# Fixes: file_basename -> {field: value}
FIXES = {
    'cure': {'use_effect': 'cure_poison'},
    'steel_skin': {'use_effect': 'iron_skin'},
    'protect': {'use_effect': 'iron_skin'},
    'invisibility': {'use_effect': 'stealth_buff'},
    'stealth': {'use_effect': 'stealth_buff'},
    'stun': {'use_effect': 'stun_aoe'},
    'distraction': {'use_effect': 'stun_aoe'},
    'push': {'use_effect': 'pushback_aoe'},
    'shield_bash_consumable': {'use_effect': 'pushback_aoe'},
    'bezerk': {'use_effect': 'berserk'},
    'charge': {'use_effect': 'speed_boost'},
    'fire_fists': {'use_effect': 'damage_buff'},
    'field_dressing': {'heal_hp': '5'},
    'first_aid': {'heal_hp': '15'},
    'anger': {'heal_mp': '15'},
    'focus': {'heal_mp': '20'},
    'fire_fish': {'heal_mp': '10'},
    'octopus': {'heal_mp': '25'},
    'teleport': {'use_effect': 'town_portal'},
    # Tools → MATERIAL slot
    'fishing_pole': {'slot': 'MATERIAL'},
    'lava_rod': {'slot': 'MATERIAL'},
    'spade': {'slot': 'MATERIAL'},
}

def main():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: {CSV_PATH} not found")
        return

    with open(CSV_PATH, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames

    fixed = 0
    for row in rows:
        basename = row['file'].replace('.tres', '')
        if basename in FIXES:
            for key, val in FIXES[basename].items():
                old = row.get(key, '')
                if old != val:
                    print(f"  {basename}: {key} = '{old}' → '{val}'")
                    row[key] = val
                    fixed += 1

    with open(CSV_PATH, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nFixed {fixed} fields")

if __name__ == '__main__':
    main()
