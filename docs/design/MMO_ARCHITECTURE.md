# Multiplayer Architecture

## Purpose

This document defines the multiplayer architecture for the game and records:

- which multiplayer models exist
- which one we are actually building first
- what groundwork is already done
- how the serverless and dedicated-server paths relate to each other

This project should not drift into accidental networking design. The runtime needs one clear model.

## Current Decision

The primary multiplayer path is:

- host-authoritative ENet
- player-hosted session
- LAN first
- direct IP second
- UPnP convenience layer after that
- lightweight room-code lobby later
- dedicated server after the co-op runtime is proven

This is not mesh P2P.

This is not a public MMO realm architecture yet.

## Multiplayer Types

### 1. Offline Single-Player

Current shipping mode.

Characteristics:

- one local player
- no network authority
- all combat and progression local

Status:

- fully active

### 2. Serverless Co-op

One player hosts. Their machine is the authority.

Characteristics:

- host simulates enemies, bullets, damage, loot, room state, quest state
- clients send inputs and receive world state
- cheap to run
- good for 1-4 players
- acceptable for private co-op and boss-arena tests

Status:

- selected as the first multiplayer target
- groundwork in progress

### 3. Direct-IP Internet Co-op

Same host-authoritative model as serverless co-op, but over the internet.

Characteristics:

- same authority model as LAN host
- requires host IP sharing
- router/NAT issues exist
- improved later with UPnP

Status:

- planned after LAN path

### 4. UPnP-Assisted Host-and-Join

Convenience layer on top of player hosting.

Characteristics:

- attempts automatic port forwarding
- improves join success for some players
- does not replace host authority
- does not guarantee connectivity for every router

Status:

- planned
- first scaffold support exists in `scripts/systems/coop_session.gd`
- host UI groundwork exists for optional UPnP-backed boss-arena hosting

### 5. Lobby-Code Multiplayer

Small service for discovery, not simulation.

Characteristics:

- room code lookup only
- actual gameplay still runs on the host machine
- cheap compared to a real game server
- useful for friend sessions and private groups

Status:

- planned after direct IP / UPnP

### 6. Dedicated Server Co-op

Separate authoritative server process for private or public sessions.

Characteristics:

- better authority and stability
- no host migration problem
- easier to scale beyond friend-hosted games
- more operational complexity

Status:

- intentionally deferred
- should reuse the same host-authoritative combat contract built for serverless co-op

### 7. MMO / Persistent Realm

Always-on public world with many players.

Characteristics:

- persistent economy
- stronger anti-cheat requirements
- shard management
- persistence and deployment cost
- much stricter replication and authority design

Status:

- not the current target
- long-term possibility only after co-op architecture is proven

## What We Have Already Achieved

### Co-op-Ready Combat Groundwork

The project is no longer purely hardwired around one player in several central runtime paths.

Implemented:

- `scripts/systems/player_query.gd`
  - active player lookup
  - primary player lookup
  - nearest player lookup
  - alive player lookup
  - random player lookup
- `scripts/enemy.gd`
  - enemies now reacquire and target the nearest active player
- `scripts/bullet.gd`
  - player-reactive projectile behaviors now resolve nearest active player
- `scripts/dungeon/dungeon_scene.gd`
  - dungeon run death handling now ends only when all tracked players are dead
- `scripts/dungeon/mine_scene.gd`
  - mine runtime uses the same alive-player gating
- `scripts/systems/game_manager.gd`
  - core player lookups now use the shared helper
- `scripts/overworld/overworld.gd`
  - major overworld player lookups now use the shared helper
- `scripts/stats/equipment_manager.gd`
  - equipment-side player lookups now use the shared helper
- `scripts/systems/lighting_manager.gd`
  - lantern/player light resolution now uses the shared helper
- `scripts/companions/companion_ai.gd`
  - companions reacquire the shared primary player
- `scripts/enemy_spawner.gd`
  - spawners resolve from the shared primary player
