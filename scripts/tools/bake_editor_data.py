#!/usr/bin/env python3
"""
Bake all zone tile grids + metadata into a self-contained friend editor HTML.
Run: python3 scripts/tools/bake_editor_data.py
Output: scripts/tools/editor_dist/world_editor_friend.html + sprite PNGs
"""

import os
import sys
import json
import shutil
import glob

# Add tools dir to path
sys.path.insert(0, os.path.dirname(__file__))
from tres_parser import load_zone
from world_editor_server import (
    _parse_zone_tile_grid, _load_all_tres,
    ZONES_DIR, QUESTS_DIR, SHOPS_DIR, SPRITES_DIR,
)

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DIST_DIR = os.path.join(os.path.dirname(__file__), 'editor_dist')
TEMPLATE_PATH = os.path.join(os.path.dirname(__file__), 'world_editor_friend_template.html')


def _extract_quest_details(q):
    """Extract quest giver, objectives, rewards from quest script data."""
    details = {}

    # Quest giver — first showDialog in start_script
    start = q.get('start_script', [])
    if start and isinstance(start, list):
        giver = _find_in_scripts(start, 'showDialog')
        if giver:
            details['giver'] = giver.get('name', '')
            details['giver_portrait'] = giver.get('portrait', 0)
            details['description'] = giver.get('text', '')

    # Objectives — from events
    events = q.get('events', [])
    objectives = []
    turn_in = ''
    for ev in events:
        if not isinstance(ev, dict):
            continue
        etype = ev.get('type', '')
        param = ev.get('param', '')
        if etype == 'kill' and param:
            objectives.append({'type': 'kill', 'target': param})
        elif etype == 'quest' and param:
            turn_in = param  # zone to return to

    details['objectives'] = objectives
    if turn_in:
        details['turn_in'] = turn_in

    # Rewards — find getItem/getExp/getGold in quest-zone event scripts
    rewards = []
    for ev in events:
        if not isinstance(ev, dict):
            continue
        if ev.get('type') == 'quest':
            _collect_rewards(ev.get('script', []), rewards)
    details['rewards'] = rewards

    return details


def _find_in_scripts(scripts, cmd):
    """Find first command of given type in nested script tree."""
    if not isinstance(scripts, list):
        return None
    for s in scripts:
        if not isinstance(s, dict):
            continue
        if s.get('cmd') == cmd:
            return s
        # Recurse into sub-scripts
        for key in ('script', 'options'):
            sub = s.get(key)
            if isinstance(sub, list):
                for item in sub:
                    if isinstance(item, dict):
                        found = _find_in_scripts(item.get('script', []), cmd)
                        if found:
                            return found
                        found = _find_in_scripts([item], cmd)
                        if found and found is not item:
                            return found
    return None


def _collect_rewards(scripts, rewards):
    """Collect getItem/getExp commands from quest completion scripts."""
    if not isinstance(scripts, list):
        return
    for s in scripts:
        if not isinstance(s, dict):
            continue
        cmd = s.get('cmd', '')
        if cmd == 'getItem':
            name = s.get('name', '')
            count = s.get('count', '1')
            if name and name != 'Gold':
                rewards.append({'type': 'item', 'name': name})
            elif name == 'Gold':
                rewards.append({'type': 'gold', 'amount': count})
        elif cmd == 'getExp':
            rewards.append({'type': 'xp', 'amount': s.get('value', '0')})
        # Recurse into nested scripts (if/showDialog/options)
        sub = s.get('script')
        if isinstance(sub, list):
            _collect_rewards(sub, rewards)
        opts = s.get('options')
        if isinstance(opts, list):
            for opt in opts:
                if isinstance(opt, dict):
                    _collect_rewards(opt.get('script', []), rewards)


