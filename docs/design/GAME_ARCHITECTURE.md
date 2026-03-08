# Game Architecture Overview

## Vision
A roguelike dungeon crawler with persistent army-building and overworld conquest. Death fuels progression. Short dungeon runs feed long-term strategic empire building.

## Three Gameplay Layers

```
┌─────────────────────────────────────────────────┐
│              LAYER 1: DUNGEON RUN               │
│   Top-down action · Hero + 3 companions         │
│   Procedural rooms · Loot · Mutations · Death   │
├─────────────────────────────────────────────────┤
│           LAYER 2: BASE CAMP / ECONOMY          │
│   Recruit troops · Craft gear · Spend relics    │
│   Unlock blueprints · Equip army divisions      │
├─────────────────────────────────────────────────┤
│          LAYER 3: OVERWORLD CONQUEST            │
│   Risk-style map · Outposts/Strongholds/Forts   │
│   Formation-based battles · Territory rewards   │
└─────────────────────────────────────────────────┘
```

## Core Loop

```
DUNGEON RUN (action gameplay, ~5-15 min)
    ↓ hero dies
COLLECT: gold, relics, troop tokens, blueprints, equipment
    ↓
BASE CAMP (strategic decisions, ~2-5 min)
    ↓ spend resources
ARMY: recruit units, equip divisions, choose formations
    ↓
OVERWORLD BATTLE (tactical, ~3-10 min)
    ↓ conquer territory
UNLOCK: new mutations, blueprints, enemy types, biomes
    ↓
NEXT DUNGEON RUN (with new options unlocked)
```

## System Dependency Map

```
PlayerStats ←── EquipmentSystem ←── MutationSystem
    ↑                ↑                    ↑
    │                │                    │
DungeonRun ──→ LootSystem ──→ BlueprintSystem
    │                                     │
    ↓                                     ↓
DeathHandler ──→ EconomySystem ──→ ArmySystem
                      │                   │
                      ↓                   ↓
                 BaseCamp ──→ OverworldMap ──→ BattleSystem
                                              │
                                              ↓
                                    FortressRewards ──→ UnlockSystem
```

## MVP Scope (Phase 1)
1. Dungeon run with procedural rooms (combat + treasure + shrine)
2. Hero with equipment (weapon, armor, artifact, core module)
3. 2-3 mutation types that visibly change gameplay
4. Death → retain gold/relics
5. Base camp screen (spend gold, view unlocks)
6. 1 companion type (archer)

## MVP Scope (Phase 2)
7. Overworld map with 5-8 nodes
8. Army recruitment with 2 unit types
9. Simple auto-battle resolution
10. 1 fortress with unlock reward

## MVP Scope (Phase 3)
11. Full formation system
12. Blueprint crafting
13. All 4 companion types
14. Full overworld map (~20 nodes)
15. Data tracking pipeline

## Technical Stack
- **Engine**: Godot 4.6 (GDScript)
- **Platform**: Android (primary), Desktop (dev/test)
- **Architecture**: Resource-driven, data-first
- **Pattern**: Systems as Nodes, Data as Resources, Config as .tres files
- **Rendering**: 2D pixel art, Mobile renderer

## File Organization

```
scripts/
  systems/          # Core game systems (singletons/autoloads)
    game_manager.gd
    run_manager.gd
    economy_manager.gd
    unlock_manager.gd
    analytics_manager.gd
  dungeon/          # Dungeon generation & room logic
  combat/           # Weapons, bullets, damage
  companions/       # Companion AI & behaviors
  army/             # Units, divisions, formations
  overworld/        # Map, nodes, battles
  ui/               # All UI controllers

resources/
  equipment/        # .tres item definitions
  mutations/        # .tres mutation definitions
  blueprints/       # .tres blueprint definitions
  enemies/          # .tres enemy definitions
  rooms/            # .tres room templates
  companions/       # .tres companion definitions
  army/             # .tres unit/formation definitions
  overworld/        # .tres territory definitions

scenes/
  dungeon/          # Room scenes, dungeon HUD
  combat/           # Bullet, weapon, effect scenes
  companions/       # Companion scenes
  army/             # Battle scenes
  overworld/        # Map scene, territory nodes
  ui/               # Menu, camp, inventory screens

docs/design/        # This documentation
```

## Save System Strategy
- Save on: death, territory conquest, camp exit
- Format: JSON or Godot Resource serialization
- Data: owned territories, inventory, blueprints, currencies, analytics

## Cross-References
- [Dungeon System](DUNGEON_SYSTEM.md)
- [Item & Mutation System](ITEM_AND_MUTATION_SYSTEM.md)
- [Army & Battle System](ARMY_AND_BATTLE_SYSTEM.md)
- [Overworld System](OVERWORLD_SYSTEM.md)
- [Economy System](ECONOMY_SYSTEM.md)
- [Data & Analytics](DATA_AND_ANALYTICS_SYSTEM.md)
