#!/usr/bin/env python3
"""
Unified item editor for EquipmentItem .tres files.

One tool, one command. Browse every item, change its sprite, rename it,
edit its stats, toggle flags — all in the browser, writes saves straight
back to disk.

Run from the project root:

    python3 tools/item_editor.py

It starts a tiny local HTTP server (default port 8765), opens your default
browser, and serves a three-pane editor:

    [ item list (filter)  |  sprite grid (click)  |  edit form (save) ]

The page bundles all 574 items + both sprite sheets in one HTML payload, so
clicking sprites and switching items is instant — only saves hit the server.

Editable fields:
    - item_name (rename)
    - description (multi-line)
    - slot_type (dropdown of MELEE / RANGED / MAGIC / HELM / BODY / SHIELD /
      BOOTS / GLOVES / RING / CLOAK / CONSUMABLE / MATERIAL / AMMO)
    - weapon_type (free string — sword, dagger, bow, …)
    - loy_tile_index (click any cell in the middle pane)
    - rarity, buy_price, sell_value
    - heal_hp, heal_mp (consumables)
    - demo_approved, is_quest_item (toggles)
    - existing modifiers: stat type, flat_bonus, percent_bonus per row

Stop the server: Ctrl-C in the terminal that launched it, or click the
"Shut down" button in the top-right of the page.
"""

from __future__ import annotations

import base64
import glob
import http.server
import json
import re
import socketserver
import sys
import threading
import webbrowser
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlsplit

PORT = 8765
PROJECT_ROOT = Path(__file__).resolve().parent.parent

MASTER_SHEET = PROJECT_ROOT / 'assets/sprites/items_master.png'
# Slot ordering must match tools/migrate_to_master_sheet.py SLOT_ORDER.
SLOT_ORDER_IDS = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
GAP_ROWS = 5
COLS_PER_ROW = 16
TILE_PX = 32

SLOT_NAMES = {
    0: 'Melee', 1: 'Ranged', 2: 'Magic',
    3: 'Helm', 4: 'Body', 5: 'Shield', 6: 'Boots',
    7: 'Gloves', 8: 'Ring', 9: 'Cloak',
    10: 'Consumable', 11: 'Material', 12: 'Ammo',
}
STAT_NAMES = {
    0: 'MAX_HP', 1: 'MOVE_SPEED', 2: 'ATTACK_DAMAGE', 3: 'ATTACK_SPEED',
    4: 'BULLET_SPEED', 5: 'BULLET_COUNT', 6: 'SPREAD_ANGLE', 7: 'PIERCE_COUNT',
    8: 'BULLET_LIFETIME', 9: 'MAX_MP', 10: 'HP_REGEN', 11: 'MP_REGEN',
    12: 'LUCK', 13: 'CRIT_DAMAGE', 14: 'ARMOR', 15: 'WEIGHT',
    16: 'ACCELERATION', 17: 'DODGE_CHANCE', 18: 'XP_MULT', 19: 'GOLD_MULT',
    20: 'PICKUP_RADIUS', 21: 'COOLDOWN_REDUCTION', 22: 'STEALTH',
    23: 'MAX_STAMINA', 24: 'STAMINA_REGEN', 25: 'TENACITY', 26: 'THORNS',
}


# ────────────────────────────────────────────────────────────────────────
# Parsing
# ────────────────────────────────────────────────────────────────────────

def _find(text: str, field: str) -> str | None:
    """Return the raw value (str) for a `field = value` line, or None."""
    m = re.search(rf'^{re.escape(field)}\s*=\s*(.+?)$', text, re.MULTILINE)
    return m.group(1).strip() if m else None


def _find_str(text: str, field: str) -> str:
    raw = _find(text, field)
    if raw is None or not raw.startswith('"'):
        return raw or ''
    # Unquote with escape handling.
    m = re.match(r'^"((?:[^"\\]|\\.)*)"', raw)
    return m.group(1).replace('\\"', '"').replace('\\\\', '\\') if m else ''


def _find_int(text: str, field: str, default: int = 0) -> int:
    raw = _find(text, field)
    if raw is None:
        return default
    try:
        return int(float(raw))
    except ValueError:
        return default


def _find_float(text: str, field: str, default: float = 0.0) -> float:
    raw = _find(text, field)
    if raw is None:
        return default
    try:
        return float(raw)
    except ValueError:
        return default


def _find_bool(text: str, field: str, default: bool = False) -> bool:
    raw = _find(text, field)
    if raw is None:
        return default
    return raw.strip().lower() == 'true'


