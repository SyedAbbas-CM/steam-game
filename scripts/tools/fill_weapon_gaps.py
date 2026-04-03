#!/usr/bin/env python3
"""
Fill weapon tier gaps by adding new items to items.csv AND creating .tres files.

Design philosophy:
- Not every weapon type needs T5. T5 = endgame legendary, only for "main" weapon types.
- Some types naturally cap at T3 or T4 (e.g. short_bow, throwing).
- New items get thematic names matching the tier's dungeon theme.
- Tile indices reuse existing weapon sprites (same type, different tier).

Tier themes:
  T0: Basic/starter (graveyard overworld start)
  T1: Graveyard Overworld drops (common monsters)
  T2: Aria Dungeon (7 floors)
  T3: Graveyard Dungeon (3 floors)
  T4: Farm Dungeon (6 floors)
  T5: Wilderness / Hidden Forest / Boss drops
"""
import os, csv

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')
CSV_PATH = os.path.join(ITEM_DIR, 'items.csv')

# Each new item: (filename, item_name, description, slot, weapon_type, rarity, damage, tile_idx, bullet_sprite, weapon_range, extra_stats)
# extra_stats is a dict of stat_col -> value string
# Tile indices reuse existing weapon sprites of same type where possible

NEW_ITEMS = [
    # ========== AXE ==========
    # T0: starter axe for potential axe-wielding merc/warrior
    ('hand_axe', 'Hand Axe', 'A small one-handed axe', 'MELEE', 'axe', 'Common', 2, 281, 144, 1.3, {}),
    # T2: Aria dungeon axe
    ('battle_axe', 'Battle Axe', 'A sturdy double-bladed axe', 'MELEE', 'axe', 'Common', 8, 281, 144, 1.3, {'ATTACK_SPEED': '0.03'}),
    ('broad_axe', 'Broad Axe', 'Wide-bladed axe for sweeping strikes', 'MELEE', 'axe', 'Uncommon', 10, 282, 144, 1.4, {'CRIT_DAMAGE': '0.1'}),
    # T4: Farm dungeon axes
    ('executioner_axe', 'Executioner Axe', 'A massive axe once used for grim justice', 'MELEE', 'axe', 'Uncommon', 22, 282, 144, 1.5, {'CRIT_DAMAGE': '0.15'}),
    ('infernal_axe', 'Infernal Axe', 'An axe forged in hellfire', 'MELEE', 'axe', 'Rare', 26, 283, 144, 1.4, {'ATTACK_SPEED': '0.05', 'CRIT_DAMAGE': '0.1'}),
    # T5: Wilderness legendary axe
    ('axe_of_ruin', 'Axe of Ruin', 'A legendary axe that cleaves through anything', 'MELEE', 'axe', 'Rare', 35, 283, 144, 1.5, {'CRIT_DAMAGE': '0.2', 'ATTACK_SPEED': '0.05'}),

    # ========== HAMMER ==========
    # T0: starter
    ('wooden_mallet', 'Wooden Mallet', 'A crude wooden mallet', 'MELEE', 'hammer', 'Common', 2, 284, 144, 1.2, {}),
    # T2: Aria
    ('iron_hammer', 'Iron Hammer', 'A solid iron hammer', 'MELEE', 'hammer', 'Common', 8, 284, 144, 1.2, {}),
    ('maul', 'Maul', 'A heavy two-handed maul', 'MELEE', 'hammer', 'Uncommon', 10, 285, 144, 1.3, {'ARMOR': '1.0'}),
    # T4: Farm
    ('thunder_hammer', 'Thunder Hammer', 'Strikes with the force of thunder', 'MELEE', 'hammer', 'Uncommon', 24, 285, 144, 1.4, {'ARMOR': '2.0'}),
    ('runic_hammer', 'Runic Hammer', 'Ancient runes glow along the head', 'MELEE', 'hammer', 'Rare', 27, 286, 144, 1.3, {'ATTACK_SPEED': '0.04', 'CRIT_DAMAGE': '0.1'}),
    # T5: Wilderness
    ('hammer_of_dawn', 'Hammer of Dawn', 'A divine hammer radiating holy light', 'MELEE', 'hammer', 'Rare', 38, 286, 144, 1.5, {'ARMOR': '3.0', 'CRIT_DAMAGE': '0.15'}),

    # ========== FLAIL ==========
    # T0: starter
    ('chain_whip', 'Chain Whip', 'A length of chain used as a weapon', 'MELEE', 'flail', 'Common', 1, 287, 144, 1.3, {}),
    # T2: Aria
    ('war_flail', 'War Flail', 'A proper military flail', 'MELEE', 'flail', 'Common', 8, 287, 144, 1.3, {'ATTACK_SPEED': '0.03'}),
    ('morning_star', 'Morning Star', 'A spiked ball on a chain', 'MELEE', 'flail', 'Uncommon', 10, 288, 144, 1.4, {'CRIT_DAMAGE': '0.1'}),
    # T5: Wilderness
    ('chain_of_torment', 'Chain of Torment', 'An enchanted chain that seeks its targets', 'MELEE', 'flail', 'Rare', 33, 288, 144, 1.5, {'ATTACK_SPEED': '0.06', 'PIERCE_COUNT': '1'}),

    # ========== SPEAR ==========
    # T0: starter
    ('wooden_spear', 'Wooden Spear', 'A sharpened wooden pole', 'MELEE', 'spear', 'Common', 2, 289, 144, 1.6, {}),
    # T1: Graveyard OW
    ('javelin', 'Javelin', 'A throwing spear used in melee', 'MELEE', 'spear', 'Common', 4, 289, 144, 1.6, {}),
    ('pike', 'Pike', 'A long-reaching pike', 'MELEE', 'spear', 'Uncommon', 5, 290, 144, 1.8, {'ATTACK_SPEED': '0.02'}),
    # T2: Aria
    ('halberd', 'Halberd', 'A polearm with an axe blade', 'MELEE', 'spear', 'Uncommon', 9, 290, 144, 1.7, {'CRIT_DAMAGE': '0.1'}),

    # ========== THROWING ==========
    # T0: starter
    ('pebbles', 'Pebbles', 'A handful of sharp pebbles', 'MELEE', 'throwing', 'Common', 1, 291, 144, 1.0, {}),
    # T1: Graveyard OW
    ('throwing_knives', 'Throwing Knives', 'Balanced knives for throwing', 'MELEE', 'throwing', 'Common', 3, 291, 144, 1.0, {'ATTACK_SPEED': '0.03'}),
    ('darts', 'Darts', 'Poisoned throwing darts', 'MELEE', 'throwing', 'Uncommon', 5, 292, 144, 1.0, {'CRIT_DAMAGE': '0.05'}),
    # T2: Aria
    ('chakram', 'Chakram', 'A razor-sharp throwing ring', 'MELEE', 'throwing', 'Uncommon', 9, 292, 144, 1.1, {'PIERCE_COUNT': '1'}),
    # T5: Wilderness
    ('void_stars', 'Void Stars', 'Stars forged from the void between worlds', 'MELEE', 'throwing', 'Rare', 32, 293, 144, 1.2, {'ATTACK_SPEED': '0.06', 'PIERCE_COUNT': '1'}),

    # ========== BOW ==========
    # T1: Graveyard OW
    ('oak_bow', 'Oak Bow', 'A reliable bow made of oak wood', 'RANGED', 'bow', 'Common', 4, 290, 145, 2.0, {}),
    ('recurve_bow', 'Recurve Bow', 'A recurved bow with extra power', 'RANGED', 'bow', 'Uncommon', 5, 291, 145, 2.2, {'BULLET_SPEED': '50.0'}),
    # T2: Aria
    ('ash_bow', 'Ash Bow', 'A bow crafted from ash wood', 'RANGED', 'bow', 'Common', 8, 292, 145, 2.2, {}),
    ('war_bow', 'War Bow', 'A powerful military longbow', 'RANGED', 'bow', 'Uncommon', 10, 293, 145, 2.4, {'BULLET_SPEED': '75.0'}),

    # ========== SHORT_BOW ==========
    # T2: Aria
    ('swift_bow', 'Swift Bow', 'A small bow built for speed', 'RANGED', 'short_bow', 'Common', 7, 294, 145, 1.5, {'ATTACK_SPEED': '0.04'}),
    # T3: GY Dungeon
    ('repeater_bow', 'Repeater Bow', 'A mechanical short bow that fires rapidly', 'RANGED', 'short_bow', 'Uncommon', 14, 295, 145, 1.6, {'ATTACK_SPEED': '0.06'}),
    ('snake_bow', 'Snake Bow', 'A curved bow resembling a serpent', 'RANGED', 'short_bow', 'Uncommon', 16, 296, 145, 1.6, {'CRIT_DAMAGE': '0.1'}),
    # T4: Farm (short_bow caps here - it's a utility/speed weapon)
    ('phantom_bow', 'Phantom Bow', 'A ghostly bow that fires with supernatural speed', 'RANGED', 'short_bow', 'Rare', 20, 297, 145, 1.7, {'ATTACK_SPEED': '0.08', 'CRIT_DAMAGE': '0.1'}),

    # ========== CROSSBOW ==========
    # T0: starter available
    ('light_crossbow', 'Light Crossbow', 'A simple hand crossbow', 'RANGED', 'crossbow', 'Common', 2, 298, 145, 1.8, {}),
    # T1: Graveyard OW
    ('hunting_crossbow', 'Hunting Crossbow', 'A crossbow used for hunting game', 'RANGED', 'crossbow', 'Common', 4, 299, 145, 1.8, {'PIERCE_COUNT': '1'}),
    ('heavy_crossbow', 'Heavy Crossbow', 'A powerful but slow crossbow', 'RANGED', 'crossbow', 'Uncommon', 5, 300, 145, 2.0, {'BULLET_SPEED': '50.0'}),
    # T2: Aria
    ('arbalest', 'Arbalest', 'A steel crossbow of great power', 'RANGED', 'crossbow', 'Uncommon', 9, 301, 145, 2.0, {'PIERCE_COUNT': '1', 'BULLET_SPEED': '50.0'}),
    # T5: Wilderness
    ('siege_crossbow', 'Siege Crossbow', 'A devastating crossbow that pierces all', 'RANGED', 'crossbow', 'Rare', 34, 302, 145, 2.5, {'PIERCE_COUNT': '2', 'BULLET_SPEED': '100.0'}),

    # ========== STAFF ==========
    # T2: Aria
    ('crystal_staff', 'Crystal Staff', 'A staff topped with a glowing crystal', 'MAGIC', 'staff', 'Common', 7, 303, 146, 2.0, {'MAX_MP': '5.0'}),
    ('ember_wand', 'Ember Wand', 'A wand crackling with fire magic', 'MAGIC', 'staff', 'Uncommon', 9, 304, 146, 1.8, {'MP_REGEN': '0.3'}),
    # T5: Wilderness
    ('staff_of_eternity', 'Staff of Eternity', 'An ancient staff of immeasurable power', 'MAGIC', 'staff', 'Rare', 35, 305, 146, 2.5, {'MAX_MP': '15.0', 'MP_REGEN': '0.5', 'COOLDOWN_REDUCTION': '0.1'}),
    ('archmage_sceptre', 'Archmage Sceptre', 'The sceptre of a legendary archmage', 'MAGIC', 'staff', 'Rare', 40, 306, 146, 2.2, {'MAX_MP': '10.0', 'CRIT_DAMAGE': '0.2'}),

    # ========== DAGGER ==========
    # T4: Farm
    ('assassin_dagger', 'Assassin Dagger', 'A blade designed for silent kills', 'MELEE', 'dagger', 'Uncommon', 21, 307, 144, 0.8, {'CRIT_DAMAGE': '0.15', 'ATTACK_SPEED': '0.05'}),
    ('venom_blade', 'Venom Blade', 'A dagger coated in deadly venom', 'MELEE', 'dagger', 'Uncommon', 24, 308, 144, 0.8, {'STEALTH': '5.0', 'CRIT_DAMAGE': '0.1'}),
    ('shadow_knife', 'Shadow Knife', 'A knife that seems to phase through armor', 'MELEE', 'dagger', 'Rare', 27, 309, 144, 0.9, {'CRIT_DAMAGE': '0.2', 'DODGE_CHANCE': '0.03'}),
    # T5: Wilderness
    ('blade_of_shadows', 'Blade of Shadows', 'A legendary dagger wreathed in darkness', 'MELEE', 'dagger', 'Rare', 32, 310, 144, 0.9, {'CRIT_DAMAGE': '0.25', 'ATTACK_SPEED': '0.08', 'DODGE_CHANCE': '0.05'}),

    # ========== CLUB ==========
    # T0: starter
    ('stick', 'Stick', 'A sturdy wooden stick', 'MELEE', 'club', 'Common', 1, 311, 144, 1.0, {}),
    # T5: Wilderness
    ('skull_crusher', 'Skull Crusher', 'A massive club made from a giants bone', 'MELEE', 'club', 'Rare', 34, 312, 144, 1.3, {'ARMOR': '3.0', 'CRIT_DAMAGE': '0.15'}),
]

