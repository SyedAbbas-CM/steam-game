# Enemy Observability

Purpose: make dungeon enemy balance auditable from real runs. This is a debug-only layer for answering questions like:

- What enemy types spawned on this floor?
- Which generated archetype and affixes did each elite get?
- Did a low-tier dungeon roll summon-heavy or area-denial behavior?
- What final HP, damage, attack pool, phases, and summon settings did the spawned enemy actually have?

## Runtime Output

`EnemyObservability` is an autoload enabled in debug/editor builds.

Each dungeon run writes:

- JSONL spawn log: `user://enemy_observability/<run>_spawns.jsonl`
- Human summary: `user://enemy_observability/<run>_summary.txt`

The Godot console prints the absolute summary path at dungeon start:

`[EnemyObs] logging to ...`

The summary updates during the run, so it remains useful even if the game is stopped mid-test.

## Captured Fields

Each spawn record includes:

- dungeon, biome, floor, room grid, room type, encounter type
- spawn reason: room spawn, horde wave, encounter spawn, corridor patrol
- recommended level, player level, overlevel, HP/damage scaling
- final enemy name, resource path, HP, damage, contact damage, armor
- size class, movement pattern summary, base attack, phase attacks
- bullet count/speed, bomb radius/flight time
- boss phases, authored boss state count
- summon-on-phase-change, summon count, summon definition
- generated archetype id, generated affix ids, generated attack pool
- status effect payload

## Audit Workflow

1. Enter the problem dungeon.
2. Reproduce the bad room or bad elite.
3. Open the printed summary path.
4. Look at `Major Spawns` first.
5. If the problem is not obvious, inspect the JSONL file for exact per-spawn fields.

## Current Design Constraints

For the demo, generated enemies should not violate these rules:

- floor 1-2 should not roll elite or super-elite rooms
- low-tier elites should not roll summon-heavy generated archetypes
- low-tier elites should not roll toxic, phantom, or defensive wall affixes
- starter dungeon elites should not get phase-change summon floods
- bomb, mine, and area-denial attacks need readable range and cadence

When a bad enemy appears, use its exact generated name and telemetry line as the tuning target.
