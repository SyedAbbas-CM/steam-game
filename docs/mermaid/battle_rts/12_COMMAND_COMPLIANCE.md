# RTS Command Compliance

## Purpose

This file explains why units appear to ignore move commands when enemies get close.

The short version:

- plain right-click is `ATTACK`, not `MOVE`
- only `Shift+RightClick` is pure `MOVE`
- `ATTACK` is attack-move and intentionally breaks into combat near enemies

## Input To Command Mapping

```mermaid
flowchart TD
    A["Right click"] --> B{"Shift held?"}
    B -->|yes| C["CommandType.MOVE"]
    B -->|no| D["CommandType.ATTACK"]

    C --> E["_issue_command_to_selection()"]
    D --> E
    E --> F["battle_arena.gd::_on_command_issued()"]
    F --> G["BattleGroup.command set"]
```

Primary code:

- [battle_command_overlay.gd#L522](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_command_overlay.gd#L522)

## What `MOVE` Actually Does

```mermaid
flowchart TD
    A["Group command = MOVE"] --> B["ai.update() per unit"]
    B --> C["target_unit[i] = -1"]
    C --> D["_do_movement_toward_pos(... force_move=true)"]
    D --> E["no combat branch"]
    E --> F["unit keeps moving to target"]
```

Primary code:

- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428)

Key behavior:

- target is cleared every frame
- cohesion is skipped during `MOVE`
- the unit is supposed to disengage and keep moving

## What `ATTACK` Actually Does

```mermaid
flowchart TD
    A["Group command = ATTACK"] --> B["has target position?"]
    B -->|no| C["_do_combat()"]
    B -->|yes| D["_update_target()"]
    D --> E{"enemy target near?"}
    E -->|yes| F["_do_movement()
    _do_attack()"]
    E -->|no| G["_do_movement_toward_pos(... force_move=true)"]
```

Primary code:

- [battle_simple_ai.gd#L456](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L456)

This is the key branch:

- if enemy gets within roughly `300px`, attack-move switches to combat behavior
- that is why units appear to stop obeying the order

## Command Behavior Comparison

```mermaid
flowchart LR
    MOVE["MOVE
    Shift+RightClick"] --> M1["clear target_unit"]
    M1 --> M2["ignore nearby enemy unless physically blocked"]

    ATK["ATTACK
    RightClick"] --> A1["keep moving toward point"]
    A1 --> A2["but if enemy gets close
    update target
    fight instead"]
```

## Why The Current UX Is Confusing

```mermaid
flowchart TD
    A["Player thinks: right click = move"] --> B["Overlay sends ATTACK"]
    B --> C["Enemy enters 300px zone"]
    C --> D["ATTACK branch switches to combat"]
    D --> E["Player experiences this as
    'units ignored my move command'"]
```

## Mixed Selection Gotcha

If you select a loose set of units from different groups, the overlay does not command those units individually.

It commands every existing group represented in the selection.

Primary code:

- [battle_command_overlay.gd#L657](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_command_overlay.gd#L657)

That means:

- selecting 3 units from group A and 2 from group B sends the command to group A and group B
- it does not create a temporary task force
- this can also make command response feel broader than expected

## Exact Code Path

```mermaid
flowchart TD
    A["battle_command_overlay.gd::_input()"] --> B["cmd = MOVE if shift_pressed else ATTACK"]
    B --> C["_issue_command_to_selection()"]
    C --> D["command_issued.emit(...)"]
    D --> E["battle_arena.gd::_on_command_issued()"]
    E --> F["group.command = cmd"]
    E --> G["units.target_unit[i] = -1"]
    F --> H["battle_simple_ai.gd::update()"]
    H --> I{"group.command"}
    I -->|MOVE| J["pure move branch"]
    I -->|ATTACK| K["attack-move branch"]
```

## Reading Anchors

- [battle_command_overlay.gd#L522](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_command_overlay.gd#L522)
- [battle_command_overlay.gd#L657](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_command_overlay.gd#L657)
- [battle_arena.gd#L1162](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd#L1162)
- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428)
- [battle_simple_ai.gd#L2179](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2179)

## Likely User-Facing Fixes

If you want this to feel less confusing later, the best options are:

1. Make plain right-click pure `MOVE`, and use another gesture for attack-move.
2. Keep the current controls, but show a stronger on-screen hint: `RightClick = Attack-Move`, `Shift+RightClick = Move`.
3. Give `ATTACK` and `MOVE` distinct cursor decals or destination markers.
4. Allow loose selections to become temporary task-force groups instead of broadcasting to all source groups.
