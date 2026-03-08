#!/usr/bin/env python3
"""Import LoY enemies from actortypes.xml → Godot .tres EnemyDefinition files."""

import xml.etree.ElementTree as ET
import os
import re

SOURCE = os.path.expanduser("~/Downloads/legends-of-yore-export/data/actors/actortypes.xml")
OUTPUT_BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "resources", "enemies", "loy")

# AttackType enum values matching enemy_definition.gd
AT = {
    "NONE": 0, "MELEE": 1, "RANGED": 2, "BURST": 3, "CHARGE": 4, "DASH": 5,
    "SUMMON": 6, "SLAM": 7, "TELEPORT": 8, "HEAL": 9,
    "SPLIT": 10, "STEALTH": 11, "SHIELD": 12, "BEAM": 13, "SPIRAL": 14, "POISON_SHOT": 15,
}

# Already imported enemies (skip these)
ALREADY_IMPORTED = {
    "Skeleton", "Skeleton Archer", "Blob", "Spider", "Kobold", "Ghost", "Cobra",
    "Cyclops", "Thief", "Wild Dog", "Scorpion", "Goblin", "Imp", "Bear", "Bandit",
    "Mummy", "Vampire", "Creeper", "Devil", "Spectre", "Rock Troll", "Beholder",
    "Widow", "Liche", "Hydra", "Orc", "Ogre", "Black Knight", "Fire Elemental",
    "Ice Elemental", "Medusa", "Genie", "Centaur", "Minotaur", "Dragon",
    "Dark Lord", "Skeleton King", "Faabian", "Small Blob",
}

# Non-monster actor types to skip
SKIP_NAMES = {"Warrior", "Archer", "Wizard", "Bag", "Chest", "Open Chest", "Barrel", "Open Barrel",
              "Trap", "NPC", "Statue", "Sign", "Boulder"}

# Kingdom color mappings
KINGDOM_COLORS = {
    "undead": "Color(0.7, 0.65, 0.85, 1)",
    "orc": "Color(0.5, 0.75, 0.4, 1)",
    "crawler": "Color(0.7, 0.8, 0.3, 1)",
    "animal": "Color(0.8, 0.65, 0.45, 1)",
    "demon": "Color(0.9, 0.35, 0.3, 1)",
    "human": "Color(0.6, 0.7, 0.9, 1)",
    "magical": "Color(0.5, 0.85, 0.9, 1)",
    "vermin": "Color(0.45, 0.6, 0.35, 1)",
    "mecha": "Color(0.75, 0.8, 0.85, 1)",
}

# Attack type assignment keywords
def get_attack_type(name, kingdom, attack, exp, has_ghost):
    nl = name.lower()

    # Special name-based overrides
    if "archer" in nl or "bowman" in nl:
        return AT["RANGED"]
    if "mage" in nl or "witch" in nl or "wizard" in nl or "magician" in nl or "wikka" in nl or "farseer" in nl:
        return AT["BURST"]
    if "knight" in nl or "guard" in nl or "guardian" in nl:
        return AT["SHIELD"]
    if "ninja" in nl:
        return AT["STEALTH"]
    if "rider" in nl or "warlord" in nl:
        return AT["CHARGE"]
    if "shaman" in nl or "cleric" in nl or "elder" in nl:
        return AT["HEAL"]
    if "blob" in nl or "slime" in nl or "squib" in nl or "gelatinous" in nl or "oily" in nl:
        return AT["SPLIT"]
    if has_ghost:
        return AT["TELEPORT"]

    # Kingdom-based defaults
    match = {
        "undead": AT["RANGED"],
        "orc": AT["MELEE"] if attack >= 5 else AT["RANGED"],
        "crawler": AT["DASH"] if "spider" in nl or "scorpion" in nl or "widow" in nl else AT["POISON_SHOT"] if "cobra" in nl or "snake" in nl or "venom" in nl else AT["RANGED"],
        "animal": AT["CHARGE"] if attack >= 4 else AT["MELEE"],
        "demon": AT["SPIRAL"] if "ifrit" in nl else AT["TELEPORT"] if "imp" in nl else AT["BURST"],
        "human": AT["STEALTH"] if "thief" in nl or "robber" in nl else AT["RANGED"],
        "magical": AT["BEAM"] if exp > 2000 else AT["BURST"],
        "vermin": AT["DASH"] if attack >= 5 else AT["POISON_SHOT"],
        "mecha": AT["BEAM"],
    }
    return match.get(kingdom, AT["RANGED"])


