#!/usr/bin/env python3
"""
World Editor → Godot Import Pipeline

Takes a JSON diff export from the web-based world editor and merges it into
the Godot overworld. Handles tiles, NPC positions, zone renames, player spawn,
and custom areas. Automatically rebuilds .tscn (editor-visible) and .scn (runtime).

Usage:
  python3 scripts/tools/import_editor_map.py ~/Downloads/latestmap.json
  python3 scripts/tools/import_editor_map.py ~/Downloads/latestmap.json --no-rebuild
  python3 scripts/tools/import_editor_map.py --promote

Pipeline:
  1. Copy base chunks → chunks2 (if needed)
  2. Apply tile diff to chunks2/
  3. Apply zone overrides (renames, etc.)
  4. Apply NPC position moves
  5. Apply player spawn position
  6. Rebuild overworld2.tscn from chunks2 (Godot headless)
  7. Create overworld2.scn for runtime

Editor SHEETS (from electron-editor/app/index.html):
  0-255:     maptiles.png       → source 0, 16 cols (32px)
  256-511:   tiles.png          → source 5, 16 cols (32px)
  512-767:   tiles2.png         → source 6, 16 cols (32px)
  768-1183:  lofiEnvironment    → source 1, 16 cols (8px→32px)
  1184-1291: dungeon_features   → source 2, 12 cols (8px→32px)
  1292-1547: lofi_obj.png       → source 3, 16 cols (8px→32px)
  1548-1619: lofi_obj_packB.png → source 4, 9 cols  (8px→32px)
"""

import json
import math
import os
import re
import shutil
import subprocess
import sys
import time

# ── Paths ──────────────────────────────────────────────────────────────────────
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHUNKS_DIR = os.path.join(PROJECT, "resources", "world", "chunks")
CHUNKS2_DIR = os.path.join(PROJECT, "resources", "world", "chunks2")
ZONES_DIR = os.path.join(PROJECT, "resources", "world", "zones")
SCENES_DIR = os.path.join(PROJECT, "scenes", "overworld")
GODOT_BIN = "/Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot"
CHUNK_SIZE = 64

# ── Layer mapping: editor name → Godot layer ──────────────────────────────────
LAYER_MAP = {
    "ground": "ground",
    "paths": "paths",
    "buildings": "buildings",
    "objects": "decorations",
    "decor": "fences",
}
ALL_LAYERS = ["ground", "paths", "water", "decorations", "buildings", "fences"]

# Old baked clutter to remove within editor-painted areas
OLD_TREE_TILES = {(1, 14, 16), (1, 15, 16), (0, 14, 7)}


