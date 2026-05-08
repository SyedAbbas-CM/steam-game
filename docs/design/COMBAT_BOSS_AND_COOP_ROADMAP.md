# Combat, Boss, And Co-op Roadmap

## Current State

- Normal enemies are still mostly driven by one large runtime in `scripts/enemy.gd`.
- Bosses now have:
  - HP-gated major phases via `BossState`
  - configurable projectile authoring via `BossShotPattern`
  - timed sub-sequences inside a phase via `BossSequenceStep`
- Spectre is the first boss using this structure.

## Combat Authoring Goal

Separate three layers:

1. Major boss phases
- HP-gated only
- choose broad fight identity
- examples:
  - outer spiral
  - chase lances
  - arena denial
  - desperation spiral

2. Phase-local sub-sequences
- timed loops inside one HP phase
- examples:
  - spiral for 10s
  - chase for 4s
  - reset for 1s

3. Projectile authoring
- per-pattern controls
- count, spread, ring, burst, spin
- speed override
- damage override
- sprite size override
- bounce/status/modifier override

## Immediate Boss Engineering Tasks

1. Convert two more bosses to the new system
- Bone Golem
- one artillery/ranged boss

2. Add more projectile controls
- lifetime override
- pierce override
- homing strength override
- projectile sprite index override
- telegraph color/VFX tag

3. Add more sequence controls
- optional one-shot step
- optional cooldown gap step
- explicit transition trigger between steps

4. Add debug visibility
- current boss phase
- current sequence step
- HP threshold markers for testing

## Co-op Scope Decision

Decide early:

- Local co-op only
- Online co-op
- Both

Recommendation:
- prepare systems for 1-4 players first
- prototype local/shared-session co-op test flow before online netcode

## Co-op Readiness Refactors

### 1. Remove single-player assumptions

Current risk:
- many systems cache one `player`
- enemies target one player only

Required abstraction:
- `get_active_players()`
- `get_primary_player()`
- enemy target selection from player list

Likely hot files:
- `scripts/enemy.gd`
- `scripts/dungeon/dungeon_manager.gd`
- `scripts/dungeon/dungeon_scene.gd`
- `scripts/player.gd`
- UI/HUD scripts

### 2. Targeting And Aggro

Need:
- nearest player targeting
- threat/aggro switching rules
- boss retarget cadence
- anti-jitter target lock windows

### 3. Damage / Status / Pickup Ownership

Need decisions for:
- shared loot vs per-player loot
- shared chests vs instanced chest contents
- revive/downed rules
- status effects on multiple players
- friendly fire policy

### 4. Room / Encounter Logic

Need:
- room clear should depend on all alive players
- entrance/exit handling for multiple players
- boss activation tied to arena occupancy, not one player body

### 5. Camera / Arena Testing

For local testing:
- shared camera for boss arenas
- clamp arena bounds
- keep all players inside one boss room

## Recommended Delivery Order

1. Finish boss-combat infrastructure
- more projectile controls
- more sequence controls

2. Convert Spectre and Bone Golem fully

3. Add player-list abstractions

4. Build a co-op boss test arena path
- 2 to 4 players in one controlled room
- no world persistence concerns yet

5. Then decide whether full online sync is worth the cost

## What To Avoid

- do not add online netcode before player-target abstractions exist
- do not keep hardcoding boss attacks inside `enemy.gd`
- do not build co-op directly on singleton-player assumptions