def parse_modifiers(text: str) -> list[dict]:
    """Pull every StatModifier sub_resource block out of the .tres."""
    out: list[dict] = []
    # Each [sub_resource ...] header up to (but not including) the next [section]
    # or end-of-file. The body holds `stat = N`, `flat_bonus = X`, `percent_bonus = Y`.
    for header_match in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"[^\]]*\]', text):
        body_start = header_match.end()
        next_section = re.search(r'\n\[(?:sub_resource|resource|ext_resource)', text[body_start:])
        body_end = body_start + next_section.start() if next_section else len(text)
        body = text[body_start:body_end]
        if 'stat_modifier.gd' not in text[max(0, header_match.start() - 200):header_match.start()] \
                and 'stat = ' not in body:
            # Skip non-StatModifier blocks (e.g. drop entries).
            continue
        sid = header_match.group(1)
        stat_m = re.search(r'^stat\s*=\s*(\d+)$', body, re.MULTILINE)
        if not stat_m:
            continue
        flat_m = re.search(r'^flat_bonus\s*=\s*([-0-9.]+)$', body, re.MULTILINE)
        pct_m = re.search(r'^percent_bonus\s*=\s*([-0-9.]+)$', body, re.MULTILINE)
        out.append({
            'id': sid,
            'stat': int(stat_m.group(1)),
            'flat': float(flat_m.group(1)) if flat_m else 0.0,
            'percent': float(pct_m.group(1)) if pct_m else 0.0,
        })
    return out


def parse_item(path: Path) -> dict | None:
    text = path.read_text()
    name = _find_str(text, 'item_name')
    if not name:
        return None
    return {
        'path': str(path.relative_to(PROJECT_ROOT)),
        'name': name,
        'description': _find_str(text, 'description'),
        'slot': _find_int(text, 'slot_type', 0),
        'wtype': _find_str(text, 'weapon_type'),
        'tile': _find_int(text, 'loy_tile_index', -1),
        'rarity': _find_int(text, 'rarity', 0),
        'buy_price': _find_int(text, 'buy_price', 0),
        'sell_value': _find_int(text, 'sell_value', 0),
        'heal_hp': _find_int(text, 'heal_hp', 0),
        'heal_mp': _find_int(text, 'heal_mp', 0),
        'demo_approved': _find_bool(text, 'demo_approved', False),
        'is_quest_item': _find_bool(text, 'is_quest_item', False),
        'ammo_type': _find_str(text, 'ammo_type'),
        'arrow_effect': _find_str(text, 'arrow_effect'),
        'modifiers': parse_modifiers(text),
    }


def load_all_items() -> list[dict]:
    out: list[dict] = []
    for p in sorted(PROJECT_ROOT.glob('resources/items/**/*.tres')):
        d = parse_item(p)
        if d:
            out.append(d)
    return out


# ────────────────────────────────────────────────────────────────────────
# Patching (writes back to .tres)
# ────────────────────────────────────────────────────────────────────────

def _set_or_insert(text: str, field: str, value: str, after: str = 'item_name') -> str:
    """Replace `field = …` if present, otherwise insert after `after` field's line."""
    pat = rf'^{re.escape(field)}\s*=\s*[^\n]+$'
    if re.search(pat, text, re.MULTILINE):
        return re.sub(pat, f'{field} = {value}', text, count=1, flags=re.MULTILINE)
    anchor = re.search(rf'^{re.escape(after)}\s*=\s*[^\n]+$', text, re.MULTILINE)
    if not anchor:
        return text
    return text[:anchor.end()] + f'\n{field} = {value}' + text[anchor.end():]


def _quote(s: str) -> str:
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def patch_modifier(text: str, mod_id: str, stat: int, flat: float, percent: float) -> str:
    """Patch stat/flat/percent inside a specific [sub_resource id="mod_id"] block."""
    # Locate the block header.
    m = re.search(rf'\[sub_resource[^\]]*id="{re.escape(mod_id)}"[^\]]*\]', text)
    if not m:
        return text
    body_start = m.end()
    next_section = re.search(r'\n\[(?:sub_resource|resource|ext_resource)', text[body_start:])
    body_end = body_start + next_section.start() if next_section else len(text)
    body = text[body_start:body_end]

    # Replace stat, flat_bonus, percent_bonus inside this body only.
    def repl(pat: str, repl_str: str, body_in: str) -> str:
        if re.search(pat, body_in, re.MULTILINE):
            return re.sub(pat, repl_str, body_in, count=1, flags=re.MULTILINE)
        # Insert after `script = ExtResource(...)` line if absent.
        anchor = re.search(r'^script\s*=\s*ExtResource\([^)]+\)$', body_in, re.MULTILINE)
        if anchor:
            return body_in[:anchor.end()] + '\n' + repl_str + body_in[anchor.end():]
        return body_in + '\n' + repl_str

    body = repl(r'^stat\s*=\s*\d+$', f'stat = {stat}', body)
    # Use compact float repr.
    flat_repr = ('%g' % flat) if flat != 0 else '0.0'
    pct_repr = ('%g' % percent) if percent != 0 else '0.0'
    if flat != 0 or re.search(r'^flat_bonus\s*=', body, re.MULTILINE):
        body = repl(r'^flat_bonus\s*=\s*[-0-9.]+$', f'flat_bonus = {flat_repr}', body)
    if percent != 0 or re.search(r'^percent_bonus\s*=', body, re.MULTILINE):
        body = repl(r'^percent_bonus\s*=\s*[-0-9.]+$', f'percent_bonus = {pct_repr}', body)

    return text[:body_start] + body + text[body_end:]


