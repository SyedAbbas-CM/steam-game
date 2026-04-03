#!/usr/bin/env python3
"""
Auto-price all LoY items based on rarity and modifier strength.
Adds buy_price and sell_value fields to each .tres file.
Shop markup is 2.5x on top of buy_price, so a 100g item costs 250g in shops.
"""
import os
import re
import glob

ITEM_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')

# Known consumable prices (these are base prices, shop will 2.5x them)
CONSUMABLE_PRICES = {
    'apple': 15, 'meat': 40, 'chop': 40, 'red_potion': 80, 'blue_potion': 120,
    'fish': 15, 'lava_fish': 60, 'gold_fish': 250, 'fire_fish': 40, 'octopus': 50,
    'trap': 50, 'fishing_pole': 80, 'spade': 60, 'powder_keg': 100,
    'pet_food': 30, 'aqua_potion': 200, 'attack_elixir': 300,
    'defense_elixir': 300, 'speed_elixir': 300, 'green_potion': 400,
}

def get_field(content, field):
    m = re.search(rf'^{field}\s*=\s*(.+)$', content, re.MULTILINE)
    return m.group(1).strip() if m else None

def set_field(content, field, value):
    pattern = rf'^({field}\s*=\s*).+$'
    new_content, count = re.subn(pattern, rf'\g<1>{value}', content, flags=re.MULTILINE)
    if count == 0:
        content = content.rstrip() + f'\n{field} = {value}\n'
        return content
    return new_content

def count_modifier_strength(content):
    """Sum all flat_bonus values in sub-resources."""
    total = 0.0
    for m in re.finditer(r'flat_bonus\s*=\s*([\d.]+)', content):
        total += float(m.group(1))
    for m in re.finditer(r'percent_bonus\s*=\s*([\d.]+)', content):
        total += float(m.group(1)) * 50  # percent bonuses are more valuable
    return total

def main():
    count = 0
    for tres_file in sorted(glob.glob(os.path.join(ITEM_DIR, '*.tres'))):
        with open(tres_file, 'r') as f:
            content = f.read()

        name = os.path.basename(tres_file).replace('.tres', '')
        rarity_str = get_field(content, 'rarity')
        slot_str = get_field(content, 'slot_type')
        rarity = int(rarity_str) if rarity_str else 0
        slot = int(slot_str) if slot_str else 4  # MATERIAL default

        # Check for consumable fixed price
        if name in CONSUMABLE_PRICES:
            buy_price = CONSUMABLE_PRICES[name]
        elif slot == 10:  # CONSUMABLE
            buy_price = 40
        else:
            # Price based on rarity + modifier strength
            mod_strength = count_modifier_strength(content)
            base_price = {0: 30, 1: 150, 2: 600}.get(rarity, 30)
            buy_price = int(base_price + mod_strength * 18)

            # Clamp to reasonable ranges per rarity
            if rarity == 0:
                buy_price = max(20, min(buy_price, 200))
            elif rarity == 1:
                buy_price = max(100, min(buy_price, 800))
            elif rarity == 2:
                buy_price = max(400, min(buy_price, 3500))

        sell_value = max(1, buy_price // 4)

        content = set_field(content, 'buy_price', str(buy_price))
        content = set_field(content, 'sell_value', str(sell_value))

        with open(tres_file, 'w') as f:
            f.write(content)

        count += 1
        if count <= 10 or count % 50 == 0:
            print(f"  {name}: buy={buy_price}g sell={sell_value}g (rarity={rarity})")

    print(f"\nPriced {count} items")

if __name__ == '__main__':
    main()
