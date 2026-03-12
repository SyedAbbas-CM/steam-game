#!/usr/bin/env python3
"""
Re-diversify LoY enemy .tres files based on kingdom, level, and attack_type.
Makes enemies feel distinct: crawlers are fast/fragile, orcs are tanky, demons hit hard, etc.
"""
import os
import re
import glob

ENEMY_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'enemies', 'loy')

# Kingdom multipliers: {kingdom: (damage_mult, speed_mult, hp_mult)}
KINGDOM_MULTS = {
    'crawler':  (0.7, 1.3, 0.8),
    'animal':   (0.8, 1.2, 1.0),
    'orc':      (1.3, 0.8, 1.5),
    'undead':   (1.0, 1.0, 1.0),
    'demon':    (1.5, 1.0, 1.3),
    'human':    (1.0, 1.1, 0.9),
    'magical':  (1.2, 0.9, 0.7),
    'mecha':    (1.1, 0.7, 1.8),
}

# Attack type enum values from enemy_definition.gd
# NONE=0, MELEE=1, RANGED=2, BURST=3, CHARGE=4, DASH=5, SUMMON=6, SLAM=7,
# TELEPORT=8, HEAL=9, SPLIT=10, STEALTH=11, SHIELD=12, BEAM=13, SPIRAL=14, POISON_SHOT=15

# Per attack type: (base_bullet_count, bullet_speed, preferred_distance, damage_mult)
ATTACK_TYPE_STATS = {
    0:  (1, 60, 50, 1.0),    # NONE
    1:  (1, 30, 15, 1.5),    # MELEE
    2:  (1, 65, 55, 1.0),    # RANGED
    3:  (6, 45, 30, 0.7),    # BURST
    4:  (1, 40, 40, 1.3),    # CHARGE
    5:  (1, 40, 40, 1.3),    # DASH
    6:  (4, 50, 60, 0.6),    # SUMMON
    7:  (4, 50, 25, 1.0),    # SLAM
    8:  (2, 70, 60, 1.1),    # TELEPORT
    9:  (1, 50, 50, 0.5),    # HEAL
    10: (1, 50, 40, 0.8),    # SPLIT
    11: (1, 55, 30, 1.4),    # STEALTH
    12: (2, 55, 45, 1.0),    # SHIELD
    13: (1, 60, 50, 1.2),    # BEAM
    14: (4, 40, 40, 0.8),    # SPIRAL
    15: (1, 60, 55, 0.9),    # POISON_SHOT
}

def get_field(content, field):
    m = re.search(rf'^{field}\s*=\s*(.+)$', content, re.MULTILINE)
    return m.group(1).strip() if m else None

def set_field(content, field, value):
    pattern = rf'^({field}\s*=\s*).+$'
    replacement = rf'\g<1>{value}'
    new_content, count = re.subn(pattern, replacement, content, flags=re.MULTILINE)
    return new_content if count > 0 else content

def process_enemy(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    kingdom = get_field(content, 'kingdom')
    level_str = get_field(content, 'level')
    attack_type_str = get_field(content, 'attack_type')

    if not kingdom or not level_str or not attack_type_str:
        return False

    kingdom = kingdom.strip('"')
    level = int(level_str)
    attack_type = int(attack_type_str)

    k_dmg, k_spd, k_hp = KINGDOM_MULTS.get(kingdom, (1.0, 1.0, 1.0))
    base_bc, base_bs, base_pd, t_dmg = ATTACK_TYPE_STATS.get(attack_type, (1, 60, 50, 1.0))

    # Calculate new stats
    new_damage = max(1, int(level * 0.6 * k_dmg * t_dmg))
    new_speed = round(max(15.0, 22.0 * k_spd + level * 0.3), 1)
    new_attack_speed = round(max(0.5, min(2.5, 2.5 - level * 0.02)), 2)
    new_bullet_count = max(1, base_bc + level // 15)
    new_bullet_speed = max(25, base_bs + level)
    new_preferred_distance = max(10.0, float(base_pd))

    # HP already sqrt-scaled from import, just apply kingdom mult
    old_hp = get_field(content, 'max_hp')
    if old_hp:
        base_hp = int(old_hp)
        new_hp = max(3, int(base_hp * k_hp))
        content = set_field(content, 'max_hp', str(new_hp))

    content = set_field(content, 'attack_damage', str(new_damage))
    content = set_field(content, 'move_speed', str(new_speed))
    content = set_field(content, 'attack_speed', str(new_attack_speed))
    content = set_field(content, 'bullet_count', str(new_bullet_count))
    content = set_field(content, 'bullet_speed', str(new_bullet_speed))
    content = set_field(content, 'preferred_distance', str(new_preferred_distance))

    with open(filepath, 'w') as f:
        f.write(content)
    return True

def main():
    count = 0
    for kingdom_dir in sorted(os.listdir(ENEMY_DIR)):
        kingdom_path = os.path.join(ENEMY_DIR, kingdom_dir)
        if not os.path.isdir(kingdom_path):
            continue
        for tres_file in sorted(glob.glob(os.path.join(kingdom_path, '*.tres'))):
            name = os.path.basename(tres_file)
            if process_enemy(tres_file):
                count += 1
                # Read back for verification
                with open(tres_file) as f:
                    c = f.read()
                dmg = get_field(c, 'attack_damage')
                spd = get_field(c, 'move_speed')
                bc = get_field(c, 'bullet_count')
                hp = get_field(c, 'max_hp')
                print(f"  {name}: HP={hp} DMG={dmg} SPD={spd} BC={bc}")

    print(f"\nDiversified {count} enemies")

if __name__ == '__main__':
    main()