# Bullet sprite indices by slot: 144=melee, 145=ranged, 146=magic
# weapon_range: daggers ~0.8, swords ~1.0, axes ~1.3, hammers ~1.2, spears ~1.6, bows ~2.0, staves ~2.0

STAT_IDS = {
    'MAX_HP': 0, 'MOVE_SPEED': 1, 'ATTACK_DAMAGE': 2, 'ATTACK_SPEED': 3,
    'BULLET_SPEED': 4, 'BULLET_COUNT': 5, 'SPREAD_ANGLE': 6, 'PIERCE_COUNT': 7,
    'BULLET_LIFETIME': 8, 'MAX_MP': 9, 'HP_REGEN': 10, 'MP_REGEN': 11,
    'LUCK': 12, 'CRIT_DAMAGE': 13, 'ARMOR': 14, 'DODGE_CHANCE': 17,
    'XP_MULT': 18, 'COOLDOWN_REDUCTION': 21, 'STEALTH': 22,
}

SLOT_IDS = {
    'MELEE': 0, 'RANGED': 1, 'MAGIC': 2,
}


def build_tres(filename, item_name, description, slot, weapon_type, rarity, damage, tile_idx, bullet_sprite, weapon_range, extra_stats):
    """Build a .tres file string."""
    # Build modifiers: always include ATTACK_DAMAGE, plus extras
    modifiers = []
    modifiers.append((STAT_IDS['ATTACK_DAMAGE'], float(damage), 0.0))
    for stat_name, val_str in extra_stats.items():
        val = float(val_str)
        if val != 0:
            modifiers.append((STAT_IDS[stat_name], val, 0.0))

    has_mods = len(modifiers) > 0
    load_steps = 3 if has_mods else 2

    rarity_map = {'Common': 0, 'Uncommon': 1, 'Rare': 2}
    slot_id = SLOT_IDS[slot]
    rarity_id = rarity_map[rarity]

    # Price: rough formula based on damage + rarity
    buy_price = int(damage * 8 + rarity_id * 50 + 10)
    sell_value = buy_price // 4

    lines = [
        f'[gd_resource type="Resource" script_class="EquipmentItem" load_steps={load_steps} format=3]',
        '',
        '[ext_resource type="Script" path="res://scripts/stats/equipment_item.gd" id="1"]',
    ]
    if has_mods:
        lines.append('[ext_resource type="Script" path="res://scripts/stats/stat_modifier.gd" id="2"]')
    lines.append('')

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
    lines.append(f'item_name = "{item_name}"')
    lines.append(f'loy_tile_index = {tile_idx}')
    lines.append(f'description = "{description}"')
    lines.append(f'slot_type = {slot_id}')

    if has_mods:
        mod_refs = ', '.join(f'SubResource("mod_{i}")' for i in range(len(modifiers)))
        lines.append(f'modifiers = Array[ExtResource("2")]([{mod_refs}])')

    lines.append(f'rarity = {rarity_id}')
    lines.append(f'buy_price = {buy_price}')
    lines.append(f'sell_value = {sell_value}')
    lines.append(f'bullet_sprite_index = {bullet_sprite}')
    lines.append(f'weapon_range = {weapon_range}')
    lines.append(f'weapon_type = "{weapon_type}"')
    lines.append('')

    return '\n'.join(lines)


