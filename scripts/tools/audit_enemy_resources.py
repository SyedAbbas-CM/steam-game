#!/usr/bin/env python3
from __future__ import annotations

import re
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

ATTACK_NAMES = [
    "NONE", "MELEE", "RANGED", "BURST", "CHARGE", "DASH",
    "SUMMON", "SLAM", "TELEPORT", "HEAL",
    "SPLIT", "STEALTH", "SHIELD", "BEAM", "SPIRAL", "POISON_SHOT",
    "VOLLEY", "CROSS_SHOT", "WAVE_SHOT", "GATLING", "MORTAR", "NOVA", "ZIGZAG",
    "SHOTGUN_BLAST", "HELIX", "METEOR_SHOWER", "BOOMERANG_SHOT", "STRAFE_RUN", "MINEFIELD",
    "RETURNING_VOLLEY", "SEEKING_MINES", "DETONATOR", "SPLITTER", "SINE_BARRAGE",
    "HOMING_SALVO", "TELEGRAPH_EXPLOSION", "ORBIT_LAUNCH",
    "WALL_BOUNCE", "LASER_GRID", "GRAVITY_WELL", "CHAIN_LIGHTNING", "DEATH_SPIRAL",
    "BOMB_TOSS", "CARPET_BOMB", "FIRE_RAIN", "CLUSTER_BOMB", "MINE_DROP",
    "BARRIER_WALL", "PULL_SHOT", "PUSH_WAVE",
    "VORTEX", "RING_PULSE", "ARTILLERY", "WHIP_LASH", "POISON_CLOUD", "DASH_STRIKE",
    "LANCE_THRUST", "SHIELD_WALL", "CURSE_BOLT", "SUMMON_WALL", "LEAPING_SLAM", "ARROW_VOLLEY",
    "SWORD_SLASH", "SPEAR_LUNGE", "CHARGE_BULL", "CLEAVE_COMBO", "WHIRLWIND",
    "GROUND_POUND", "TAIL_WHIP", "SHIELD_BASH", "GRAB_THROW", "STOMP_WAVE",
]

HEAVY = {
    "BOMB_TOSS", "CARPET_BOMB", "FIRE_RAIN", "CLUSTER_BOMB", "MINE_DROP",
    "ARTILLERY", "POISON_CLOUD", "MORTAR", "METEOR_SHOWER",
}
AREA = {"MINEFIELD", "SEEKING_MINES", "MINE_DROP", "POISON_CLOUD", "BARRIER_WALL", "TELEGRAPH_EXPLOSION", "ORBIT_LAUNCH"}
SUMMON = {"SUMMON", "SUMMON_WALL"}


def field(text: str, name: str, default: str = "") -> str:
    m = re.search(rf"^{re.escape(name)}\s*=\s*(.+)$", text, re.M)
    return m.group(1).strip() if m else default


def number(text: str, name: str, default: float = 0.0) -> float:
    raw = field(text, name, str(default))
    try:
        return float(raw)
    except ValueError:
        return default


def attack_name(value: str) -> str:
    try:
        idx = int(float(value))
    except ValueError:
        return value
    if 0 <= idx < len(ATTACK_NAMES):
        return ATTACK_NAMES[idx]
    return str(idx)


def array_attacks(raw: str) -> list[str]:
    return [attack_name(x) for x in re.findall(r"-?\d+", raw)]


def audit_enemy(path: Path, include_damage_noise: bool) -> list[str]:
    text = path.read_text(errors="ignore")
    name = field(text, "enemy_name", path.stem).strip('"')
    attack = attack_name(field(text, "attack_type", "2"))
    phase2 = attack_name(field(text, "phase_2_attack", "0"))
    phase3 = attack_name(field(text, "phase_3_attack", "0"))
    level = int(number(text, "level", 1))
    bullet_speed = number(text, "bullet_speed", 0)
    bullet_count = int(number(text, "bullet_count", 0))
    attack_damage = int(number(text, "attack_damage", 0))
    summon_on_phase = field(text, "summon_on_phase_change", "false") == "true"
    summon_count = int(number(text, "summon_phase_count", 0))
    attacks = {attack, phase2, phase3}

    issues: list[str] = []
    if level <= 5 and attacks & HEAVY:
        issues.append(f"low-level heavy attack {sorted(attacks & HEAVY)}")
    if level <= 5 and attacks & AREA:
        issues.append(f"low-level area denial {sorted(attacks & AREA)}")
    if summon_on_phase and summon_count >= 3 and level <= 5:
        issues.append(f"low-level phase summons count={summon_count}")
    if bullet_speed >= 120 and level <= 8:
        issues.append(f"fast projectile speed={bullet_speed:g}")
    if bullet_count >= 8 and level <= 8:
        issues.append(f"high bullet count={bullet_count}")
    if attack_damage >= 36 and level <= 5:
        issues.append(f"high early damage={attack_damage}")
    elif include_damage_noise and attack_damage >= 12 and level <= 5:
        issues.append(f"watch early damage={attack_damage}")
    if issues:
        return [f"{path.relative_to(ROOT)} :: {name} :: " + "; ".join(issues)]
    return []


def audit_generation(path: Path) -> list[str]:
    text = path.read_text(errors="ignore")
    ident = field(text, "archetype_id", field(text, "affix_id", path.stem)).strip('"')
    attacks = array_attacks(field(text, "attack_pool", "") + " " + field(text, "add_attack_types", ""))
    issues: list[str] = []
    if set(attacks) & HEAVY:
        issues.append(f"adds heavy attacks {sorted(set(attacks) & HEAVY)}")
    if set(attacks) & AREA:
        issues.append(f"adds area denial {sorted(set(attacks) & AREA)}")
    if set(attacks) & SUMMON:
        issues.append(f"adds summons {sorted(set(attacks) & SUMMON)}")
    if issues:
        return [f"{path.relative_to(ROOT)} :: {ident} :: " + "; ".join(issues)]
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit enemy resource balance risks.")
    parser.add_argument("--include-test", action="store_true", help="Include resources/enemies/test fixtures.")
    parser.add_argument("--include-damage-noise", action="store_true", help="Also report moderate early damage values.")
    args = parser.parse_args()

    findings: list[str] = []
    for path in sorted((ROOT / "resources/enemies").rglob("*.tres")):
        rel = path.relative_to(ROOT)
        if not args.include_test and rel.parts[:3] == ("resources", "enemies", "test"):
            continue
        findings.extend(audit_enemy(path, args.include_damage_noise))
    for path in sorted((ROOT / "resources/enemy_generation").rglob("*.tres")):
        findings.extend(audit_generation(path))

    print("Enemy Resource Audit")
    print(f"Findings: {len(findings)}")
    for line in findings:
        print("- " + line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
