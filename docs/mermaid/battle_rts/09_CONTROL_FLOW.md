# RTS Control Flow

## Purpose

This file shows how control actually moves through the battle code each frame.

## Top Level Frame Flow

```mermaid
flowchart TD
    A["_physics_process(delta)
    battle_arena.gd#L1192"] --> B["units.build_spatial_hash()"]
    B --> C["units.update_formation_bonuses()
    every N frames"]
    C --> D["ai.update(dt)"]
    D --> E["projectiles.update(dt, units, blocked_tiles)"]
    E --> F["_check_soa_projectiles_vs_player()"]
    F --> G["_check_player_bullets_vs_soa()"]
    G --> H["collision.resolve(units, dt, blocked_tiles)"]
    H --> I["_resolve_player_unit_collision()"]
    I --> J["_check_player_abilities_vs_soa()"]
    J --> K["_update_unit_physics()"]
    K --> L["victory / waves / hud / fog / renderer"]
```

## Per-Unit Decision Flow

```mermaid
flowchart TD
    A["ai.update()
    per-unit loop"] --> B{"alive?"}
    B -->|no| Z["skip"]
    B -->|yes| C["burn / debuff / stagger / scatter checks"]
    C --> D["ability update"]
    D --> E{"route?"}
    E -->|yes| R["_do_rout()"]
    E -->|no| F["read group_id and BattleGroup.command"]
    F --> G["optional group cohesion"]
    G --> H{"command"}
    H -->|MOVE| I["_do_movement_toward_pos()
    clear target_unit"]
    H -->|ATTACK| J["_update_target()
    move+attack toward command target"]
    H -->|HOLD| K["_do_attack_any()"]
    H -->|DEFENSIVE| L["_do_cluster()
    _do_attack_any()"]
    H -->|SCATTER| M["_do_scatter()
    _do_combat()"]
    H -->|FOLLOW| N["_do_follow_player()"]
    H -->|CHARGE| O["_do_movement_toward_pos()
    speed boost
    _do_attack_any()"]
    H -->|RETREAT| P["_do_rout_retreat()
    limited attack"]
```

## Command Ingress Flow

```mermaid
flowchart LR
    A["Mouse / keyboard"] --> B["battle_command_overlay.gd::_input()"]
    B --> C["_issue_command_to_selection()"]
    C --> D["command_issued signal"]
    D --> E["battle_arena.gd::_on_command_issued()"]
    E --> F["BattleGroup.command = cmd"]
    E --> G["BattleGroup.target_x/y = world pos"]
    E --> H["clear units.target_unit"]
    F --> I["ai.update() sees new command next frame"]
```

## Attack Flow

```mermaid
flowchart TD
    A["_update_target()"] --> B["_do_attack()"]
    B --> C{"in range and LOS?"}
    C -->|no| Z["no attack"]
    C -->|yes| D["morale + commander + formation modifiers"]
    D --> E["projectiles.spawn()"]
    E --> F["battle_projectile_system.gd::update()"]
    F --> G["BattleUnitSystem.damage()"]
    G --> H["hp / morale / alive change"]
```

## Player Bridge Flow

```mermaid
flowchart TD
    A["Player bullets"] --> B["_check_player_bullets_vs_soa()"]
    B --> C["units.damage()"]

    D["SoA projectiles"] --> E["_check_soa_projectiles_vs_player()"]
    E --> F["player.take_damage()"]

    G["Player body collision"] --> H["_resolve_player_unit_collision()"]
    H --> I["units.damage()"]
    H --> J["player.take_damage()"]

    K["Player dash / abilities"] --> L["_check_player_abilities_vs_soa()"]
    L --> M["units.damage() / knockback"]
```

## Exact Control Hubs

- [battle_arena.gd#L1192](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd#L1192): frame orchestrator
- [battle_simple_ai.gd#L281](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L281): AI root
- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428): command dispatch
- [battle_simple_ai.gd#L2179](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2179): movement hub
- [battle_simple_ai.gd#L2283](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2283): attack hub

## Reading Advice

When the behavior is surprising, ask these questions in order:

1. what command was written into `BattleGroup`?
2. what did `ai.update()` do with that command?
3. what state did it write into `BattleUnitSystem`?
4. what did the frame loop do after that?
