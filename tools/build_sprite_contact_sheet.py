#!/usr/bin/env python3
"""
Sprite contact sheet generator.

Walks resources/items/**/*.tres, reads item_name / slot_type / loy_tile_index /
weapon_type / description / demo_approved, then emits tools/sprite_contact_sheet.html
that crops the tile region from assets/sprites/loy/tiles.png + tiles2.png and
shows it next to the item metadata.

Run from the project root:
    python3 tools/build_sprite_contact_sheet.py

Open the output HTML in any browser. Filter / sort by clicking the controls
at the top. Red border = no icon (loy_tile_index = -1). Orange = not demo
approved.

Re-run anytime after editing items — output is regenerated in place.

Reads no Godot APIs; the tile→sheet math mirrors scripts/ui/item_icon_helper.gd
(idx < 256 → tiles.png; idx >= 256 → tiles2.png; col = idx%16; row = idx//16;
32px per tile).
"""

import re
import glob
import html
from collections import defaultdict

SHEETS = {
    'tiles': 'assets/sprites/loy/tiles.png',
    'tiles2': 'assets/sprites/loy/tiles2.png',
}
TILE_PX = 32       # source tile size in PNG
DISPLAY_PX = 64    # how big to render in the contact sheet (2× pixel art)

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
    desc = re.search(r'^description\s*=\s*"(.*?)"$', text, re.MULTILINE)
    wtype = re.search(r'^weapon_type\s*=\s*"([a-z_]*)"$', text, re.MULTILINE)
    demo = re.search(r'^demo_approved\s*=\s*(true|false)$', text, re.MULTILINE)
    return {
        'path': p,
        'name': name.group(1),
        'slot': int(slot.group(1)),
        'tile': int(tile.group(1)) if tile else -1,
        'desc': (desc.group(1) if desc else '').strip(),
        'wtype': wtype.group(1) if wtype else '',
        'demo_approved': demo.group(1) == 'true' if demo else False,
    }


def sprite_style(tile_idx: int) -> str:
    if tile_idx < 0:
        return 'background: repeating-linear-gradient(45deg,#222 0 6px,#111 6px 12px);'
    sheet = SHEETS['tiles'] if tile_idx < 256 else SHEETS['tiles2']
    idx = tile_idx % 256
    col = idx % 16
    row = idx // 16
    # The contact sheet HTML lives at tools/, so the sheet path is one
    # directory up. background-size scales the full sheet so we can crop
    # at DISPLAY_PX precision.
    sheet_rel = '../' + sheet
    scale = DISPLAY_PX // TILE_PX
    return (
        f'background-image:url("{sheet_rel}");'
        f'background-position:-{col * TILE_PX * scale}px -{row * TILE_PX * scale}px;'
        f'background-size:{16 * DISPLAY_PX}px auto;'
        f'image-rendering:pixelated;'
    )


