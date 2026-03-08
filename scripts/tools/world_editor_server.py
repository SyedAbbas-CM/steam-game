#!/usr/bin/env python3
"""
World Map Editor — Flask backend.
Serves zone/quest/shop data from .tres files and the editor HTML frontend.
Run: python3 scripts/tools/world_editor_server.py
Open: http://localhost:5000
"""

import os
import sys
import json
import glob
import re
from flask import Flask, jsonify, request, send_file, send_from_directory

# Add tools dir to path for tres_parser
sys.path.insert(0, os.path.dirname(__file__))
from tres_parser import parse_tres, write_tres, load_zone

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ZONES_DIR = os.path.join(PROJECT_ROOT, 'resources', 'world', 'zones')
QUESTS_DIR = os.path.join(PROJECT_ROOT, 'resources', 'quests')
SHOPS_DIR = os.path.join(PROJECT_ROOT, 'resources', 'shops')
NPC_SCRIPTS_DIR = os.path.join(PROJECT_ROOT, 'resources', 'npcs', 'scripts')
SPRITES_DIR = os.path.join(PROJECT_ROOT, 'assets', 'sprites', 'loy')
MAPS_DIR = os.path.join(os.path.expanduser('~/Downloads'), 'legends-of-yore-export', 'data', 'maps')
ZONE_XML_DIR = os.path.join(os.path.expanduser('~/Downloads'), 'legends-of-yore-export', 'data', 'world', 'zones')
TOOLS_DIR = os.path.dirname(__file__)

# Map file lookup (zone_id -> map filename without .txt)
ZONE_MAP_FILES = {
    "airlon": "airlon", "bch1": "beach", "blf1": "bluff", "brg1": "bridge",
    "camp": "camp", "cel1": "cellar", "cennyn": "cennyn", "clearing": "clearing",
    "crt1": "courtyard", "end1": "end1", "farm": "farm", "for1": "forest",
    "for2": "forest2", "for3": "forest3", "for4": "forest4", "frozen": "frozen",
    "gomb": "gombard", "island": "island", "jungle1": "jungle1", "jungle2": "jungle2",
    "kor": "kor", "llecudd": "llecudd", "moors": "moors", "naleg": "naleg",
    "nord1": "nordolk", "paititi": "paititi", "peaks": "peaks", "plains": "plains",
    "shrine": "shrine", "swamp": "swamp", "talmita": "talmita", "talnivek": "talnivek",
    "thicket": "thicket", "thicket2": "thicket2", "thule": "thule",
    "tor1": "tor1", "tor2": "tor2", "tor3": "tor3", "tor4": "tor4",
    "tor5": "tor5", "tor6": "tor6", "tundra": "tundra", "und1": "under1",
    "vale": "vale", "willows": "willows", "ynys": "ynys",
}

# Character -> sprite index mapping (from LoadedMap.java / TileMapping.java)
CHAR_TO_SPRITE = {
    ' ': 1, '!': -1, '#': 0, '|': 6, 'D': 2, 'W': 32, 'L': 33,
    'T': 126, 'o': 7, '*': 7, 'R': 131, 'b': 129, 'B': 128,
    '@': 124, 'F': 4, 'S': 4, 'U': 136, 's': 5, 'X': -1,
    'E': 4, 'e': 5, '^': 160, '_': 161, '+': 169, '=': 171,
    '&': 166, 'n': 139, 'a': 158, 'd': 142, 'f': 174, 'c': 99,
    'P': 1, 'C': 1,
}

# Sprite indices that should get tileset offset applied (< 30)
def sprite_with_offset(sprite_idx, tileset):
    if sprite_idx < 30:
        return sprite_idx + tileset
    return sprite_idx

app = Flask(__name__)


# ── Helpers ──────────────────────────────────────────────────────────────

def _load_all_tres(directory, loader=load_zone):
    """Load all .tres files from a directory."""
    results = []
    pattern = os.path.join(directory, '*.tres')
    for filepath in sorted(glob.glob(pattern)):
        try:
            data = loader(filepath)
            data['_filepath'] = filepath
            results.append(data)
        except Exception as e:
            print(f"Error loading {filepath}: {e}")
    return results


# ── Routes: Zones ────────────────────────────────────────────────────────

@app.route('/api/zones')
def get_zones():
    """List all zones with basic info for the map view."""
    zones = _load_all_tres(ZONES_DIR)
    # Return lightweight list (no full NPC/quest data)
    summary = []
    for z in zones:
        summary.append({
            'id': z.get('id', ''),
            'zone_name': z.get('zone_name', ''),
            'tileset': z.get('tileset', 0),
            'width': z.get('width', 25),
            'height': z.get('height', 25),
            'baked_offset': z.get('baked_offset', {'x': 0, 'y': 0}),
            'baked_scale': z.get('baked_scale', 1),
            'world_pos': z.get('world_pos', {'x': 0, 'y': 0}),
            'dungeon_base': z.get('dungeon_base', ''),
            'dungeon_count': z.get('dungeon_count', 0),
            'description': z.get('description', ''),
            'npc_count': len(z.get('npcs', [])),
            'exit_count': len(z.get('exits', [])),
            'exits': z.get('exits', []),
        })
    return jsonify(summary)


