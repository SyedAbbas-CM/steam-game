# Dungeon Runtime Map

This diagram is based on the current dungeon scene and its main scripts:

- [dungeon.tscn](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scenes/dungeon/dungeon.tscn)
- [dungeon_scene.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_scene.gd)
- [dungeon_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd)
- [floor_generator.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/floor_generator.gd)
- [dungeon_events.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_events.gd)

Open this file in Cursor and use Markdown preview to view the Mermaid diagrams.

## Scene Structure

```mermaid
flowchart TD
    SCN["scenes/dungeon/dungeon.tscn"] --> MAIN["dungeon_scene.gd
    scene entry
    UI wiring
    player hookup"]

    MAIN --> DM["DungeonManager
    dungeon_manager.gd
    run orchestration"]

    DM --> FL["Floor TileMapLayer"]
    DM --> LIQ["Liquids TileMapLayer"]
    DM --> WA["Walls TileMapLayer"]
    DM --> DE["Decorations TileMapLayer"]
    DM --> RT["RoomTriggers Node2D"]
    DM --> EC["EnemyContainer Node2D"]
    DM --> HC["HazardContainer Node2D"]
    DM --> PL["Player instance"]

    MAIN --> RS["RewardScreen"]
    MAIN --> DS["DeathScreen"]
    MAIN --> IS["InventoryScreen"]
    MAIN --> TC["TouchControls"]
    MAIN --> BULL["Bullets Node2D"]
    MAIN --> HUD["GameHUD runtime instance"]
    MAIN --> FPV["FirstPersonView runtime instance"]

    style MAIN fill:#30506b,stroke:#9fd3ff,color:#fff
    style DM fill:#4b3f6b,stroke:#d2b7ff,color:#fff
```

## Runtime Flow

```mermaid
flowchart TD
    GM["GameManager
    pending_biome_name
    run transitions"] --> SCENE["dungeon_scene.gd::_ready()"]

    SCENE --> SETUP["UI + Player Setup
    reward_screen.setup
    inventory_screen.setup
    game_hud.setup"]

    SCENE --> START["DungeonManager.start_run()"]

    START --> EVENTS["DungeonEvents.new()
    events.setup(self)"]
    START --> BIOME["find biome
    _find_biome_by_name()"]
    START --> CHAIN["find level chain
    _find_level_chain()"]
    START --> FLOOR["_generate_floor(1)"]

    FLOOR --> FGEN["FloorGenerator.generate_floor_map()
    rooms
    start
    stairs"]

    FLOOR --> PAINT["paint world
    _paint_room()
    _paint_corridor()
    _paint_liquid_tiles()
    _paint_room_decorations()"]

    FLOOR --> TRANS["build transitions
    _create_all_transitions()"]
    FLOOR --> TRIG["create room triggers
    _create_room_trigger()"]
    FLOOR --> NAV["DungeonNav / flow field"]
    FLOOR --> READY["floor_changed.emit()"]

    READY --> HUDFLOW["dungeon_scene.gd::_on_floor_changed()
    update HUD
    update minimap
    refresh first-person view"]

    style START fill:#3d5a40,stroke:#b7f0b7,color:#fff
    style FLOOR fill:#6b4c30,stroke:#f5d19a,color:#fff
    style EVENTS fill:#5a355a,stroke:#efb7ff,color:#fff
```

## Dungeon Manager Responsibilities

```mermaid
mindmap
  root((DungeonManager))
    Run Lifecycle
      start_run
      floor_changed signal
      run_ended signal
      current_biome
      current_level
      run_state
    World Painting
      _generate_floor
      _paint_room
      _paint_corridor
      liquids
      decorations
      wall collisions
    Encounters
      _spawn_room_enemies
      _on_enemy_died
      _spawn_boss_portal
      _spawn_key_pickup
    Room State
      room_states
      visited
      alive
      cleared
      liquid_mask
      web_positions
    Transitions
      _create_all_transitions
      _open_interact_transition
      _go_next_floor
      _go_prev_floor
    Destruction
      smash_area
      break_wall_at
      break_deco_at
    Navigation
      DungeonNav
      flow field updates
      enemy _nav bridge
```