def main() -> None:
    items: list[dict] = []
    for p in sorted(glob.glob('resources/items/**/*.tres', recursive=True)):
        d = parse_item(p)
        if d:
            items.append(d)

    groups: dict[int, list[dict]] = defaultdict(list)
    for it in items:
        groups[it['slot']].append(it)
    for k in groups:
        groups[k].sort(key=lambda x: (x['tile'], x['name']))

    out: list[str] = []
    out.append('<!doctype html><html><head><meta charset="utf-8"><title>Sprite Contact Sheet</title>')
    out.append('''<style>
body{background:#1a1a1f;color:#ddd;font-family:-apple-system,Helvetica,Arial,sans-serif;margin:0;padding:24px;}
h1{margin:0 0 8px;color:#fff;}
h2{margin:32px 0 12px;padding:8px 12px;background:#272730;border-left:4px solid #c08040;color:#f0d090;}
.note{color:#aaa;margin-bottom:24px;line-height:1.5;}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px;}
.card{background:#222226;border:1px solid #333;border-radius:6px;padding:10px;display:flex;gap:10px;align-items:flex-start;}
.card.junk{border-color:#c04040;background:#2a1a1a;}
.card.no-icon{border-color:#a06030;background:#251f1a;}
.icon{width:64px;height:64px;background-color:#0a0a0e;border:1px solid #444;border-radius:3px;flex-shrink:0;}
.meta{font-size:12px;line-height:1.4;min-width:0;flex:1;}
.meta .name{font-weight:600;font-size:13px;color:#fff;word-break:break-word;}
.meta .sub{color:#999;}
.meta .desc{color:#bbb;font-style:italic;margin-top:4px;font-size:11px;}
.tag{display:inline-block;background:#333;color:#ccc;padding:1px 5px;border-radius:3px;font-size:10px;margin-right:3px;}
.tag.demo{background:#306030;color:#dfd;}
.tag.notdemo{background:#a04040;color:#fdd;}
.tag.wtype{background:#445;color:#dde;}
.summary{background:#2a2a32;padding:10px 14px;border-radius:6px;margin-bottom:24px;}
.summary b{color:#fff;}
.controls{position:sticky;top:0;background:#1a1a1f;padding:10px 0;z-index:10;border-bottom:1px solid #333;margin-bottom:16px;}
.controls input{background:#0a0a0e;color:#fff;border:1px solid #444;padding:6px 10px;border-radius:4px;width:300px;}
.controls label{margin-left:16px;color:#aaa;font-size:13px;}
.tile-index{color:#888;font-family:monospace;}
</style>''')
    out.append('</head><body>')
    out.append('<h1>Item Sprite Contact Sheet</h1>')
    out.append(
        f'<div class="summary">Indexed <b>{len(items)} items</b> across '
        f'<b>{len(groups)} slot types</b>. Sprites cropped from '
        f'<code>assets/sprites/loy/tiles.png</code> (0-255) and '
        f'<code>tiles2.png</code> (256+). Open from the project root.</div>'
    )
    out.append(
        '<div class="note">Red border = <b>loy_tile_index = -1</b> (no icon). '
        'Orange-ish red = <code>demo_approved = false</code>. '
        'Scroll, find mismatches, send me a list of paths.</div>'
    )

    out.append('<div class="controls">')
    out.append('<input id="filter" type="text" placeholder="Filter by name / type / path" oninput="doFilter()">')
    out.append('<label><input id="demo-only" type="checkbox" onclick="doFilter()"> demo_approved only</label>')
    out.append('<label><input id="no-icon-only" type="checkbox" onclick="doFilter()"> no-icon only (tile=-1)</label>')
    out.append('</div>')

    for slot in sorted(groups):
        name = SLOT_NAMES.get(slot, f"slot {slot}")
        out.append(
            f'<h2>{html.escape(name)} '
            f'<span style="color:#888;font-size:14px;font-weight:400;">'
            f'({len(groups[slot])} items)</span></h2>'
        )
        out.append('<div class="grid">')
        for it in groups[slot]:
            classes = ['card']
            if it['tile'] < 0:
                classes.append('no-icon')
            if not it['demo_approved']:
                classes.append('junk')
            short = it['path'].replace('resources/items/', '')
            tags = []
            if it['demo_approved']:
                tags.append('<span class="tag demo">demo</span>')
            else:
                tags.append('<span class="tag notdemo">not-demo</span>')
            if it['wtype']:
                tags.append(f'<span class="tag wtype">{html.escape(it["wtype"])}</span>')
            search_key = (it['name'].lower() + ' ' + it['wtype'] + ' ' + short.lower()).strip()
            out.append(
                f'<div class="{" ".join(classes)}" '
                f'data-search="{html.escape(search_key)}" '
                f'data-demo="{1 if it["demo_approved"] else 0}" '
                f'data-tile="{it["tile"]}">'
            )
            out.append(f'<div class="icon" style="{sprite_style(it["tile"])}"></div>')
            out.append('<div class="meta">')
            out.append(f'<div class="name">{html.escape(it["name"])}</div>')
            out.append(f'<div class="sub">{" ".join(tags)} <span class="tile-index">#{it["tile"]}</span></div>')
            if it['desc']:
                d = it['desc'][:90] + ('…' if len(it['desc']) > 90 else '')
                out.append(f'<div class="desc">{html.escape(d)}</div>')
            out.append(
                f'<div class="sub" style="margin-top:6px;font-size:10px;color:#666;">'
                f'{html.escape(short)}</div>'
            )
            out.append('</div></div>')
        out.append('</div>')

    out.append('''<script>
function doFilter(){
  var q=document.getElementById('filter').value.toLowerCase();
  var demo=document.getElementById('demo-only').checked;
  var noicon=document.getElementById('no-icon-only').checked;
  document.querySelectorAll('.card').forEach(c=>{
    var s=c.getAttribute('data-search');
    var isDemo=c.getAttribute('data-demo')==='1';
    var tile=parseInt(c.getAttribute('data-tile'));
    var show=true;
    if(q && s.indexOf(q)===-1) show=false;
    if(demo && !isDemo) show=false;
    if(noicon && tile>=0) show=false;
    c.style.display=show?'':'none';
  });
}
</script>''')
    out.append('</body></html>')

    with open('tools/sprite_contact_sheet.html', 'w') as f:
        f.write('\n'.join(out))
    print(f"Wrote tools/sprite_contact_sheet.html — {len(items)} items, {len(groups)} groups")


if __name__ == '__main__':
    main()
