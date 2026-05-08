# Mines And Socketing Implementation Log

## 2026-04-29

### Planning
- Added the main design/engineering plan:
  - [MINES_AND_SOCKETING_SYSTEM.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/design/MINES_AND_SOCKETING_SYSTEM.md)
- Mapped reuse points in the current codebase:
  - item model: `EquipmentItem`
  - equip/inventory flow: `EquipmentManager`
  - save/load: `GameManager`, `SaveData`
  - gathering persistence: `HarvestNode`
  - crafting recipe model: `CraftingRecipe`

### Data Model Foundations
- Added [gem_definition.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/data/gem_definition.gd)
- Added [blueprint_definition.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/data/blueprint_definition.gd)
- Extended [equipment_item.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_item.gd) with:
  - `archetype_tags`
  - `blueprint_id`
  - `salvage_research_family`
  - `socket_count`
  - `socket_types`
  - `socketed_gem_paths`
  - item instance state helpers for save/load

### Save + Persistence
- Extended [save_data.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd) with:
  - `inventory_item_states`
  - `discovered_gems`
  - `blueprint_progress`
  - `crafted_item_counts`
  - `material_codex`
  - `enemy_codex`
- Extended [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd) so inventory save/load now persists per-item state, not just item paths and ammo quantity

### Visible UI Support
- Updated [inventory_screen.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/inventory_screen.gd)
- Updated [chest_ui.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/chest_ui.gd)
- Tooltips now show:
  - socket counts
  - archetype tags
  - per-socket fill state

### Gameplay Integration
- Updated [equipment_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd)
- Socketed gems now contribute stat modifiers through the normal stat pipeline
- Both flat and percent gem modifiers are applied to equipped gear stats
- Added socket management helpers:
  - `can_socket_gem`
  - `socket_gem`
  - `unsocket_gem`

### Content Seeds
- Added sample gem resources:
  - [chipped_ruby.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/gems/chipped_ruby.tres)
  - [chipped_sapphire.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/gems/chipped_sapphire.tres)
  - [chipped_emerald.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/gems/chipped_emerald.tres)
- Added sample blueprint resource:
  - [iron_dagger_blueprint.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/blueprints/iron_dagger_blueprint.tres)
- Updated [resource_registry.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/resource_registry.gd) with export-safe `gems()` and `blueprints()` lists

### Blueprint + Salvage Progression
- Updated [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd) with persistent helpers for:
  - blueprint discovery
  - blueprint progress
  - gem discovery
  - crafted item counts
  - material codex recording
- Updated [equipment_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/stats/equipment_manager.gd) with:
  - safe equipped-item removal through `remove_from_inventory`
  - `salvage_inventory_item` blueprint progress hook
- Updated [crafting_ui.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/crafting_ui.gd) so:
  - recipes whose result item has a locked `blueprint_id` now show as blueprint-gated
  - blueprint progress is shown in the recipe list
  - crafted results increment permanent craft counts
  - consumed ingredients record material codex usage

### Mine Backend Foundations
- Added [mine_definition.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/data/mine_definition.gd)
  - mine identity, darkness, danger tier, enemy pools, material tables, blueprint hooks, terrain durability fields
- Added [mine_node.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/world/mine_node.gd)
  - extends existing `HarvestNode`
  - records mined material discovery into the codex
  - can reveal gem discoveries
  - can advance blueprint progress on harvest
- Added sample mine resource:
  - [ironvein_depths.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/mines/ironvein_depths.tres)
- Updated [resource_registry.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/resource_registry.gd) with export-safe `mines()`

### Validation
- `--check-only` passed for the touched scripts using temp `HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp`

## 2026-04-30

### Mine Runtime MVP
- Added [mine_runtime.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/mine_runtime.gd)
- Mine runtime now handles:
  - activation against a selected `MineDefinition`
  - per-floor spawning of `MineNode` resource nodes into eligible generated rooms
  - seeded breakable mine-wall cells with per-cell HP/state
  - reward spawning when breakable cells are destroyed
  - blueprint fragment progress from mine caches
  - gem discovery hooks from gem-bearing mine cells

### Dungeon Integration
- Updated [dungeon_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd)
- Added:
  - `mines`
  - `current_mine`
  - `mine_runtime`
- Dungeon startup now:
  - loads mine definitions from `ResourceRegistry.mines()`
  - resolves a current mine from dungeon/biome naming
  - activates `MineRuntime` when a mine definition matches
