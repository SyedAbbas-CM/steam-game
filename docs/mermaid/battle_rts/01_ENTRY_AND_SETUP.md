# RTS Battle Entry And Setup

## Battle Entry Flow

```mermaid
flowchart LR
    OW["overworld.gd::_try_start_battle()"] --> CFG1["build config
    player_army
    enemy_army
    enemy_tier
    enemy_zone_count
    region rects"]

    WM["world_map_screen.gd::_start_battle()"] --> CFG2["build config
    player_army
    enemy_army
    divisions
    region rects"]

    CFG1 --> GM["GameManager.start_battle(config)"]
    CFG2 --> GM

    GM --> STORE["battle_config stored on GameManager"]
    STORE --> SCENE["change scene
    battle_arena.tscn"]
    SCENE --> READY["battle_arena.gd::_ready()"]
```

## Arena Setup Pipeline

```mermaid
flowchart TD
    READY["battle_arena.gd::_ready()"] --> REGION["_setup_region(config)"]
    REGION --> TERRAIN["_prepare_terrain()
    find chunks
    collect tile data
    discover blocked tiles"]

    TERRAIN --> SYS["instantiate systems
    units
    projectiles
    commander
    collision
    ai"]

    SYS --> PLAYER["_spawn_player()"]
    PLAYER --> UI["build hud + command overlay + fog + renderer"]
    UI --> CHUNKS["_load_next_chunks()
    deferred chunk loading"]

    CHUNKS --> FINAL["_finalize_battle_init()"]

    FINAL --> WALLS["build wall body
    collision shapes
    boundary walls"]
    FINAL --> VISUALS["apply tile data"]
    FINAL --> BATTLETERRAIN["_setup_battle_terrain()"]
    FINAL --> ARMIES["_spawn_armies(config)"]
    FINAL --> AISTART["ai.initialize()
    ai.setup_flow_fields()
    ai.compute_initial_flow_fields()"]
    FINAL --> RUN["battle runtime active"]
```

## Related Files

- [overworld.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd)
- [world_map_screen.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/world_map_screen.gd)
- [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
- [battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)
- [battle_arena.tscn](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scenes/battle/battle_arena.tscn)

## Inputs

- `battle_config.zone_name`
- `battle_config.player_army`
- `battle_config.enemy_army`
- `battle_config.divisions`
- `battle_config.battle_region`
- `battle_config.player_spawn_rect`
- `battle_config.enemy_spawn_rect`
- `battle_config.enemy_tier`
- `battle_config.enemy_zone_count`

## Outputs

- initialized battle systems
- spawned player hero
- spawned blue/red army units
- initial AI objectives and flow fields

## Key Functions

- `overworld.gd::_try_start_battle()`
- `world_map_screen.gd::_start_battle()`
- `game_manager.gd::start_battle()`
- `battle_arena.gd::_ready()`
- `battle_arena.gd::_finalize_battle_init()`
- `battle_arena.gd::_spawn_armies()`
