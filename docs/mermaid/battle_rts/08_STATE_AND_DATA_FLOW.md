# RTS State And Data Flow

## Purpose

This file answers one question: where does the state live, and who mutates it?

## State Ownership

```mermaid
flowchart LR
    UI["BattleCommandOverlay
    selection state
    transient UI state"] --> CMD["BattleCommander.BattleGroup
    command
    target_x/y
    formation
    charge_state"]

    CMD --> AI["BattleSimpleAI
    decision logic
    timers
    phase state
    objectives"]

    AI --> UNITS["BattleUnitSystem
    x y vx vy
    hp morale
    target_unit
    group_id
    ability state"]

    AI --> PROJ["BattleProjectileSystem
    projectile SoA"]

    ARENA["BattleArena
    blocked tiles
    battle config
    player ref
    wave state
    UI refs"] --> AI
    ARENA --> UNITS
    ARENA --> PROJ

    FLOW["BattleFlowField
    objective fields
    LOS
    avoidance"] --> AI
```

## Data Flow

```mermaid
flowchart TD
    A["Player input"] --> B["BattleCommandOverlay selection state"]
    B --> C["command_issued(group_id, cmd, x, y)"]
    C --> D["battle_arena.gd::_on_command_issued()"]
    D --> E["BattleGroup.command / target_x / target_y"]
    E --> F["battle_simple_ai.gd::update()"]
    F --> G["BattleUnitSystem target_unit / vx / vy / morale / ability flags"]
    F --> H["BattleProjectileSystem.spawn()"]
    G --> I["battle_arena.gd::_update_unit_physics()"]
    H --> J["battle_projectile_system.gd::update()"]
    J --> K["BattleUnitSystem.damage()"]
```

## Primary Data Carriers

### Group intent

- [battle_commander.gd#L9](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_commander.gd#L9)
- fields:
  - `command`
  - `target_group_id`
  - `formation_type`
  - `target_x`
  - `target_y`
  - `charge_state`
  - `initial_size`

### Unit runtime state

- [battle_unit_system.gd#L151](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_unit_system.gd#L151)
- high-value arrays:
  - `x`, `y`, `vx`, `vy`
  - `group_id`
  - `target_unit`
  - `morale`
  - `ability_cooldown`, `ability_timer`, `ability_active`
  - `is_commander`, `commander_debuff_timer`
  - `formation_bonus_active`, `group_formation`
  - `charge_time`
  - `scatter_time`, `saved_group_id`

### Arena-owned external state

- [battle_arena.gd#L47](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd#L47)
- high-value fields:
  - `units`
  - `projectiles`
  - `commander`
  - `ai`
  - `_blocked_tiles`
  - `_config`
  - `command_mode`
  - `_pending_red_waves`

### AI-owned strategic state

- [battle_simple_ai.gd#L14](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L14)
- high-value fields:
  - `_battle_time`
  - `_retarget_timer`
  - `_strategy_timer`
  - `_army_phase`
  - `red_objective`, `blue_objective`
  - `player_position`, `player_alive`
  - `_blue_cavalry_ratio`, `_blue_heavy_ratio`

## Mutation Map

```mermaid
flowchart TD
    OVL["Overlay"] -->|writes| G1["BattleGroup.command"]
    OVL -->|writes| G2["BattleGroup.target_x/y"]
    OVL -->|sometimes rewrites| U1["BattleUnitSystem.group_id"]

    ARENA["BattleArena"] -->|writes| G1
    ARENA -->|clears| U2["BattleUnitSystem.target_unit"]
    ARENA -->|bridges| U3["BattleUnitSystem.hp / alive / morale"]
    ARENA -->|bridges| P1["BattleProjectileSystem.alive"]

    AI["BattleSimpleAI"] -->|writes| U2
    AI -->|writes| U4["BattleUnitSystem.vx/vy/facing"]
    AI -->|writes| U5["BattleUnitSystem.morale"]
    AI -->|writes| U6["BattleUnitSystem.ability_*"]
    AI -->|spawns| P2["Projectiles"]

    PROJ["ProjectileSystem"] -->|calls| DMG["BattleUnitSystem.damage()"]
    DMG -->|writes| U3
```

## High Stakes State

These are the fields that connect multiple subsystems and are easiest to break:

- `BattleGroup.command`
- `BattleGroup.target_x / target_y`
- `BattleUnitSystem.group_id`
- `BattleUnitSystem.target_unit`
- `BattleUnitSystem.morale`
- `BattleUnitSystem.ability_active`
- `BattleUnitSystem.group_formation`
- `BattleProjectileSystem.source_formation`

If you change those, read the AI loop and arena frame loop again before committing.
