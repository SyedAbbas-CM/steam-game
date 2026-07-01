#!/usr/bin/env python3
"""
After you reshuffle sprite pointers in item_editor.py (click an item, click a
sprite cell), each item's .tres now says "use cell N" — but the master PNG
still has its pixel layout from the last time build_items_master or the
migration ran. So the item ends up displaying whatever sprite was already
painted at cell N, not the sprite it "used to have."

This script fixes that. For every item whose loy_tile_index changed vs the
last committed master state, it copies that item's original 32×32 sprite
from its OLD cell in the master to its NEW cell, so the visual layout
follows your reshuffles.

Usage:

    python3 tools/apply_sprite_reshuffles.py             # uses HEAD~1 as reference
    python3 tools/apply_sprite_reshuffles.py <commit>    # explicit reference commit

The reference commit is the state of the .tres files BEFORE your reshuffles.
Default is HEAD~1 (one commit before now), which is right if your reshuffles
sit in the working tree, staged, or in the most recent commit.

Preserves the sprite at each item's OLD cell (leaves it there in case you
want to reuse it). Only paints over cells that receive a new sprite from a
reshuffle. Original master.png is overwritten in place — check git diff
before committing to sanity-check the reshuffle.
"""

from __future__ import annotations

import glob
import re
import subprocess
import sys
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
MASTER = PROJECT / 'assets/sprites/items_master.png'
TILE_PX = 32
COLS = 16


def parse_tile(text: str) -> int:
    m = re.search(r'^loy_tile_index\s*=\s*(-?\d+)$', text, re.MULTILINE)
    return int(m.group(1)) if m else -1


def get_historical_tile(rel_path: str, commit: str) -> int | None:
    """Read the .tres at the given git commit and pull its loy_tile_index."""
    try:
        blob = subprocess.check_output(
            ['git', '-C', str(PROJECT), 'show', f'{commit}:{rel_path}'],
            stderr=subprocess.DEVNULL,
        )
        return parse_tile(blob.decode('utf-8', errors='replace'))
    except subprocess.CalledProcessError:
        return None


def cell_rect(idx: int) -> tuple[int, int, int, int]:
    col = idx % COLS
    row = idx // COLS
    return (col * TILE_PX, row * TILE_PX,
            (col + 1) * TILE_PX, (row + 1) * TILE_PX)


def main() -> None:
    commit = sys.argv[1] if len(sys.argv) > 1 else 'HEAD~1'
    print(f'Reference commit for pre-shuffle state: {commit}')

    if not MASTER.is_file():
        print(f'ERROR: {MASTER.relative_to(PROJECT)} not found. '
              'Run tools/migrate_to_master_sheet.py first.')
        sys.exit(1)

    # Ask git which item .tres files changed relative to that reference —
    # cheap way to skip files we know weren't reshuffled.
    try:
        diff_names = subprocess.check_output(
            ['git', '-C', str(PROJECT), 'diff', '--name-only', commit,
             '--', 'resources/items/'],
            stderr=subprocess.DEVNULL,
        ).decode().strip().splitlines()
    except subprocess.CalledProcessError as e:
        print(f'ERROR: git diff failed. Is {commit} a real ref? ({e})')
        sys.exit(1)

    if not diff_names:
        print(f'No .tres files differ from {commit}. Nothing to reshuffle.')
        return

    print(f'{len(diff_names)} .tres files differ from {commit}.')

    moves: list[dict] = []
    for rel in diff_names:
        abs_path = PROJECT / rel
        if not abs_path.is_file():
            continue
        current_tile = parse_tile(abs_path.read_text())
        old_tile = get_historical_tile(rel, commit)
        if current_tile < 0 or old_tile is None or old_tile < 0:
            continue
        if current_tile != old_tile:
            moves.append({'path': rel, 'old': old_tile, 'new': current_tile})

    if not moves:
        print('No loy_tile_index changes found across the diff. Nothing to move.')
        return

    print(f'{len(moves)} items had their sprite pointer changed:')
    for m in moves[:15]:
        name = m['path'].replace('resources/items/', '')
        print(f'  {name}: cell {m["old"]} → {m["new"]}')
    if len(moves) > 15:
        print(f'  … and {len(moves) - 15} more.')

    # Load the current master (which is the source of the "old" sprites,
    # since it hasn't been regenerated since the migration).
    master = Image.open(MASTER).convert('RGBA')
    max_cells = (master.size[1] // TILE_PX) * COLS

    # For each move, crop from old cell, paste at new cell. Cache crops
    # first so simultaneous moves don't read from cells already overwritten.
    crops: list[tuple[int, Image.Image]] = []
    for m in moves:
        if m['old'] >= max_cells or m['new'] >= max_cells:
            print(f'  SKIP {m["path"]}: cell index out of range ({m["old"]} → {m["new"]}, max {max_cells - 1})')
            continue
        crops.append((m['new'], master.crop(cell_rect(m['old']))))

    # Now paste.
    for new_idx, sprite in crops:
        master.paste(sprite, (cell_rect(new_idx)[0], cell_rect(new_idx)[1]))

    master.save(MASTER)
    print(f'\nWrote {MASTER.relative_to(PROJECT)} ({master.size[0]}×{master.size[1]} px)')
    print(f'Repositioned {len(crops)} sprites. Hard-reload the editor to see it.')


if __name__ == '__main__':
    main()
