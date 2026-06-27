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

The JSONL file now includes both spawn records and runtime combat records:

- `enemy_spawn`: final composed enemy stats and generated identity
- `enemy_attack`: attack selected at runtime, phase, state, distance, bullet count, bullet speed
- `projectile_spawn`: projectile sanity samples for major/generated enemies and suspicious bullets
- `enemy_suspicion`: throttled runtime anomalies such as an elite staying stationary too long

## Captured Fields

Each spawn record includes:

- dungeon, biome, floor, room grid, room type, encounter type
- spawn reason: room spawn, horde wave, encounter spawn, corridor patrol
- recommended level, player level, overlevel, HP/damage scaling
- final enemy name, resource path, HP, damage, contact damage, armor
- early balance cap deltas when starter-dungeon safety caps changed HP/damage/projectiles
- size class, movement pattern summary, base attack, phase attacks
- bullet count/speed, bomb radius/flight time
- boss phases, authored boss state count
- summon-on-phase-change, summon count, summon definition
- generated archetype id, generated affix ids, generated attack pool
- status effect payload
- search tags for symptom descriptions, such as `green`, `poison`, `summoner`, `adds`, `bomb`, `mine`, `area_denial`, `orbit`, `stationary`, and `bullet_spam`

Runtime records also include:

- stable `enemy_instance_id`
- attack id and attack source (`direct`, `combo`, etc.)
- active phase and state
- current distance to player
- projectile speed, damage, direction, behavior, lifetime
- rolling projectile count over the last 3 seconds
- suspicious tags: `zero_direction`, `zero_speed`, `zero_damage`, `very_fast_projectile`, `projectile_spam`, `stationary_too_long`

## Audit Workflow

1. Enter the problem dungeon.
2. Reproduce the bad room or bad elite.
3. Open the printed summary path.
4. Look at `Major Spawns` first.
5. Check `Recent Suspicious Runtime Events`.
6. If the problem is not obvious, inspect the JSONL file for exact per-spawn and runtime fields.

From the repo, use:

```bash
python3 scripts/tools/audit_enemy_resources.py
python3 scripts/tools/audit_enemy_resources.py --include-damage-noise
python3 scripts/tools/audit_enemy_resources.py --include-test
python3 scripts/tools/audit_dungeon_pools.py Haven-Dungeons

scripts/tools/find_enemy_logs.sh
scripts/tools/find_enemy_logs.sh 'green'
scripts/tools/find_enemy_logs.sh 'summoner'
scripts/tools/find_enemy_logs.sh 'stationary|mine|orbit'
scripts/tools/find_enemy_logs.sh 'zero_speed|zero_damage|projectile_spam'
scripts/tools/find_enemy_logs.sh 'very_fast_projectile|bomb|artillery'
```

The helper searches:

`~/Library/Application Support/Godot/app_userdata/DungeonCrawl/enemy_observability`

If a custom userdata path is used:

```bash
ENEMY_OBS_DIR=/path/to/enemy_observability scripts/tools/find_enemy_logs.sh 'toxic'
```

## Current Design Constraints

For the demo, generated enemies should not violate these rules:

- floor 1-2 should not roll elite or super-elite rooms
- low-tier elites should not roll summon-heavy generated archetypes
- low-tier elites should not roll toxic, phantom, or defensive wall affixes
- starter dungeon elites should not get phase-change summon floods
- bomb, mine, and area-denial attacks need readable range and cadence

When a bad enemy appears, use its exact generated name and telemetry line as the tuning target.

## Runtime Audit Targets

Use these tags to map player-facing reports to logs:

- “bullets stuck where fired”: search `zero_speed`, `zero_direction`, `stationary`
- “bombs too fast”: search `very_fast_projectile`, `bomb`, `artillery`
- “does no damage”: search `zero_damage`
- “100 bullets/minions”: search `projectile_spam`, `summoner`, `adds`
- “elite just stands still”: search `stationary_too_long`, `hold_ranged`, `anchor`
- “starter dungeon enemy is too tanky”: search `early_balance_caps`, then compare `before` and `after`

## Current Findings

- `Haven-Dungeons` was vulnerable to old-scale enemy resources such as Risen Corpse and Bone Crawler.
- `Haven-Crypt` must stay a separate level chain from `Haven-Dungeons`; chain-base logic must not strip a bare `-Crypt` suffix.
- Starter dungeon runtime caps now limit final HP, attack damage, contact damage, bullet speed, and bullet count after all scaling/generated modifiers.
