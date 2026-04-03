#!/usr/bin/env python3
"""
Export all LoY items to a CSV for editing in a spreadsheet.
Run: python3 scripts/tools/export_items_csv.py
Output: resources/items/loy/items.csv
"""
import os, re, glob, csv

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')
OUTPUT = os.path.join(ITEM_DIR, 'items.csv')

STAT_NAMES = {
    0: 'MAX_HP', 1: 'MOVE_SPEED', 2: 'ATTACK_DAMAGE', 3: 'ATTACK_SPEED',
    4: 'BULLET_SPEED', 5: 'BULLET_COUNT', 6: 'SPREAD_ANGLE', 7: 'PIERCE_COUNT',
    8: 'BULLET_LIFETIME', 9: 'MAX_MP', 10: 'HP_REGEN', 11: 'MP_REGEN',
    12: 'LUCK', 13: 'CRIT_DAMAGE', 14: 'ARMOR', 15: 'WEIGHT', 16: 'ACCELERATION',
    17: 'DODGE_CHANCE', 18: 'XP_MULT', 19: 'GOLD_MULT', 20: 'PICKUP_RADIUS',
    21: 'COOLDOWN_REDUCTION', 22: 'STEALTH', 23: 'MAX_STAMINA', 24: 'STAMINA_REGEN',
}

SLOT_NAMES = {
    0: 'MELEE', 1: 'RANGED', 2: 'MAGIC', 3: 'HELM', 4: 'BODY',
    5: 'SHIELD', 6: 'BOOTS', 7: 'GLOVES', 8: 'RING', 9: 'CLOAK',
    10: 'CONSUMABLE', 11: 'MATERIAL',
}

RARITY_NAMES = {0: 'Common', 1: 'Uncommon', 2: 'Rare'}

# Stat columns we include in CSV (the ones actually used)
STAT_COLS = [
    'MAX_HP', 'ATTACK_DAMAGE', 'ARMOR', 'MOVE_SPEED', 'ATTACK_SPEED',
    'BULLET_SPEED', 'BULLET_COUNT', 'PIERCE_COUNT', 'BULLET_LIFETIME',
    'MAX_MP', 'HP_REGEN', 'MP_REGEN', 'LUCK', 'CRIT_DAMAGE',
    'DODGE_CHANCE', 'XP_MULT', 'COOLDOWN_REDUCTION', 'STEALTH',
]


def get_field(content, field):
    m = re.search(rf'^{field}\s*=\s*(.+)$', content, re.MULTILINE)
    return m.group(1).strip() if m else ''


def get_modifiers(content):
    """Returns dict of stat_name -> flat_bonus."""
    mods = {}
    for m in re.finditer(
        r'\[sub_resource[^\]]*\]\s*script\s*=\s*ExtResource\("2"\)\s*'
        r'stat\s*=\s*(\d+)\s*'
        r'(?:flat_bonus\s*=\s*([\d.]+)\s*)?'
        r'(?:percent_bonus\s*=\s*([\d.]+)\s*)?',
        content
    ):
        stat_id = int(m.group(1))
        flat = float(m.group(2)) if m.group(2) else 0.0
        pct = float(m.group(3)) if m.group(3) else 0.0
        name = STAT_NAMES.get(stat_id, f'STAT_{stat_id}')
        # Store flat; if percent, store as "p0.1" format
        if pct > 0 and flat == 0:
            mods[name] = f'p{pct}'
        elif pct > 0:
            mods[name] = f'{flat}+p{pct}'
        else:
            mods[name] = flat
    return mods


def main():
    files = sorted(glob.glob(os.path.join(ITEM_DIR, '*.tres')))

    headers = [
        'file', 'item_name', 'description', 'slot', 'rarity',
        'buy_price', 'sell_value', 'loy_tile_index',
        'bullet_sprite_index', 'weapon_range', 'weapon_type',
        'ability_id', 'heal_hp', 'heal_mp', 'use_effect',
    ] + STAT_COLS

    rows = []
    for filepath in files:
        with open(filepath, 'r') as f:
            content = f.read()

        fname = os.path.basename(filepath)
        name_raw = get_field(content, 'item_name')
        name = name_raw.strip('"') if name_raw else fname.replace('.tres', '')
        desc_raw = get_field(content, 'description')
        desc = desc_raw.strip('"') if desc_raw else ''

        slot_num = int(get_field(content, 'slot_type') or '11')
        rarity_num = int(get_field(content, 'rarity') or '0')

        row = {
            'file': fname,
            'item_name': name,
            'description': desc,
            'slot': SLOT_NAMES.get(slot_num, str(slot_num)),
            'rarity': RARITY_NAMES.get(rarity_num, str(rarity_num)),
            'buy_price': get_field(content, 'buy_price') or '0',
            'sell_value': get_field(content, 'sell_value') or '0',
            'loy_tile_index': get_field(content, 'loy_tile_index') or '',
            'bullet_sprite_index': get_field(content, 'bullet_sprite_index') or '',
            'weapon_range': get_field(content, 'weapon_range') or '',
            'weapon_type': get_field(content, 'weapon_type').strip('"') if get_field(content, 'weapon_type') else '',
            'ability_id': get_field(content, 'ability_id').strip('"') if get_field(content, 'ability_id') else '',
            'heal_hp': get_field(content, 'heal_hp') or '',
            'heal_mp': get_field(content, 'heal_mp') or '',
            'use_effect': get_field(content, 'use_effect').strip('"') if get_field(content, 'use_effect') else '',
        }

        mods = get_modifiers(content)
        for stat_col in STAT_COLS:
            row[stat_col] = mods.get(stat_col, '')

        rows.append(row)

    with open(OUTPUT, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Exported {len(rows)} items to {OUTPUT}")
    print(f"Open in Numbers/Excel/Google Sheets to edit.")
    print(f"After editing, run: python3 scripts/tools/import_items_csv.py")


if __name__ == '__main__':
    main()