@app.route('/api/zone/<zone_id>')
def get_zone(zone_id):
    """Get full zone data including NPCs, houses, signs, spawns."""
    filepath = os.path.join(ZONES_DIR, f'{zone_id}.tres')
    if not os.path.exists(filepath):
        # Try with underscore variant
        filepath = os.path.join(ZONES_DIR, f'{zone_id.replace("-", "_")}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Zone not found'}), 404
    data = load_zone(filepath)
    return jsonify(data)


@app.route('/api/zone/<zone_id>', methods=['PUT'])
def save_zone(zone_id):
    """Save zone data changes."""
    filepath = os.path.join(ZONES_DIR, f'{zone_id}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Zone not found'}), 404

    updates = request.json
    parsed = parse_tres(filepath)

    # Update fields
    for key, val in updates.items():
        if key.startswith('_') or key == 'script':
            continue
        # Convert Vector2i back
        if key in ('world_pos', 'baked_offset') and isinstance(val, dict):
            parsed['data'][key] = {'_type': 'Vector2i', 'x': int(val['x']), 'y': int(val['y'])}
        else:
            parsed['data'][key] = val

    write_tres(filepath, parsed)
    return jsonify({'ok': True})


# ── Routes: Quests ───────────────────────────────────────────────────────

@app.route('/api/quests')
def get_quests():
    quests = _load_all_tres(QUESTS_DIR)
    summary = []
    for q in quests:
        summary.append({
            'id': q.get('id', ''),
            'title': q.get('title', ''),
            'level': q.get('level', 0),
            'location': q.get('location', ''),
            'target_location': q.get('target_location', ''),
        })
    return jsonify(summary)


@app.route('/api/quest/<quest_id>')
def get_quest(quest_id):
    filepath = os.path.join(QUESTS_DIR, f'{quest_id}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Quest not found'}), 404
    return jsonify(load_zone(filepath))


@app.route('/api/quest/<quest_id>', methods=['PUT'])
def save_quest(quest_id):
    filepath = os.path.join(QUESTS_DIR, f'{quest_id}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Quest not found'}), 404
    updates = request.json
    parsed = parse_tres(filepath)
    for key, val in updates.items():
        if key.startswith('_') or key == 'script':
            continue
        parsed['data'][key] = val
    write_tres(filepath, parsed)
    return jsonify({'ok': True})


# ── Routes: Shops ────────────────────────────────────────────────────────

@app.route('/api/shops')
def get_shops():
    shops = _load_all_tres(SHOPS_DIR)
    summary = []
    for s in shops:
        summary.append({
            'id': s.get('id', ''),
            'shop_type': s.get('shop_type', ''),
            'shop_name': s.get('shop_name', ''),
            'title': s.get('title', ''),
            'stock_count': len(s.get('stock', [])),
        })
    return jsonify(summary)


@app.route('/api/shop/<shop_id>', methods=['GET'])
def get_shop(shop_id):
    filepath = os.path.join(SHOPS_DIR, f'{shop_id}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Shop not found'}), 404
    return jsonify(load_zone(filepath))


@app.route('/api/shop/<shop_id>', methods=['PUT'])
def save_shop(shop_id):
    filepath = os.path.join(SHOPS_DIR, f'{shop_id}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Shop not found'}), 404
    updates = request.json
    parsed = parse_tres(filepath)
    for key, val in updates.items():
        if key.startswith('_') or key == 'script':
            continue
        parsed['data'][key] = val
    write_tres(filepath, parsed)
    return jsonify({'ok': True})


# ── Routes: NPC Scripts ──────────────────────────────────────────────────

@app.route('/api/npc-scripts')
def get_npc_scripts():
    scripts = _load_all_tres(NPC_SCRIPTS_DIR)
    return jsonify([{
        'id': os.path.splitext(os.path.basename(s['_filepath']))[0],
        'command_count': len(s.get('commands', [])),
    } for s in scripts])


@app.route('/api/npc-script/<script_id>')
def get_npc_script(script_id):
    filepath = os.path.join(NPC_SCRIPTS_DIR, f'{script_id}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Script not found'}), 404
    return jsonify(load_zone(filepath))


# ── Routes: Tile Grid ────────────────────────────────────────────────────

