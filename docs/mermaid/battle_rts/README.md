# RTS Battle System Map

This folder documents the RTS army commanding mode and the enemy battle AI in the current codebase.

Focus area:

- battle scene setup
- player command mode
- group and commander model
- SoA unit runtime
- enemy tactical AI
- battle entry and exit boundaries

Use these files in order:

1. [00_OVERVIEW.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/mermaid/battle_rts/00_OVERVIEW.md)
2. [01_ENTRY_AND_SETUP.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/mermaid/battle_rts/01_ENTRY_AND_SETUP.md)
3. [02_COMMAND_MODE.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/mermaid/battle_rts/02_COMMAND_MODE.md)
4. [03_GROUPS_AND_UNITS.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/mermaid/battle_rts/03_GROUPS_AND_UNITS.md)
5. [04_ENEMY_AI.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/mermaid/battle_rts/04_ENEMY_AI.md)
6. [05_FRAME_LOOP_AND_BRIDGES.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/mermaid/battle_rts/05_FRAME_LOOP_AND_BRIDGES.md)
7. [06_REFACTOR_TARGETS.md](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/docs/mermaid/battle_rts/06_REFACTOR_TARGETS.md)

Primary files covered:

- [battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)
- [battle_simple_ai.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd)
- [battle_command_overlay.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_command_overlay.gd)
- [battle_commander.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_commander.gd)
- [battle_unit_system.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_unit_system.gd)
- [battle_projectile_system.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_projectile_system.gd)
- [battle_renderer.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_renderer.gd)
- [battle_flow_field.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_flow_field.gd)
- [battle_fog_of_war.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_fog_of_war.gd)
- [battle_hud.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_hud.gd)

Upstream entry files:

- [overworld.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/overworld/overworld.gd)
- [world_map_screen.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/ui/world_map_screen.gd)
- [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)
