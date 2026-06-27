#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def field(text: str, name: str, default: str = "") -> str:
    match = re.search(rf"^{re.escape(name)}\s*=\s*(.+)$", text, re.M)
    return match.group(1).strip() if match else default


def number(text: str, name: str, default: float = 0.0) -> float:
    raw = field(text, name, str(default))
    try:
        return float(raw)
    except ValueError:
        return default


def chain_base(level_id: str) -> str:
    parts = level_id.split("-")
    if len(parts) > 1 and parts[-1] in {"Dungeons", "base", "Base", "Tower"}:
        return "-".join(parts[:-1])
    if len(parts) > 1 and parts[-1].isdigit():
        return "-".join(parts[:-1])
    return level_id


def level_prefix(level_id: str) -> str:
    return (level_id.split("-", 1)[0] if "-" in level_id else level_id).lower()


def load_enemies() -> dict[str, dict]:
    enemies: dict[str, dict] = {}
    for path in sorted((ROOT / "resources/enemies").rglob("*.tres")):
        text = path.read_text(errors="ignore")
        name = field(text, "enemy_name", path.stem).strip('"')
        enemies[name.lower()] = {
            "name": name,
            "path": path.relative_to(ROOT),
            "level": int(number(text, "level", 1)),
            "hp": int(number(text, "max_hp", 0)),
            "damage": int(number(text, "attack_damage", 0)),
            "contact": int(number(text, "contact_damage", 0)),
            "attack_type": int(number(text, "attack_type", 0)),
            "bullet_count": int(number(text, "bullet_count", 0)),
            "bullet_speed": number(text, "bullet_speed", 0.0),
        }
    return enemies


def level_sort_key(path: Path, text: str) -> tuple[int, str]:
    level_id = field(text, "id", path.stem).strip('"')
    parts = level_id.split("-")
    is_base = len(parts) > 1 and parts[-1] in {"Dungeons", "base", "Base", "Tower", "Crypt"}
    suffix = 0 if is_base else 99
    if len(parts) > 1 and parts[-1].isdigit():
        suffix = int(parts[-1])
    return suffix, level_id


def load_chain(level_id: str) -> list[tuple[Path, str]]:
    prefix = level_prefix(level_id)
    wanted_base = chain_base(level_id)
    chain: list[tuple[Path, str]] = []
    for path in sorted((ROOT / "resources/levels").glob("*.tres")):
        if not path.stem.lower().startswith(prefix):
            continue
        text = path.read_text(errors="ignore")
        if chain_base(field(text, "id", path.stem).strip('"')) == wanted_base:
            chain.append((path, text))
    chain.sort(key=lambda item: level_sort_key(item[0], item[1]))
    return chain[:3]


def monster_entries(text: str) -> list[tuple[str, int]]:
    raw = field(text, "monster_pool", "[]")
    entries: list[tuple[str, int]] = []
    for match in re.finditer(r'\{\s*"type":\s*"([^"]+)",\s*"chance":\s*(\d+)\s*\}', raw):
        entries.append((match.group(1), int(match.group(2))))
    return entries


def risk(enemy: dict, rec_level: int) -> str:
    notes: list[str] = []
    if rec_level <= 4 and enemy["hp"] >= 240:
        notes.append("old-scale hp")
    if rec_level <= 4 and enemy["damage"] >= 36:
        notes.append("high damage")
    if rec_level <= 4 and enemy["contact"] >= 24:
        notes.append("high contact")
    if rec_level <= 4 and enemy["bullet_speed"] >= 120:
        notes.append("fast projectile")
    if enemy["bullet_count"] >= 8:
        notes.append("high bullet count")
    return ", ".join(notes)


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit actual monster pools for a dungeon chain.")
    parser.add_argument("level_id", nargs="?", default="Haven-Dungeons")
    args = parser.parse_args()

    enemies = load_enemies()
    chain = load_chain(args.level_id)
    print(f"Dungeon Pool Audit: {args.level_id}")
    if not chain:
        print("No matching level chain found.")
        return 1
    for path, text in chain:
        level_id = field(text, "id", path.stem).strip('"')
        rec_level = int(number(text, "recommended_level", 1))
        print(f"\n{level_id} rec_level={rec_level} ({path.relative_to(ROOT)})")
        for name, chance in monster_entries(text):
            enemy = enemies.get(name.lower())
            if enemy is None:
                print(f"- {name} chance={chance}: missing enemy resource")
                continue
            flags = risk(enemy, rec_level)
            suffix = f" :: {flags}" if flags else ""
            print(
                f"- {enemy['name']} chance={chance} lvl={enemy['level']} "
                f"hp={enemy['hp']} dmg={enemy['damage']} contact={enemy['contact']} "
                f"bullets={enemy['bullet_count']} speed={enemy['bullet_speed']:g}{suffix}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