def _parse_zone_tile_grid(zone_id, width, height, tileset):
    """Parse a zone's map .txt + XML into a 2D grid of sprite indices."""
    grid = [[-1] * width for _ in range(height)]

    # 1. Fill with floor
    for y in range(height):
        for x in range(width):
            grid[y][x] = sprite_with_offset(1, tileset)  # FLOOR

    # 2. Parse map .txt file
    if zone_id in ZONE_MAP_FILES:
        map_path = os.path.join(MAPS_DIR, ZONE_MAP_FILES[zone_id] + '.txt')
        if os.path.exists(map_path):
            with open(map_path) as f:
                content = f.read()
            lines = content.split(';')
            clean = [l.strip().replace('\n','').replace('\r','') for l in lines]
            data_start = 0
            for i, l in enumerate(clean):
                if l.startswith('end'):
                    data_start = i + 1
                    break
            for row_idx in range(data_start, len(clean)):
                y = row_idx - data_start
                if y >= height:
                    break
                line = clean[row_idx]
                for x in range(min(len(line), width)):
                    c = line[x]
                    if c in CHAR_TO_SPRITE:
                        si = CHAR_TO_SPRITE[c]
                        if si >= 0:
                            grid[y][x] = sprite_with_offset(si, tileset)

    # 3. Parse XML for houses, trees, graves, setTile
    xml_path = os.path.join(ZONE_XML_DIR, zone_id + '.xml')
    if os.path.exists(xml_path):
        with open(xml_path) as f:
            xml = f.read()

        # Houses -> wall sprites
        for m in re.finditer(r'<house\s+([^>]+)', xml):
            attrs = m.group(1)
            hx = _xml_int(attrs, 'x')
            hy = _xml_int(attrs, 'y')
            hw = _xml_int(attrs, 'width', 4)
            hh = _xml_int(attrs, 'height', 4)
            wall = sprite_with_offset(0, tileset)
            side = sprite_with_offset(6, tileset)
            door = sprite_with_offset(2, tileset)
            tiled = sprite_with_offset(7, tileset)
            for bx in range(hw):
                for by in range(hh):
                    px, py = hx + bx, hy + by
                    if 0 <= px < width and 0 <= py < height:
                        if bx == 0 or bx == hw-1:
                            grid[py][px] = side
                        elif by == 0 or by == hh-1:
                            grid[py][px] = wall
                        else:
                            grid[py][px] = tiled

        # Trees
        for m in re.finditer(r'<trees\s+([^>]+)', xml):
            attrs = m.group(1)
            tx = _xml_int(attrs, 'x')
            ty = _xml_int(attrs, 'y')
            tw = _xml_int(attrs, 'width')
            th = _xml_int(attrs, 'height')
            tree_sprite = 126  # default tree
            for bx in range(tw):
                for by in range(th):
                    px, py = tx + bx, ty + by
                    if 0 <= px < width and 0 <= py < height:
                        # ~30% density (use scrambled hash to avoid diagonal patterns)
                        if ((px * 2654435761 + py * 2246822519) & 0xFFFFFFFF) % 100 < 30:
                            grid[py][px] = tree_sprite + tileset if tree_sprite < 30 else tree_sprite

        # Graves
        for m in re.finditer(r'<graves\s+([^>]+)', xml):
            attrs = m.group(1)
            gx = _xml_int(attrs, 'x')
            gy = _xml_int(attrs, 'y')
            gw = _xml_int(attrs, 'width')
            gh = _xml_int(attrs, 'height')
            for bx in range(0, gw, 2):
                for by in range(0, gh, 3):
                    px, py = gx + bx, gy + by
                    if 0 <= px < width and 0 <= py < height:
                        grid[py][px] = 48 + ((bx + by) % 10)

    # 4. Apply tile_overrides from .tres (hand-painted changes from web editor)
    zone_filepath = os.path.join(ZONES_DIR, zone_id + '.tres')
    if os.path.exists(zone_filepath):
        from tres_parser import parse_tres
        parsed = parse_tres(zone_filepath)
        overrides = parsed['data'].get('tile_overrides', {})
        if isinstance(overrides, dict):
            for key, sprite_idx in overrides.items():
                parts = key.split(',')
                if len(parts) == 2:
                    ox, oy = int(parts[0]), int(parts[1])
                    if 0 <= ox < width and 0 <= oy < height:
                        grid[oy][ox] = int(sprite_idx)

    return grid


def _xml_int(attrs, name, default=0):
    m = re.search(rf' {name}="(\d+)"', ' ' + attrs)
    return int(m.group(1)) if m else default


