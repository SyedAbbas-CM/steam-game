#!/usr/bin/env python3
"""
Export the actual Godot overworld terrain from chunk files into a compact
format the web editor can use.

Reads all chunk_*.tres files, keeps ground and overlay layers separate,
and outputs RLE-encoded data so the web editor draws ground first then
overlays (trees, buildings, fences, water) on top.

Output: scripts/tools/godot_terrain.json
"""

import os
import re
import glob
import json

CHUNKS_DIR = os.path.abspath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', '..',
    'resources', 'world', 'chunks'
))
CHUNK_SIZE = 64

# Ground layer renders first, then overlays render on top
GROUND_LAYERS = ['ground']
OVERLAY_LAYERS = ['water', 'paths', 'buildings', 'decorations', 'fences']


def atlas_to_sprite(source_id, atlas_x, atlas_y):
    """Convert Godot atlas coords to sprite index in maptiles.png (source 0)."""
    if source_id == 0:
        return atlas_y * 16 + atlas_x
    elif source_id == 1:
        # Source 1 = lofiEnvironment (void/stars tiles)
        # Use -2 to signal "void black" to renderer (renders as dark background)
        return -2
    return -1


def rle_encode(grid, width, height, min_x, min_y):
    """RLE encode sparse grid. Returns [sprite, count, sprite, count, ...]"""
    result = []
    for y in range(min_y, min_y + height):
        cur = grid.get((min_x, y), -1)
        count = 1
        for x in range(min_x + 1, min_x + width):
            v = grid.get((x, y), -1)
            if v == cur:
                count += 1
            else:
                result.append(cur)
                result.append(count)
                cur = v
                count = 1
        result.append(cur)
        result.append(count)
    return result


def sparse_encode(grid, width, height, min_x, min_y):
    """Encode sparse overlay as [x, y, sprite, x, y, sprite, ...] — much smaller for sparse data."""
    result = []
    for (x, y), sprite in sorted(grid.items(), key=lambda t: (t[0][1], t[0][0])):
        result.append(x)
        result.append(y)
        result.append(sprite)
    return result


def export_terrain():
    print(f"Reading chunks from {CHUNKS_DIR}...")
    chunk_files = sorted(glob.glob(os.path.join(CHUNKS_DIR, 'chunk_*.tres')))
    print(f"  Found {len(chunk_files)} chunks")

    ground = {}   # (x,y) -> sprite
    overlay = {}  # (x,y) -> sprite (topmost non-ground layer)

    min_x, max_x, min_y, max_y = 999999, -999999, 999999, -999999

    for i, filepath in enumerate(chunk_files):
        if i % 100 == 0:
            print(f"  Processing chunk {i+1}/{len(chunk_files)}...")

        with open(filepath) as f:
            content = f.read()

        # Parse each layer
        for layer_name in GROUND_LAYERS + OVERLAY_LAYERS:
            pattern = rf'metadata/{layer_name}\s*=\s*PackedInt32Array\(([^)]*)\)'
            m = re.search(pattern, content)
            if not m or not m.group(1).strip():
                continue

            values = [int(v.strip()) for v in m.group(1).split(',')]
            target = ground if layer_name in GROUND_LAYERS else overlay

            for j in range(0, len(values) - 4, 5):
                x, y = values[j], values[j+1]
                source_id = values[j+2]
                atlas_x, atlas_y = values[j+3], values[j+4]
                sprite = atlas_to_sprite(source_id, atlas_x, atlas_y)
                if sprite < 0:
                    continue

                target[(x, y)] = sprite
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

    width = max_x - min_x + 1
    height = max_y - min_y + 1
    print(f"\n  World: ({min_x},{min_y}) to ({max_x},{max_y}) = {width}x{height}")
    print(f"  Ground tiles: {len(ground)}, Overlay tiles: {len(overlay)}")

    # RLE encode both layers
    print("  Encoding...")
    ground_rle = rle_encode(ground, width, height, min_x, min_y)
    overlay_rle = rle_encode(overlay, width, height, min_x, min_y)
    print(f"  Ground RLE: {len(ground_rle)} ints")
    print(f"  Overlay RLE: {len(overlay_rle)} ints")

    output = {
        'min_x': min_x,
        'min_y': min_y,
        'width': width,
        'height': height,
        'ground_rle': ground_rle,
        'overlay_rle': overlay_rle,
    }

    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'godot_terrain.json')
    with open(out_path, 'w') as f:
        json.dump(output, f, separators=(',', ':'))

    size_kb = os.path.getsize(out_path) // 1024
    print(f"\n  Wrote {out_path} ({size_kb} KB)")
    return output


if __name__ == '__main__':
    export_terrain()
