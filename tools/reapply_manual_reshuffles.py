#!/usr/bin/env python3
"""
Reapply the manual sprite reshuffles from a past commit on top of the
current tier-ordered layout, semantically.

The intent captured in a reshuffle like "iron_dagger: 68 → 19" was:
    "make iron_dagger display whatever sprite lives at cell 19."

At the time of the reshuffle (post-first-migration, pre-tier), cell 19 was
owned by a specific item (say, broadsword). After the tier reorder that
same target item moved to a new tile. To preserve the reshuffle intent, we
need to point iron_dagger at broadsword's CURRENT tier tile.

Reads both a "post first migration" commit (default 5acd2a2, alphabetical)
and a "post manual reshuffle" commit (default d1589fb). Every item whose
tile changed between them was manually reshuffled by the user.

For each such (item, target_cell) pair:
  1. Find the item that at 5acd2a2 lived at target_cell — call it target.
  2. Read target's current tile in the working tree.
  3. Rewrite item's current .tres to point at target's current tile.

Usage:

    python3 tools/reapply_manual_reshuffles.py
    python3 tools/reapply_manual_reshuffles.py 5acd2a2 d1589fb

Master.png is untouched — the repair already painted correct sprites at
every tier position, so retargeting a pointer is enough.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
POST_MIG_DEFAULT = '5acd2a2'   # post first migration (alphabetical)
POST_RESHUFFLE_DEFAULT = 'd1589fb'  # after user's 67 reshuffles


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


def load_tiles(commit: str, rel_paths: list[str]) -> dict[str, int]:
    out: dict[str, int] = {}
    for rel in rel_paths:
        text = git_read(commit, rel)
        if text is None:
            continue
        t = parse_tile(text)
        if t >= 0:
            out[rel] = t
    return out


def main() -> None:
    post_mig = sys.argv[1] if len(sys.argv) > 1 else POST_MIG_DEFAULT
    post_reshuffle = sys.argv[2] if len(sys.argv) > 2 else POST_RESHUFFLE_DEFAULT
    print(f'Post-first-migration commit: {post_mig}')
    print(f'Post-manual-reshuffle commit: {post_reshuffle}')

    # Enumerate current items on disk.
    items = list(PROJECT.glob('resources/items/**/*.tres'))
    rel_paths = [str(p.relative_to(PROJECT)) for p in items]
    print(f'Enumerating {len(items)} items…')

    # Read tile snapshots at both reference commits.
    tiles_post_mig = load_tiles(post_mig, rel_paths)
    tiles_post_reshuffle = load_tiles(post_reshuffle, rel_paths)

    # Which items had their tile changed by the user between the two commits.
    reshuffles: list[tuple[str, int, int]] = []
    for rel in rel_paths:
        pm = tiles_post_mig.get(rel, -1)
        pr = tiles_post_reshuffle.get(rel, -1)
        if pm >= 0 and pr >= 0 and pm != pr:
            reshuffles.append((rel, pm, pr))
    print(f'Detected {len(reshuffles)} manual reshuffles.')

    # Build post-mig cell → item map (each cell owned by exactly one item at
    # 5acd2a2, since the first migration assigned unique cells).
    cell_to_owner: dict[int, str] = {}
    for rel, tile in tiles_post_mig.items():
        if tile not in cell_to_owner:
            cell_to_owner[tile] = rel

    # Read current-on-disk tiles so we know where each owner now lives.
    current_tiles: dict[str, int] = {}
    for p, rel in zip(items, rel_paths):
        current_tiles[rel] = parse_tile(p.read_text())

    # Apply.
    applied = 0
    skipped = 0
    log: list[str] = []
    for rel, old_pm_tile, target_cell in reshuffles:
        owner_rel = cell_to_owner.get(target_cell)
        if owner_rel is None:
            skipped += 1
            log.append(f'  SKIP {rel}: no owner known for target cell {target_cell}')
            continue
        target_current = current_tiles.get(owner_rel, -1)
        if target_current < 0:
            skipped += 1
            log.append(f'  SKIP {rel}: target {owner_rel} has no current tile')
            continue

        # Rewrite this item's loy_tile_index in place.
        p = PROJECT / rel
        text = p.read_text()
        pat = r'^loy_tile_index\s*=\s*(-?\d+)$'
        new_text = re.sub(pat, f'loy_tile_index = {target_current}', text, count=1, flags=re.MULTILINE)
        if new_text == text:
            skipped += 1
            log.append(f'  SKIP {rel}: no loy_tile_index line to patch')
            continue
        p.write_text(new_text)
        applied += 1
        cur_before = current_tiles[rel]
        log.append(f'  {rel}: cell {cur_before} → {target_current} '
                   f'(mimics {owner_rel.replace("resources/items/", "")})')

    print(f'\nApplied {applied} reshuffles, skipped {skipped}.')
    print()
    for line in log[:30]:
        print(line)
    if len(log) > 30:
        print(f'  … and {len(log) - 30} more.')
    print('\nDone. Hard-reload the editor to see it.')


if __name__ == '__main__':
    main()