def build_csv_row(filename, item_name, description, slot, weapon_type, rarity, damage, tile_idx, bullet_sprite, weapon_range, extra_stats):
    """Build a CSV row dict matching the existing format."""
    buy_price = int(damage * 8 + {'Common': 0, 'Uncommon': 1, 'Rare': 2}[rarity] * 50 + 10)
    sell_value = buy_price // 4

    row = {
        'file': filename + '.tres',
        'item_name': item_name,
        'description': description,
        'slot': slot,
        'rarity': rarity,
        'buy_price': str(buy_price),
        'sell_value': str(sell_value),
        'loy_tile_index': str(tile_idx),
        'bullet_sprite_index': str(bullet_sprite),
        'weapon_range': str(weapon_range),
        'weapon_type': weapon_type,
        'ability_id': '',
        'heal_hp': '',
        'heal_mp': '',
        'use_effect': '',
        'ATTACK_DAMAGE': f'{damage}.0' if damage == int(damage) else str(damage),
    }

    # Fill stat columns
    stat_cols = ['MAX_HP', 'ATTACK_DAMAGE', 'ARMOR', 'MOVE_SPEED', 'ATTACK_SPEED',
                 'BULLET_SPEED', 'BULLET_COUNT', 'PIERCE_COUNT', 'BULLET_LIFETIME',
                 'MAX_MP', 'HP_REGEN', 'MP_REGEN', 'LUCK', 'CRIT_DAMAGE',
                 'DODGE_CHANCE', 'XP_MULT', 'COOLDOWN_REDUCTION', 'STEALTH']
    for col in stat_cols:
        if col == 'ATTACK_DAMAGE':
            continue  # already set
        row.setdefault(col, extra_stats.get(col, ''))

    return row