# ── Tile index conversion ─────────────────────────────────────────────────────
def convert_tile_index(global_idx):
    """Convert editor global sprite index → (source_id, atlas_x, atlas_y)."""
    if global_idx == -1:
        return None
    if 0 <= global_idx <= 255:
        return (0, global_idx % 16, global_idx // 16)
    if 256 <= global_idx <= 511:
        local = global_idx - 256
        return (5, local % 16, local // 16)
    if 512 <= global_idx <= 767:
        local = global_idx - 512
        return (6, local % 16, local // 16)
    if 768 <= global_idx <= 1183:
        local = global_idx - 768
        return (1, local % 16, local // 16)
    if 1184 <= global_idx <= 1291:
        local = global_idx - 1184
        return (2, local % 12, local // 12)
    if 1292 <= global_idx <= 1547:
        local = global_idx - 1292
        return (3, local % 16, local // 16)
    if 1548 <= global_idx <= 1619:
        local = global_idx - 1548
        return (4, local % 9, local // 9)
    print(f"  WARNING: Unknown tile index {global_idx}, skipping")
    return None


# ── Chunk I/O ──────────────────────────────────────────────────────────────────
def parse_packed_int32(text):
    m = re.search(r'PackedInt32Array\(([^)]*)\)', text)
    if not m:
        return []
    inner = m.group(1).strip()
    return [int(x.strip()) for x in inner.split(',')] if inner else []


def ints_to_tile_dict(ints):
    tiles = {}
    for i in range(0, len(ints) - 4, 5):
        tiles[(ints[i], ints[i + 1])] = (ints[i + 2], ints[i + 3], ints[i + 4])
    return tiles


def tile_dict_to_ints(tiles):
    result = []
    for (cx, cy), (src, ax, ay) in sorted(tiles.items()):
        result.extend([cx, cy, src, ax, ay])
    return result


def format_packed_int32(ints):
    if not ints:
        return "PackedInt32Array()"
    return "PackedInt32Array(" + ", ".join(str(x) for x in ints) + ")"


def read_chunk(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    chunk_data = {}
    for layer in ALL_LAYERS:
        m = re.search(rf'metadata/{layer}\s*=\s*PackedInt32Array\([^)]*\)', content)
        chunk_data[layer] = ints_to_tile_dict(parse_packed_int32(m.group())) if m else {}
    cx_m = re.search(r'metadata/cx\s*=\s*(-?\d+)', content)
    cy_m = re.search(r'metadata/cy\s*=\s*(-?\d+)', content)
    return int(cx_m.group(1)) if cx_m else 0, int(cy_m.group(1)) if cy_m else 0, chunk_data


def write_chunk(filepath, cx, cy, chunk_data):
    lines = ['[gd_resource type="Resource" format=3]', '', '[resource]',
             f'metadata/cx = {cx}', f'metadata/cy = {cy}']
    for layer in ALL_LAYERS:
        tiles = chunk_data.get(layer, {})
        if tiles:
            lines.append(f'metadata/{layer} = {format_packed_int32(tile_dict_to_ints(tiles))}')
    with open(filepath, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def write_index(chunks_dir, chunk_keys):
    keys_str = ', '.join(f'"{cx}_{cy}"' for cx, cy in sorted(chunk_keys))
    with open(os.path.join(chunks_dir, "index.tres"), 'w') as f:
        f.write(f'[gd_resource type="Resource" format=3]\n\n[resource]\n'
                f'metadata/keys = PackedStringArray({keys_str})\n'
                f'metadata/chunk_size = {CHUNK_SIZE}\nmetadata/bake_time = {time.time()}\n')


def load_all_chunks(chunks_dir):
    chunks = {}
    if not os.path.isdir(chunks_dir):
        print(f"ERROR: Chunks directory not found: {chunks_dir}")
        return chunks
    for fname in os.listdir(chunks_dir):
        if fname.startswith("chunk_") and fname.endswith(".tres"):
            cx, cy, data = read_chunk(os.path.join(chunks_dir, fname))
            chunks[(cx, cy)] = data
    return chunks


# ── Zone/NPC updates ──────────────────────────────────────────────────────────
def apply_zone_overrides(overrides):
    if not overrides:
        return
    for zone_id, override_data in overrides.items():
        zone_file = _find_zone_file(zone_id)
        if not zone_file:
            continue
        with open(zone_file, 'r') as f:
            content = f.read()
        modified = False
        for key, value in override_data.items():
            pattern = rf'({key}\s*=\s*)"[^"]*"'
            if re.search(pattern, content):
                content = re.sub(pattern, rf'\1"{value}"', content)
                modified = True
                print(f"  {zone_id}: {key} = \"{value}\"")
        if modified:
            with open(zone_file, 'w') as f:
                f.write(content)


def apply_npc_moves(npc_moves):
    if not npc_moves:
        return
    zone_moves = {}
    for key, pos in npc_moves.items():
        parts = key.rsplit('_', 1)
        if len(parts) != 2:
            continue
        zone_moves.setdefault(parts[0], {})[int(parts[1])] = pos

    for zone_id, moves in zone_moves.items():
        zone_file = _find_zone_file(zone_id)
        if not zone_file:
            continue
        with open(zone_file, 'r') as f:
            content = f.read()
        modified = False
        npc_dicts = list(re.finditer(r'\{[^}]*"name"[^}]*\}', content))
        for npc_idx, pos in moves.items():
            if npc_idx >= len(npc_dicts):
                print(f"  WARNING: NPC index {npc_idx} out of range for {zone_id}")
                continue
            old_text = npc_dicts[npc_idx].group()
            new_x, new_y = int(round(pos.get('x', 0))), int(round(pos.get('y', 0)))
            new_text = re.sub(r'"x":\s*\d+', f'"x": {new_x}', old_text)
            new_text = re.sub(r'"y":\s*\d+', f'"y": {new_y}', new_text)
            if new_text != old_text:
                content = content.replace(old_text, new_text, 1)
                modified = True
                print(f"  {zone_id} NPC {npc_idx} → ({new_x}, {new_y})")
        if modified:
            with open(zone_file, 'w') as f:
                f.write(content)


def apply_player_spawn(player_spawn):
    """Write player_spawn_tile export var to overworld2.tscn root node."""
    if not player_spawn:
        return
    sx = int(player_spawn.get('x', 0))
    sy = int(player_spawn.get('y', 0))

    tscn_path = os.path.join(SCENES_DIR, "overworld2.tscn")
    if not os.path.isfile(tscn_path):
        print(f"  WARNING: overworld2.tscn not found, skipping spawn update")
        return

    with open(tscn_path, 'r') as f:
        content = f.read()

    # Update or insert player_spawn_tile on the root node (after chunks_base_path line)
    if 'player_spawn_tile' in content:
        content = re.sub(
            r'player_spawn_tile = Vector2i\([^)]+\)',
            f'player_spawn_tile = Vector2i({sx}, {sy})',
            content
        )
    elif 'chunks_base_path' in content:
        content = content.replace(
            'chunks_base_path = ',
            f'player_spawn_tile = Vector2i({sx}, {sy})\nchunks_base_path = '
        )

    with open(tscn_path, 'w') as f:
        f.write(content)
    print(f"  Spawn tile: ({sx}, {sy})")


def apply_enemy_spawns(spawns):
    """Save editor enemy spawn regions to enemy_spawns.tres.

    The runtime (overworld.gd) loads this resource and reads regions from metadata.
    Each region supports either a single enemy_type or a spawn_table with weighted types.
    Coordinates are world tiles (already in baked tile space from the editor).
    """
    out_path = os.path.join(PROJECT, "resources", "world", "enemy_spawns.tres")

    # Build the metadata array string
    region_strs = []
    for s in spawns:
        name = str(s.get("name", "unnamed"))
        x1 = int(s.get("x1", 0))
        y1 = int(s.get("y1", 0))
        x2 = int(s.get("x2", 0))
        y2 = int(s.get("y2", 0))
        max_count = int(s.get("max_count", 3))
        behavior = str(s.get("behavior", "chase"))
        hostile = bool(s.get("hostile", True))
        hostile_str = "true" if hostile else "false"

        parts = [
            f'"name": "{name}"',
            f'"x1": {x1}',
            f'"y1": {y1}',
            f'"x2": {x2}',
            f'"y2": {y2}',
            f'"max_count": {max_count}',
            f'"behavior": "{behavior}"',
            f'"hostile": {hostile_str}',
        ]

        # Support spawn_table (weighted) or single enemy_type
        spawn_table = s.get("spawn_table", [])
        if spawn_table:
            table_entries = []
            for entry in spawn_table:
                t = str(entry.get("type", "Goblin"))
                w = int(entry.get("weight", 1))
                table_entries.append(f'{{\n"type": "{t}",\n"weight": {w}\n}}')
            parts.append(f'"spawn_table": [{", ".join(table_entries)}]')
        else:
            enemy_type = str(s.get("enemy_type", "Goblin"))
            parts.append(f'"enemy_type": "{enemy_type}"')

        region_strs.append("{\n" + ",\n".join(parts) + "\n}")

    regions_str = ", ".join(region_strs)

    content = f'''[gd_resource type="Resource" format=3]

[resource]
metadata/regions = [{regions_str}]
'''

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w') as f:
        f.write(content)
    print(f"  Wrote {len(spawns)} spawn regions → {os.path.relpath(out_path, PROJECT)}")
    for s in spawns:
        table = s.get("spawn_table", [])
        if table:
            types_str = ", ".join(f"{e.get('type')}({e.get('weight')})" for e in table)
        else:
            types_str = s.get("enemy_type", "?")
        print(f"    {s.get('name', '?')}: [{types_str}] x{s.get('max_count', 3)} "
              f"({s.get('x1')},{s.get('y1')})→({s.get('x2')},{s.get('y2')}) "
              f"[{s.get('behavior', 'chase')}, hostile={s.get('hostile', True)}]")


def apply_waypoints(waypoints):
    """Save waypoints to waypoints.tres resource for runtime use (army spawns, etc)."""
    out_path = os.path.join(PROJECT, "resources", "world", "waypoints.tres")

    wp_strs = []
    for wp in waypoints:
        name = str(wp.get("name", "unnamed"))
        x = int(wp.get("x", 0))
        y = int(wp.get("y", 0))
        wp_strs.append(f'{{\n"name": "{name}",\n"x": {x},\n"y": {y}\n}}')

    content = f'''[gd_resource type="Resource" format=3]

[resource]
metadata/waypoints = [{", ".join(wp_strs)}]
'''

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w') as f:
        f.write(content)
    print(f"  Wrote {len(waypoints)} waypoints → {os.path.relpath(out_path, PROJECT)}")
    for wp in waypoints:
        print(f"    {wp.get('name', '?')}: ({wp.get('x')}, {wp.get('y')})")


def _find_zone_file(zone_id):
    zone_file = os.path.join(ZONES_DIR, f"{zone_id}.tres")
    if os.path.isfile(zone_file):
        return zone_file
    for fname in os.listdir(ZONES_DIR):
        if fname.lower().startswith(zone_id.lower()) and fname.endswith(".tres"):
            return os.path.join(ZONES_DIR, fname)
    print(f"  WARNING: Zone file not found for '{zone_id}'")
    return None


# ── Godot rebuild ──────────────────────────────────────────────────────────────
def rebuild_tscn(use_chunks2=True):
    script = "scripts/tools/chunks2_to_tscn.gd" if use_chunks2 else "scripts/tools/chunks_to_tscn.gd"
    script_path = os.path.join(PROJECT, script)
    if not os.path.isfile(script_path):
        print(f"ERROR: Rebuild script not found: {script_path}")
        return False
    if not os.path.isfile(GODOT_BIN):
        print(f"ERROR: Godot not found at {GODOT_BIN}")
        print(f"Run manually: Godot --headless --path {PROJECT} --script {script}")
        return False

    label = 'overworld2' if use_chunks2 else 'overworld'
    print(f"\nRebuilding {label}.tscn + {label}.scn...")
    result = subprocess.run(
        [GODOT_BIN, "--headless", "--path", PROJECT, "--script", script],
        capture_output=True, text=True, timeout=300
    )
    for line in (result.stdout or '').strip().split('\n'):
        if line.strip():
            print(f"  {line}")
    if result.returncode != 0 and result.stderr:
        print(f"  STDERR: {result.stderr[:500]}")
        return False
    return True


# ── Commands ───────────────────────────────────────────────────────────────────
def ensure_chunks2():
    """Copy base chunks → chunks2 if chunks2 doesn't exist yet."""
    if os.path.isdir(CHUNKS2_DIR) and len(os.listdir(CHUNKS2_DIR)) > 10:
        return  # Already exists with data
    print("Creating chunks2/ from base chunks...")
    os.makedirs(CHUNKS2_DIR, exist_ok=True)
    count = 0
    for fname in os.listdir(CHUNKS_DIR):
        if fname.endswith(".tres"):
            shutil.copy2(os.path.join(CHUNKS_DIR, fname), os.path.join(CHUNKS2_DIR, fname))
            count += 1
    print(f"  Copied {count} base chunk files → chunks2/")


def import_diff(json_path, no_rebuild=False):
    """Main import: apply JSON diff to chunks2, rebuild .tscn/.scn."""
    print(f"=== World Editor Import Pipeline ===")
    print(f"JSON: {json_path}")
    t0 = time.time()

    with open(json_path) as f:
        data = json.load(f)

    # Ensure chunks2 exists
    ensure_chunks2()

    # Load chunks2
    print("\nLoading chunks2...")
    chunks = load_all_chunks(CHUNKS2_DIR)
    print(f"  {len(chunks)} chunks loaded")

    layer_paints = data.get("layer_paints", {})

    # Build editor footprint for clutter removal
    custom_areas = data.get("custom_areas", [])
    editor_bounds = [(a["x1"], a["y1"], a["x2"], a["y2"]) for a in custom_areas]
    ground_entries = layer_paints.get("ground", [])
    if ground_entries:
        xs = [e[0] for e in ground_entries]
        ys = [e[1] for e in ground_entries]
        editor_bounds.append((min(xs), min(ys), max(xs), max(ys)))

    def in_bounds(x, y):
        return any(x1 <= x <= x2 and y1 <= y <= y2 for x1, y1, x2, y2 in editor_bounds)

    # Remove old baked clutter within editor bounds
    clutter_removed = 0
    for chunk_data in chunks.values():
        dec = chunk_data.get("decorations", {})
        to_remove = [pos for pos, tile in dec.items() if in_bounds(pos[0], pos[1]) and tile in OLD_TREE_TILES]
        for pos in to_remove:
            del dec[pos]
            clutter_removed += 1
    if clutter_removed:
        print(f"  Removed {clutter_removed} old baked clutter")


    # Apply tile paints
    modified_chunks = set()
    total_placed = 0
    total_erased = 0

    for editor_layer, godot_layer in LAYER_MAP.items():
        tiles = layer_paints.get(editor_layer, [])
        if not tiles:
            continue
        placed = erased = 0
        for entry in tiles:
            wx, wy, gidx = entry[0], entry[1], entry[2]
            ck = (math.floor(wx / CHUNK_SIZE), math.floor(wy / CHUNK_SIZE))
            if ck not in chunks:
                chunks[ck] = {layer: {} for layer in ALL_LAYERS}
            tile_data = convert_tile_index(gidx)
            if tile_data is None and gidx == -1:
                if (wx, wy) in chunks[ck][godot_layer]:
                    del chunks[ck][godot_layer][(wx, wy)]
                    erased += 1
            elif tile_data:
                chunks[ck][godot_layer][(wx, wy)] = tile_data
                placed += 1
            modified_chunks.add(ck)
        total_placed += placed
        total_erased += erased
        print(f"  {editor_layer} → {godot_layer}: {placed} placed, {erased} erased")

    # Mark clutter-affected chunks
    for ck in list(chunks.keys()):
        for x1, y1, x2, y2 in editor_bounds:
            if (math.floor(x1 / CHUNK_SIZE) <= ck[0] <= math.floor(x2 / CHUNK_SIZE) and
                    math.floor(y1 / CHUNK_SIZE) <= ck[1] <= math.floor(y2 / CHUNK_SIZE)):
                modified_chunks.add(ck)

    print(f"\n  Total: {total_placed} placed, {total_erased} erased, {len(modified_chunks)} chunks modified")

    # Write modified chunks
    print(f"\nWriting chunks to {CHUNKS2_DIR}...")
    for ck in modified_chunks:
        if ck in chunks:
            write_chunk(os.path.join(CHUNKS2_DIR, f"chunk_{ck[0]}_{ck[1]}.tres"), ck[0], ck[1], chunks[ck])

    # Update index with all chunk keys
    write_index(CHUNKS2_DIR, chunks.keys())

    # Zone overrides
    overrides = data.get("zone_overrides", {})
    if overrides:
        print("\nZone overrides:")
        apply_zone_overrides(overrides)

    # NPC moves
    npc_moves = data.get("npc_moves", {})
    if npc_moves:
        print(f"\nNPC moves ({len(npc_moves)}):")
        apply_npc_moves(npc_moves)

    # Player spawn
    player_spawn = data.get("player_spawn", {})
    if player_spawn:
        print(f"\nPlayer spawn:")
        apply_player_spawn(player_spawn)

    # Custom areas
    areas = data.get("custom_areas", [])
    if areas:
        print(f"\nCustom areas: {len(areas)}")
        for a in areas:
            print(f"  {a.get('name', '?')}: ({a.get('x1')},{a.get('y1')}) → ({a.get('x2')},{a.get('y2')})")

    # Enemy spawn regions
    enemy_spawns = data.get("enemy_spawns", [])
    if enemy_spawns:
        print(f"\nEnemy spawn regions: {len(enemy_spawns)}")
        apply_enemy_spawns(enemy_spawns)

    # Waypoints (army spawn points, etc.)
    waypoints = data.get("waypoints", [])
    if waypoints:
        print(f"\nWaypoints: {len(waypoints)}")
        apply_waypoints(waypoints)

    elapsed = time.time() - t0
    print(f"\nChunk import done in {elapsed:.1f}s")

    # Rebuild .tscn + .scn
    if not no_rebuild:
        rebuild_tscn(use_chunks2=True)
    else:
        print("Skipping .tscn rebuild (--no-rebuild)")

    print(f"\n=== Import complete! Open overworld2.tscn in Godot to see changes. ===")


def promote():
    """Promote overworld2 → main overworld."""
    print("=== Promoting overworld2 → overworld ===")
    if not os.path.isdir(CHUNKS2_DIR):
        print(f"ERROR: chunks2/ not found")
        sys.exit(1)

    # Copy chunks
    count = 0
    for fname in os.listdir(CHUNKS2_DIR):
        if fname.endswith(".tres"):
            shutil.copy2(os.path.join(CHUNKS2_DIR, fname), os.path.join(CHUNKS_DIR, fname))
            count += 1
    print(f"Copied {count} chunks → chunks/")

    # Copy player_spawn_tile from overworld2.tscn to overworld.tscn
    ow2 = os.path.join(SCENES_DIR, "overworld2.tscn")
    ow1 = os.path.join(SCENES_DIR, "overworld.tscn")
    if os.path.isfile(ow2) and os.path.isfile(ow1):
        with open(ow2, 'r') as f:
            content2 = f.read()
        m = re.search(r'player_spawn_tile = Vector2i\(([^)]+)\)', content2)
        if m:
            spawn_str = m.group(1)
            with open(ow1, 'r') as f:
                content1 = f.read()
            if 'player_spawn_tile' in content1:
                content1 = re.sub(
                    r'player_spawn_tile = Vector2i\([^)]+\)',
                    f'player_spawn_tile = Vector2i({spawn_str})',
                    content1
                )
            elif 'chunks_base_path' in content1:
                content1 = content1.replace(
                    'chunks_base_path = ',
                    f'player_spawn_tile = Vector2i({spawn_str})\nchunks_base_path = '
                )
            with open(ow1, 'w') as f:
                f.write(content1)
            print(f"Player spawn copied: ({spawn_str})")

    # Rebuild overworld.tscn + .scn
    rebuild_tscn(use_chunks2=False)
    print("\n=== Promotion complete! Game now loads the edited world. ===")


# ── CLI ────────────────────────────────────────────────────────────────────────
def main():
    if "--promote" in sys.argv:
        promote()
        return

    if len(sys.argv) < 2 or sys.argv[1].startswith("--"):
        print("World Editor → Godot Import Pipeline")
        print()
        print("Usage:")
        print("  python3 import_editor_map.py <export.json>              # Full import + rebuild")
        print("  python3 import_editor_map.py <export.json> --no-rebuild # Just update chunks")
        print("  python3 import_editor_map.py --promote                  # overworld2 → overworld")
        sys.exit(1)

    json_path = sys.argv[1]
    if not os.path.isfile(json_path):
        print(f"ERROR: File not found: {json_path}")
        sys.exit(1)

    no_rebuild = "--no-rebuild" in sys.argv
    import_diff(json_path, no_rebuild=no_rebuild)


if __name__ == "__main__":
    main()
