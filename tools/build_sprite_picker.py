#!/usr/bin/env python3
"""
Interactive sprite picker.

Generates `tools/sprite_picker.html` — a self-contained two-pane tool where
you click an item on the left and click a sprite cell on the right to assign
it. Tracks all your changes in browser memory, then lets you download a JSON
diff of `{ item_path: new_loy_tile_index }` mappings.

Companion script `apply_sprite_assignments.py` reads that JSON and patches
the .tres files for you.

Workflow:
    1. python3 tools/build_sprite_picker.py
    2. open tools/sprite_picker.html
    3. click an item card on the left → click any sprite cell on the right
    4. repeat for as many items as you like
    5. click "Download assignments.json" at the top
    6. python3 tools/apply_sprite_assignments.py ~/Downloads/assignments.json
    7. python3 tools/build_items_master_sheet.py (regenerate master)

Sprite cells available for assignment cover both tiles.png (0-255) and
tiles2.png (256-511). Cells that are already in use by other items are
labeled with a small badge so you can avoid clobbering — though you can
deliberately reuse a sprite if multiple items should share an icon.
"""

import re
import glob
import html
import base64
import json
from collections import defaultdict

SHEETS = {
    'tiles':  'assets/sprites/loy/tiles.png',   # indices 0-255
    'tiles2': 'assets/sprites/loy/tiles2.png',  # indices 256-511
}
TILE_PX = 32
DISPLAY_PX = 48   # right-pane cell size
LEFT_ICON_PX = 56 # left-pane item icon size
COLS = 16
ROWS_PER_SHEET = 16

SLOT_NAMES = {
    0: 'Melee', 1: 'Ranged', 2: 'Magic',
    3: 'Helm', 4: 'Body', 5: 'Shield', 6: 'Boots',
    7: 'Gloves', 8: 'Ring', 9: 'Cloak',
    10: 'Consumable', 11: 'Material', 12: 'Ammo',
}


def parse_item(p: str) -> dict | None:
    with open(p) as f:
        text = f.read()
    name = re.search(r'^item_name\s*=\s*"(.+?)"$', text, re.MULTILINE)
    slot = re.search(r'^slot_type\s*=\s*(\d+)$', text, re.MULTILINE)
    if not (name and slot):
        return None
    tile = re.search(r'^loy_tile_index\s*=\s*(-?\d+)$', text, re.MULTILINE)
    wtype = re.search(r'^weapon_type\s*=\s*"([a-z_]*)"$', text, re.MULTILINE)
    demo = re.search(r'^demo_approved\s*=\s*(true|false)$', text, re.MULTILINE)
    return {
        'path': p,
        'name': name.group(1),
        'slot': int(slot.group(1)),
        'tile': int(tile.group(1)) if tile else -1,
        'wtype': wtype.group(1) if wtype else '',
        'demo': demo.group(1) == 'true' if demo else False,
    }