def main():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: {CSV_PATH} not found")
        return

    # Read existing CSV
    with open(CSV_PATH, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames

    existing_files = set(r['file'] for r in rows)

    created_tres = 0
    created_csv = 0
    skipped = 0

    for item_data in NEW_ITEMS:
        filename = item_data[0]
        tres_filename = filename + '.tres'
        tres_path = os.path.join(ITEM_DIR, tres_filename)

        if tres_filename in existing_files:
            print(f"  SKIP {tres_filename} (already in CSV)")
            skipped += 1
            continue

        # Create .tres file
        content = build_tres(*item_data)
        with open(tres_path, 'w') as f:
            f.write(content)
        created_tres += 1

        # Add CSV row
        csv_row = build_csv_row(*item_data)
        rows.append(csv_row)
        created_csv += 1

        print(f"  CREATE {item_data[1]:25s} ({item_data[4]:>10s} T{'0' if item_data[6] <= 2 else '1' if item_data[6] <= 5 else '2' if item_data[6] <= 10 else '3' if item_data[6] <= 19 else '4' if item_data[6] <= 28 else '5'}) dmg={item_data[6]}")

    # Write updated CSV
    with open(CSV_PATH, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nCreated {created_tres} .tres files, added {created_csv} CSV rows, skipped {skipped}")
    print(f"Total items now: {len(rows)}")
    print("\nNow run: python3 scripts/tools/price_items.py  (to recalculate prices)")


if __name__ == '__main__':
    main()
