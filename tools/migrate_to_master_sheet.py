#!/usr/bin/env python3
"""
Migration: consolidate all item sprites into a single grouped master sheet.

What this does, in order:

1. Lays out a fresh `assets/sprites/items_master.png` (512×3456 px, 16 cols ×
   108 rows × 32 px tiles).
2. Groups items by `slot_type` — Melee block first, then Ranged, Magic, Helm,
   Body, Shield, Boots, Gloves, Ring, Cloak, Consumable, Material, Ammo. Each
   group is followed by 5 empty rows so you can paint in new sprites of that
   slot type without renumbering anything.
3. Within each group items are sorted alphabetically by item_name for stable
   placement. Each item's current sprite is cropped from the appropriate
   source sheet (`tiles.png` for old idx 0-255, `tiles2.png` for 256+) and
   pasted into its new cell.
4. Rewrites `loy_tile_index = N` in every .tres so each item points at its
   new cell in the master sheet.
5. Patches `scripts/ui/item_icon_helper.gd` to load only `items_master.png`,
   updates the col/row math (cols still 16, rows now 108), and remaps the
   per-slot default tile to the first cell of each slot's section.
6. Writes `tools/items_master_layout.md` documenting the section ranges so
   future-you can find any item's neighbourhood.

Run from the project root:

    python3 tools/migrate_to_master_sheet.py

Reversible via git (rev the commit). Idempotent — running it twice produces
the same result.
"""

from __future__ import annotations

import glob
import re
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
TILES_PATH = PROJECT / 'assets/sprites/loy/tiles.png'
TILES2_PATH = PROJECT / 'assets/sprites/loy/tiles2.png'
MASTER_PATH = PROJECT / 'assets/sprites/items_master.png'
HELPER_PATH = PROJECT / 'scripts/ui/item_icon_helper.gd'
LAYOUT_DOC = PROJECT / 'tools/items_master_layout.md'

TILE_PX = 32
COLS = 16
GAP_ROWS = 5

SLOT_ORDER = [
    (0, 'Melee'), (1, 'Ranged'), (2, 'Magic'),
    (3, 'Helm'), (4, 'Body'), (5, 'Shield'),
    (6, 'Boots'), (7, 'Gloves'), (8, 'Ring'), (9, 'Cloak'),
    (10, 'Consumable'), (11, 'Material'), (12, 'Ammo'),
]


def parse_item(path: Path) -> dict | None:
    text = path.read_text()
    n = re.search(r'^item_name\s*=\s*"(.+?)"$', text, re.MULTILINE)
    s = re.search(r'^slot_type\s*=\s*(\d+)$', text, re.MULTILINE)
    t = re.search(r'^loy_tile_index\s*=\s*(-?\d+)$', text, re.MULTILINE)
    if not (n and s):
        return None
    r = re.search(r'^rarity\s*=\s*(\d+)$', text, re.MULTILINE)
    b = re.search(r'^buy_price\s*=\s*([-0-9]+)$', text, re.MULTILINE)
    return {
        'path': path,
        'name': n.group(1),
        'slot': int(s.group(1)),
        'old_tile': int(t.group(1)) if t else -1,
        'rarity': int(r.group(1)) if r else 0,
        'buy_price': int(b.group(1)) if b else 0,
    }