- Floor generation now calls into mine runtime after room/corridor paint so the mine layer can:
  - mark breakable wall clusters
  - place mine harvest nodes
- Added forwarding helpers:
  - `has_breakable_mine_cell`
  - `damage_breakable_mine_cell_at`
- Active mines now also feed their own enemy pools into room encounter spawning, with elite/super-elite/boss rooms preferring the mine elite pool when one is defined

### Explicit Mine Run Selection
- Updated [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
  - added `pending_mine_id`
  - added `queue_dungeon_run(biome_name, mine_id)`
- Updated [dungeon_scene.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_scene.gd)
  - forwards `pending_mine_id` into the dungeon manager
  - clears the pending mine override after startup
- Updated [dungeon_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd)
  - added `preferred_mine_id`
  - explicit mine selection now takes priority over biome/alias inference

### First Mining Interaction Hook
- Updated [dungeon_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd)
- Added:
  - `_get_nearest_breakable_mine_cell`
  - `_try_mine_nearby_cell`
- The dungeon `interact` flow now:
  - still prioritizes stairs and event interactables
  - then tries nearby interact transitions
  - then, if nothing else is active, mines the nearest breakable mine wall near the player
- This makes the mine backend usable without waiting on a dedicated mining tool UI flow

### Mine Definition Expansion
- Extended [mine_definition.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/data/mine_definition.gd) with:
  - biome aliases for activation
  - node spawn tuning
  - breakable cluster tuning
- Updated [ironvein_depths.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/mines/ironvein_depths.tres) with:
  - aliases
  - node density settings
  - breakable cluster settings

### Validation
- Full project import loaded the new global classes:
  - `MineDefinition`
  - `MineRuntime`
- This was verified against the project context rather than isolated single-script parsing, which is more reliable for this codebase because of the existing global-class dependency graph.
- After the explicit mine-selection and interact-mining additions, a full project-context import completed again with only the pre-existing sample-scene UID warnings.

### Next Recommended Steps
1. Hook player/mining attacks or interaction tools into `damage_breakable_mine_cell_at`
2. Add at least one explicit mine-entry path so `current_mine` is selected intentionally, not only by alias matching
3. Expand mine reward content:
   - more mine definitions
   - more blueprint resources
   - real gem item acquisition
4. Add codex/almanac UI over the now-persisted material/gem/blueprint state

## 2026-04-30

### Overworld Mine Entry Hook
- Updated [overworld.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd)
- Updated [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
- Standard dungeon entrances now carry an optional `mine_id` metadata field.
- Current temporary policy:
  - regular `E` enters the normal dungeon
  - `Sprint + E` enters the linked mine delve instead
  - until more mine definitions exist, standard dungeon entrances can route into `ironvein_depths` for testing
- `GameManager.start_dungeon_run()` now accepts an optional `mine_id` and persists it through the dungeon scene transition.

### Reason
- This removes the need for manual code-driven `queue_dungeon_run(..., mine_id)` calls just to test mining.
- It gives the system a real player-facing test path while world-specific mine entrances are still unauthored.

### Blueprint Coverage Pass
- Added blueprint IDs directly onto crafted result items:
  - `iron_dagger`
  - `iron_shield`
  - `crystal_wand`
  - `venom_bow`
- Added new blueprint resources:
  - [iron_shield_blueprint.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/blueprints/iron_shield_blueprint.tres)
  - [crystal_wand_blueprint.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/blueprints/crystal_wand_blueprint.tres)
  - [venom_bow_blueprint.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/blueprints/venom_bow_blueprint.tres)
- Registered them in [resource_registry.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/resource_registry.gd)
- This makes salvage progress and crafting gates meaningful for more than a single starter weapon.

### Second Mine Branch
- Added [crystal_hollows.tres](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/resources/mines/crystal_hollows.tres)
- This mine shifts the loop toward:
  - `Cave Crystal`
  - `Magic Essence`
  - crystal-flavored gem discovery
  - `crystal_wand_blueprint` progression
- Updated the temporary overworld mine selector in [overworld.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd):
  - `Sprint + E` on most dungeon entrances still routes to `ironvein_depths`
  - crystal-leaning dungeon names now route to `crystal_hollows`
  - current heuristic keys: `spire`, `frost`, `storm`, `sanctum`, `eldori`, `cenneth`, `crystal`
