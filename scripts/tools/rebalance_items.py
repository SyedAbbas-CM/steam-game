#!/usr/bin/env python3
"""
Rebalance all 385 LoY equipment items.

- Weapons get damage scaled by rarity + buy_price
- Armor gets HP + armor scaled by rarity + buy_price
- Every equippable item gets a secondary stat based on slot
- Name keywords influence secondary stat choice
- Consumables and materials are skipped
- Items already at correct primary stat keep their value

Run: python3 scripts/tools/rebalance_items.py
Then: python3 scripts/tools/price_items.py  (to re-price based on new stats)
"""
import os
import re
import glob
import math
import hashlib

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')

# --- Stat type enum values ---
STAT = {
    'MAX_HP': 0, 'MOVE_SPEED': 1, 'ATTACK_DAMAGE': 2, 'ATTACK_SPEED': 3,
    'BULLET_SPEED': 4, 'BULLET_COUNT': 5, 'SPREAD_ANGLE': 6, 'PIERCE_COUNT': 7,
    'BULLET_LIFETIME': 8, 'MAX_MP': 9, 'HP_REGEN': 10, 'MP_REGEN': 11,
    'LUCK': 12, 'CRIT_DAMAGE': 13, 'ARMOR': 14, 'DODGE_CHANCE': 17,
    'XP_MULT': 18, 'COOLDOWN_REDUCTION': 21, 'STEALTH': 22,
}

# --- Slot types ---
WEAPON_MELEE = 0
WEAPON_RANGED = 1
WEAPON_MAGIC = 2
HELM = 3
BODY = 4
SHIELD = 5
BOOTS = 6
GLOVES = 7
RING = 8
CLOAK = 9
CONSUMABLE = 10
MATERIAL = 11

WEAPON_SLOTS = {WEAPON_MELEE, WEAPON_RANGED, WEAPON_MAGIC}
ARMOR_SLOTS = {HELM, BODY, SHIELD, BOOTS, GLOVES, RING, CLOAK}
SKIP_SLOTS = {CONSUMABLE, MATERIAL}

# --- Damage curves (rarity -> (min_price, max_price, min_dmg, max_dmg)) ---
DAMAGE_CURVES = {
    0: (10, 80, 2, 8),
    1: (50, 300, 6, 18),
    2: (200, 1500, 12, 52),
}

# --- HP curves (rarity -> (min_price, max_price, min_hp, max_hp)) ---
HP_CURVES = {
    0: (10, 80, 2, 8),
    1: (50, 300, 5, 15),
    2: (200, 1500, 8, 25),
}

# --- Armor curves (rarity -> (min_armor, max_armor)) ---
ARMOR_CURVES = {
    0: (0, 2),
    1: (1, 4),
    2: (2, 8),
}

# --- Secondary stat pools per slot ---
SECONDARY_POOLS = {
    WEAPON_MELEE:  [STAT['ATTACK_SPEED'], STAT['CRIT_DAMAGE'], STAT['ARMOR']],
    WEAPON_RANGED: [STAT['BULLET_SPEED'], STAT['PIERCE_COUNT'], STAT['ATTACK_SPEED']],
    WEAPON_MAGIC:  [STAT['BULLET_COUNT'], STAT['COOLDOWN_REDUCTION'], STAT['MAX_MP']],
    HELM:   [STAT['CRIT_DAMAGE'], STAT['MP_REGEN'], STAT['LUCK']],
    BODY:   [STAT['ARMOR']],  # always armor
    SHIELD: [STAT['ARMOR'], STAT['DODGE_CHANCE']],
    BOOTS:  [STAT['MOVE_SPEED']],
    GLOVES: [STAT['ATTACK_SPEED']],
    RING:   [STAT['CRIT_DAMAGE'], STAT['LUCK'], STAT['DODGE_CHANCE'], STAT['XP_MULT']],
    CLOAK:  [STAT['STEALTH'], STAT['DODGE_CHANCE'], STAT['MOVE_SPEED']],
}

# --- Name keyword -> stat override ---
NAME_KEYWORDS = {
    'swift': STAT['ATTACK_SPEED'], 'quick': STAT['ATTACK_SPEED'], 'light': STAT['ATTACK_SPEED'],
    'iron': STAT['ARMOR'], 'steel': STAT['ARMOR'], 'plate': STAT['ARMOR'], 'heavy': STAT['ARMOR'],
    'shadow': STAT['CRIT_DAMAGE'], 'dark': STAT['CRIT_DAMAGE'], 'night': STAT['CRIT_DAMAGE'],
    'holy': STAT['HP_REGEN'], 'blessed': STAT['HP_REGEN'], 'divine': STAT['HP_REGEN'],
    'hunter': STAT['PIERCE_COUNT'], 'hawk': STAT['PIERCE_COUNT'], 'eagle': STAT['PIERCE_COUNT'],
    'frost': STAT['BULLET_SPEED'], 'ice': STAT['BULLET_SPEED'], 'frozen': STAT['BULLET_SPEED'],
    'fire': STAT['CRIT_DAMAGE'], 'flame': STAT['CRIT_DAMAGE'], 'burning': STAT['CRIT_DAMAGE'],
    'lucky': STAT['LUCK'], 'fortune': STAT['LUCK'],
}

