#!/usr/bin/env python3
"""
One-time script: Add lofi_dungeon_features_32.png as source 2 to the overworld tileset.
Run: python3 scripts/tools/add_tileset_source.py
"""

import re
import os

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TSCN = os.path.join(PROJECT, "scenes", "overworld", "overworld.tscn")

# Dungeon features: 12 cols x 9 rows = 108 tiles
COLS = 12
ROWS = 9
TEXTURE_UID = "uid://ck2nwkjt6shdo"
TEXTURE_PATH = "res://assets/sprites/lofi_dungeon_features_32.png"
EXT_RES_ID = "6_dngfeat"
SUB_RES_ID = "TileSetAtlasSource_dngft"

def build_ext_resource_line():
    return f'[ext_resource type="Texture2D" uid="{TEXTURE_UID}" path="{TEXTURE_PATH}" id="{EXT_RES_ID}"]'

def build_atlas_source_block():
    lines = [
        f'[sub_resource type="TileSetAtlasSource" id="{SUB_RES_ID}"]',
        f'texture = ExtResource("{EXT_RES_ID}")',
        'texture_region_size = Vector2i(32, 32)',
    ]
    for y in range(ROWS):
        for x in range(COLS):
            lines.append(f'{x}:{y}/0 = 0')
    return '\n'.join(lines)

def main():
    print(f"Reading {TSCN}...")
    with open(TSCN, 'r') as f:
        content = f.read()

    # Check if already added
    if SUB_RES_ID in content:
        print("Source 2 already added. Nothing to do.")
        return

    # 1. Insert ext_resource after last ext_resource line
    ext_line = build_ext_resource_line()
    # Find last [ext_resource ...] line
    last_ext = None
    for m in re.finditer(r'^\[ext_resource [^\]]+\]$', content, re.MULTILINE):
        last_ext = m
    if not last_ext:
        print("ERROR: Could not find ext_resource lines")
        return
    insert_pos = last_ext.end()
    content = content[:insert_pos] + '\n' + ext_line + content[insert_pos:]
    print(f"  Inserted ext_resource for dungeon features")

    # 2. Insert atlas source block before the TileSet sub_resource
    atlas_block = build_atlas_source_block()
    tileset_match = re.search(r'^\[sub_resource type="TileSet"', content, re.MULTILINE)
    if not tileset_match:
        print("ERROR: Could not find TileSet sub_resource")
        return
    insert_pos = tileset_match.start()
    content = content[:insert_pos] + atlas_block + '\n\n' + content[insert_pos:]
    print(f"  Inserted TileSetAtlasSource with {COLS}x{ROWS} = {COLS*ROWS} tiles")

    # 3. Add sources/2 line after sources/1
    content = content.replace(
        'sources/1 = SubResource("TileSetAtlasSource_0wbp6")',
        f'sources/1 = SubResource("TileSetAtlasSource_0wbp6")\nsources/2 = SubResource("{SUB_RES_ID}")'
    )
    print(f"  Added sources/2 to TileSet")

    # Write back
    with open(TSCN, 'w') as f:
        f.write(content)
    print(f"Done! {TSCN} updated with source 2.")

if __name__ == "__main__":
    main()