def main() -> None:
    items: list[dict] = []
    for p in sorted(glob.glob('resources/items/**/*.tres', recursive=True)):
        d = parse_item(p)
        if d:
            items.append(d)

    # Embed both sheets as data: URLs once.
    sheet_urls = {}
    for k, path in SHEETS.items():
        with open(path, 'rb') as f:
            sheet_urls[k] = 'data:image/png;base64,' + base64.b64encode(f.read()).decode('ascii')

    # Count usage of each cell (badge "Nx" if shared).
    usage: dict[int, int] = defaultdict(int)
    for it in items:
        if it['tile'] >= 0:
            usage[it['tile']] += 1

    items_json = json.dumps([
        {'path': it['path'], 'name': it['name'], 'slot': it['slot'],
         'tile': it['tile'], 'wtype': it['wtype'], 'demo': it['demo']}
        for it in items
    ])
    usage_json = json.dumps(usage)

    out: list[str] = []
    out.append('<!doctype html><html><head><meta charset="utf-8"><title>Sprite Picker</title>')
    out.append('<style>')
    out.append(f':root{{--tiles:url("{sheet_urls["tiles"]}");--tiles2:url("{sheet_urls["tiles2"]}");}}')
    out.append('''
*{box-sizing:border-box;}
body{background:#16161b;color:#ddd;font-family:-apple-system,Helvetica,Arial,sans-serif;margin:0;height:100vh;overflow:hidden;display:flex;flex-direction:column;}
.topbar{padding:10px 16px;background:#1c1c22;border-bottom:1px solid #333;display:flex;align-items:center;gap:14px;}
.topbar h1{margin:0;font-size:16px;color:#fff;}
.topbar .stat{color:#aaa;font-size:13px;}
.topbar .stat b{color:#f0d090;}
.btn{background:#2a4a7a;color:#fff;border:0;padding:8px 14px;border-radius:5px;cursor:pointer;font-size:13px;}
.btn:hover{background:#3a5a9a;}
.btn.danger{background:#7a2a2a;}
.btn.danger:hover{background:#9a3a3a;}
.btn.ghost{background:#2a2a2a;}
.btn.ghost:hover{background:#3a3a3a;}
.main{flex:1;display:grid;grid-template-columns:340px 1fr;overflow:hidden;}
.pane{overflow-y:auto;padding:12px;}
.left{background:#1a1a1f;border-right:1px solid #333;}
.right{background:#1c1c20;}
.section-head{font-size:12px;text-transform:uppercase;letter-spacing:1px;color:#888;margin:14px 6px 8px;padding-bottom:4px;border-bottom:1px solid #333;}
.section-head:first-child{margin-top:0;}
.item{display:flex;gap:10px;padding:8px;margin-bottom:6px;background:#222226;border:1px solid transparent;border-radius:5px;cursor:pointer;}
.item:hover{background:#2a2a30;}
.item.selected{border-color:#f0d090;background:#2a2820;}
.item.changed{background:#1a2a1a;}
.item.changed .name::after{content:" *";color:#80c080;}
.item .icon{width:56px;height:56px;flex-shrink:0;background-color:#0a0a0e;border:1px solid #444;border-radius:3px;image-rendering:pixelated;}
.item .meta{flex:1;font-size:12px;line-height:1.3;min-width:0;}
.item .name{font-weight:600;font-size:13px;color:#fff;word-break:break-word;}
.item .sub{color:#999;font-size:11px;margin-top:2px;}
.item .tile-now{color:#888;font-family:monospace;font-size:11px;}
.item .tile-new{color:#80c080;font-family:monospace;font-size:11px;}
.controls{margin-bottom:12px;display:flex;gap:8px;align-items:center;flex-wrap:wrap;}
.controls input{background:#0a0a0e;color:#fff;border:1px solid #444;padding:6px 10px;border-radius:4px;flex:1;min-width:150px;}
.controls label{color:#aaa;font-size:13px;display:flex;gap:6px;align-items:center;}
.sheet-section{margin-bottom:24px;}
.sheet-title{font-size:13px;color:#aaa;margin-bottom:8px;}
.sheet-title b{color:#fff;}
.grid{display:grid;grid-template-columns:repeat(16,1fr);gap:2px;max-width:880px;}
.cell{position:relative;width:100%;aspect-ratio:1;background-color:#0a0a0e;border:1px solid #2a2a30;cursor:pointer;image-rendering:pixelated;}
.cell:hover{outline:2px solid #f0d090;outline-offset:-2px;z-index:1;}
.cell.assigned{outline:2px solid #80c080;outline-offset:-2px;z-index:1;}
.cell.used::after{content:attr(data-uses);position:absolute;top:1px;right:1px;background:rgba(0,0,0,0.7);color:#f0d090;font-size:9px;padding:0 3px;border-radius:2px;}
.cell-idx{position:absolute;bottom:0;left:0;background:rgba(0,0,0,0.55);color:#bbb;font-size:8px;padding:0 2px;font-family:monospace;line-height:1;}
.status{position:fixed;bottom:14px;right:14px;background:#2a3a2a;color:#dfd;padding:8px 12px;border-radius:4px;font-size:13px;opacity:0;transition:opacity 0.3s;}
.status.show{opacity:1;}
.empty-hint{color:#888;font-style:italic;padding:20px;text-align:center;}
''')
    out.append('</style></head><body>')
    out.append('''<div class="topbar">
<h1>Sprite Picker</h1>
<div class="stat"><b id="changed-count">0</b> changes pending</div>
<button class="btn" onclick="downloadJSON()">Download assignments.json</button>
<button class="btn ghost" onclick="resetAll()">Reset</button>
<div class="stat" style="margin-left:auto;">Click an item, then click a sprite cell.</div>
</div>''')

    out.append('<div class="main">')

    # ============== LEFT PANE: items grouped by slot ==============
    out.append('<div class="pane left">')
    out.append('<div class="controls">')
    out.append('<input id="item-filter" type="text" placeholder="Filter items…" oninput="filterItems()">')
    out.append('</div>')

    by_slot: dict[int, list[dict]] = defaultdict(list)
    for it in items:
        by_slot[it['slot']].append(it)
    for s in by_slot:
        by_slot[s].sort(key=lambda x: x['name'])

    for slot in sorted(by_slot):
        name = SLOT_NAMES.get(slot, f"slot {slot}")
        out.append(f'<div class="section-head">{html.escape(name)} ({len(by_slot[slot])})</div>')
        for it in by_slot[slot]:
            short = it['path'].replace('resources/items/', '')
            out.append(
                f'<div class="item" data-path="{html.escape(it["path"])}" '
                f'data-name="{html.escape(it["name"].lower())}" '
                f'data-tile="{it["tile"]}" '
                f'onclick="selectItem(this)">'
            )
            # icon shows current sprite (or grey if -1)
            out.append('<div class="icon" data-current="1"></div>')
            out.append('<div class="meta">')
            out.append(f'<div class="name">{html.escape(it["name"])}</div>')
            out.append(f'<div class="sub">{html.escape(short)}</div>')
            out.append(f'<div class="tile-now">tile #<span class="tile-num">{it["tile"]}</span></div>')
            out.append('</div></div>')
    out.append('</div>')  # /left

    # ============== RIGHT PANE: spritesheet grids ==============
    out.append('<div class="pane right">')
    out.append('<div class="empty-hint" id="empty-hint">'
               '← Select an item from the left to start assigning. '
               'Then click any sprite cell here.</div>')

    out.append('<div id="sheets" style="display:none;">')
    for sheet_key, sheet_url in sheet_urls.items():
        base = 0 if sheet_key == 'tiles' else 256
        label = 'tiles.png (0–255)' if sheet_key == 'tiles' else 'tiles2.png (256–511)'
        out.append(f'<div class="sheet-section">')
        out.append(f'<div class="sheet-title"><b>{label}</b> — click any cell to assign</div>')
        out.append('<div class="grid">')
        for r in range(ROWS_PER_SHEET):
            for c in range(COLS):
                idx = base + r * COLS + c
                style = (
                    f'background-image:var(--{sheet_key});'
                    f'background-position:-{c * DISPLAY_PX}px -{r * DISPLAY_PX}px;'
                    f'background-size:{COLS * DISPLAY_PX}px auto;'
                )
                used_class = ' used' if usage.get(idx, 0) > 0 else ''
                uses_attr = f' data-uses="{usage.get(idx, 0)}x"' if usage.get(idx, 0) > 0 else ''
                out.append(
                    f'<div class="cell{used_class}" data-idx="{idx}" style="{style}"{uses_attr} '
                    f'onclick="assignCell({idx})">'
                    f'<span class="cell-idx">{idx}</span></div>'
                )
        out.append('</div></div>')
    out.append('</div>')  # /sheets
    out.append('</div>')  # /right
    out.append('</div>')  # /main
    out.append('<div class="status" id="status">Saved.</div>')

    # ============== JS ==============
    out.append('<script>')
    out.append(f'const ITEMS = {items_json};')
    out.append(f'const USAGE = {usage_json};')
    out.append('''
const COLS = 16;
const TILE_PX = 32;
const DISPLAY_PX = 48;
const LEFT_ICON_PX = 56;
const SHEET_URLS = {
  tiles: 'var(--tiles)',
  tiles2: 'var(--tiles2)',
};
let assignments = {};   // path -> new tile index
let selectedPath = null;

function setIconStyle(el, tile, displayPx){
  if(tile < 0){
    el.style.background = 'repeating-linear-gradient(45deg,#222 0 6px,#111 6px 12px)';
    el.style.backgroundImage = '';
    return;
  }
  const sheetKey = tile < 256 ? 'tiles' : 'tiles2';
  const local = tile % 256;
  const col = local % COLS;
  const row = Math.floor(local / COLS);
  el.style.backgroundImage = SHEET_URLS[sheetKey];
  el.style.backgroundPosition = `-${col * displayPx}px -${row * displayPx}px`;
  el.style.backgroundSize = `${COLS * displayPx}px auto`;
  el.style.imageRendering = 'pixelated';
}

function paintAllIcons(){
  ITEMS.forEach(it => {
    const card = document.querySelector(`.item[data-path="${CSS.escape(it.path)}"]`);
    if(!card) return;
    const icon = card.querySelector('.icon[data-current]');
    const tile = (assignments[it.path] !== undefined) ? assignments[it.path] : it.tile;
    setIconStyle(icon, tile, LEFT_ICON_PX);
    card.querySelector('.tile-num').textContent = tile;
    card.classList.toggle('changed', assignments[it.path] !== undefined && assignments[it.path] !== it.tile);
  });
}

function selectItem(card){
  document.querySelectorAll('.item.selected').forEach(c => c.classList.remove('selected'));
  card.classList.add('selected');
  selectedPath = card.dataset.path;
  document.getElementById('empty-hint').style.display = 'none';
  document.getElementById('sheets').style.display = '';
  // highlight current cell
  document.querySelectorAll('.cell.assigned').forEach(c => c.classList.remove('assigned'));
  const it = ITEMS.find(x => x.path === selectedPath);
  const tile = (assignments[selectedPath] !== undefined) ? assignments[selectedPath] : it.tile;
  if(tile >= 0){
    const cell = document.querySelector(`.cell[data-idx="${tile}"]`);
    if(cell){
      cell.classList.add('assigned');
      cell.scrollIntoView({block:'center', behavior:'smooth'});
    }
  }
}

function assignCell(idx){
  if(!selectedPath) return;
  const it = ITEMS.find(x => x.path === selectedPath);
  if(idx === it.tile){
    delete assignments[selectedPath];
  } else {
    assignments[selectedPath] = idx;
  }
  paintAllIcons();
  document.querySelectorAll('.cell.assigned').forEach(c => c.classList.remove('assigned'));
  const cell = document.querySelector(`.cell[data-idx="${idx}"]`);
  if(cell) cell.classList.add('assigned');
  updateCounter();
  flash('Assigned cell ' + idx);
}

function updateCounter(){
  document.getElementById('changed-count').textContent = Object.keys(assignments).length;
}

function flash(msg){
  const s = document.getElementById('status');
  s.textContent = msg;
  s.classList.add('show');
  clearTimeout(window._flashTimer);
  window._flashTimer = setTimeout(() => s.classList.remove('show'), 1500);
}

function downloadJSON(){
  const out = Object.keys(assignments).map(p => ({path: p, tile: assignments[p]}));
  if(out.length === 0){ flash('Nothing to download.'); return; }
  const blob = new Blob([JSON.stringify(out, null, 2)], {type:'application/json'});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'assignments.json';
  a.click();
  URL.revokeObjectURL(a.href);
  flash('Downloaded assignments.json');
}

function resetAll(){
  if(!confirm('Clear all pending assignments?')) return;
  assignments = {};
  paintAllIcons();
  document.querySelectorAll('.cell.assigned').forEach(c => c.classList.remove('assigned'));
  updateCounter();
  flash('Reset.');
}

function filterItems(){
  const q = document.getElementById('item-filter').value.toLowerCase();
  document.querySelectorAll('.item').forEach(c => {
    c.style.display = (!q || c.dataset.name.indexOf(q) !== -1) ? '' : 'none';
  });
}

paintAllIcons();
''')
    out.append('</script></body></html>')

    with open('tools/sprite_picker.html', 'w') as f:
        f.write('\n'.join(out))
    print(f"Wrote tools/sprite_picker.html ({len(items)} items, 512 sprite cells)")


if __name__ == '__main__':
    main()