# --- Secondary stat value ranges by rarity (flat_bonus) ---
# For percent-style stats (attack_speed, crit_damage, dodge_chance, etc.), use smaller values
PERCENT_STATS = {
    STAT['ATTACK_SPEED'], STAT['CRIT_DAMAGE'], STAT['DODGE_CHANCE'],
    STAT['XP_MULT'], STAT['COOLDOWN_REDUCTION'], STAT['STEALTH'],
    STAT['MOVE_SPEED'], STAT['HP_REGEN'], STAT['MP_REGEN'],
}

def secondary_value(stat_id, rarity):
    """Return a secondary stat flat_bonus value based on stat type and rarity."""
    if stat_id == STAT['PIERCE_COUNT']:
        return [1, 1, 2][rarity]
    if stat_id == STAT['BULLET_COUNT']:
        return [1, 1, 2][rarity]
    if stat_id == STAT['BULLET_SPEED']:
        return [0.1, 0.15, 0.2][rarity]
    if stat_id == STAT['MAX_MP']:
        return [5, 10, 20][rarity]
    if stat_id == STAT['ARMOR']:
        a_min, a_max = ARMOR_CURVES[rarity]
        return round((a_min + a_max) / 2)
    if stat_id in PERCENT_STATS:
        return [0.05, 0.1, 0.15][rarity]
    # Fallback flat stats
    return [1, 2, 4][rarity]


def lerp_price(price, rarity, curves):
    """Interpolate a value based on price within a rarity band."""
    min_p, max_p, min_v, max_v = curves[rarity]
    price = max(min_p, min(max_p, price))
    t = (price - min_p) / max(1, max_p - min_p)
    return round(min_v + t * (max_v - min_v))


def get_field(content, field):
    m = re.search(rf'^{field}\s*=\s*(.+)$', content, re.MULTILINE)
    return m.group(1).strip() if m else None


def get_existing_modifiers(content):
    """Parse all sub_resource modifiers. Returns list of (stat_id, flat_bonus, percent_bonus)."""
    mods = []
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
        mods.append((stat_id, flat, pct))
    return mods


def deterministic_pick(pool, item_name):
    """Pick a secondary stat from pool deterministically based on item name."""
    h = int(hashlib.md5(item_name.encode()).hexdigest(), 16)
    return pool[h % len(pool)]


def pick_secondary(slot, item_name, existing_stats):
    """Choose a secondary stat for this item, avoiding duplicates with primary."""
    name_lower = item_name.lower()

    # Check name keywords first
    for keyword, stat_id in NAME_KEYWORDS.items():
        if keyword in name_lower.split() or keyword in name_lower.replace('-', ' ').split():
            if stat_id not in existing_stats:
                return stat_id

    pool = SECONDARY_POOLS.get(slot, [])
    if not pool:
        return None

    # Filter out stats already on the item
    available = [s for s in pool if s not in existing_stats]
    if not available:
        return None

    return deterministic_pick(available, item_name)


def build_tres(item_data, modifiers):
    """Build a complete .tres file string."""
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

    # Write sub-resources for modifiers
    for i, (stat_id, flat, pct) in enumerate(modifiers):
        lines.append(f'[sub_resource type="Resource" id="mod_{i}"]')
        lines.append('script = ExtResource("2")')
        lines.append(f'stat = {stat_id}')
        if flat != 0.0:
            # Use int format if whole number
            if flat == int(flat):
                lines.append(f'flat_bonus = {int(flat)}.0')
            else:
                lines.append(f'flat_bonus = {flat}')
        if pct != 0.0:
            lines.append(f'percent_bonus = {pct}')
        lines.append('')

    lines.append('[resource]')
    lines.append('script = ExtResource("1")')

    # Write fields in canonical order
    field_order = [
        'item_name', 'loy_tile_index', 'description', 'slot_type',
        'modifiers', 'rarity', 'buy_price', 'sell_value',
        'bullet_sprite_index', 'weapon_range',
        'ability_id', 'ability_mp_cost', 'ability_cooldown',
        'heal_hp', 'heal_mp', 'use_effect',
    ]

    for field in field_order:
        if field == 'modifiers' and has_mods:
            mod_refs = ', '.join(f'SubResource("mod_{i}")' for i in range(len(modifiers)))
            lines.append(f'modifiers = Array[ExtResource("2")]([{mod_refs}])')
        elif field in item_data:
            lines.append(f'{field} = {item_data[field]}')

    lines.append('')
    return '\n'.join(lines)


def parse_item(content):
    """Parse an item .tres file into field dict and existing modifiers."""
    item_data = {}
    fields = [
        'item_name', 'loy_tile_index', 'description', 'slot_type',
        'rarity', 'buy_price', 'sell_value',
        'bullet_sprite_index', 'weapon_range',
        'ability_id', 'ability_mp_cost', 'ability_cooldown',
        'heal_hp', 'heal_mp', 'use_effect',
    ]
    for field in fields:
        val = get_field(content, field)
        if val is not None:
            item_data[field] = val

    modifiers = get_existing_modifiers(content)
    return item_data, modifiers


