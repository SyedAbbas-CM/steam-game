#!/usr/bin/env python3
"""Batch rebalance weapon ATTACK_DAMAGE (stat=2) flat_bonus values.

Target ranges:
  rarity 0: 1-2
  rarity 1: 2-4
  rarity 2: 4-7

Only modifies flat_bonus >= 1.0 (skips fractional values like 0.05/0.1/0.15
which are percent-style bonuses on staves/cloaks).
"""

import os
import re
import math

ITEMS_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'items', 'loy')

def normalize(old_dmg: float, rarity: int) -> float:
    if rarity == 0:
        return max(1.0, min(2.0, round(old_dmg / 4.0)))
    elif rarity == 1:
        return max(2.0, min(4.0, round(old_dmg / 6.0)))
    elif rarity == 2:
        return max(4.0, min(7.0, round(old_dmg / 7.0)))
    return old_dmg

def process_file(path: str) -> tuple:
    """Returns (changed: bool, item_name, old_dmg, new_dmg, rarity)"""
    with open(path, 'r') as f:
        content = f.read()

    if 'stat = 2' not in content:
        return (False, None, None, None, None)

    # Get rarity
    m = re.search(r'rarity = (\d+)', content)
    rarity = int(m.group(1)) if m else 0

    name_m = re.search(r'item_name = "([^"]+)"', content)
    item_name = name_m.group(1) if name_m else os.path.basename(path)

    # Find and replace flat_bonus in stat=2 sub_resource blocks
    changed = False
    old_dmg = None
    new_dmg = None

    # Split into sub_resource blocks
    parts = re.split(r'(\[sub_resource[^\]]*\])', content)
    result = []
    i = 0
    while i < len(parts):
        if i + 1 < len(parts) and parts[i].startswith('[sub_resource'):
            header = parts[i]
            body = parts[i + 1]
            if 'stat = 2' in body:
                fb_match = re.search(r'flat_bonus = ([\d.]+)', body)
                if fb_match:
                    old_val = float(fb_match.group(1))
                    if old_val >= 1.0:
                        new_val = normalize(old_val, rarity)
                        if new_val != old_val:
                            body = body.replace(
                                f'flat_bonus = {fb_match.group(1)}',
                                f'flat_bonus = {new_val:.1f}'
                            )
                            changed = True
                            old_dmg = old_val
                            new_dmg = new_val
            result.append(header)
            result.append(body)
            i += 2
        else:
            result.append(parts[i])
            i += 1

    if changed:
        with open(path, 'w') as f:
            f.write(''.join(result))

    return (changed, item_name, old_dmg, new_dmg, rarity)


def main():
    items_dir = os.path.normpath(ITEMS_DIR)
    changed_count = 0
    changes = []

    for fname in sorted(os.listdir(items_dir)):
        if not fname.endswith('.tres'):
            continue
        path = os.path.join(items_dir, fname)
        was_changed, name, old, new, rarity = process_file(path)
        if was_changed:
            changed_count += 1
            changes.append((name, rarity, old, new))

    print(f"Rebalanced {changed_count} weapon items")
    print()
    for rarity in [0, 1, 2]:
        items = [(n, o, nw) for n, r, o, nw in changes if r == rarity]
        if items:
            vals = [nw for _, _, nw in items]
            print(f"Rarity {rarity}: {len(items)} items, new range {min(vals):.0f}-{max(vals):.0f}")
            for n, o, nw in items[:5]:
                print(f"  {n}: {o:.0f} → {nw:.0f}")
            if len(items) > 5:
                print(f"  ... and {len(items)-5} more")


if __name__ == '__main__':
    main()
