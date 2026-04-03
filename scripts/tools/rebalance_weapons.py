#!/usr/bin/env python3
"""
Rebalance ALL weapon damage for proper progression.

Class base_damage (becomes base_stats.attack_damage via int()):
  Warrior: 2, Mercenary: 1, Ranger: 1, Wizard: 1

Final damage = class_base + weapon_flat_bonus
So weapon flat_bonus = target_damage - class_base_damage

User-confirmed starter targets:
  Sword: 2 total → flat=0 (warrior base=2), flat=1 (merc base=1)
  ...but the same sword.tres is shared! So flat must be 0, warrior base=2 gives 2, merc base=1 gives 1.

Wait, that means merc sword does 1 dmg? User said sword=2.
The simplest fix: set warrior base_damage to 1 (like everyone else) and set weapon flat = target - 1.

Actually let me re-read: the user said "sword does 2 dmg, longbow does 2, dagger does 2, staff does 1, short bow does 1".
These are the weapon damage values regardless of class. So class base should be low/0 or weapon flat should be the full damage.

Simplest approach: set all class base_damage to 0 or 1, and let weapon flat = target damage - base.
With base=1 for all: Sword flat=1, LongBow flat=1, Dagger flat=1, Staff flat=0, ShortBow flat=0.

Let's go with: PlayerStats.attack_damage default = 0, all class base_damage = 0.
Then weapon flat IS the final damage. Clean and simple.

Actually checking: PlayerStats has attack_damage = 1 as default, and class overrides it.
Let's set all class base_damage to 0 and PlayerStats default to 0.
Then weapon flat bonus = exact target damage.

TIER TARGETS (flat bonus on weapon = total damage at level 1 with 0 base):
  T0 (starter):  1-2 dmg
  T1 (GY OW):    3-5 dmg
  T2 (Aria):     7-10 dmg
  T3 (GY Dung):  14-18 dmg (reduced from current 17-22, too close to T4)
  T4 (Farm):     20-28 dmg
  T5 (Wild):     30-45 dmg

Current problems spotted:
- Short Bow: 4 dmg, should be 1
- Long Bow: 4 dmg, should be 2
- Staff: 2 dmg, should be 1
- Sword: 2 dmg, should be 2 (OK if base=0)
- Dagger: 2 dmg, should be 2 (OK if base=0)
- Composite Bow: classified as bow, should be short_bow
- Many T3 weapons are all 17-19, need more spread
- No T2 weapons for axe, hammer, flail, spear, throwing, crossbow
- Huge jump from T1 (3-5) to T3 (17-22) for most types
"""
import os, csv

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')
CSV_PATH = os.path.join(ITEM_DIR, 'items.csv')

# Reclassify certain items
RECLASSIFY = {
    'composite_bow': 'short_bow',  # it's a short bow type, not a longbow
}

