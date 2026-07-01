#!/usr/bin/env python3
"""
Repaint items_master.png so every sprite lands at the tile position each
item's .tres currently claims. Does NOT touch any .tres — .tres positions
are authoritative (tier-ordered from the last migration), the master pixels
just need to match.

Uses the pre-migration commit as the source of truth for each item's
original LoY tile (in tiles.png / tiles2.png), then paints that sprite at
the item's CURRENT tile index in a fresh master.

Usage:

    python3 tools/repair_master_pixels.py             # default source is 5acd2a2^
    python3 tools/repair_master_pixels.py <commit>    # explicit pre-migration commit
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
TILES_PATH = PROJECT / 'assets/sprites/loy/tiles.png'
TILES2_PATH = PROJECT / 'assets/sprites/loy/tiles2.png'
MASTER_PATH = PROJECT / 'assets/sprites/items_master.png'

TILE_PX = 32
COLS = 16
DEFAULT_PRE_COMMIT = '5acd2a2^'  # commit right before the first migration


def parse_tile(text: str) -> int:
    m = re.search(r'^loy_tile_index\s*=\s*(-?\d+)$', text, re.MULTILINE)
    return int(m.group(1)) if m else -1


def git_read(commit: str, rel_path: str) -> str | None:
    try:
        blob = subprocess.check_output(
            ['git', '-C', str(PROJECT), 'show', f'{commit}:{rel_path}'],
            stderr=subprocess.DEVNULL,
        )
        return blob.decode('utf-8', errors='replace')
    except subprocess.CalledProcessError:
        return None


def crop_cell(sheet: Image.Image, idx: int) -> Image.Image | None:
    if idx < 0:
        return None
    max_cells = (sheet.size[1] // TILE_PX) * COLS
    if idx >= max_cells:
        return None
    c = idx % COLS
    r = idx // COLS
    return sheet.crop((c * TILE_PX, r * TILE_PX, (c + 1) * TILE_PX, (r + 1) * TILE_PX))


def cell_pos(idx: int) -> tuple[int, int]:
    return ((idx % COLS) * TILE_PX, (idx // COLS) * TILE_PX)


def main() -> None:
    pre = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PRE_COMMIT
    print(f'Pre-migration reference commit: {pre}')

    if not MASTER_PATH.is_file():
        print(f'ERROR: {MASTER_PATH.relative_to(PROJECT)} missing. '
              'Something else is wrong — expected the master file to exist.')
        sys.exit(1)

    tiles = Image.open(TILES_PATH).convert('RGBA')
    tiles2 = Image.open(TILES2_PATH).convert('RGBA')
    # Preserve the master's dimensions (108 rows currently). Start from a
    # blank RGBA canvas — we'll only paint the cells we know about.
    existing = Image.open(MASTER_PATH).convert('RGBA')
    master = Image.new('RGBA', existing.size, (0, 0, 0, 0))

    items = list(PROJECT.glob('resources/items/**/*.tres'))
    print(f'Repairing {len(items)} items…')

    placed = 0
    skipped = 0
    for p in items:
        rel = str(p.relative_to(PROJECT))
        # Current tile — where this item wants its sprite to land.
        current_tile = parse_tile(p.read_text())
        if current_tile < 0:
            continue
        # Original LoY tile — where its sprite lives in tiles.png / tiles2.png.
        pre_text = git_read(pre, rel)
        if pre_text is None:
            # Newly added item that didn't exist pre-migration — no LoY sprite.
            skipped += 1
            continue
        loy_tile = parse_tile(pre_text)
        if loy_tile < 0:
            skipped += 1
            continue
        # LoY range: 0-255 tiles.png, 256-511 tiles2.png.
        if loy_tile < 256:
            sprite = crop_cell(tiles, loy_tile)
        elif loy_tile < 512:
            sprite = crop_cell(tiles2, loy_tile - 256)
        else:
            skipped += 1
            continue
        if sprite is None:
            skipped += 1
            continue
        x, y = cell_pos(current_tile)
        master.paste(sprite, (x, y), sprite)
        placed += 1

    master.save(MASTER_PATH)
    print(f'Placed {placed} sprites, skipped {skipped}.')
    print(f'Wrote {MASTER_PATH.relative_to(PROJECT)} ({master.size[0]}×{master.size[1]} px)')
    print('Hard-reload the editor to see it.')


if __name__ == '__main__':
    main()