@app.route('/api/zone/<zone_id>/tiles')
def get_zone_tiles(zone_id):
    """Get the tile grid for a zone (2D array of sprite indices into maptiles.png)."""
    filepath = os.path.join(ZONES_DIR, f'{zone_id}.tres')
    if not os.path.exists(filepath):
        return jsonify({'error': 'Zone not found'}), 404
    data = load_zone(filepath)
    width = data.get('width', 25)
    height = data.get('height', 25)
    tileset = data.get('tileset', 0)
    grid = _parse_zone_tile_grid(zone_id, width, height, tileset)
    return jsonify({'width': width, 'height': height, 'tileset': tileset, 'grid': grid})


# ── Routes: Export / Diff ────────────────────────────────────────────────

# Store original state for diffing
_original_zones = {}

@app.route('/api/snapshot')
def take_snapshot():
    """Take a snapshot of all zone data for diffing later."""
    global _original_zones
    zones = _load_all_tres(ZONES_DIR)
    _original_zones = {z.get('id',''): z for z in zones}
    return jsonify({'ok': True, 'count': len(_original_zones)})

@app.route('/api/diff')
def get_diff():
    """Compare current zone data against the snapshot."""
    if not _original_zones:
        return jsonify({'error': 'No snapshot taken. Call /api/snapshot first.'}), 400
    current_zones = _load_all_tres(ZONES_DIR)
    changes = []
    for z in current_zones:
        zid = z.get('id', '')
        if zid not in _original_zones:
            changes.append({'zone': zid, 'type': 'added'})
            continue
        orig = _original_zones[zid]
        diffs = []
        for key in set(list(z.keys()) + list(orig.keys())):
            if key.startswith('_'):
                continue
            if z.get(key) != orig.get(key):
                diffs.append(key)
        if diffs:
            changes.append({'zone': zid, 'type': 'modified', 'fields': diffs})
    return jsonify(changes)

@app.route('/api/export', methods=['POST'])
def export_changes():
    """Export all zone data as a JSON bundle for sharing."""
    zones = _load_all_tres(ZONES_DIR)
    export_path = os.path.join(PROJECT_ROOT, 'world_export.json')
    with open(export_path, 'w') as f:
        json.dump(zones, f, indent=2, default=str)
    return jsonify({'ok': True, 'path': export_path, 'count': len(zones)})


# ── Routes: Changeset Import / Apply ─────────────────────────────────────

_imported_changeset = None

@app.route('/api/import-changeset', methods=['POST'])
def import_changeset():
    """Import a friend's changeset for review."""
    global _imported_changeset
    _imported_changeset = request.json
    tc = sum(len(v) for v in _imported_changeset.get('tile_changes', {}).values())
    an = sum(len(v) for v in _imported_changeset.get('annotations', {}).values())
    return jsonify({
        'ok': True,
        'author': _imported_changeset.get('author', 'Unknown'),
        'timestamp': _imported_changeset.get('timestamp', ''),
        'tile_change_count': tc,
        'annotation_count': an,
        'zones': list(_imported_changeset.get('tile_changes', {}).keys()),
    })

@app.route('/api/changeset')
def get_changeset():
    """Get the currently imported changeset."""
    if not _imported_changeset:
        return jsonify({'error': 'No changeset imported'}), 404
    return jsonify(_imported_changeset)

@app.route('/api/apply-changes', methods=['POST'])
def apply_changes():
    """Apply accepted tile changes as tile_overrides in zone .tres files."""
    accepted = request.json  # {zone_id: [[x, y, old, new], ...]}
    updated = 0
    for zone_id, changes in accepted.items():
        filepath = os.path.join(ZONES_DIR, f'{zone_id}.tres')
        if not os.path.exists(filepath):
            continue
        parsed = parse_tres(filepath)
        overrides = parsed['data'].get('tile_overrides', {})
        if not isinstance(overrides, dict):
            overrides = {}
        for change in changes:
            x, y = change[0], change[1]
            new_idx = change[3]
            overrides[f'{x},{y}'] = new_idx
        parsed['data']['tile_overrides'] = overrides
        write_tres(filepath, parsed)
        updated += 1
    return jsonify({'ok': True, 'zones_updated': updated})

@app.route('/api/clear-changeset', methods=['POST'])
def clear_changeset():
    """Clear the imported changeset."""
    global _imported_changeset
    _imported_changeset = None
    return jsonify({'ok': True})


# ── Routes: Sprites ──────────────────────────────────────────────────────

@app.route('/sprites/<filename>')
def get_sprite(filename):
    return send_from_directory(SPRITES_DIR, filename)


# ── Routes: Editor Frontend ──────────────────────────────────────────────

@app.route('/')
def editor():
    return send_file(os.path.join(TOOLS_DIR, 'world_editor.html'))


# ── Main ─────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print(f"Project root: {PROJECT_ROOT}")
    print(f"Zones: {ZONES_DIR}")
    print(f"Quests: {QUESTS_DIR}")
    print(f"Sprites: {SPRITES_DIR}")
    print(f"\nStarting World Editor at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
