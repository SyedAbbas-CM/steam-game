# Boss Patterns And Multiplayer Continuation

## Purpose

This document is the continuation point for:

- boss combat authoring
- procedural projectile patterns
- reusable bullet movement behaviors
- first-pass co-op architecture

Use this after the current Spectre/Bone Golem work so the next pass does not restart from scratch.

## Current Priorities

- stabilize the new co-op groundwork without relying on global class-name resolution
- keep replacing core single-player assumptions with shared player-query helpers
- build serverless co-op first, then layer dedicated-server support on top of the same combat abstractions
- align the implementation with `docs/design/MMO_ARCHITECTURE.md` so host-authoritative ENet remains the default path

## Current Combat Status

### Boss State Layer

Bosses now support:

- HP-gated major phases via `BossState`
- timed sub-sequences inside one major phase via `BossSequenceStep`
- configurable projectile authoring via `BossShotPattern`

Primary code:

- `scripts/enemies/boss_state.gd`
- `scripts/enemies/boss_sequence_step.gd`
- `scripts/enemies/boss_shot_pattern.gd`
- `scripts/enemy.gd`
- `scripts/bullet.gd`

### Projectile Layer

Projectile authoring now supports:

- count
- spread
- ring emission
- burst count / burst interval
- rotating burst offset
- bullet speed override
- damage override
- sprite scale override
- bullet movement pattern
- orbit radius / radial speed / radial accel / return timing
- bounce override
- status payload

### Bullet Movement Layer

Projectiles now support most reusable movement profiles:

- weighted
- orbit point
- orbit ally/spawner
- orbit player
- patrol horizontal
- patrol vertical
- flee
- zigzag

## Co-op Progress Update

The first real abstraction pass is in:

- `scripts/systems/player_query.gd`
  - shared helpers for active, alive, primary, and nearest players
- `scripts/enemy.gd`
  - enemy targeting now refreshes from nearest active player
- `scripts/bullet.gd`
  - projectile homing and player-reactive bullet behaviors now target nearest active player
- `scripts/dungeon/dungeon_scene.gd`
  - dungeon start/death flow now tracks multiple players and only ends the run when all tracked players are dead
- `scripts/dungeon/mine_scene.gd`
  - mine runtime now uses the same multi-player death gating
- `scripts/systems/game_manager.gd`
  - core player lookups now use the shared helper
- `scripts/overworld/overworld.gd`
  - major overworld player lookups now use the shared helper
- `scripts/stats/equipment_manager.gd`
  - equipment-side player lookups now route through the shared helper
- `scripts/systems/lighting_manager.gd`
  - player lantern attachment now resolves through the shared helper
- `scripts/companions/companion_ai.gd`
  - companion follow logic now reacquires the shared primary player instead of assuming a single static node forever
- `scripts/enemy_spawner.gd`
  - dynamic spawns now resolve from the shared primary player helper
- `scripts/quests/quest_manager.gd`
  - quest runtime now resolves the current player through the same abstraction point
- `scripts/overworld/height_system.gd`
  - the height sandbox no longer assumes a direct one-player scene lookup
- `scripts/player.gd`
  - player nodes now expose peer ownership and local-control metadata for later replication work

Stability note:

- explicit script preloads are now preferred over relying on global `class_name` resolution for this helper
- this avoids parser instability while the co-op refactor spreads through the project

Session groundwork:

- `scripts/systems/coop_session.gd`
  - ENet host/join scaffold
  - session mode tracking
  - UPnP attempt helper
  - LAN address discovery and host network summary
  - intended to stay valid for both serverless co-op and later dedicated-server adaptation
- `scripts/systems/game_manager.gd`
  - owns the boss-arena co-op prototype boot path
- `scripts/ui/title_screen.gd`
  - direct entry hooks for hosting and joining the boss arena prototype from a normal save slot
  - optional UPnP-backed host dialog for internet-host groundwork
- wall bounce
- dash in/out
- kite
- swoop
- teleport
- mirror
- intercept
- elastic
- edge skater
- bait punish
- ambush

These are projectile-safe interpretations, not literal copies of all enemy AI behavior.

