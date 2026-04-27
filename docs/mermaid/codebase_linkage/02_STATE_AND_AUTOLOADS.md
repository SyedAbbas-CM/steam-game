# State And Autoloads

## Autoload Graph

```mermaid
flowchart TD
    PG["project.godot"] --> GM["GameManager"]
    PG --> QM["QuestManager"]
    PG --> SFX["SFXManager"]
    PG --> VFX["VFXManager"]
    PG --> FM["FactionManager"]

    GM --> SD["SaveData"]
    GM --> QM
    GM --> FM

    QM --> GM
    QM --> SD

    FM --> GM
    FM --> SD

    OW["Overworld"] --> GM
    OW --> QM
    OW --> FM
    OW --> SFX

    DG["DungeonScene / DungeonManager"] --> GM
    DG --> QM

    P["Player / Equipment"] --> GM
    P --> SFX
    P --> VFX
```

Autoload declarations live in:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/project.godot](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/project.godot)

Primary autoload scripts:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/quests/quest_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/quests/quest_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/faction_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/faction_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/sfx_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/sfx_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/vfx_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/vfx_manager.gd)

## Persistent State Ownership

```mermaid
flowchart LR
    SD["SaveData resource"] --> GM["GameManager
    active slot / save_data"]
    GM --> Char["character state"]
    GM --> World["world state"]
    GM --> Army["army / war state"]
    GM --> Pending["pending scene state
    biome / return pos / battle config"]

    QM["QuestManager"] --> Quest["quest progress / flags"]
    FM["FactionManager"] --> Terr["territory / diplomacy"]

    GM --> QM
    GM --> FM
```

Relevant files:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/quests/quest_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/quests/quest_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/faction_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/faction_manager.gd)

## First-Pass Read

If you want to understand global coupling first, read in this order:

1. `project.godot`
2. `game_manager.gd`
3. `save_data.gd`
4. `quest_manager.gd`
5. `faction_manager.gd`