def get_speed_tier(exp):
    """Returns (move_speed, aggro_range, attack_speed, bullet_speed, bullet_count_bonus)"""
    if exp < 200:
        return 18.0, 60.0, 2.0, 50.0, 0
    elif exp < 500:
        return 22.0, 80.0, 1.6, 60.0, 0
    elif exp < 1000:
        return 26.0, 90.0, 1.2, 70.0, 1
    elif exp < 2000:
        return 30.0, 100.0, 1.0, 80.0, 1
    else:
        return 22.0, 120.0, 0.8, 85.0, 2  # Boss: slower but more bullets


def get_boss_config(exp):
    """Returns (boss_phases, phase_2_attack, phase_3_attack, phase_2_bullets, phase_3_bullets, summon_on_phase)"""
    if exp >= 6000:
        return 3, AT["BURST"], AT["SPIRAL"], 8, 12, True
    elif exp >= 4000:
        return 2, AT["SPIRAL"], AT["NONE"], 8, 0, True
    elif exp >= 2000:
        return 2, AT["BURST"], AT["NONE"], 6, 0, False
    return 1, AT["NONE"], AT["NONE"], 0, 0, False


def sanitize_filename(name):
    """Convert enemy name to valid filename."""
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


def get_preferred_distance(attack_type):
    """Ranged enemies keep distance, melee rush in."""
    ranged_types = {AT["RANGED"], AT["BURST"], AT["BEAM"], AT["SPIRAL"], AT["POISON_SHOT"], AT["HEAL"]}
    if attack_type in ranged_types:
        return 45.0
    return 0.0


# Named boss special configs
SPECIAL_BOSSES = {
    "Smorag": {
        "attack_type": AT["BEAM"],
        "boss_phases": 3,
        "phase_2_attack": AT["SPIRAL"],
        "phase_3_attack": AT["BURST"],
        "phase_2_bullet_count": 10,
        "phase_3_bullet_count": 14,
        "leaves_trail": True,
        "trail_type": "fire",
        "explodes_on_death": True,
    },
    "Deathbringer": {
        "attack_type": AT["SPIRAL"],
        "boss_phases": 3,
        "phase_2_attack": AT["BEAM"],
        "phase_3_attack": AT["BURST"],
        "phase_2_bullet_count": 10,
        "phase_3_bullet_count": 16,
    },
    "Balrog": {
        "attack_type": AT["BEAM"],
        "boss_phases": 2,
        "phase_2_attack": AT["BURST"],
        "phase_2_bullet_count": 10,
        "leaves_trail": True,
        "trail_type": "fire",
    },
    "Dark Balrog": {
        "attack_type": AT["BEAM"],
        "boss_phases": 3,
        "phase_2_attack": AT["SPIRAL"],
        "phase_3_attack": AT["BURST"],
        "phase_2_bullet_count": 12,
        "phase_3_bullet_count": 16,
        "leaves_trail": True,
        "trail_type": "fire",
        "explodes_on_death": True,
    },
    "Giant Lizard": {
        "attack_type": AT["CHARGE"],
        "boss_phases": 3,
        "phase_2_attack": AT["SLAM"],
        "phase_3_attack": AT["SPIRAL"],
        "phase_2_bullet_count": 8,
        "phase_3_bullet_count": 12,
    },
    "Giant Widow": {
        "attack_type": AT["DASH"],
        "boss_phases": 3,
        "phase_2_attack": AT["BURST"],
        "phase_3_attack": AT["SPIRAL"],
        "phase_2_bullet_count": 10,
        "phase_3_bullet_count": 14,
        "leaves_trail": True,
        "trail_type": "web",
    },
    "Plaguemaster": {
        "attack_type": AT["POISON_SHOT"],
        "boss_phases": 3,
        "phase_2_attack": AT["BURST"],
        "phase_3_attack": AT["SPIRAL"],
        "phase_2_bullet_count": 8,
        "phase_3_bullet_count": 12,
        "leaves_trail": True,
        "trail_type": "poison",
    },
    "Golem": {
        "attack_type": AT["SLAM"],
        "boss_phases": 2,
        "phase_2_attack": AT["CHARGE"],
        "phase_2_bullet_count": 6,
    },
    "Cave Troll": {
        "attack_type": AT["SLAM"],
        "boss_phases": 2,
        "phase_2_attack": AT["BURST"],
        "phase_2_bullet_count": 8,
    },
    "Lava Lizard": {
        "attack_type": AT["BEAM"],
        "boss_phases": 2,
        "phase_2_attack": AT["SPIRAL"],
        "phase_2_bullet_count": 10,
        "leaves_trail": True,
        "trail_type": "fire",
    },
    "Golgothra": {
        "attack_type": AT["BURST"],
        "boss_phases": 3,
        "phase_2_attack": AT["SPIRAL"],
        "phase_3_attack": AT["BEAM"],
        "phase_2_bullet_count": 10,
        "phase_3_bullet_count": 14,
    },
    "Chaos Warrior": {
        "attack_type": AT["CHARGE"],
        "boss_phases": 2,
        "phase_2_attack": AT["BURST"],
        "phase_2_bullet_count": 8,
    },
}