def rebalance_item(filepath):
    """Rebalance a single item. Returns (name, changes) or None if skipped."""
    with open(filepath, 'r') as f:
        content = f.read()

    item_data, existing_mods = parse_item(content)

    slot = int(item_data.get('slot_type', '11'))
    if slot in SKIP_SLOTS:
        return None

    rarity = int(item_data.get('rarity', '0'))
    buy_price = int(item_data.get('buy_price', '15'))
    item_name = item_data.get('item_name', '"Unknown"').strip('"')

    changes = []
    new_mods = list(existing_mods)
    existing_stat_ids = {m[0] for m in existing_mods}

    # --- Primary stat ---
    if slot in WEAPON_SLOTS:
        # Weapon: ensure ATTACK_DAMAGE
        target_dmg = lerp_price(buy_price, rarity, DAMAGE_CURVES)
        current_dmg = 0
        dmg_idx = None
        for i, (sid, flat, pct) in enumerate(new_mods):
            if sid == STAT['ATTACK_DAMAGE']:
                current_dmg = flat
                dmg_idx = i
                break

        if current_dmg < target_dmg:
            if dmg_idx is not None:
                new_mods[dmg_idx] = (STAT['ATTACK_DAMAGE'], float(target_dmg), 0.0)
                changes.append(f'damage {current_dmg}->{target_dmg}')
            else:
                new_mods.insert(0, (STAT['ATTACK_DAMAGE'], float(target_dmg), 0.0))
                existing_stat_ids.add(STAT['ATTACK_DAMAGE'])
                changes.append(f'added damage={target_dmg}')

    elif slot in ARMOR_SLOTS:
        # Armor: ensure MAX_HP (except RING which may have damage)
        if slot == RING:
            # Rings: add HP if no damage, keep damage if present
            has_dmg = STAT['ATTACK_DAMAGE'] in existing_stat_ids
            has_hp = STAT['MAX_HP'] in existing_stat_ids
            if not has_dmg and not has_hp:
                target_hp = lerp_price(buy_price, rarity, HP_CURVES)
                new_mods.insert(0, (STAT['MAX_HP'], float(target_hp), 0.0))
                existing_stat_ids.add(STAT['MAX_HP'])
                changes.append(f'added hp={target_hp}')
            elif has_hp:
                for i, (sid, flat, pct) in enumerate(new_mods):
                    if sid == STAT['MAX_HP']:
                        target_hp = lerp_price(buy_price, rarity, HP_CURVES)
                        if flat < target_hp:
                            new_mods[i] = (STAT['MAX_HP'], float(target_hp), pct)
                            changes.append(f'hp {flat}->{target_hp}')
                        break
        else:
            target_hp = lerp_price(buy_price, rarity, HP_CURVES)
            current_hp = 0
            hp_idx = None
            for i, (sid, flat, pct) in enumerate(new_mods):
                if sid == STAT['MAX_HP']:
                    current_hp = flat
                    hp_idx = i
                    break

            if current_hp < target_hp:
                if hp_idx is not None:
                    new_mods[hp_idx] = (STAT['MAX_HP'], float(target_hp), 0.0)
                    changes.append(f'hp {current_hp}->{target_hp}')
                else:
                    new_mods.insert(0, (STAT['MAX_HP'], float(target_hp), 0.0))
                    existing_stat_ids.add(STAT['MAX_HP'])
                    changes.append(f'added hp={target_hp}')

    # --- Secondary stat ---
    existing_stat_ids = {m[0] for m in new_mods}
    secondary = pick_secondary(slot, item_name, existing_stat_ids)
    if secondary is not None:
        sec_val = secondary_value(secondary, rarity)
        new_mods.append((secondary, float(sec_val), 0.0))
        stat_name = [k for k, v in STAT.items() if v == secondary][0]
        changes.append(f'+{stat_name}={sec_val}')

    if not changes:
        return None

    # Rebuild the .tres file
    new_content = build_tres(item_data, new_mods)

    with open(filepath, 'w') as f:
        f.write(new_content)

    return item_name, changes


def main():
    files = sorted(glob.glob(os.path.join(ITEM_DIR, '*.tres')))
    print(f"Scanning {len(files)} items...\n")

    modified = 0
    skipped = 0
    stat_usage = {}

    for filepath in files:
        result = rebalance_item(filepath)
        if result is None:
            skipped += 1
            continue

        name, changes = result
        modified += 1
        print(f"  {name}: {', '.join(changes)}")

        # Track stat usage
        for change in changes:
            for stat_name in STAT:
                if stat_name in change:
                    stat_usage[stat_name] = stat_usage.get(stat_name, 0) + 1

    print(f"\n--- Summary ---")
    print(f"Modified: {modified}")
    print(f"Skipped (consumable/material): {skipped}")
    print(f"\nStat type usage:")
    for stat_name, count in sorted(stat_usage.items(), key=lambda x: -x[1]):
        print(f"  {stat_name}: {count} items")


if __name__ == '__main__':
    main()