# Explicit damage overrides (flat_bonus = this value since base will be 0)
# Format: filename_without_tres -> new_ATTACK_DAMAGE
DAMAGE_OVERRIDES = {
    # === T0: Starters (1-2 dmg) ===
    'sword': 2,
    'dagger': 2,
    'long_bow': 2,
    'staff': 1,
    'short_bow': 1,
    'rusty_sword': 1,     # vendor trash
    'dirty_staff': 1,     # vendor trash
    'bow': 1,             # generic bow, worse than Long Bow
    'grimey_bow': 1,      # vendor trash

    # === T1: Graveyard Overworld (3-5 dmg) ===
    'longsword': 4,
    'flashbang': 3,
    'freeze': 3,
    'weaken': 3,
    'fireball': 5,
    'frost_bolt': 5,      # was T2 at 9, move down - it's common
    'hatchet': 3,
    'axe': 4,
    'mighty_axe': 5,
    'club': 3,
    'mace': 4,
    'hammer': 3,
    'flail': 3,
    'spiked_flail': 4,
    'composite_bow': 3,   # short_bow type, early upgrade
    'spire_dagger': 3,
    'ridged_dagger': 4,
    'tooth_dagger': 4,
    'beholder_staff': 3,
    'bone_staff': 4,
    'staff_of_mord': 5,

    # === T2: Aria Dungeon (7-10 dmg) ===
    'stinger_sword': 8,
    'drain': 7,
    'explosion': 10,      # uncommon, strong
    'bandit_shiv': 8,
    'hunter_knife': 8,
    'razor_knife': 9,
    'spiked_club': 8,

    # === T3: Graveyard Dungeon (14-19 dmg) ===
    'flinger': 14,
    'mighty_blade': 15,
    'sickle': 15,
    'jesters_shaker': 15,
    'lava_sword': 16,
    'crusader_sword': 16,
    'curved_sword': 16,
    'magic_sword': 17,
    'assasin_blade': 18,
    'fire_sword': 17,
    'clawn': 17,
    'jeweled_hook': 16,
    'lion_blade': 18,
    'wicket_blade': 17,

    'viking_axe': 15,
    'cleaver': 16,
    'demonic_axe': 17,

    'hunters_mace': 15,
    'troll_club': 16,

    'warhammer': 17,

    'nunchuks': 15,
    'juggling_balls': 16,

    'task_spear': 15,
    'trident': 17,

    'throwing_stars': 16,

    'hunters_bow': 14,
    'magic_bow': 15,
    'dark_bow': 16,
    'elven_bow': 16,
    'lava_bow': 17,

    'crossbow': 15,

    'diamond_knife': 16,

    'dark_staff': 14,
    'merlins_wand': 15,
    'staff_of_demid': 15,
    'staff_of_ra': 15,
    'zann_wand': 15,
    'obsidian_wand': 16,
    'red_stone_sceptre': 16,
    'warlock_staff': 16,

    # === T4: Farm Dungeon (20-28 dmg) ===
    'corlion': 20,
    'double_clawn': 20,
    'malorian_crook': 21,
    'phoenix_blade': 21,
    'dktahg': 22,
    'rapier': 23,
    'scythe': 23,
    'harpe': 24,
    'katana': 24,
    'blade_of_ages': 25,
    'dual_swords': 25,
    'flame_rapier': 25,
    'spectral_blade': 26,
    'cutlass': 26,
    'ornate_blade': 27,
    'poisoned_spike': 27,
    'blade_of_virtue': 28,

    'magma_club': 22,

    'dark_nunchucks': 21,

    'chaos_spear': 22,

    'ronia_stone': 22,

    'golden_bow': 20,
    'goif_bow': 21,
    'harp_bow': 23,
    'elder_bow': 24,
    'ornate_bow': 26,

    'dual_crossbow': 24,

    'gands_wand': 18,
    'opal_wand': 18,
    'pygmy_staff': 18,
    'ruby_staff': 19,
    'zidian_wand': 19,
    'crooked_staff': 20,
    'wand_of_ages': 20,
    'cyrilian_ankh': 21,
    'argeebe_wand': 22,
    'cyania_sceptre': 22,
    'winged_sceptre': 22,

    # === T5: Wilderness / Boss (30-45 dmg) ===
    'blade_of_honour': 30,
    'magic_missile': 30,
    'blade_of_justice': 33,
    'sword_of_nivek': 36,
    'lightning': 40,
    'smite': 45,

    'bow_of_justice': 30,
    'twin_strung_bow': 33,
    'dwarf_bow': 36,
    'mechanical_bow': 42,

    'titans_trident': 32,
}


def main():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: {CSV_PATH} not found")
        return

    with open(CSV_PATH, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames

    changes = 0
    for row in rows:
        basename = row['file'].replace('.tres', '')

        # Reclassify
        if basename in RECLASSIFY:
            old_wt = row.get('weapon_type', '')
            new_wt = RECLASSIFY[basename]
            if old_wt != new_wt:
                print(f"  RECLASSIFY {row['item_name']:30s} {old_wt} → {new_wt}")
                row['weapon_type'] = new_wt
                changes += 1

        # Damage overrides
        if basename in DAMAGE_OVERRIDES:
            new_dmg = DAMAGE_OVERRIDES[basename]
            old_dmg = row.get('ATTACK_DAMAGE', '')
            new_dmg_str = f'{new_dmg}.0' if new_dmg == int(new_dmg) else str(new_dmg)
            if old_dmg != new_dmg_str:
                print(f"  DMG {row['item_name']:30s} {old_dmg:>6s} → {new_dmg_str}")
                row['ATTACK_DAMAGE'] = new_dmg_str
                changes += 1

    with open(CSV_PATH, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n{changes} changes applied")
    print("Now run: python3 scripts/tools/import_items_csv.py")


if __name__ == '__main__':
    main()
