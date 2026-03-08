# Implementation Roadmap

## Current State (Built)
- [x] Player CharacterBody2D with WASD + mouse-aim shooting
- [x] Bullet system (Area2D, directional, colored)
- [x] Enemy spawner (timed, screen-edge spawning)
- [x] Enemy AI (chase + 3-spread shooting)
- [x] Equipment stat system (PlayerStats, StatModifier, EquipmentManager)
- [x] Weapon pattern architecture (WeaponPattern → WeaponSystem)
- [x] 6 weapon patterns (spread, ring, burst, spiral, shotgun, parallel)
- [x] Bullet modifiers (homing, pierce)
- [x] Drop system (DropTable, Pickup, auto-equip)
- [x] 5 sample equipment items
- [x] HP display, damage/invincibility
- [x] Tilemap ground, camera follow

## Phase 1: Dungeon MVP (~20 tasks)

### 1A: Room System
- [ ] RoomData resource (type, enemies, rewards, cleared state)
- [ ] Room scene template (enclosed area with walls)
- [ ] Door/portal nodes that transition between rooms
- [ ] Room transition logic (clear room → open door → next room)
- [ ] Floor generator (sequence of rooms with weighted types)

### 1B: Run Manager
- [ ] RunState resource (current floor, room, accumulated loot)
- [ ] RunManager autoload (start run, track state, end run on death)
- [ ] Death screen (show run summary: floors, kills, gold)
- [ ] Persist gold/relics/tokens on death

### 1C: Reward System
- [ ] Reward selection UI (3 cards to choose from)
- [ ] Treasure room implementation
- [ ] Mutation shrine implementation
- [ ] Reward pool with rarity weighting

### 1D: Mutations (First 4)
- [ ] MutationDefinition resource
- [ ] MutationProcessor node (event hooks)
- [ ] Implement: pierce, life_steal, homing_shots, exploding_bullets
- [ ] Visual feedback per mutation (particle/color changes)

### 1E: First Companion
- [ ] CompanionDefinition resource
- [ ] Companion scene (CharacterBody2D + AI)
- [ ] Archer companion: follow hero, shoot nearest enemy
- [ ] Companion as dungeon reward option

## Phase 2: Base Camp & Economy (~15 tasks)

### 2A: Base Camp Scene
- [ ] Camp scene (menu-based or simple spatial)
- [ ] Currency display (gold, relics, tokens)
- [ ] Recruitment panel (spend tokens → get units)
- [ ] Equipment inventory screen
- [ ] Blueprint crafting screen

### 2B: Army Building
- [ ] UnitDefinition resource
- [ ] Division resource (group of units)
- [ ] Recruit units at camp
- [ ] View army screen
- [ ] Equip divisions with gear

### 2C: Permanent Upgrades
- [ ] Upgrade definitions (relic sink)
- [ ] Upgrade purchase UI
- [ ] Apply upgrade effects to runs

## Phase 3: Overworld & Battles (~15 tasks)

### 3A: Overworld Map
- [ ] Territory definitions (5-8 nodes)
- [ ] Map scene with clickable nodes
- [ ] Territory state (owned/enemy/neutral)
- [ ] Path connections and accessibility rules
- [ ] Passive income per turn

### 3B: Battle System
- [ ] Auto-resolve for outposts
- [ ] Formation selection UI for strongholds
- [ ] Battle result screen (casualties, rewards)
- [ ] Type advantage matrix

### 3C: Fortress
- [ ] Multi-phase fortress battle
- [ ] Fortress unlock rewards (new mutations/items)
- [ ] Victory screen with unlock showcase

## Phase 4: Polish & Depth (~20 tasks)

### 4A: Content
- [ ] 3+ weapon types with unique patterns
- [ ] 12+ mutations
- [ ] All 4 companion types
- [ ] 10+ equipment items per slot
- [ ] 5+ blueprint recipes
- [ ] 20+ territory nodes across 5 biomes

### 4B: Analytics
- [ ] AnalyticsHub singleton
- [ ] Run summary tracking
- [ ] Lifetime stats persistence
- [ ] Death analysis

### 4C: Visual Polish
- [ ] Screen shake on hits
- [ ] Particle effects for mutations
- [ ] UI transitions and animations
- [ ] Sound effects framework
- [ ] Music system

### 4D: Android
- [ ] Touch controls (virtual joystick + auto-aim)
- [ ] Screen scaling for mobile
- [ ] Save/load system
- [ ] Performance optimization
- [ ] Export configuration

## Dependency Graph

```
Phase 1A (Rooms) ──→ Phase 1B (Run Manager) ──→ Phase 1C (Rewards)
                                                       │
Phase 1D (Mutations) ◄─────────────────────────────────┘
Phase 1E (Companions) ◄────────────────────────────────┘
         │
         ▼
Phase 2A (Camp) ──→ Phase 2B (Army) ──→ Phase 2C (Upgrades)
                         │
                         ▼
                  Phase 3A (Map) ──→ Phase 3B (Battles) ──→ Phase 3C (Fortress)
                                                                    │
                                                                    ▼
                                                           Phase 4 (Polish)
```

## Estimated Scope
- **Phase 1**: Core dungeon loop playable
- **Phase 2**: Meta progression functional
- **Phase 3**: Full gameplay loop complete
- **Phase 4**: Content-complete and shippable
