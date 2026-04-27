# Codebase Linkage Pack

This pack is the first-pass connection map for the whole game.

It is not a deep logic walkthrough. Its job is to answer:

- what the main systems are
- which files are the entrypoints
- which autoloads/global systems everything flows through
- how player, UI, world, dungeon, battle, quest, faction, and save systems connect
- which files are high-connectivity hubs

Read in this order:

1. [00_SYSTEM_OVERVIEW.md](./00_SYSTEM_OVERVIEW.md)
2. [01_RUNTIME_ENTRYPOINTS.md](./01_RUNTIME_ENTRYPOINTS.md)
3. [02_STATE_AND_AUTOLOADS.md](./02_STATE_AND_AUTOLOADS.md)
4. [03_PLAYER_INVENTORY_UI_LINKS.md](./03_PLAYER_INVENTORY_UI_LINKS.md)
5. [04_WORLD_DUNGEON_BATTLE_LINKS.md](./04_WORLD_DUNGEON_BATTLE_LINKS.md)
6. [05_QUEST_FACTION_SAVE_LINKS.md](./05_QUEST_FACTION_SAVE_LINKS.md)
7. [06_FILE_CLUSTER_CATALOG.md](./06_FILE_CLUSTER_CATALOG.md)
8. [07_SCENE_SCRIPT_MATRIX.md](./07_SCENE_SCRIPT_MATRIX.md)
9. [08_HIGH_CONNECTIVITY_HUBS.md](./08_HIGH_CONNECTIVITY_HUBS.md)
10. [09_BRANCH_AND_SYSTEM_SPLIT.md](./09_BRANCH_AND_SYSTEM_SPLIT.md)

Primary hub files in this pass:

- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/project.godot](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/project.godot)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/player.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/dungeon/dungeon_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/quests/quest_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/quests/quest_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/faction_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/faction_manager.gd)
- [/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd)