def crop_from_sheet(idx: int, sheet: Image.Image) -> Image.Image | None:
    """Crop the 32×32 cell at grid position idx from any 16-wide sprite sheet."""
    if idx < 0:
        return None
    max_cells = (sheet.size[1] // TILE_PX) * COLS
    if idx >= max_cells:
        return None
    c = idx % COLS
    r = idx // COLS
    return sheet.crop((c * TILE_PX, r * TILE_PX, (c + 1) * TILE_PX, (r + 1) * TILE_PX))


def resolve_source_sprite(
    old_tile: int,
    tiles: Image.Image,
    tiles2: Image.Image,
    current_master: Image.Image | None,
) -> Image.Image | None:
    """Pick the correct source sheet.

    Critical: once a master exists, EVERY item's loy_tile_index is a master
    coordinate — not a LoY (tiles.png/tiles2.png) coordinate. Even values like
    cell 32 or cell 200 look like they could be LoY indices, but after the
    first migration they refer to positions inside items_master.png. So we
    must always use the master when it exists; only fall back to the LoY
    sheets on a truly fresh migration.
    """
    if old_tile < 0:
        return None
    if current_master is not None:
        return crop_from_sheet(old_tile, current_master)
    # Fresh install fallback: master doesn't exist yet, indices are LoY coords.
    if old_tile < 256:
        return crop_from_sheet(old_tile, tiles)
    if old_tile < 512:
        return crop_from_sheet(old_tile - 256, tiles2)
    return None


def main() -> None:
    print('Loading source sheets…')
    tiles = Image.open(TILES_PATH).convert('RGBA')
    tiles2 = Image.open(TILES2_PATH).convert('RGBA')
    # If a master already exists it becomes the source for any item whose
    # current loy_tile_index lives in the master range (>=512). That way a
    # re-migration correctly carries each item's sprite from its current
    # cell to its new cell instead of accidentally cropping from tiles.png
    # at a bogus offset (which is what wrecked the last re-migration).
    current_master: Image.Image | None = None
    if MASTER_PATH.is_file():
        current_master = Image.open(MASTER_PATH).convert('RGBA')
        print(f'  using existing {MASTER_PATH.relative_to(PROJECT)} '
              f'({current_master.size[0]}×{current_master.size[1]}) as source '
              'for items in master-range indices')

    print('Scanning items…')
    items: list[dict] = []
    for p in sorted(PROJECT.glob('resources/items/**/*.tres')):
        d = parse_item(p)
        if d:
            items.append(d)
    print(f'  {len(items)} items')

    by_slot: dict[int, list[dict]] = {s: [] for s, _ in SLOT_ORDER}
    for it in items:
        by_slot.setdefault(it['slot'], []).append(it)
    # Sort each slot section by tier: rarity (0 common → 2 rare) first, then
    # buy_price (cheap → expensive) as a stable tier proxy, then name for tie
    # break. Result: early-game gear at the top of each slot block, later-tier
    # / boss drops further down.
    for s in by_slot:
        by_slot[s].sort(key=lambda x: (x['rarity'], x['buy_price'], x['name'].lower()))

    # Compute section row ranges.
    sections: list[dict] = []
    cur_row = 0
    for slot_id, slot_name in SLOT_ORDER:
        n = len(by_slot.get(slot_id, []))
        rows_used = (n + COLS - 1) // COLS if n else 0
        start_row = cur_row
        end_row = start_row + rows_used  # exclusive
        sections.append({
            'slot': slot_id, 'name': slot_name, 'count': n,
            'start_row': start_row, 'end_row': end_row,
            'gap_end_row': end_row + GAP_ROWS,
        })
        cur_row = end_row + GAP_ROWS

    total_rows = cur_row
    print(f'Master sheet layout: {COLS} cols × {total_rows} rows ({total_rows * TILE_PX} px tall)')

    master = Image.new('RGBA', (COLS * TILE_PX, total_rows * TILE_PX), (0, 0, 0, 0))

    # Place each item, capture path → new_idx mapping.
    new_index: dict[Path, int] = {}
    for sec in sections:
        slot_id = sec['slot']
        group = by_slot.get(slot_id, [])
        for i, it in enumerate(group):
            c = i % COLS
            r = sec['start_row'] + i // COLS
            sprite = resolve_source_sprite(it['old_tile'], tiles, tiles2, current_master)
            if sprite is not None:
                master.paste(sprite, (c * TILE_PX, r * TILE_PX), sprite)
            new_index[it['path']] = r * COLS + c

    MASTER_PATH.parent.mkdir(parents=True, exist_ok=True)
    master.save(MASTER_PATH)
    print(f'Wrote {MASTER_PATH.relative_to(PROJECT)} ({master.size[0]}×{master.size[1]} px)')

    # Rewrite every .tres.
    print('Rewriting loy_tile_index in .tres files…')
    rewritten = 0
    for it in items:
        new_idx = new_index[it['path']]
        text = it['path'].read_text()
        pat = r'^loy_tile_index\s*=\s*(-?\d+)$'
        if re.search(pat, text, re.MULTILINE):
            new_text = re.sub(pat, f'loy_tile_index = {new_idx}', text, count=1, flags=re.MULTILINE)
        else:
            # Insert after item_name as the convention.
            new_text = re.sub(
                r'^(item_name\s*=\s*".+?")$',
                rf'\1\nloy_tile_index = {new_idx}',
                text, count=1, flags=re.MULTILINE,
            )
        if new_text != text:
            it['path'].write_text(new_text)
            rewritten += 1
    print(f'  rewrote {rewritten} files')

    # Patch ItemIconHelper to use the master sheet.
    patch_icon_helper(sections)
    print(f'Patched {HELPER_PATH.relative_to(PROJECT)}')

    # Write the human-readable layout doc.
    write_layout_doc(sections, by_slot, new_index)
    print(f'Wrote {LAYOUT_DOC.relative_to(PROJECT)}')

    print()
    print('Done. Verify with:')
    print('    /Users/developer-cloudprimero/Downloads/Godot.app/Contents/MacOS/Godot \\')
    print('        --headless --path . --export-release "macOS"')


def patch_icon_helper(sections: list[dict]) -> None:
    """Rewrite item_icon_helper.gd to use one master texture + new slot defaults."""
    # Each slot's default tile is the first cell of its new section (row * 16).
    slot_default = {s['slot']: s['start_row'] * COLS for s in sections if s['count'] > 0}
    new_content = f'''class_name ItemIconHelper
extends RefCounted

## Maps EquipmentItem → AtlasTexture from items_master.png using loy_tile_index.
##
## items_master.png is the single consolidated 16-wide sprite sheet built by
## tools/migrate_to_master_sheet.py. tiles.png + tiles2.png are no longer
## referenced for item icons — every item's loy_tile_index points into this
## master sheet, grouped by slot type (see tools/items_master_layout.md).

const COLS := 16
const TILE_PX := 32

static var _master_tex: Texture2D

static func _ensure_textures() -> void:
	if not _master_tex:
		_master_tex = load("res://assets/sprites/items_master.png") as Texture2D

## Get an AtlasTexture for the item's icon from the master sheet.
static func get_icon_texture(item: EquipmentItem) -> Texture2D:
	if not item or item.loy_tile_index < 0:
		return null
	_ensure_textures()
	if not _master_tex:
		return null
	var idx: int = item.loy_tile_index
	var col: int = idx % COLS
	var row: int = idx / COLS
	var atlas := AtlasTexture.new()
	atlas.atlas = _master_tex
	atlas.region = Rect2(col * TILE_PX, row * TILE_PX, TILE_PX, TILE_PX)
	return atlas

## Get the loy_tile_index (for compatibility)
static func get_sprite_index(item: EquipmentItem) -> int:
	if not item:
		return -1
	return item.loy_tile_index

## Get a default icon texture for an empty equip slot. Indices are now the
## first cell of each slot's section in the master sheet (see migration tool).
static func get_slot_icon_texture(slot: EquipmentItem.SlotType) -> Texture2D:
	_ensure_textures()
	var idx: int = _slot_default_tile(slot)
	if idx < 0 or not _master_tex:
		return null
	var col: int = idx % COLS
	var row: int = idx / COLS
	var atlas := AtlasTexture.new()
	atlas.atlas = _master_tex
	atlas.region = Rect2(col * TILE_PX, row * TILE_PX, TILE_PX, TILE_PX)
	return atlas

static func _slot_default_tile(slot: EquipmentItem.SlotType) -> int:
	match slot:
'''
    for slot_id, slot_name in SLOT_ORDER:
        default = slot_default.get(slot_id, -1)
        if default < 0:
            continue
        enum_name = {
            0: 'WEAPON_MELEE', 1: 'WEAPON_RANGED', 2: 'WEAPON_MAGIC',
            3: 'HELM', 4: 'BODY', 5: 'SHIELD', 6: 'BOOTS',
            7: 'GLOVES', 8: 'RING', 9: 'CLOAK',
            10: 'CONSUMABLE', 11: 'MATERIAL', 12: 'AMMO',
        }[slot_id]
        new_content += f'\t\tEquipmentItem.SlotType.{enum_name}: return {default}\n'
    new_content += '''\treturn -1

static func get_slot_name(slot: EquipmentItem.SlotType) -> String:
	match slot:
		EquipmentItem.SlotType.WEAPON_MELEE: return "Melee"
		EquipmentItem.SlotType.WEAPON_RANGED: return "Ranged"
		EquipmentItem.SlotType.WEAPON_MAGIC: return "Magic"
		EquipmentItem.SlotType.HELM: return "Helm"
		EquipmentItem.SlotType.BODY: return "Body"
		EquipmentItem.SlotType.SHIELD: return "Shield"
		EquipmentItem.SlotType.BOOTS: return "Boots"
		EquipmentItem.SlotType.GLOVES: return "Gloves"
		EquipmentItem.SlotType.RING: return "Ring"
		EquipmentItem.SlotType.CLOAK: return "Cloak"
		EquipmentItem.SlotType.CONSUMABLE: return "Use"
		EquipmentItem.SlotType.MATERIAL: return "Mat"
	return "?"
'''
    HELPER_PATH.write_text(new_content)


def write_layout_doc(sections: list[dict], by_slot: dict[int, list[dict]], new_index: dict[Path, int]) -> None:
    out: list[str] = []
    out.append('# Items Master Sheet Layout')
    out.append('')
    out.append('Generated by `tools/migrate_to_master_sheet.py`. The master sheet '
               f'is at `assets/sprites/items_master.png` ({COLS} cols × variable '
               f'rows × {TILE_PX} px). All item `loy_tile_index` values point '
               'into this single sheet — no more tiles.png / tiles2.png split.')
    out.append('')
    out.append('## Section ranges')
    out.append('')
    out.append('| Slot | Items | Row range (inclusive) | Cell range | Empty gap after |')
    out.append('|---|---|---|---|---|')
    for sec in sections:
        if sec['count'] == 0:
            continue
        first_cell = sec['start_row'] * COLS
        last_cell = sec['end_row'] * COLS - 1
        gap_start_row = sec['end_row']
        gap_end_row = sec['gap_end_row'] - 1
        out.append(
            f"| {sec['name']} | {sec['count']} | rows {sec['start_row']}–{sec['end_row'] - 1} "
            f"| cells {first_cell}–{last_cell} "
            f"| rows {gap_start_row}–{gap_end_row} ({GAP_ROWS * COLS} free cells) |"
        )
    out.append('')
    out.append('To add a new item of a given slot:')
    out.append('1. Open `assets/sprites/items_master.png` in your image editor.')
    out.append('2. Paint a new 32×32 sprite into an **empty cell inside that slot\'s gap rows**.')
    out.append('3. Set the new item\'s `loy_tile_index` to that cell number.')
    out.append('')
    out.append('## Items by section')
    out.append('')
    for sec in sections:
        if sec['count'] == 0:
            continue
        out.append(f'### {sec["name"]} ({sec["count"]} items)')
        out.append('')
        for it in by_slot[sec['slot']]:
            idx = new_index[it['path']]
            short = str(it['path'].relative_to(PROJECT)).replace('resources/items/', '')
            out.append(f'- **#{idx}** — {it["name"]} (`{short}`)')
        out.append('')

    LAYOUT_DOC.write_text('\n'.join(out))


if __name__ == '__main__':
    main()