- `scripts/quests/quest_manager.gd`
  - quest player access routes through the shared helper
- `scripts/overworld/height_system.gd`
  - height sandbox player access no longer assumes one direct node lookup
- `scripts/player.gd`
  - player nodes now carry peer ownership metadata and a local-control abstraction point

### Session Scaffold

Added:

- `scripts/systems/coop_session.gd`

Current responsibilities:

- session mode tracking
- host direct ENet session
- join direct ENet session
- clean session teardown
- peer connect/disconnect signal forwarding
- UPnP attempt helper
- local LAN address discovery
- host network summary for UI/debug visibility

This is scaffold-level groundwork, not a full multiplayer implementation.

### Boss-Arena Prototype Entry Path

Implemented prototype boot path:

- title screen slot UI can now:
  - host boss arena
  - join boss arena by direct IP
- `scripts/systems/game_manager.gd`
  - owns the transition contract for this prototype
  - host path starts ENet hosting, then boots `Test-Arena-Boss`
  - join path connects first, then boots `Test-Arena-Boss` only after join success

This is still a session bootstrap path, not full synchronized gameplay.

Internet-hosting groundwork now included:

- host dialog exposes optional UPnP attempt
- session layer records:
  - LAN IPs
  - chosen port
  - external IP if UPnP succeeds
  - whether the mapping succeeded

This does not guarantee internet connectivity for every router, but it is the correct base before adding room-code or relay infrastructure.

## What Is Not Done Yet

Not implemented yet:

- replicated player spawning
- input replication
- host-side authoritative player simulation
- enemy state replication
- projectile replication
- deterministic loot ownership rules
- multiplayer-safe quest progression rules
- reconnect / host migration
- lobby service
- dedicated-server runtime split

## Authority Model

The authority contract should remain consistent across both serverless and dedicated server modes.

### Host / Server Owns

- enemy AI
- bullet spawning
- trap state
- damage resolution
- room progression
- dungeon/mine floor state
- loot drops
- quest/event world state

### Client Owns

- local input capture
- local presentation
- client-side prediction only where needed later

### Client Sends

- movement input
- aim vector
- ability use
- interact requests

### Host Sends Back

- accepted player state
- enemy state
- projectile state
- room/event state
- damage and death results
- loot spawn/results

## Recommended Rollout

### Phase 1: LAN Boss-Arena Co-op

Goal:

- 2 players
- boss arena only
- host-authoritative
- direct ENet host/join

Why:

- smallest map/state surface
- easiest place to validate targeting, bullets, and death handling

### Phase 2: Full Dungeon Co-op

Goal:

- 2-4 players
- dungeon runtime
- mine runtime
- shared progression session

### Phase 3: Internet Direct-IP + UPnP

Goal:

- friend-hosted sessions outside LAN

### Phase 4: Room-Code Discovery

Goal:

- tiny discovery service only
- no gameplay simulation on the lobby service

### Phase 5: Dedicated Server Variant

Goal:

- separate authority process
- same gameplay authority rules as host-authoritative co-op

## Constraints

Do not do these:

- do not build mesh P2P combat
- do not hardcode new systems around one global player
- do not build public persistent-world assumptions into the co-op-first runtime
- do not make client damage authoritative

## Immediate Next Steps

1. Keep replacing remaining singleton-player assumptions in gameplay-critical scripts.
2. Route spawned players through the new peer ownership metadata consistently.
3. Autoload `CoopSession`.
4. Build a minimal host/join debug path for boss arena only.
5. Replicate player spawn and movement first.
6. Replicate enemy targeting and projectile spawn second.

## Related Docs

- `docs/design/BOSS_PATTERNS_AND_MULTIPLAYER_CONTINUATION.md`
- `docs/design/COMBAT_BOSS_AND_COOP_ROADMAP.md`
- `docs/design/GAME_ARCHITECTURE.md`
