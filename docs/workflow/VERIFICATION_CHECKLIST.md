# Verification Checklist

Use the smallest applicable checklist for each phase.

## A. Systems / Save Data Changes

- Project boots to the title screen.
- Existing save slots still load.
- New save fields have safe defaults.
- Creating a new save still works.
- Returning to title and reloading preserves the new state.
- No unrelated save fields were wiped or reset.

Primary files usually involved:

- [save_data.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/save_data.gd)
- [game_manager.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/systems/game_manager.gd)

## B. Dungeon / Roguelite Runtime Changes

- Dungeon scene boots without errors.
- Starting a run still works.
- Combat still starts.
- Gold / XP / loot pickup still function.
- Death and return-to-overworld still function.

Primary scene:

- [dungeon.tscn](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scenes/dungeon/dungeon.tscn)

## C. Overworld / World State Changes

- Overworld scene loads.
- Chunk loading does not stall or spam errors.
- Entering a dungeon still works.
- Returning from dungeon restores world state correctly.
- Zone UI and interactions still respond.

Primary scene:

- [overworld.tscn](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scenes/overworld/overworld.tscn)

## D. Battle Layer Changes

- Battle arena scene boots.
- Player and both factions spawn.
- Command mode still toggles.
- Battle resolves cleanly.
- Post-battle rewards and state transitions still work.

Primary scene:

- [battle_arena.tscn](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scenes/battle/battle_arena.tscn)

## E. UI Changes

- Scene opens without missing-node errors.
- Inputs still route correctly.
- Buttons do not regress existing flows.
- New labels reflect live state, not stale cached state.
- Resolution scaling still looks acceptable.

## Diff Review Checklist

- Did the agent touch files outside the approved phase?
- Did any shared file change unexpectedly?
- Were save-data keys renamed or repurposed?
- Were direct `/root/...` dependencies added where a service seam should exist?
- Did the agent add hardcoded content where data should own it?

## Commit Gate

Do not commit a phase until:

- the diff matches the approved phase
- the matching runtime path was exercised
- any known risk is written down in the handoff