## Room Clear To Reward / Event Flow

```mermaid
flowchart LR
    ROOM["player enters room
    _on_room_trigger_entered()"] --> VISIT["_visit_room()"]
    VISIT --> SPAWN["_spawn_room_enemies()"]
    SPAWN --> FIGHT["combat loop"]
    FIGHT --> DEATH["_on_enemy_died()"]
    DEATH --> CLEAR{"room alive count == 0?"}

    CLEAR -->|yes| EVENT["events.on_room_cleared()
    horde
    mimic
    altar
    blessing
    merchant"]

    CLEAR -->|yes| REWARD{"room type reward?"}
    REWARD -->|treasure/shrine| REQSIG["reward_requested.emit(room_data)"]
    REQSIG --> RSCREEN["dungeon_scene.gd::_on_reward_requested()
    RewardScreen.show_rewards()"]
    RSCREEN --> PICK["player picks reward"]
    PICK --> APPLY["dungeon_scene.gd::_on_reward_chosen()
    apply gold/item/heal/companion/blessing"]

    EVENT --> HUD["HUD flash / SFX / extra spawns"]

    style EVENT fill:#614126,stroke:#f0c78a,color:#fff
    style RSCREEN fill:#294d68,stroke:#9fd3ff,color:#fff
```

## Floor Events Layer

```mermaid
flowchart TD
    EV["DungeonEvents"] --> HO["Horde Rush
    _try_horde()"]
    EV --> MI["Mimic Chest
    _try_mimic()"]
    EV --> AL["Cursed Altar
    _try_altar()"]
    EV --> BL["Blessing Shrine
    _try_blessing()"]
    EV --> ME["Wandering Merchant
    _try_merchant()"]
    EV --> BU["Timed Buffs
    _tick_timed_buffs()"]
    EV --> NPC["Floor NPC bootstrap
    on_floor_ready()
    _spawn_elder_npc()"]

    HO --> EC["EnemyContainer"]
    MI --> EC
    AL --> PL["Player stats / buffs"]
    BL --> HUD["HUD + RewardScreen"]
    ME --> SHOP["merchant_opened signal"]
```

## Exit And Persistence Flow

```mermaid
flowchart TD
    RUN["Run active"] --> END1["run complete
    _on_dungeon_complete()"]
    RUN --> END2["player death
    _on_player_died()"]
    RUN --> END3["town portal
    _on_use_effect('town_portal')"]

    END1 --> GM1["GameManager.on_run_ended()"]
    END1 --> RET1["GameManager.return_to_overworld()"]

    END2 --> GM2["GameManager.on_character_death()"]
    END2 --> DEAD["DeathScreen.show_death()"]

    END3 --> META["GameManager.set_meta('spawn_overworld_portal', true)"]
    END3 --> GM3["GameManager.on_run_ended()"]
    END3 --> RET3["GameManager.return_to_overworld()"]

    style GM1 fill:#3d5a40,stroke:#b7f0b7,color:#fff
    style GM2 fill:#6b3030,stroke:#ffb3b3,color:#fff
    style RET1 fill:#30506b,stroke:#9fd3ff,color:#fff
    style RET3 fill:#30506b,stroke:#9fd3ff,color:#fff
```

## Refactor Read

The current dungeon runtime has a clear composition root:

- `dungeon_scene.gd` is the scene-level coordinator.
- `dungeon_manager.gd` is the central system orchestrator.
- `floor_generator.gd` owns layout generation.
- `dungeon_events.gd` owns floor event logic.

The main pressure point is that `dungeon_manager.gd` still owns too many layers at once:

- floor generation
- tile painting
- trap generation
- transitions
- room triggers
- enemy spawning
- boss/key/stairs progression
- destruction and collision rebuilding

That is the right file to split first if you want the dungeon system to become easier to extend.
