#!/usr/bin/env python3
"""Assign bullet_sprite_index and weapon_range to all weapon .tres files based on name."""

import os
import re

ITEMS_DIR = os.path.join(os.path.dirname(__file__), '../../resources/items/loy')

# Sprite indices matching ObjSpriteIndex constants
## Sprite indices from lofi_obj.png (16 cols × 16 rows, 8×8 tiles)
## Index = row * 16 + col
## Named sprites from lofi_obj_tileset.tres custom_data_0
SPRITE_MAP = {
    # Bows/crossbows → arrow_basic (8,15) = 248
    'bow': 248, 'crossbow': 248,
    # Staves, wands, books → blue_magic_basic (0,14) = 224
    'staff': 224, 'wand': 224, 'book': 224, 'rod': 224,
    # Fire weapons → red_magic_basic (0,13) = 208
    'fire': 208, 'flame': 208, 'lava': 208, 'inferno': 208,
    # Ice → blue_magic_sparkles (9,11) = 185
    'ice': 185, 'frost': 185, 'frozen': 185, 'cold': 185,
    # Poison → green_magic_basic (8,13) = 216
    'poison': 216, 'venom': 216, 'toxic': 216,
    # Lightning → white_charge (7,8) = 135
    'lightning': 135, 'thunder': 135, 'storm': 135, 'shock': 135,
    # Holy → white_magic_strong (10,8) = 138
    'holy': 138, 'divine': 138, 'sacred': 138, 'blessed': 138,
    # Dark → pink_magic_basic (8,14) = 232
    'dark': 232, 'shadow': 232, 'death': 232, 'void': 232,
    # Swords/blades → blade_basic (0,15) = 240
    'sword': 240, 'blade': 240, 'dagger': 240, 'shiv': 240, 'knife': 240,
    # Axes/hammers → red_star (0,9) = 144
    'axe': 144, 'hammer': 144, 'mace': 144, 'club': 144,
    # Spears → arrow_strong (6,5) = 86
    'spear': 86, 'lance': 86, 'javelin': 86, 'pike': 86,
    # Claws → white_shuriken (8,8) = 136
    'claw': 136, 'fang': 136, 'talon': 136,
    # Throwing → white_star (0,8) = 128
    'throwing': 128, 'shuriken': 136, 'star': 128,
}

RANGE_MAP = {
    'bow': 5.0, 'crossbow': 5.0,
    'staff': 4.0, 'wand': 4.0, 'book': 4.0, 'rod': 4.0,  # 100% (unchanged)
    'sword': 1.65, 'blade': 1.65,       # 66% of 2.5
    'dagger': 1.0, 'shiv': 1.0, 'knife': 1.0,  # 66% of 1.5
    'axe': 1.3, 'hammer': 1.3, 'mace': 1.3, 'club': 1.3,  # 66% of 2.0
    'spear': 2.3, 'lance': 2.3, 'javelin': 2.3, 'pike': 2.3,  # 66% of 3.5
    'claw': 0.8, 'fang': 0.8, 'talon': 0.8,  # 66% of 1.2
    'fire': 3.5, 'flame': 3.5, 'lava': 3.0,
    'ice': 3.5, 'frost': 3.5,
    'poison': 3.0, 'venom': 3.0,
    'lightning': 4.0, 'thunder': 4.0,
    'holy': 3.5, 'divine': 3.5,
    'dark': 3.5, 'shadow': 3.5,
}

DEFAULT_SPRITE = 224  # blue_magic_basic
DEFAULT_RANGE = 3.0

def get_item_name(content):
    m = re.search(r'item_name\s*=\s*"([^"]*)"', content)
    return m.group(1) if m else ''

def get_slot_type(content):
    m = re.search(r'slot_type\s*=\s*(\d+)', content)
    return int(m.group(1)) if m else -1

def find_sprite_for_name(name):
    lower = name.lower()
    # Check specific elemental keywords first (fire_sword should get fire sprite)
    elemental = ['fire', 'flame', 'lava', 'inferno', 'ice', 'frost', 'frozen', 'cold',
                 'poison', 'venom', 'toxic', 'lightning', 'thunder', 'storm', 'shock',
                 'holy', 'divine', 'sacred', 'blessed', 'dark', 'shadow', 'death', 'void']
    for kw in elemental:
        if kw in lower:
            return SPRITE_MAP[kw]
    # Then weapon type keywords
    weapon_types = ['crossbow', 'bow', 'staff', 'wand', 'book', 'rod',
                    'sword', 'blade', 'dagger', 'shiv', 'knife',
                    'axe', 'hammer', 'mace', 'club',
                    'spear', 'lance', 'javelin', 'pike',
                    'claw', 'fang', 'talon',
                    'throwing', 'shuriken', 'star']
    for kw in weapon_types:
        if kw in lower:
            return SPRITE_MAP[kw]
    return DEFAULT_SPRITE

def find_range_for_name(name):
    lower = name.lower()
    # Weapon type keywords first
    range_keys = ['crossbow', 'bow', 'staff', 'wand', 'book', 'rod',
                  'sword', 'blade', 'dagger', 'shiv', 'knife',
                  'axe', 'hammer', 'mace', 'club',
                  'spear', 'lance', 'javelin', 'pike',
                  'claw', 'fang', 'talon']
    for kw in range_keys:
        if kw in lower:
            return RANGE_MAP[kw]
    return DEFAULT_RANGE

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    slot = get_slot_type(content)
    if slot not in (0, 1, 2):  # WEAPON_MELEE=0, WEAPON_RANGED=1, WEAPON_MAGIC=2
        return False

    name = get_item_name(content)
    if not name:
        return False

    sprite_idx = find_sprite_for_name(name)
    wrange = find_range_for_name(name)

    # Remove old fields if present
    content = re.sub(r'\nbullet_sprite_index\s*=\s*[^\n]*', '', content)
    content = re.sub(r'\nweapon_range\s*=\s*[^\n]*', '', content)

    # Add fields before the end of [resource] section
    # Find last property line and append after it
    lines = content.rstrip().split('\n')
    lines.append(f'bullet_sprite_index = {sprite_idx}')
    lines.append(f'weapon_range = {wrange}')
    lines.append('')

    with open(filepath, 'w') as f:
        f.write('\n'.join(lines))

    return True

def main():
    count = 0
    for fname in sorted(os.listdir(ITEMS_DIR)):
        if not fname.endswith('.tres'):
            continue
        fpath = os.path.join(ITEMS_DIR, fname)
        if process_file(fpath):
            count += 1

    print(f"Assigned bullet sprites and ranges to {count} weapon items")

if __name__ == '__main__':
    main()
