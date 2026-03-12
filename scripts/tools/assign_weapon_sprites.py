#!/usr/bin/env python3
"""Assign bullet_sprite_index and weapon_range to all weapon .tres files based on name."""

import os
import re

ITEMS_DIR = os.path.join(os.path.dirname(__file__), '../../resources/items/loy')

# Sprite indices matching ObjSpriteIndex constants
SPRITE_MAP = {
    # Bows → arrows
    'bow': 96, 'crossbow': 96,
    # Staves, wands, books → magic missiles
    'staff': 111, 'wand': 111, 'book': 111, 'rod': 111,
    # Fire weapons → fireballs
    'fire': 104, 'flame': 104, 'lava': 104, 'inferno': 104,
    # Ice → ice bolts
    'ice': 105, 'frost': 105, 'frozen': 105, 'cold': 105,
    # Poison
    'poison': 106, 'venom': 106, 'toxic': 106,
    # Lightning
    'lightning': 107, 'thunder': 107, 'storm': 107, 'shock': 107,
    # Holy
    'holy': 108, 'divine': 108, 'sacred': 108, 'blessed': 108,
    # Dark
    'dark': 109, 'shadow': 109, 'death': 109, 'void': 109,
    # Swords/blades → slash
    'sword': 120, 'blade': 120, 'dagger': 120, 'shiv': 120, 'knife': 120,
    # Axes/hammers → impact
    'axe': 123, 'hammer': 123, 'mace': 123, 'club': 123,
    # Spears → bolt
    'spear': 102, 'lance': 102, 'javelin': 102, 'pike': 102,
    # Claws → slash2
    'claw': 121, 'fang': 121, 'talon': 121,
    # Throwing → star
    'throwing': 61, 'shuriken': 61, 'star': 117,
}

RANGE_MAP = {
    'bow': 5.0, 'crossbow': 5.0,
    'staff': 4.0, 'wand': 4.0, 'book': 4.0, 'rod': 4.0,
    'sword': 2.5, 'blade': 2.5,
    'dagger': 1.5, 'shiv': 1.5, 'knife': 1.5,
    'axe': 2.0, 'hammer': 2.0, 'mace': 2.0, 'club': 2.0,
    'spear': 3.5, 'lance': 3.5, 'javelin': 3.5, 'pike': 3.5,
    'claw': 1.2, 'fang': 1.2, 'talon': 1.2,
    'fire': 3.5, 'flame': 3.5, 'lava': 3.0,
    'ice': 3.5, 'frost': 3.5,
    'poison': 3.0, 'venom': 3.0,
    'lightning': 4.0, 'thunder': 4.0,
    'holy': 3.5, 'divine': 3.5,
    'dark': 3.5, 'shadow': 3.5,
}

DEFAULT_SPRITE = 110  # ENERGY_BALL
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
    if slot != 0:  # Only weapons (slot_type=0)
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
