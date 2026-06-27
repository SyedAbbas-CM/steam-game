#!/usr/bin/env python3
"""
Apply the JSON dumped by tools/sprite_picker.html to the .tres files.

The JSON is a list of {"path": "resources/items/.../foo.tres", "tile": 234}
objects. For each entry we rewrite the matching .tres file's
loy_tile_index = N line. No other content is touched.

Usage:
    python3 tools/apply_sprite_assignments.py <path-to-assignments.json>

Prints a summary of what changed; the underlying .tres files are edited in
place. Run `python3 tools/build_items_master_sheet.py` afterwards to refresh
the master sprite PNG (it pulls live sprites from tiles.png / tiles2.png at
each item's current loy_tile_index, so the updated indices flow through).
"""

import json
import re
import sys
from pathlib import Path


def apply(path: Path, new_tile: int) -> tuple[bool, int | None]:
    if not path.is_file():
        return False, None
    text = path.read_text()
    m = re.search(r'^loy_tile_index\s*=\s*(-?\d+)$', text, re.MULTILINE)
    if not m:
        # Item doesn't have the field — insert after item_name as a reasonable home.
        insert = f'loy_tile_index = {new_tile}\n'
        new_text = re.sub(
            r'^(item_name\s*=\s*".+?")$',
            r'\1\n' + insert.rstrip(),
            text, count=1, flags=re.MULTILINE,
        )
        if new_text == text:
            return False, None
        path.write_text(new_text)
        return True, None
    old = int(m.group(1))
    if old == new_tile:
        return False, old
    new_text = text[:m.start()] + f'loy_tile_index = {new_tile}' + text[m.end():]
    path.write_text(new_text)
    return True, old


def main() -> None:
    if len(sys.argv) != 2:
        print('Usage: python3 tools/apply_sprite_assignments.py <assignments.json>')
        sys.exit(1)

    payload = json.loads(Path(sys.argv[1]).read_text())
    if not isinstance(payload, list):
        print('JSON must be a list of {path, tile} objects.')
        sys.exit(1)

    changed = 0
    skipped = 0
    missing = 0
    for entry in payload:
        path = Path(entry['path'])
        new_tile = int(entry['tile'])
        ok, old = apply(path, new_tile)
        if ok:
            changed += 1
            print(f'  {path.name}: {old} → {new_tile}')
        elif old is None:
            missing += 1
            print(f'  MISSING: {path}')
        else:
            skipped += 1

    print()
    print(f'Changed {changed} files. Skipped {skipped} (no-op). Missing {missing}.')


if __name__ == '__main__':
    main()