def generate_tres(name, desc, kingdom, tile, health, attack, defence, exp, width, height, has_ghost):
    """Generate .tres file content for an EnemyDefinition."""
    move_speed, aggro, atk_speed, bullet_spd, bullet_bonus = get_speed_tier(exp)
    atk_type = get_attack_type(name, kingdom, attack, exp, has_ghost)

    # Override for special bosses
    special = SPECIAL_BOSSES.get(name, {})
    if "attack_type" in special:
        atk_type = special["attack_type"]

    # Compressed HP: sqrt scaling so bosses aren't absurdly tanky
    # LoY health 5→15, 10→22, 25→38, 50→53, 100→75, 200→106, 750→206
    import math
    max_hp = max(5, int(7.5 * math.sqrt(health)))
    atk_dmg = max(1, min(8, attack))  # cap at 8 to keep bullet-hell fair
    bullet_count = max(1, min(5, 1 + attack // 3 + bullet_bonus))
    shield = max(0, min(15, (defence - 4) * 2)) if defence > 4 else 0
    xp = max(1, exp // 10)
    score = max(1, exp // 5)
    contact_dmg = max(1, min(5, attack // 2))
    level = max(1, exp // 100)
    pref_dist = get_preferred_distance(atk_type)
    color = KINGDOM_COLORS.get(kingdom, "Color(1, 1, 1, 1)")

    # Size class
    size_class = 0  # NORMAL
    if width >= 2 or height >= 2:
        size_class = 1  # LARGE
        max_hp = int(max_hp * 1.5)

    # Boss phases
    boss_phases, p2_atk, p3_atk, p2_bullets, p3_bullets, summon_phase = get_boss_config(exp)
    # Override from special
    boss_phases = special.get("boss_phases", boss_phases)
    p2_atk = special.get("phase_2_attack", p2_atk)
    p3_atk = special.get("phase_3_attack", p3_atk)
    p2_bullets = special.get("phase_2_bullet_count", p2_bullets)
    p3_bullets = special.get("phase_3_bullet_count", p3_bullets)
    summon_phase = special.get("summon_on_phase_change", summon_phase)
    leaves_trail = special.get("leaves_trail", False)
    trail_type = special.get("trail_type", "")
    explodes = special.get("explodes_on_death", False)

    # Escape description for .tres
    desc = desc.replace('"', '\\"').strip()

    lines = [
        '[gd_resource type="Resource" script_class="EnemyDefinition" load_steps=2 format=3]',
        '',
        '[ext_resource type="Script" path="res://scripts/enemies/enemy_definition.gd" id="1"]',
        '',
        '[resource]',
        'script = ExtResource("1")',
        '',
        f'enemy_name = "{name}"',
        f'description = "{desc}"',
        f'max_hp = {max_hp}',
        f'move_speed = {move_speed}',
        f'contact_damage = {contact_dmg}',
        f'level = {level}',
        f'kingdom = "{kingdom}"',
        f'size_class = {size_class}',
        'hostile = true',
        f'attack_type = {atk_type}',
        f'attack_damage = {atk_dmg}',
        f'attack_speed = {atk_speed}',
        f'bullet_speed = {int(bullet_spd)}',
        f'bullet_count = {bullet_count}',
        f'preferred_distance = {pref_dist}',
        'charge_speed = 80.0',
        'charge_duration = 0.3',
        f'aggro_range = {aggro}',
        f'ignores_terrain = {"true" if has_ghost else "false"}',
    ]

    if shield > 0:
        lines.append(f'shield_hp = {shield}')
    if leaves_trail:
        lines.append('leaves_trail = true')
        lines.append(f'trail_type = "{trail_type}"')
    if explodes:
        lines.append('explodes_on_death = true')
        lines.append('explode_radius = 24.0')

    # Boss phases
    if boss_phases > 1:
        lines.append(f'boss_phases = {boss_phases}')
        lines.append(f'phase_2_attack = {p2_atk}')
        if boss_phases >= 3:
            lines.append(f'phase_3_attack = {p3_atk}')
        if p2_bullets > 0:
            lines.append(f'phase_2_bullet_count = {p2_bullets}')
        if p3_bullets > 0:
            lines.append(f'phase_3_bullet_count = {p3_bullets}')
        if summon_phase:
            lines.append('summon_on_phase_change = true')
            lines.append('summon_phase_count = 3')

    lines.extend([
        'use_loy_sprite = true',
        f'loy_tile_index = {tile}',
        f'sprite_color = {color}',
        f'xp_value = {xp}',
        f'score_value = {score}',
        '',
    ])

    return '\n'.join(lines)


def main():
    tree = ET.parse(SOURCE)
    root = tree.getroot()

    created = 0
    skipped = 0

    for actor in root.findall('actorType'):
        name = actor.get('name', '')
        exp_str = actor.get('exp', '')

        # Skip non-monsters (no exp = not an enemy)
        if not exp_str:
            skipped += 1
            continue

        # Skip player classes and objects
        if name in SKIP_NAMES:
            skipped += 1
            continue

        # Skip already imported
        if name in ALREADY_IMPORTED:
            skipped += 1
            continue

        # Parse attributes
        exp = int(exp_str)
        tile = int(actor.get('tile', '0'))
        kingdom = actor.get('kingdom', 'unknown')
        width = int(actor.get('width', '1'))
        height = int(actor.get('height', '1'))
        desc = actor.get('description', f'A {kingdom} creature')

        # Parse statistics
        stats = actor.find('statistics')
        health = int(stats.get('health', '5')) if stats is not None else 5
        attack = int(stats.get('attack', '2')) if stats is not None else 2
        defence = int(stats.get('defence', '2')) if stats is not None else 2

        # Check for ghost option
        has_ghost = False
        options = actor.find('options')
        if options is not None and options.get('ghost', '') == 'true':
            has_ghost = True

        # Generate .tres content
        content = generate_tres(name, desc, kingdom, tile, health, attack, defence, exp, width, height, has_ghost)

        # Write file
        kingdom_dir = os.path.join(OUTPUT_BASE, kingdom)
        os.makedirs(kingdom_dir, exist_ok=True)
        filename = sanitize_filename(name) + '.tres'
        filepath = os.path.join(kingdom_dir, filename)

        with open(filepath, 'w') as f:
            f.write(content)
        created += 1

    print(f"Created {created} enemy definitions, skipped {skipped}")
    print(f"Output: {OUTPUT_BASE}")


if __name__ == '__main__':
    main()
