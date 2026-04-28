#!/usr/bin/env python3
"""
Import items.csv back into .tres files.
Reads the CSV, updates each item's name, description, slot, rarity, and all stat modifiers.
Non-stat fields (loy_tile_index, bullet_sprite_index, weapon_range, ability, consumable) are preserved.

Run: python3 scripts/tools/import_items_csv.py
Then: python3 scripts/tools/price_items.py   (to recalculate prices from new stats)
"""
import os, re, csv, sys

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')
CSV_PATH = os.path.join(ITEM_DIR, 'items.csv')

STAT_IDS = {
    'MAX_HP': 0, 'MOVE_SPEED': 1, 'ATTACK_DAMAGE': 2, 'ATTACK_SPEED': 3,
    'BULLET_SPEED': 4, 'BULLET_COUNT': 5, 'SPREAD_ANGLE': 6, 'PIERCE_COUNT': 7,
    'BULLET_LIFETIME': 8, 'MAX_MP': 9, 'HP_REGEN': 10, 'MP_REGEN': 11,
    'LUCK': 12, 'CRIT_DAMAGE': 13, 'ARMOR': 14, 'WEIGHT': 15, 'ACCELERATION': 16,
    'DODGE_CHANCE': 17, 'XP_MULT': 18, 'GOLD_MULT': 19, 'PICKUP_RADIUS': 20,
    'COOLDOWN_REDUCTION': 21, 'STEALTH': 22, 'MAX_STAMINA': 23, 'STAMINA_REGEN': 24,
}

SLOT_IDS = {
    'MELEE': 0, 'RANGED': 1, 'MAGIC': 2, 'HELM': 3, 'BODY': 4,
    'SHIELD': 5, 'BOOTS': 6, 'GLOVES': 7, 'RING': 8, 'CLOAK': 9,
    'CONSUMABLE': 10, 'MATERIAL': 11,
}

RARITY_IDS = {'Common': 0, 'Uncommon': 1, 'Rare': 2}

STAT_COLS = [
    'MAX_HP', 'ATTACK_DAMAGE', 'ARMOR', 'MOVE_SPEED', 'ATTACK_SPEED',
    'BULLET_SPEED', 'BULLET_COUNT', 'PIERCE_COUNT', 'BULLET_LIFETIME',
    'MAX_MP', 'HP_REGEN', 'MP_REGEN', 'LUCK', 'CRIT_DAMAGE',
    'DODGE_CHANCE', 'XP_MULT', 'COOLDOWN_REDUCTION', 'STEALTH',
]


def parse_stat_value(val_str):
    """Parse a stat cell value. Returns (flat, percent).
    Formats: '5' or '5.0' -> (5.0, 0.0)
             'p0.1' -> (0.0, 0.1)
             '5+p0.1' -> (5.0, 0.1)
    """
    val_str = str(val_str).strip()
    if not val_str:
        return None
    if '+p' in val_str:
        parts = val_str.split('+p')
        return (float(parts[0]), float(parts[1]))
    if val_str.startswith('p'):
        return (0.0, float(val_str[1:]))
    return (float(val_str), 0.0)


def build_tres(row, modifiers):
    """Build a .tres file from CSV row data and parsed modifiers."""
    has_mods = len(modifiers) > 0
    load_steps = 3 if has_mods else 2

    lines = [
        f'[gd_resource type="Resource" script_class="EquipmentItem" load_steps={load_steps} format=3]',
        '',
        '[ext_resource type="Script" path="res://scripts/stats/equipment_item.gd" id="1"]',
    ]
    if has_mods:
        lines.append('[ext_resource type="Script" path="res://scripts/stats/stat_modifier.gd" id="2"]')
    lines.append('')

    # Sub-resources
    for i, (stat_id, flat, pct) in enumerate(modifiers):
        lines.append(f'[sub_resource type="Resource" id="mod_{i}"]')
        lines.append('script = ExtResource("2")')
        lines.append(f'stat = {stat_id}')
        if flat != 0.0:
            if flat == int(flat):
                lines.append(f'flat_bonus = {int(flat)}.0')
            else:
                lines.append(f'flat_bonus = {flat}')
        if pct != 0.0:
            lines.append(f'percent_bonus = {pct}')
        lines.append('')

    lines.append('[resource]')
    lines.append('script = ExtResource("1")')
    lines.append(f'item_name = "{row["item_name"]}"')

    if row.get('loy_tile_index'):
        lines.append(f'loy_tile_index = {row["loy_tile_index"]}')

    lines.append(f'description = "{row["description"]}"')

    slot_id = SLOT_IDS.get(row['slot'], int(row['slot']) if row['slot'].isdigit() else 11)
    lines.append(f'slot_type = {slot_id}')

    if has_mods:
        mod_refs = ', '.join(f'SubResource("mod_{i}")' for i in range(len(modifiers)))
        lines.append(f'modifiers = Array[ExtResource("2")]([{mod_refs}])')

    rarity_id = RARITY_IDS.get(row['rarity'], int(row['rarity']) if row['rarity'].isdigit() else 0)
    lines.append(f'rarity = {rarity_id}')
    lines.append(f'buy_price = {row.get("buy_price", "0")}')
    lines.append(f'sell_value = {row.get("sell_value", "0")}')

    if row.get('bullet_sprite_index'):
        lines.append(f'bullet_sprite_index = {row["bullet_sprite_index"]}')
    if row.get('weapon_range'):
        lines.append(f'weapon_range = {row["weapon_range"]}')
    if row.get('weapon_type'):
        lines.append(f'weapon_type = "{row["weapon_type"]}"')
    if row.get('weapon_type'):
        lines.append(f'weapon_type = "{row["weapon_type"]}"')
    if row.get('weapon_type'):
        lines.append(f'weapon_type = "{row["weapon_type"]}"')
    if row.get('ability_id'):
        lines.append(f'ability_id = "{row["ability_id"]}"')
    if row.get('heal_hp'):
        lines.append(f'heal_hp = {row["heal_hp"]}')
    if row.get('heal_mp'):
        lines.append(f'heal_mp = {row["heal_mp"]}')
    if row.get('use_effect'):
        lines.append(f'use_effect = "{row["use_effect"]}"')

    lines.append('')
    return '\n'.join(lines)


def main():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: {CSV_PATH} not found. Run export_items_csv.py first.")
        sys.exit(1)

    with open(CSV_PATH, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    print(f"Importing {len(rows)} items from CSV...\n")

    modified = 0
    errors = 0

    for row in rows:
        filename = row['file']
        filepath = os.path.join(ITEM_DIR, filename)

        if not os.path.exists(filepath):
            print(f"  WARNING: {filename} not found, skipping")
            errors += 1
            continue

        # Parse stat modifiers from CSV columns
        modifiers = []
        for stat_name in STAT_COLS:
            val = row.get(stat_name, '').strip()
            if not val:
                continue
            parsed = parse_stat_value(val)
            if parsed is None:
                continue
            flat, pct = parsed
            if flat == 0 and pct == 0:
                continue
            stat_id = STAT_IDS[stat_name]
            modifiers.append((stat_id, flat, pct))

        # Build and write
        content = build_tres(row, modifiers)

        with open(filepath, 'w') as f:
            f.write(content)

        modified += 1

    print(f"\nImported {modified} items ({errors} errors)")
    print(f"Now run: python3 scripts/tools/price_items.py")


if __name__ == '__main__':
    main()
