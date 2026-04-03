# RTS Battle Overview

## Purpose

This subsystem turns strategic army state into a real-time battle where:

- the player controls a hero directly
- blue units can be selected and commanded in RTS-style command mode
- red units are controlled by a tactical AI layer
- both sides run through a shared SoA battle simulation

## System Topology

```mermaid
flowchart TD
    OW["overworld.gd / world_map_screen.gd
    build battle config"] --> GM["GameManager.start_battle()
    stores battle_config
    changes scene"]

    GM --> BA["battle_arena.gd
    battle scene orchestrator"]

    BA --> CMD["battle_command_overlay.gd
    player RTS command UI"]
    BA --> HUD["battle_hud.gd
    battle counts / retreat / fog"]
    BA --> RENDER["battle_renderer.gd
    unit + projectile visuals"]
    BA --> FOG["battle_fog_of_war.gd"]

    BA --> UNITS["battle_unit_system.gd
    SoA unit state"]
    BA --> PROJ["battle_projectile_system.gd
    SoA projectiles"]
    BA --> COLL["battle_collision.gd
    unit-unit resolution"]
    BA --> COM["battle_commander.gd
    group command model"]
    BA --> AI["battle_simple_ai.gd
    enemy tactical logic
    unit movement / targeting / morale"]
    BA --> FLOW["battle_flow_field.gd
    battlefield navigation"]

    BA --> PLAYER["player.tscn
    direct hero control"]

    AI --> COM
    AI --> UNITS
    AI --> PROJ
    AI --> FLOW
    CMD --> COM
    CMD --> UNITS
    RENDER --> UNITS
    RENDER --> PROJ
    FOG --> UNITS
```

## Inputs

- `GameManager.battle_config`
- battle region rects and spawn rects
- player army composition
- enemy army composition
- optional player `army_divisions`
- zone terrain / tileset / enemy scaling metadata

## Outputs

- live battle result
- troop token rewards
- veteran progression updates
- hired fighter loss updates
- `GameManager.on_battle_ended()` consequences

## Key Files

- [battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)
- [battle_simple_ai.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd)
- [battle_command_overlay.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_command_overlay.gd)
- [battle_commander.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_commander.gd)

## Key Types

- `BattleCommander.BattleGroup`
- `BattleUnitSystem`
- `BattleProjectileSystem`
- `BattleSimpleAI`

## Reading Order

If you want to understand this system deeply, read in this order:

1. `battle_arena.gd`
2. `battle_commander.gd`
3. `battle_command_overlay.gd`
4. `battle_unit_system.gd`
5. `battle_simple_ai.gd`
6. `battle_projectile_system.gd`
