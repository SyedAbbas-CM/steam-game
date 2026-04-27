# World Dungeon Battle Links

## Macro World Flow

```mermaid
flowchart LR
    OW["overworld.gd"] --> WM["world map / war table / battle entry"]
    WM --> GM["GameManager.battle_config"]
    GM --> BA["battle_arena.gd"]
    BA --> GM2["battle result back into GameManager"]
    GM2 --> FM["FactionManager territory result"]
    GM2 --> OW2["return to overworld"]
```

Relevant files:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/world_map_screen.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/world_map_screen.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/objects/war_table.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/objects/war_table.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)

## Dungeon Entry And Exit

```mermaid
flowchart TD
    GM["GameManager"] --> DS["dungeon_scene.gd"]
    DS --> DM["dungeon_manager.gd"]
    DM --> P["Player"]
    DM --> RW["Reward flow"]
    DM --> RE["run_ended signal"]
    RE --> GM2["GameManager.on_run_ended()"]
    GM2 --> OW["return_to_overworld()"]
```

Relevant files:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_scene.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_scene.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_events.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_events.gd)

## Scene Shell Responsibilities

```mermaid
flowchart TD
    OW["overworld.gd"] --> OWA["zone/chunk/spawn shell"]
    OW --> OWU["HUD / inventory / quest arrow shell"]
    OW --> OWB["battle entry shell"]

    DS["dungeon_scene.gd"] --> DSA["UI shell"]
    DS --> DSB["player/hud wiring shell"]
    DS --> DSC["GameManager bridge shell"]

    BA["battle_arena.gd"] --> BAA["battle setup shell"]
    BA --> BAB["player bridge shell"]
    BA --> BAC["RTS system shell"]
    BA --> BAD["result shell"]
```

## First-Pass Takeaway

The scene scripts are not pure visuals. They are subsystem wiring roots. Later refactors should preserve them as thin coordinators while moving mechanics into collaborators.

