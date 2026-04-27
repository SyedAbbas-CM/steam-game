# Runtime Entrypoints

## Boot Sequence

```mermaid
flowchart LR
    A["project.godot
    main_scene"] --> B["scenes/ui/title_screen.tscn"]
    B --> C["scripts/ui/title_screen.gd"]
    C --> D["GameManager"]
    D --> E["load slot / select class"]
    E --> F["change_scene_to_file(...)"]
    F --> G["overworld / dungeon / battle scene"]
```

Relevant files:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/project.godot](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/project.godot)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scenes/ui/title_screen.tscn](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scenes/ui/title_screen.tscn)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/title_screen.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/title_screen.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)

## Scene Entrypoint Shells

```mermaid
flowchart TD
    GM["GameManager"] --> OW["overworld.tscn
    overworld.gd"]
    GM --> DS["dungeon.tscn
    dungeon_scene.gd"]
    GM --> BA["battle_arena.tscn
    battle_arena.gd"]

    OW --> OWP["Player instance + GameHUD + world systems"]
    DS --> DSP["DungeonManager + Player + reward/UI shell"]
    BA --> BAP["RTS systems + Player + command overlay"]
```

Key shell files:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_scene.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_scene.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)

## Why These Matter

- these are the first runtime files to read for any subsystem
- they are the composition roots where managers, UI, and the player get wired together
- later refactors should keep these files thin and move logic down into subsystem collaborators