def save_item(rel_path: str, data: dict) -> tuple[bool, str]:
    path = PROJECT_ROOT / rel_path
    if not path.is_file():
        return False, f'File not found: {rel_path}'
    if 'resources/items' not in rel_path:
        return False, f'Refusing to write outside resources/items'

    text = path.read_text()
    original = text

    if 'name' in data:
        text = _set_or_insert(text, 'item_name', _quote(data['name']))
    if 'description' in data:
        text = _set_or_insert(text, 'description', _quote(data['description']))
    if 'slot' in data:
        text = _set_or_insert(text, 'slot_type', str(int(data['slot'])))
    if 'wtype' in data:
        text = _set_or_insert(text, 'weapon_type', _quote(data['wtype']))
    if 'tile' in data:
        text = _set_or_insert(text, 'loy_tile_index', str(int(data['tile'])))
    if 'rarity' in data:
        text = _set_or_insert(text, 'rarity', str(int(data['rarity'])))
    if 'buy_price' in data:
        text = _set_or_insert(text, 'buy_price', str(int(data['buy_price'])))
    if 'sell_value' in data:
        text = _set_or_insert(text, 'sell_value', str(int(data['sell_value'])))
    if 'heal_hp' in data:
        text = _set_or_insert(text, 'heal_hp', str(int(data['heal_hp'])))
    if 'heal_mp' in data:
        text = _set_or_insert(text, 'heal_mp', str(int(data['heal_mp'])))
    if 'demo_approved' in data:
        text = _set_or_insert(text, 'demo_approved', 'true' if data['demo_approved'] else 'false')
    if 'is_quest_item' in data:
        text = _set_or_insert(text, 'is_quest_item', 'true' if data['is_quest_item'] else 'false')
    if 'ammo_type' in data:
        text = _set_or_insert(text, 'ammo_type', _quote(data['ammo_type']))
    if 'arrow_effect' in data:
        text = _set_or_insert(text, 'arrow_effect', _quote(data['arrow_effect']))

    if 'modifiers' in data:
        for mod in data['modifiers']:
            text = patch_modifier(
                text, mod['id'],
                int(mod['stat']),
                float(mod.get('flat', 0)),
                float(mod.get('percent', 0)),
            )

    if text == original:
        return True, 'No changes.'
    path.write_text(text)
    return True, f'Saved {rel_path}'


# ────────────────────────────────────────────────────────────────────────
# HTTP server
# ────────────────────────────────────────────────────────────────────────

_HTML_TEMPLATE: str | None = None
_SHUTDOWN: threading.Event = threading.Event()


def _compute_layout(items: list[dict]) -> tuple[list[dict], int]:
    """Mirror the layout in migrate_to_master_sheet.py so the editor's grid
    matches the actual master PNG. Returns (sections, total_rows)."""
    by_slot: dict[int, int] = defaultdict(int)
    for it in items:
        by_slot[it['slot']] += 1
    sections: list[dict] = []
    cur_row = 0
    for sid in SLOT_ORDER_IDS:
        n = by_slot.get(sid, 0)
        rows_used = (n + COLS_PER_ROW - 1) // COLS_PER_ROW if n else 0
        sections.append({
            'slot': sid,
            'name': SLOT_NAMES.get(sid, f'slot {sid}'),
            'count': n,
            'start_row': cur_row,
            'end_row': cur_row + rows_used,
            'gap_end_row': cur_row + rows_used + GAP_ROWS,
        })
        cur_row += rows_used + GAP_ROWS
    return sections, cur_row


def _build_html() -> str:
    if not MASTER_SHEET.is_file():
        raise FileNotFoundError(
            f'{MASTER_SHEET} not found. Run tools/migrate_to_master_sheet.py first.'
        )
    master_url = 'data:image/png;base64,' + base64.b64encode(MASTER_SHEET.read_bytes()).decode('ascii')
    items = load_all_items()
    usage: dict[int, int] = defaultdict(int)
    for it in items:
        if it['tile'] >= 0:
            usage[it['tile']] += 1
    sections, total_rows = _compute_layout(items)

    payload = {
        'items': items,
        'usage': dict(usage),
        'slot_names': SLOT_NAMES,
        'stat_names': STAT_NAMES,
        'sections': sections,
        'total_rows': total_rows,
        'cols': COLS_PER_ROW,
    }
    return _HTML.replace('__MASTER_URL__', master_url) \
                .replace('__BOOTSTRAP_JSON__', json.dumps(payload))


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args) -> None:  # noqa: D401
        pass  # silence default access logs

    def _json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = urlsplit(self.path).path
        if path == '/':
            html = _build_html().encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(html)))
            # No-cache so browser refresh always sees the latest .tres state.
            # Without this, Chrome/Safari happily serve stale HTML on reload,
            # which makes it look like sprite changes didn't stick.
            self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
            self.send_header('Pragma', 'no-cache')
            self.end_headers()
            self.wfile.write(html)
        elif path == '/api/items':
            self._json(200, {'items': load_all_items()})
        else:
            self.send_error(404)

    def do_POST(self) -> None:  # noqa: N802
        path = urlsplit(self.path).path
        length = int(self.headers.get('Content-Length', '0'))
        raw = self.rfile.read(length) if length else b''
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            self._json(400, {'ok': False, 'msg': 'invalid JSON'})
            return

        if path == '/api/save':
            rel = payload.get('path', '')
            ok, msg = save_item(rel, payload)
            self._json(200 if ok else 400, {'ok': ok, 'msg': msg})
        elif path == '/api/shutdown':
            self._json(200, {'ok': True, 'msg': 'bye'})
            _SHUTDOWN.set()
            threading.Thread(target=lambda: (self.server.shutdown(), self.server.server_close())).start()
        else:
            self.send_error(404)