def bake_world_data():
    """Build the complete world data JSON."""
    print("Loading zones...")
    zones_data = {}
    for filepath in sorted(glob.glob(os.path.join(ZONES_DIR, '*.tres'))):
        try:
            data = load_zone(filepath)
            zid = data.get('id', '')
            if not zid:
                continue
            # Skip zones not placed in the baked world
            baked_scale = data.get('baked_scale', 0)
            baked_off = data.get('baked_offset', {'x': -99999, 'y': -99999})
            if not baked_scale or baked_scale <= 1 or baked_off.get('x', -99999) <= -99000:
                print(f"  Skipping {zid} (not placed in world)")
                continue
            width = data.get('width', 25)
            height = data.get('height', 25)
            tileset = data.get('tileset', 0)

            print(f"  Baking {zid} ({width}x{height}, tileset={tileset})...")
            grid = _parse_zone_tile_grid(zid, width, height, tileset)

            zones_data[zid] = {
                'id': zid,
                'zone_name': data.get('zone_name', ''),
                'tileset': tileset,
                'width': width,
                'height': height,
                'baked_offset': data.get('baked_offset', {'x': 0, 'y': 0}),
                'baked_scale': data.get('baked_scale', 1),
                'description': data.get('description', ''),
                'dungeon_base': data.get('dungeon_base', ''),
                'dungeon_count': data.get('dungeon_count', 0),
                'exits': data.get('exits', []),
                'npcs': data.get('npcs', []),
                'houses': data.get('houses', []),
                'spawns': data.get('spawns', []),
                'signs': data.get('signs', []),
                'grid': grid,
            }
        except Exception as e:
            print(f"  ERROR: {filepath}: {e}")

    print(f"\nLoaded {len(zones_data)} zones")

    # Quests — extract rich data from scripts
    print("Loading quests...")
    quests = []
    for filepath in sorted(glob.glob(os.path.join(QUESTS_DIR, '*.tres'))):
        try:
            q = load_zone(filepath)
            qdata = {
                'id': q.get('id', ''),
                'title': q.get('title', ''),
                'level': q.get('level', 0),
                'location': q.get('location', ''),
            }
            # Extract quest giver, objectives, rewards from scripts
            qdata.update(_extract_quest_details(q))
            quests.append(qdata)
        except:
            pass
    print(f"  {len(quests)} quests")

    # Shops
    print("Loading shops...")
    shops = []
    for filepath in sorted(glob.glob(os.path.join(SHOPS_DIR, '*.tres'))):
        try:
            s = load_zone(filepath)
            shops.append({
                'id': s.get('id', ''),
                'shop_name': s.get('shop_name', s.get('title', '')),
                'shop_type': s.get('shop_type', ''),
            })
        except:
            pass
    print(f"  {len(shops)} shops")

    # Godot terrain from chunks
    print("Loading Godot terrain...")
    terrain_path = os.path.join(os.path.dirname(__file__), 'godot_terrain.json')
    terrain = None
    if os.path.exists(terrain_path):
        with open(terrain_path) as f:
            terrain = json.load(f)
        grle = len(terrain.get('ground_rle', terrain.get('rle', [])))
        orle = len(terrain.get('overlay_rle', []))
        print(f"  Terrain: {terrain['width']}x{terrain['height']}, ground {grle} + overlay {orle} ints")
    else:
        print("  WARNING: godot_terrain.json not found. Run export_godot_terrain.py first.")

    return {
        'version': 1,
        'zones': zones_data,
        'quests': quests,
        'shops': shops,
        'terrain': terrain,
    }


def build_dist(world_data):
    """Generate the distribution files."""
    os.makedirs(DIST_DIR, exist_ok=True)

    # Serialize JSON (compact)
    json_str = json.dumps(world_data, separators=(',', ':'))
    print(f"\nJSON data size: {len(json_str) // 1024} KB")

    # Read template HTML
    if not os.path.exists(TEMPLATE_PATH):
        print(f"ERROR: Template not found at {TEMPLATE_PATH}")
        print("Please create the friend editor template first.")
        sys.exit(1)

    with open(TEMPLATE_PATH, 'r') as f:
        html = f.read()

    # Inject data
    html = html.replace('/*__WORLD_DATA__*/', f'const WORLD_DATA = {json_str};', 1)

    # Write output HTML
    out_html = os.path.join(DIST_DIR, 'world_editor_friend.html')
    with open(out_html, 'w') as f:
        f.write(html)
    print(f"Wrote {out_html} ({os.path.getsize(out_html) // 1024} KB)")

    # Copy sprites
    for sprite in ['maptiles.png', 'chars.png', 'chars2.png']:
        src = os.path.join(SPRITES_DIR, sprite)
        dst = os.path.join(DIST_DIR, sprite)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"Copied {sprite}")
        else:
            print(f"WARNING: {src} not found")

    # Create a zip for easy sharing
    zip_path = os.path.join(os.path.dirname(DIST_DIR), 'world_editor_dist')
    shutil.make_archive(zip_path, 'zip', DIST_DIR)
    zip_size = os.path.getsize(zip_path + '.zip') // 1024
    print(f"\nCreated {zip_path}.zip ({zip_size} KB)")
    print("Share this zip with friends!")


if __name__ == '__main__':
    data = bake_world_data()
    build_dist(data)
