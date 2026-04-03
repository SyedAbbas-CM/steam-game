#!/usr/bin/env python3
"""Create new armor items to fill tier gaps."""
import os

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')

# Template for items with 1 modifier
TEMPLATE_1MOD = """[gd_resource type="Resource" script_class="EquipmentItem" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/stats/equipment_item.gd" id="1"]
[ext_resource type="Script" path="res://scripts/stats/stat_modifier.gd" id="2"]

[sub_resource type="Resource" id="mod_0"]
script = ExtResource("2")
stat = {stat0}
flat_bonus = {val0}

[resource]
script = ExtResource("1")
item_name = "{name}"
loy_tile_index = {tile}
description = "{desc}"
slot_type = {slot}
modifiers = Array[ExtResource("2")]([SubResource("mod_0")])
rarity = {rarity}
buy_price = {buy}
sell_value = {sell}
"""

TEMPLATE_2MOD = """[gd_resource type="Resource" script_class="EquipmentItem" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/stats/equipment_item.gd" id="1"]
[ext_resource type="Script" path="res://scripts/stats/stat_modifier.gd" id="2"]

[sub_resource type="Resource" id="mod_0"]
script = ExtResource("2")
stat = {stat0}
flat_bonus = {val0}

[sub_resource type="Resource" id="mod_1"]
script = ExtResource("2")
stat = {stat1}
flat_bonus = {val1}

[resource]
script = ExtResource("1")
item_name = "{name}"
loy_tile_index = {tile}
description = "{desc}"
slot_type = {slot}
modifiers = Array[ExtResource("2")]([SubResource("mod_0"), SubResource("mod_1")])
rarity = {rarity}
buy_price = {buy}
sell_value = {sell}
"""

# stat IDs: 0=MAX_HP, 2=ATTACK_DAMAGE, 5=MOVE_SPEED, 12=LUCK, 14=ARMOR, 17=DODGE_CHANCE, 22=STEALTH

# Items to create: (filename, name, desc, slot, rarity, tile, buy, sell, mods)
# mods = [(stat, val), ...]
items = [
    # === Common Rings (slot 8) === None exist currently!
    ("copper_ring", "Copper Ring", "A simple copper band (+2 HP)", 8, 0, 173, 30, 7,
     [(0, 2.0)]),
    ("iron_ring", "Iron Ring", "A sturdy iron ring (+3 HP, +1 Armor)", 8, 0, 173, 50, 12,
     [(0, 3.0), (14, 1.0)]),
    ("stone_ring", "Stone Ring", "A heavy stone ring (+1 ATK)", 8, 0, 173, 45, 11,
     [(2, 1.0)]),

    # === Common Gloves (slot 7) === Only 2 exist
    ("work_gloves", "Work Gloves", "Sturdy work gloves (+2 HP)", 7, 0, 167, 25, 6,
     [(0, 2.0)]),
    ("leather_gloves", "Leather Gloves", "Basic leather gloves (+1 ATK)", 7, 0, 167, 35, 8,
     [(2, 1.0)]),
    ("padded_gloves", "Padded Gloves", "Padded training gloves (+3 HP)", 7, 0, 167, 40, 10,
     [(0, 3.0)]),

    # === Uncommon Cloaks (slot 9) === Only 1 exists
    ("traveler_cloak", "Traveler's Cloak", "A warm traveling cloak (+5 HP, +5% dodge)", 9, 1, 168, 180, 45,
     [(0, 5.0), (17, 0.05)]),
    ("shadow_cloak", "Shadow Cloak", "A dark cloak for the stealthy (+3 HP, +10% stealth)", 9, 1, 168, 200, 50,
     [(0, 3.0), (22, 0.1)]),

    # === Uncommon Shields (slot 5) === Only 1 exists
    ("iron_shield", "Iron Shield", "A solid iron shield (+6 HP, +1 Armor)", 5, 1, 199, 200, 50,
     [(0, 6.0), (14, 1.0)]),
    ("tower_shield", "Tower Shield", "A tall shield offering great protection (+8 HP, +2 Armor)", 5, 1, 199, 280, 70,
     [(0, 8.0), (14, 2.0)]),
]

count = 0
for filename, name, desc, slot, rarity, tile, buy, sell, mods in items:
    path = os.path.join(ITEM_DIR, f"{filename}.tres")
    if os.path.exists(path):
        print(f"  SKIP {filename} (already exists)")
        continue
    if len(mods) == 1:
        content = TEMPLATE_1MOD.format(
            name=name, desc=desc, slot=slot, rarity=rarity, tile=tile,
            buy=buy, sell=sell, stat0=mods[0][0], val0=mods[0][1])
    else:
        content = TEMPLATE_2MOD.format(
            name=name, desc=desc, slot=slot, rarity=rarity, tile=tile,
            buy=buy, sell=sell, stat0=mods[0][0], val0=mods[0][1],
            stat1=mods[1][0], val1=mods[1][1])
    with open(path, 'w') as f:
        f.write(content)
    count += 1
    print(f"  Created {filename}: {name} (slot={slot}, rarity={rarity}, buy={buy}g)")

print(f"\nCreated {count} new armor items")