# ────────────────────────────────────────────────────────────────────────
# HTML / JS payload
# ────────────────────────────────────────────────────────────────────────

_HTML = r'''<!doctype html>
<html><head><meta charset="utf-8"><title>Item Editor</title>
<style>
:root{--master:url("__MASTER_URL__");}
*{box-sizing:border-box;}
body{margin:0;height:100vh;display:flex;flex-direction:column;background:#16161b;color:#ddd;font-family:-apple-system,Helvetica,Arial,sans-serif;overflow:hidden;}
.topbar{padding:10px 16px;background:#1c1c22;border-bottom:1px solid #333;display:flex;align-items:center;gap:14px;}
.topbar h1{margin:0;font-size:15px;color:#fff;}
.topbar .stat{color:#aaa;font-size:13px;}
.topbar .stat b{color:#f0d090;}
.btn{background:#2a4a7a;color:#fff;border:0;padding:7px 12px;border-radius:4px;cursor:pointer;font-size:13px;}
.btn:hover{background:#3a5a9a;}
.btn.danger{background:#7a2a2a;}
.btn.danger:hover{background:#9a3a3a;}
.btn.ghost{background:#2a2a2a;}
.btn.ghost:hover{background:#3a3a3a;}
.btn.primary{background:#2a7a4a;}
.btn.primary:hover{background:#3a9a5a;}
.main{flex:1;display:grid;grid-template-columns:300px 1fr 380px;overflow:hidden;}
.pane{overflow-y:auto;padding:12px;}
.pane.left{background:#1a1a1f;border-right:1px solid #333;}
.pane.middle{background:#1c1c20;border-right:1px solid #333;}
.pane.right{background:#1a1a1f;}
.section-head{font-size:11px;text-transform:uppercase;letter-spacing:1px;color:#888;margin:14px 4px 6px;padding-bottom:4px;border-bottom:1px solid #2c2c30;}
.section-head:first-child{margin-top:0;}

/* Item list */
.item{display:flex;gap:8px;padding:6px;margin-bottom:4px;background:#222226;border:1px solid transparent;border-radius:4px;cursor:pointer;}
.item:hover{background:#2a2a30;}
.item.selected{border-color:#f0d090;background:#2a2820;}
.item.dirty .name::after{content:" *";color:#80c080;}
.item .icon{width:44px;height:44px;flex-shrink:0;background-color:#0a0a0e;border:1px solid #444;border-radius:3px;image-rendering:pixelated;}
.item .meta{flex:1;font-size:11px;line-height:1.3;min-width:0;}
.item .name{font-weight:600;font-size:12px;color:#fff;word-break:break-word;}
.item .sub{color:#999;font-size:10px;margin-top:1px;}
.controls{margin-bottom:10px;}
.controls input{background:#0a0a0e;color:#fff;border:1px solid #444;padding:6px 10px;border-radius:4px;width:100%;font-size:12px;}

/* Sprite grid */
.sheet-head{font-size:12px;color:#aaa;margin:10px 0 6px;}
.sheet-head b{color:#fff;}
.section-band{margin:14px 0 6px;padding:6px 10px;background:#272730;border-left:4px solid #c08040;color:#f0d090;font-size:12px;border-radius:3px;}
.section-band b{color:#fff;font-size:13px;}
.grid{display:grid;grid-template-columns:repeat(16,1fr);gap:2px;max-width:880px;margin-bottom:6px;}
.cell{position:relative;width:100%;aspect-ratio:1;background-color:#0a0a0e;border:1px solid #2a2a30;cursor:pointer;image-rendering:pixelated;}
.cell.gap{background-color:#15151a;border-color:#1f1f25;}
.cell:hover{outline:2px solid #f0d090;outline-offset:-2px;z-index:1;}
.cell.assigned{outline:2px solid #80c080;outline-offset:-2px;z-index:1;}
.cell.used::after{content:attr(data-uses);position:absolute;top:1px;right:1px;background:rgba(0,0,0,0.7);color:#f0d090;font-size:9px;padding:0 3px;border-radius:2px;}
.cell-idx{position:absolute;bottom:0;left:0;background:rgba(0,0,0,0.55);color:#bbb;font-size:8px;padding:0 2px;font-family:monospace;line-height:1;}

/* Edit form */
.form .row{margin-bottom:12px;}
.form label{display:block;color:#aaa;font-size:11px;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:3px;}
.form input[type=text],.form input[type=number],.form textarea,.form select{
  background:#0a0a0e;color:#fff;border:1px solid #444;padding:6px 10px;border-radius:4px;width:100%;font-size:13px;font-family:inherit;
}
.form textarea{min-height:60px;resize:vertical;}
.form .row-2{display:grid;grid-template-columns:1fr 1fr;gap:10px;}
.form .row-3{display:grid;grid-template-columns:auto 1fr 1fr;gap:8px;align-items:center;}
.form .toggle{display:flex;align-items:center;gap:8px;cursor:pointer;}
.form .preview{display:flex;gap:10px;align-items:center;background:#222226;padding:8px;border-radius:4px;}
.form .preview .icon{width:48px;height:48px;background-color:#0a0a0e;border:1px solid #444;border-radius:3px;image-rendering:pixelated;flex-shrink:0;}
.form .preview .info{font-size:11px;color:#aaa;}
.form .preview .info b{color:#f0d090;display:block;font-size:13px;color:#fff;}
.mod-row{background:#1f1f24;padding:6px;border-radius:4px;margin-bottom:6px;font-size:12px;}
.mod-row select{background:#0a0a0e;color:#fff;border:1px solid #444;padding:4px;border-radius:3px;font-size:11px;width:100%;}
.mod-row input{background:#0a0a0e;color:#fff;border:1px solid #444;padding:4px 6px;border-radius:3px;width:100%;font-size:11px;}
.mod-row .grid3{display:grid;grid-template-columns:1.4fr 1fr 1fr;gap:4px;align-items:center;}
.mod-row .grid3 label{font-size:9px;color:#888;text-transform:none;letter-spacing:0;margin-bottom:1px;}
.actions{display:flex;gap:8px;margin-top:14px;position:sticky;bottom:-12px;background:#1a1a1f;padding-top:8px;padding-bottom:8px;border-top:1px solid #2c2c30;}
.empty-hint{color:#888;font-style:italic;padding:30px 10px;text-align:center;}
.status{position:fixed;bottom:14px;right:14px;background:#2a3a2a;color:#dfd;padding:8px 14px;border-radius:5px;font-size:13px;opacity:0;transition:opacity 0.3s;pointer-events:none;}
.status.show{opacity:1;}
.status.err{background:#3a2a2a;color:#fdd;}
</style></head><body>
<div class="topbar">
  <h1>Item Editor</h1>
  <div class="stat"><b id="item-count">0</b> items</div>
  <div class="stat"><b id="dirty-count">0</b> unsaved</div>
  <button class="btn ghost" onclick="shutDown()" style="margin-left:auto;">Shut down server</button>
</div>
<div class="main">
  <div class="pane left">
    <div class="controls">
      <input id="item-filter" type="text" placeholder="Filter items…" oninput="filterItems()">
    </div>
    <div id="item-list"></div>
  </div>
  <div class="pane middle">
    <div id="sheet-empty" class="empty-hint">Pick an item on the left to start editing.</div>
    <div id="sheet-container" style="display:none;">
      <div class="sheet-head"><b>items_master.png</b> — sprites grouped by slot, gap rows are paintable space</div>
      <div id="sections"></div>
    </div>
  </div>
  <div class="pane right">
    <div id="form-empty" class="empty-hint">Nothing selected.</div>
    <div id="form" class="form" style="display:none;"></div>
  </div>
</div>
<div class="status" id="status"></div>
<script>
const COLS = 16;
const ICON_PX_LIST = 44;
const ICON_PX_FORM = 48;
const MASTER_VAR = 'var(--master)';

const BOOT = __BOOTSTRAP_JSON__;
const SLOT_NAMES = BOOT.slot_names;
const STAT_NAMES = BOOT.stat_names;
const ITEMS = BOOT.items;       // canonical, mutated as we save
const USAGE = BOOT.usage;       // cell idx -> count, refreshed when a tile changes
const SECTIONS = BOOT.sections; // [{slot, name, start_row, end_row, gap_end_row, count}]
const TOTAL_ROWS = BOOT.total_rows;
let selected = null;            // currently-selected path
let edits = {};                 // path -> partial edits (cleared on save)

function escapeHTML(s){return (s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function $(id){return document.getElementById(id);}

function spriteStyle(tile, displayPx){
  if(tile < 0) return 'background:repeating-linear-gradient(45deg,#222 0 6px,#111 6px 12px);';
  // The master sheet is 16 cols × TOTAL_ROWS tall. Pixel-based positioning works
  // for fixed-size icons (list + form preview). Grid cells use percentage-based
  // positioning instead — see renderSections().
  const col = tile % COLS;
  const row = Math.floor(tile / COLS);
  return `background-image:${MASTER_VAR};background-position:-${col*displayPx}px -${row*displayPx}px;background-size:${COLS*displayPx}px ${TOTAL_ROWS*displayPx}px;image-rendering:pixelated;`;
}

function getEdited(it){
  return { ...it, ...(edits[it.path] || {}) };
}

function isDirty(path){
  return !!edits[path] && Object.keys(edits[path]).length > 0;
}

function renderItemList(){
  const list = $('item-list');
  list.innerHTML = '';
  const bySlot = {};
  for(const it of ITEMS){
    if(!bySlot[it.slot]) bySlot[it.slot] = [];
    bySlot[it.slot].push(it);
  }
  const sortedSlots = Object.keys(bySlot).map(Number).sort((a,b)=>a-b);
  for(const slot of sortedSlots){
    const head = document.createElement('div');
    head.className = 'section-head';
    head.textContent = SLOT_NAMES[slot] + ' (' + bySlot[slot].length + ')';
    list.appendChild(head);
    bySlot[slot].sort((a,b)=>a.name.localeCompare(b.name));
    for(const it of bySlot[slot]){
      const eff = getEdited(it);
      const card = document.createElement('div');
      card.className = 'item' + (selected === it.path ? ' selected' : '') + (isDirty(it.path) ? ' dirty' : '');
      card.dataset.path = it.path;
      card.dataset.search = (eff.name.toLowerCase() + ' ' + eff.wtype + ' ' + it.path.toLowerCase());
      card.onclick = () => selectItem(it.path);
      card.innerHTML = `
        <div class="icon" style="${spriteStyle(eff.tile, ICON_PX_LIST)}"></div>
        <div class="meta">
          <div class="name">${escapeHTML(eff.name)}</div>
          <div class="sub">${escapeHTML(SLOT_NAMES[eff.slot] || ('slot '+eff.slot))}${eff.wtype ? ' · ' + escapeHTML(eff.wtype) : ''}</div>
        </div>`;
      list.appendChild(card);
    }
  }
  $('item-count').textContent = ITEMS.length;
  $('dirty-count').textContent = Object.keys(edits).length;
  filterItems();
}

function filterItems(){
  const q = $('item-filter').value.toLowerCase();
  document.querySelectorAll('.item').forEach(c => {
    c.style.display = (!q || c.dataset.search.indexOf(q) !== -1) ? '' : 'none';
  });
}

// Render the master sheet broken into per-slot sections, with a header band
// before each slot block + a visually separated empty band for the gap rows.
// Cells use percentage-based background positioning so the crop stays aligned
// at any rendered cell width.
//
// background-size on a cell is "(16 cols × cellW) px wide × (TOTAL_ROWS × cellH) px tall"
// expressed as percentages: 1600% wide × (TOTAL_ROWS×100)% tall. Position is the
// fraction across the master, computed from the cell's row/col.
function renderSections(){
  const root = $('sections');
  root.innerHTML = '';
  const sheetW_pct = 100 * COLS;             // 1600%
  const sheetH_pct = 100 * TOTAL_ROWS;
  for(const sec of SECTIONS){
    if(sec.count === 0 && (sec.gap_end_row - sec.start_row) === 0) continue;
    // Section header
    const head = document.createElement('div');
    head.className = 'section-band';
    head.innerHTML = `<b>${sec.name}</b> · ${sec.count} items · rows ${sec.start_row}–${sec.end_row - 1} · gap rows ${sec.end_row}–${sec.gap_end_row - 1}`;
    root.appendChild(head);
    // Sprite rows (occupied + gap, the gap cells stay transparent so painting
    // them in Aseprite later just lights up here)
    const grid = document.createElement('div');
    grid.className = 'grid';
    for(let r = sec.start_row; r < sec.gap_end_row; r++){
      const isGap = r >= sec.end_row;
      for(let c = 0; c < COLS; c++){
        const idx = r * COLS + c;
        const xPct = (c / (COLS - 1)) * 100;
        const yPct = TOTAL_ROWS > 1 ? (r / (TOTAL_ROWS - 1)) * 100 : 0;
        const uses = USAGE[idx] || 0;
        const cell = document.createElement('div');
        cell.className = 'cell' + (uses > 0 ? ' used' : '') + (isGap ? ' gap' : '');
        cell.dataset.idx = idx;
        cell.style.cssText = `background-image:${MASTER_VAR};background-position:${xPct}% ${yPct}%;background-size:${sheetW_pct}% ${sheetH_pct}%;image-rendering:pixelated;`;
        if(uses > 0) cell.dataset.uses = uses + 'x';
        cell.innerHTML = `<span class="cell-idx">${idx}</span>`;
        cell.onclick = () => assignCell(idx);
        grid.appendChild(cell);
      }
    }
    root.appendChild(grid);
  }
}

function selectItem(path){
  selected = path;
  document.querySelectorAll('.item').forEach(c => c.classList.toggle('selected', c.dataset.path === path));
  $('sheet-empty').style.display = 'none';
  $('sheet-container').style.display = '';
  $('form-empty').style.display = 'none';
  $('form').style.display = '';
  renderForm();
  highlightAssigned();
}

function highlightAssigned(){
  document.querySelectorAll('.cell.assigned').forEach(c => c.classList.remove('assigned'));
  if(!selected) return;
  const it = ITEMS.find(x => x.path === selected);
  const eff = getEdited(it);
  if(eff.tile >= 0){
    const cell = document.querySelector(`.cell[data-idx="${eff.tile}"]`);
    if(cell){
      cell.classList.add('assigned');
      cell.scrollIntoView({block:'center', behavior:'smooth'});
    }
  }
}

function assignCell(idx){
  if(!selected) return;
  setEdit('tile', idx);
  highlightAssigned();
  rerenderRow(selected);
  flash('Assigned cell ' + idx);
}

function setEdit(field, value){
  if(!selected) return;
  if(!edits[selected]) edits[selected] = {};
  const it = ITEMS.find(x => x.path === selected);
  if(it[field] === value){
    delete edits[selected][field];
    if(Object.keys(edits[selected]).length === 0) delete edits[selected];
  } else {
    edits[selected][field] = value;
  }
  $('dirty-count').textContent = Object.keys(edits).length;
  rerenderRow(selected);
}

function setModEdit(idx, prop, value){
  if(!selected) return;
  const it = ITEMS.find(x => x.path === selected);
  const eff = getEdited(it);
  const mods = (eff.modifiers || []).slice();
  if(!mods[idx]) return;
  const before = JSON.stringify(mods[idx]);
  mods[idx] = { ...mods[idx], [prop]: value };
  if(before === JSON.stringify(it.modifiers[idx])){
    // No-op vs original — drop the mod edit; but keep others
    if(!edits[selected]) edits[selected] = {};
    edits[selected].modifiers = mods;
    if(JSON.stringify(mods) === JSON.stringify(it.modifiers)){
      delete edits[selected].modifiers;
      if(Object.keys(edits[selected]).length === 0) delete edits[selected];
    }
  } else {
    if(!edits[selected]) edits[selected] = {};
    edits[selected].modifiers = mods;
  }
  $('dirty-count').textContent = Object.keys(edits).length;
  rerenderRow(selected);
}

function rerenderRow(path){
  const card = document.querySelector(`.item[data-path="${CSS.escape(path)}"]`);
  if(!card) return;
  const it = ITEMS.find(x => x.path === path);
  const eff = getEdited(it);
  card.classList.toggle('dirty', isDirty(path));
  card.querySelector('.icon').style.cssText = spriteStyle(eff.tile, ICON_PX_LIST);
  card.querySelector('.name').textContent = eff.name;
  card.querySelector('.sub').textContent = (SLOT_NAMES[eff.slot] || ('slot ' + eff.slot)) + (eff.wtype ? ' · ' + eff.wtype : '');
  card.dataset.search = (eff.name.toLowerCase() + ' ' + eff.wtype + ' ' + path.toLowerCase());
}

function renderForm(){
  if(!selected) return;
  const it = ITEMS.find(x => x.path === selected);
  const eff = getEdited(it);
  const slotOpts = Object.keys(SLOT_NAMES).map(k => `<option value="${k}" ${parseInt(k)===eff.slot?'selected':''}>${SLOT_NAMES[k]}</option>`).join('');
  const statOpts = Object.keys(STAT_NAMES).map(k => `<option value="${k}">${k} ${STAT_NAMES[k]}</option>`).join('');
  let modsHTML = '';
  (eff.modifiers || []).forEach((m, i) => {
    const opts = Object.keys(STAT_NAMES).map(k => `<option value="${k}" ${parseInt(k)===m.stat?'selected':''}>${k} ${STAT_NAMES[k]}</option>`).join('');
    modsHTML += `<div class="mod-row">
      <div class="grid3">
        <div><label>Stat</label><select onchange="setModEdit(${i}, 'stat', parseInt(this.value))">${opts}</select></div>
        <div><label>flat</label><input type="number" step="0.01" value="${m.flat}" onchange="setModEdit(${i}, 'flat', parseFloat(this.value))"></div>
        <div><label>%</label><input type="number" step="0.01" value="${m.percent}" onchange="setModEdit(${i}, 'percent', parseFloat(this.value))"></div>
      </div>
    </div>`;
  });
  if(!modsHTML) modsHTML = '<div style="color:#666;font-style:italic;padding:8px;">No StatModifier sub-resources on this item.</div>';

  $('form').innerHTML = `
    <div class="preview">
      <div class="icon" style="${spriteStyle(eff.tile, ICON_PX_FORM)}"></div>
      <div class="info">
        <b>${escapeHTML(eff.name)}</b>
        ${escapeHTML(it.path)}<br>
        tile = ${eff.tile} · slot = ${SLOT_NAMES[eff.slot] || eff.slot}
      </div>
    </div>
    <div class="section-head" style="margin-top:16px;">Basics</div>
    <div class="row"><label>Name</label><input type="text" value="${escapeHTML(eff.name)}" oninput="setEdit('name', this.value)"></div>
    <div class="row"><label>Description</label><textarea oninput="setEdit('description', this.value)">${escapeHTML(eff.description)}</textarea></div>
    <div class="row row-2">
      <div><label>Slot type</label><select onchange="setEdit('slot', parseInt(this.value))">${slotOpts}</select></div>
      <div><label>Weapon type</label><input type="text" value="${escapeHTML(eff.wtype)}" oninput="setEdit('wtype', this.value)" placeholder="sword, bow, …"></div>
    </div>
    <div class="row row-2">
      <div><label>Rarity</label><input type="number" min="0" max="5" value="${eff.rarity}" onchange="setEdit('rarity', parseInt(this.value))"></div>
      <div><label>Sprite (tile #)</label><input type="number" min="-1" value="${eff.tile}" onchange="setEdit('tile', parseInt(this.value)); highlightAssigned();"></div>
    </div>
    <div class="row row-2">
      <div><label>Buy price</label><input type="number" min="0" value="${eff.buy_price}" onchange="setEdit('buy_price', parseInt(this.value))"></div>
      <div><label>Sell value</label><input type="number" min="0" value="${eff.sell_value}" onchange="setEdit('sell_value', parseInt(this.value))"></div>
    </div>
    ${eff.slot === 10 ? `
    <div class="section-head">Consumable</div>
    <div class="row row-2">
      <div><label>Heal HP</label><input type="number" value="${eff.heal_hp}" onchange="setEdit('heal_hp', parseInt(this.value))"></div>
      <div><label>Heal MP</label><input type="number" value="${eff.heal_mp}" onchange="setEdit('heal_mp', parseInt(this.value))"></div>
    </div>` : ''}
    ${eff.slot === 12 ? `
    <div class="section-head">Ammo</div>
    <div class="row row-2">
      <div><label>Ammo type</label><input type="text" value="${escapeHTML(eff.ammo_type)}" oninput="setEdit('ammo_type', this.value)" placeholder="arrow, knife, stone"></div>
      <div><label>Arrow effect</label><input type="text" value="${escapeHTML(eff.arrow_effect)}" oninput="setEdit('arrow_effect', this.value)"></div>
    </div>` : ''}
    <div class="section-head">Flags</div>
    <div class="row toggle"><input type="checkbox" id="dem" ${eff.demo_approved?'checked':''} onchange="setEdit('demo_approved', this.checked)"><label for="dem" style="margin:0;">demo_approved</label></div>
    <div class="row toggle"><input type="checkbox" id="qi" ${eff.is_quest_item?'checked':''} onchange="setEdit('is_quest_item', this.checked)"><label for="qi" style="margin:0;">is_quest_item</label></div>
    <div class="section-head">Stat modifiers</div>
    ${modsHTML}
    <div class="actions">
      <button class="btn primary" onclick="saveCurrent()">Save</button>
      <button class="btn ghost" onclick="revertCurrent()">Revert</button>
      <button class="btn ghost" onclick="saveAll()">Save all</button>
    </div>
  `;
}

// Send only the fields that actually changed so the server writes just those.
// Sending the full effective item made the server touch every field including
// defaults, which bloated files with `weapon_type = ""`, `heal_hp = 0`, etc.
function buildDiffPayload(path){
  const it = ITEMS.find(x => x.path === path);
  const dirty = edits[path] || {};
  const out = { path };
  for(const k of Object.keys(dirty)) out[k] = dirty[k];
  return out;
}

async function saveCurrent(){
  if(!selected) return;
  if(!edits[selected]){ flash('Nothing to save.'); return; }
  const it = ITEMS.find(x => x.path === selected);
  const payload = buildDiffPayload(selected);
  const ok = await save(payload);
  if(ok){
    Object.assign(it, edits[selected]);
    delete edits[selected];
    refreshUsage();
    renderItemList();
    selectItem(selected);
  }
}

async function saveAll(){
  const paths = Object.keys(edits);
  if(paths.length === 0){ flash('Nothing to save.'); return; }
  let ok = 0, fail = 0;
  for(const p of paths){
    const it = ITEMS.find(x => x.path === p);
    if(!it) continue;
    const payload = buildDiffPayload(p);
    if(await save(payload, true)){
      Object.assign(it, edits[p]);
      delete edits[p];
      ok++;
    } else fail++;
  }
  refreshUsage();
  renderItemList();
  if(selected) selectItem(selected);
  flash(`Saved ${ok}` + (fail ? ` (${fail} failed)` : ''));
}

function revertCurrent(){
  if(!selected) return;
  delete edits[selected];
  $('dirty-count').textContent = Object.keys(edits).length;
  rerenderRow(selected);
  renderForm();
  highlightAssigned();
}

async function save(eff, silent){
  try{
    const res = await fetch('/api/save', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(eff)});
    const data = await res.json();
    if(!silent) flash(data.msg || (data.ok ? 'Saved.' : 'Error.'), !data.ok);
    return data.ok;
  } catch(err){
    flash('Network error: ' + err, true);
    return false;
  }
}

function refreshUsage(){
  for(const k of Object.keys(USAGE)) delete USAGE[k];
  for(const it of ITEMS){ if(it.tile >= 0) USAGE[it.tile] = (USAGE[it.tile]||0)+1; }
  document.querySelectorAll('.cell').forEach(c => {
    const idx = parseInt(c.dataset.idx);
    const u = USAGE[idx] || 0;
    c.classList.toggle('used', u > 0);
    if(u > 0) c.dataset.uses = u + 'x'; else c.removeAttribute('data-uses');
  });
}

async function shutDown(){
  if(!confirm('Stop the editor server?')) return;
  try{ await fetch('/api/shutdown', {method:'POST', body:'{}'}); }catch(e){}
  document.body.innerHTML = '<div style="padding:40px;text-align:center;color:#aaa;">Server stopped. You can close this tab.</div>';
}

function flash(msg, isErr){
  const s = $('status');
  s.textContent = msg;
  s.classList.toggle('err', !!isErr);
  s.classList.add('show');
  clearTimeout(window._flashTimer);
  window._flashTimer = setTimeout(() => s.classList.remove('show'), 2500);
}

// Init
renderSections();
renderItemList();
</script></body></html>
'''


def main() -> None:
    # Probe the port before announcing — fail fast if it's busy.
    try:
        with socketserver.TCPServer(('', PORT), Handler) as srv:
            url = f'http://localhost:{PORT}'
            print(f'Item editor running at {url}')
            print('Opening browser…')
            threading.Timer(0.4, lambda: webbrowser.open(url)).start()
            try:
                srv.serve_forever()
            except KeyboardInterrupt:
                print()
                print('Shutting down.')
                srv.shutdown()
    except OSError as e:
        print(f'Could not bind port {PORT}: {e}')
        print(f'Hint: another instance might be running; close it or change PORT.')
        sys.exit(1)


if __name__ == '__main__':
    main()
