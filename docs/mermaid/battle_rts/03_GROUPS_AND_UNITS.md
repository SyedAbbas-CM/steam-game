# Groups And SoA Units

## Purpose

The battle system separates:

- group-level intent in `BattleCommander`
- per-unit runtime state in `BattleUnitSystem`

This is the core abstraction that both player command mode and enemy AI share.

## Group Model

```mermaid
classDiagram
    class BattleGroup {
        +int id
        +String name
        +int faction
        +int unit_type
        +int command
        +int target_group_id
        +int formation_type
        +float target_x
        +float target_y
        +bool permanent
        +int charge_state
        +float charge_timer
        +int initial_size
        +Vector2 withdraw_pos
    }

    class BattleCommander {
        +create_group()
        +get_group()
        +remove_group()
        +get_faction_groups()
        +set_command()
        +get_permanent_group_for_type()
    }

    BattleCommander --> BattleGroup
```

## Spawn And Group Ownership

```mermaid
flowchart TD
    CONFIG["battle_config
    player_army / enemy_army / divisions"] --> SPAWN["_spawn_armies()"]

    SPAWN --> BLUE["spawn blue faction"]
    SPAWN --> RED["spawn red faction"]

    BLUE --> DIVS["_spawn_faction_with_divisions()
    create named permanent groups"]
    BLUE --> DEFBLUE["_spawn_faction_in_rect()
    default permanent groups"]
    RED --> DEFRED["_spawn_faction_in_rect()
    default permanent groups"]

    DIVS --> GROUPS["BattleCommander.create_group()"]
    DEFBLUE --> GROUPS
    DEFRED --> GROUPS

    GROUPS --> UNITS["BattleUnitSystem.spawn()
    group_id stored on each unit"]
    UNITS --> CMDR["_make_commander()
    first spawned unit in group"]
```

## Shared Data Model

```mermaid
flowchart LR
    G["BattleGroup
    command intent"] --> U["BattleUnitSystem
    unit arrays"]

    U --> POS["x y vx vy"]
    U --> COMBAT["hp max_hp defense
    morale target_unit"]
    U --> GROUP["group_id
    group_formation
    is_commander"]
    U --> STATUS["stagger
    burn
    ability_active
    scatter"]

    AI["BattleSimpleAI"] --> G
    AI --> U
    CMD["BattleCommandOverlay"] --> G
    RENDER["BattleRenderer"] --> U
    PROJ["BattleProjectileSystem"] --> U
```

## Related Files

- [battle_commander.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_commander.gd)
- [battle_unit_system.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_unit_system.gd)
- [battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)

## Inputs

- army composition arrays
- optional player `army_divisions`
- unit type
- faction
- stat scaling
- veteran rank

## Outputs

- live SoA unit state
- group centers
- group alive counts
- formation-driven stat bonuses

## Key Functions

- `battle_arena.gd::_spawn_armies()`
- `battle_arena.gd::_spawn_faction_with_divisions()`
- `battle_arena.gd::_spawn_faction_in_rect()`
- `battle_arena.gd::_make_commander()`
- `battle_unit_system.gd::spawn()`
- `battle_unit_system.gd::damage()`
- `battle_unit_system.gd::build_spatial_hash()`
- `battle_unit_system.gd::get_nearby()`
- `battle_unit_system.gd::update_formation_bonuses()`
- `battle_unit_system.gd::get_group_center()`
- `battle_unit_system.gd::get_group_alive_count()`

## Important Design Note

This system uses permanent type/division groups as the stable control surface.

Loose selection in command mode does not fundamentally replace groups.
It translates the player's selection back into commands on existing groups.