### Procedural Pattern Families

`BossShotPattern` now supports:

- `BASIC`
- `ROSE`
- `LISSAJOUS`
- `CYCLOID`
- `LOG_SPIRAL`
- `FRACTAL_FAN`
- `RECURSIVE_FAN`

Pattern library presets currently exist under:

- `resources/boss_patterns/library/`

Current presets:

- `rose_three_petals.tres`
- `rose_five_petals.tres`
- `lissajous_cross.tres`
- `cycloid_crown.tres`
- `log_spiral_three_arm.tres`
- `fractal_fan_branching.tres`
- `recursive_fan_wide.tres`

### Seeded Variation

Procedural patterns now support deterministic seeded variation:

- `use_seed_variation`
- `seed_value`
- `seed_step_per_burst`
- `angle_jitter_degrees`
- `param_jitter`
- `recursive_spawn_scale_jitter`

This is not “infinite fractals” in runtime terms.

Actual runtime model:

- bounded recursive depth
- deterministic seeded variation
- finite sample count

That is the correct practical design for a game.

## Boss Status

### Spectre

Spectre is the current live test boss.

Important note:

- Spectre has been used as the integration target while the pattern system was evolving.
- Its current phase tuning may still be rough.
- Treat Spectre as the pattern-system proving ground first, final boss tuning second.

Current intent:

- opening: log spiral pressure
- chase: large heavy lance shots
- mid phase: rose-orbit style pressure
- late phase: fractal / cycloid pressure

Test path:

- town test entrance row
- `Boss Arena`
- Spectre is the first boss room

### Bone Golem

Bone Golem is also on the authored boss system and already uses moving projectile logic.

Use it as:

- melee/control encounter test
- arena-pressure test
- summoned structure test

## Known Unfinished Combat Work

### Spectre tuning

Still likely needed:

- movement cleanup during spiral phases
- better pacing between log spiral and chase
- clearer fractal phase readability
- less visual overstacking if any phase still carpets too hard

### Bomb / artillery balance

Shared bomb infrastructure was recently capped and slowed down.

Still validate:

- Artillery Golem
- Magma Golem
- poison cloud bosses
- any boss that uses clustered lobs

### Pattern usability

Still needed:

- assign more procedural presets to actual bosses
- decide which families are elite-safe versus boss-only
- add debug UI to show active boss phase and sequence step more clearly if needed

### Elite / Hyper-elite generation

This is not implemented yet.

Planned split:

- bosses = authored
- elites / hyper elites = systemic composition

Target future pieces:

- `EliteArchetypeDefinition`
- `EliteAffixDefinition`
- runtime elite builder

## Multiplayer Goal Split

Two versions are desired:

1. serverless co-op first
2. dedicated-server co-op later

That is the correct order.

## Version A: Serverless Co-op

### Definition

“Serverless” here should mean:

- host-player authoritative session
- one player hosts
- others join directly
- no separate dedicated server process required

Recommended transport for first pass:

- Godot ENet multiplayer
- listen-server model

### Why do this first

- much faster to test
- enough to prove combat/gameplay with 2-4 players
- lets us validate targeting, rooms, bosses, loot, and latency tolerance before building a real backend

### Scope

Target:

- 1 to 4 players
- boss arena first
- maybe one dungeon flow later

First playable objective:

- two players can join the same boss arena
- both can move, shoot, get hit, and clear the encounter

### Serverless architecture recommendation

Host-authoritative, not lockstep.

Meaning:

- host owns enemy simulation
- host owns boss states and projectile spawning
- clients send input/state intent
- host replicates:
  - enemy positions
  - projectile spawns
  - HP/status changes
  - room/encounter state

Do not start with deterministic lockstep.

This project is too action-heavy for that to be the first implementation.

### First serverless milestone

1. Multiple players can exist in one session
2. Shared arena load works
3. Enemies target nearest/primary valid player
4. Host simulates boss/projectiles
5. Clients render replicated projectiles and damage
6. Shared victory / reset works

## Version B: Dedicated Server Co-op

### Definition

