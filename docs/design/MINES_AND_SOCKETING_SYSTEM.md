# Mines, Sockets, Blueprints

## Goal

Add a new progression branch that deepens build variety without replacing the current dungeon loop:

- mines for extraction and risk/reward exploration
- ores, gems, and refinement for crafting progression
- socketed gear for build expression
- blueprint and salvage research for long-term unlocks
- archetype tags to make synergies intentional instead of accidental

This system should reuse the existing combat, inventory, save, crafting, and harvesting foundations rather than creating parallel one-off logic.

## Current Reuse Points

### Item + Build Layer

- [equipment_item.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_item.gd)
  - already supports modifiers, bullet modifiers, enchantments, granted spells, ammo, and requirements
  - best place for archetype tags, sockets, blueprint IDs, and per-item serialized state
- [equipment_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd)
  - already handles inventory, equip/unequip, ammo stacking, and consumables
  - best place for future salvage, socketing, and crafting-facing inventory helpers
- [item_enchantment.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/item_enchantment.gd)
  - current enchant system is effect-based and compact
  - can coexist with socketed gems rather than being replaced

### Save + Meta Progression

- [save_data.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd)
  - already persists blueprints, harvested nodes, upgrades, quests, and world flags
  - should be extended with item instance state, gem discovery, codex data, and blueprint research progress
- [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
  - already serializes inventory/equipment and loads item copies
  - best place to persist socketed gem state and blueprint/salvage research state

### Gathering + World Persistence

- [harvest_node.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/world/harvest_node.gd)
  - already handles gather interaction, persistence, respawn timers, and item drops
  - strongest reuse point for ore veins, crystal nodes, mushroom clusters, and mine extraction nodes

### Crafting + Economy

- [crafting_recipe.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/data/crafting_recipe.gd)
  - current recipe resource is usable for forge/alchemy outputs
  - later extension may add blueprint ID, station type, and recipe tags
- [item_pool.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/drops/item_pool.gd)
  - currently rarity/price driven
  - later target for archetype-aware drops and mine-specific resource drops

### Dungeon Runtime

- [dungeon_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd)
  - reusable for enemy spawning, room content, loot injection, and map helpers
  - not a good direct host for full destructible-terrain logic
- [dungeon_events.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_events.gd)
  - reusable event model for cave-ins, vein guardians, gas pockets, unstable crystal rooms

## New Systems

### 1. Mine Biome Layer

Mines are not just another dungeon skin.

Key rules:
- tighter, darker, more hazardous
- resource extraction matters more than full clear
- partial destructibility, not full freeform destruction
- mine-specific enemies, hazards, ore rooms, crystal chambers

Recommended implementation:
- add `MineDefinition` resource
- build a mine-specific manager or generation mode that reuses spawn/content helpers but owns destructible cell state
- use outer hard boundaries plus marked destructible cells inside

### 2. Destructible Terrain

Wall types:
- soft rock
- ore wall
- gem wall
- reinforced wall
- fragile wall
- gas wall

Do not make all walls destructible. Mark specific cells or cell types as breakable.

Recommended data:
- `MineTileState`
  - `cell`
  - `tile_type`
  - `hp`
  - `drop_table`
  - `revealed`
  - `passable`

### 3. Resource Extraction

Mine outputs:
- ores
- rough gems
- crystal dust
- essences
- blueprint fragments

Refinement chain:
- raw ore -> ingot
- rough gem -> cut gem
- gem shards -> fused gem
- salvage parts + rare materials -> named gear recipes

### 4. Socketed Items

Target item ranges:
- common: 0-1 sockets
- uncommon: 1-2
- rare: 2-3
- epic: 3-4
- legendary: 4-6

Socket types:
- open
- colored
- prismatic
- locked

Early implementation should begin with `open` sockets only.

### 5. Gem System

Gem families:
- ruby: power, vitality, heat/burn
- sapphire: spirit/intellect, mana, cooldown, spell crit
- emerald: agility, evasion, wealth, poison
- topaz: crit, attack speed, lightning, precision
- amethyst: life steal, curse, soul, bleed, shadow
- diamond/prism: defense, all-stat, resonance

Gem tiers:
- chipped
- flawed
- normal
- polished
- pristine
- mythic

Initial gem implementation should support:
- stat modifiers
- tags
- quality tier
- future special trait hooks

### 6. Blueprint + Salvage Research

Use two unlock paths:
- direct blueprint discovery
- salvage research progress from duplicate items

Intended player loop:
- find item or fragment
- salvage duplicates or gather fragments
- unlock permanent recipe
- craft item later at hub

### 7. Archetype Tags

Tags are the glue system.

Example tags:
- melee
- ranged
- magic
- poison
- bleed
- frost
- fire
- lightning
- shield
- summon
- crit
- wealth
- curse
- lifesteal

Items, gems, mutations, recipes, and future relics should use the same tag vocabulary.

### 8. Journal / Almanac / Craft Ledger

Suggested tabs:
- Enemies
- Materials
- Gems
- Blueprints
- Crafted Items
- Mine Regions

The system should track:
- discovered
- crafted
- salvaged
- mined
- first seen / first killed for enemies
- drop locations and notes unlocked over time

## Phase Plan

### Phase 1: Foundations

- add item tags
- add sockets to items
- add gem definition resource
- add blueprint definition resource
- add save-data support for:
  - item instance state
  - discovered gems
  - material codex
  - enemy codex
  - blueprint progress
  - crafted item counts

### Phase 2: Crafting Expansion

- salvage station
- socketing UI
- gem cutting / refinement
- blueprint research progress UI
- forge/alchemy/gem station split

### Phase 3: Mines MVP

- one mine biome
- destructible soft-rock cells
- ore/gem nodes
- mine enemy pool
- darkness/visibility modifier
- basic extraction rewards

### Phase 4: Build Depth

- tag-aware loot shaping
- gem special effects
- socket reroll / unlock tools
- archetype set bonuses
- codex completion rewards

## Immediate Engineering Tasks

1. Extend `EquipmentItem` so items can carry sockets, tags, blueprint IDs, and per-instance state.
2. Extend `SaveData` + `GameManager` so inventory items persist socketed gems and future crafted-state changes.
3. Add `GemDefinition` and `BlueprintDefinition` resource scripts.
4. Hook codex/blueprint discovery data into save state now, even if the UI comes later.
5. Reuse `HarvestNode` patterns when mines are implemented instead of inventing a second gather persistence model.
