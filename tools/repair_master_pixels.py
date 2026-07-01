#!/usr/bin/env python3
"""
Repaint items_master.png so each item's CHOSEN sprite lands at that item's
CURRENT tile position. Every item + its sprite move together as a pair.

"Chosen sprite" means:
- For an item that was never manually reshuffled: its own LoY sprite (the
  one it had at the pre-migration commit).
- For an item that WAS manually reshuffled (loy_tile_index changed between
  the post-first-migration commit and the post-reshuffle commit): the LoY
  sprite of the OTHER item that owned the target cell — i.e. whichever
  sprite the user pointed this item at.

That preserves the user's intent ("iron_dagger should show broadsword's
sprite") across any layout reordering: iron_dagger and broadsword each keep
their own tier positions, and both cells carry the broadsword-style sprite.

Does NOT touch any .tres — positions there are authoritative.

Usage:

    python3 tools/repair_master_pixels.py
    python3 tools/repair_master_pixels.py <pre_commit> <post_mig> <post_reshuffle>

Defaults:
    pre_commit       = 5acd2a2^   (last commit BEFORE the first migration,
                                   items still hold LoY tile indices)
    post_mig         = 5acd2a2    (post first migration, alphabetical layout)
    post_reshuffle   = d1589fb    (after the user's 67 manual reshuffles)
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
DEFAULT_PRE = '5acd2a2^'
DEFAULT_POST_MIG = '5acd2a2'
DEFAULT_POST_RESHUFFLE = 'd1589fb'


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


def load_tiles_snapshot(commit: str, rel_paths: list[str]) -> dict[str, int]:
    out: dict[str, int] = {}
    for rel in rel_paths:
        text = git_read(commit, rel)
        if text is None:
            continue
        t = parse_tile(text)
        if t >= 0:
            out[rel] = t
    return out


def loy_sprite(loy_tile: int, tiles: Image.Image, tiles2: Image.Image) -> Image.Image | None:
    if loy_tile < 0:
        return None
    if loy_tile < 256:
        return crop_cell(tiles, loy_tile)
    if loy_tile < 512:
        return crop_cell(tiles2, loy_tile - 256)
    return None


def main() -> None:
    pre = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PRE
    post_mig = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_POST_MIG
    post_reshuffle = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_POST_RESHUFFLE
    print(f'Pre-migration commit    : {pre}')
    print(f'Post-migration commit   : {post_mig}')
    print(f'Post-user-reshuffle     : {post_reshuffle}')

    if not MASTER_PATH.is_file():
        print(f'ERROR: {MASTER_PATH.relative_to(PROJECT)} missing.')
        sys.exit(1)

    tiles = Image.open(TILES_PATH).convert('RGBA')
    tiles2 = Image.open(TILES2_PATH).convert('RGBA')
    existing = Image.open(MASTER_PATH).convert('RGBA')

    items = list(PROJECT.glob('resources/items/**/*.tres'))
    rel_paths = [str(p.relative_to(PROJECT)) for p in items]
    print(f'Repairing {len(items)} items…')

    # Snapshots at the two reference commits.
    tiles_pre = load_tiles_snapshot(pre, rel_paths)                    # each item → own LoY tile
    tiles_post_mig = load_tiles_snapshot(post_mig, rel_paths)          # each item → alphabetical cell
    tiles_post_reshuffle = load_tiles_snapshot(post_reshuffle, rel_paths)  # each item → post-reshuffle cell

    # Cell → owner map at 5acd2a2 (each cell had exactly one owner then).
    cell_to_owner: dict[int, str] = {}
    for rel, tile in tiles_post_mig.items():
        cell_to_owner.setdefault(tile, rel)

    # Fresh canvas so orphan cells stay transparent.
    master = Image.new('RGBA', existing.size, (0, 0, 0, 0))

    placed = 0
    skipped = 0
    reshuffled = 0
    for p, rel in zip(items, rel_paths):
        current_tile = parse_tile(p.read_text())
        if current_tile < 0:
            continue

        pm = tiles_post_mig.get(rel, -1)
        pr = tiles_post_reshuffle.get(rel, -1)

        # Decide which item's LoY sprite this item should DISPLAY.
        source_rel: str | None
        if pm >= 0 and pr >= 0 and pm != pr:
            # User reshuffled — display whoever owned the target cell.
            source_rel = cell_to_owner.get(pr)
            reshuffled += 1
        else:
            # Never reshuffled — display own sprite.
            source_rel = rel

        if source_rel is None:
            skipped += 1
            continue

        loy_tile = tiles_pre.get(source_rel, -1)
        sprite = loy_sprite(loy_tile, tiles, tiles2)
        if sprite is None:
            skipped += 1
            continue

        x, y = cell_pos(current_tile)
        master.paste(sprite, (x, y), sprite)
        placed += 1

    master.save(MASTER_PATH)
    print(f'Placed {placed} sprites '
          f'({reshuffled} of which were user reshuffles), skipped {skipped}.')
    print(f'Wrote {MASTER_PATH.relative_to(PROJECT)} ({master.size[0]}×{master.size[1]} px)')
    print('Hard-reload the editor to see it.')


if __name__ == '__main__':
    main()