Separate headless authoritative simulation.

Recommended later shape:

- dedicated headless Godot server
- clients are pure views/input senders
- server owns:
  - encounters
  - enemy AI
  - projectile simulation
  - loot and persistence decisions

### Why this comes second

- much more engineering cost
- requires stronger replication model
- requires better state ownership discipline
- requires explicit persistence/session flow decisions

Do not do this before the serverless version proves the gameplay loop.

## Co-op Readiness Tasks

These should happen before real multiplayer implementation hardens.

### 1. Remove single-player assumptions

Need to replace:

- cached singular `player`
- code that assumes one player group member matters
- boss logic that only aims/thinks around one target

Introduce:

- `get_active_players()`
- `get_primary_player()`
- `get_nearest_player(from_pos)`
- `get_random_alive_player()`

Hot files:

- `scripts/enemy.gd`
- `scripts/player.gd`
- `scripts/dungeon/dungeon_manager.gd`
- `scripts/dungeon/dungeon_scene.gd`
- HUD/UI scripts

### Progress update

Implemented groundwork so far:

- `scripts/systems/player_query.gd`
  - shared player lookup utility
  - active players
  - primary player
  - nearest player
  - alive players
- `scripts/enemy.gd`
  - now uses shared player-list helpers for nearest-player targeting
- `scripts/bullet.gd`
  - homing / force / projectile movement targeting now uses nearest active player
- `scripts/dungeon/dungeon_scene.gd`
  - now initializes from primary player
  - marks all current players as in-dungeon
  - death handling only ends the run when all tracked players are dead
- `scripts/dungeon/mine_scene.gd`
  - same multi-player death/in-dungeon handling pattern as dungeon scene
- `scripts/systems/game_manager.gd`
  - major scene-transition and save paths now resolve through primary player helper
- `scripts/overworld/overworld.gd`
  - key runtime spawn/despawn/teleport HUD paths now use shared player query helpers

This is not networking yet.

It is the first structural pass so combat/runtime logic stops depending on one hardcoded player lookup everywhere.

### 2. Targeting rules

Need:

- nearest-player targeting
- occasional retarget windows
- anti-jitter lock duration
- boss phase rules that tolerate multiple players

### 3. Damage / pickups / loot rules

Need decisions for:

- shared loot vs instanced loot
- shared chest state vs per-player chest state
- pickup ownership windows
- revive/downed rules
- player death in boss arenas

### 4. Room / arena logic

Need:

- room clear checks over all alive players
- multi-player boss activation
- arena reset rules
- player reconnect / late join policy for serverless tests

### 5. Camera / viewport policy

Need to choose:

- shared camera for arena tests
- split camera
- remote online independent camera

For first serverless arena test:

- shared camera is acceptable
- keep scope narrow

## Recommended Implementation Order

### Phase 1: Finish combat authoring foundation

1. stabilize Spectre
2. stabilize Bone Golem
3. tune bomb/artillery pacing
4. assign procedural patterns to more bosses

### Phase 2: Co-op readiness refactor

1. replace singular-player assumptions
2. build player-list utility API
3. update enemy targeting
4. update room/boss activation logic

### Phase 3: Serverless co-op prototype

1. two-player arena join/host flow
2. host-authoritative boss arena
3. replicated projectiles / damage / HP
4. boss win/lose/reset

### Phase 4: Expand serverless scope

1. 3-4 players
2. dungeon test path
3. loot/pickup synchronization
4. reconnect edge cases

### Phase 5: Dedicated server version

1. move authority off host player
2. headless simulation
3. explicit persistence/session lifecycle

## Immediate Next Tasks

If resuming from this document, do these first:

1. Test Spectre again after the latest procedural swaps.
2. Decide which procedural phases are actually good and which are only tech demos.
3. Add multiplayer-ready player targeting helpers in `enemy.gd` and related managers.
4. Start the serverless co-op prototype with a boss-arena-only path.

## What Not To Do

- do not start dedicated server work first
- do not network the full overworld first
- do not keep adding boss hacks directly into `enemy.gd`
- do not build co-op on top of singleton-player assumptions
