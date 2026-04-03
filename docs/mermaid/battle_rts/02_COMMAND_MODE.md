# RTS Command Mode

## Purpose

Command mode is the player's RTS control surface layered on top of the live battle.

The player can:

- toggle command mode with `Tab`
- select units or permanent groups
- issue `ATTACK`, `MOVE`, `HOLD`, `FOLLOW`, `SCATTER`, `DEFENSIVE`
- switch camera to blue commanders
- release follow groups into active attack

## Command Mode Topology

```mermaid
flowchart TD
    INPUT["battle_arena.gd::_input()
    Tab / R / F-keys / zoom"] --> TOGGLE["_toggle_command_mode()"]

    TOGGLE --> HUD["BattleHUD.set_command_mode()"]
    TOGGLE --> OVERLAY["BattleCommandOverlay.show_overlay()
    or hide_overlay()"]
    TOGGLE --> CAMERA["detach or reattach camera
    command zoom / player zoom"]

    OVERLAY --> SELECT["selection logic
    click unit
    double-click same type
    drag box
    select all
    disband"]

    SELECT --> ISSUE["_issue_command_to_selection()"]
    ISSUE --> SIG["command_issued signal"]
    SIG --> APPLY["battle_arena.gd::_on_command_issued()"]
    APPLY --> GROUP["BattleGroup.command
    target_x / target_y updated"]
    APPLY --> CLEAR["units.target_unit reset
    ai.clear_paths_for_group()"]
```

## Selection Model

```mermaid
flowchart LR
    A["Blue unit click"] --> B{"unit has group_id?"}
    B -->|yes| C["select existing group"]
    B -->|no| D["select loose unit set"]

    E["Double click"] --> F["select nearby same-type blue units"]
    G["Box drag"] --> H["select all blue units in rect"]
    I["Select All button"] --> J["select all alive blue units"]

    C --> K["_selected_group_id"]
    D --> L["_selected_units"]
    F --> K
    F --> L
    H --> K
    H --> L
    J --> L
```

## Command Application Path

```mermaid
flowchart LR
    UI["BattleCommandOverlay"] --> CMD["command_issued(group_id, cmd, x, y)"]
    CMD --> BA["battle_arena.gd::_on_command_issued()"]
    BA --> BG["BattleCommander.BattleGroup"]
    BG --> FIELDS["command
    target_x
    target_y"]
    BA --> RESET["clear unit target_unit
    clear ai flow paths for group"]
    FIELDS --> AI["battle_simple_ai.gd
    per-unit command handling"]
```

## Related Files

- [battle_arena.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd)
- [battle_command_overlay.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_command_overlay.gd)
- [battle_hud.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_hud.gd)
- [battle_commander.gd](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_commander.gd)

## Inputs

- `Tab`
- `R`
- `F1..F10`
- left click / right click / drag
- `Shift+RightClick`
- `Ctrl+LeftClick`
- command buttons in overlay

## Outputs

- active camera mode and zoom
- selected group or loose unit set
- `BattleGroup.command`
- `BattleGroup.target_x`
- `BattleGroup.target_y`

## Key Functions

- `battle_arena.gd::_toggle_command_mode()`
- `battle_arena.gd::_switch_to_commander()`
- `battle_arena.gd::_switch_to_player()`
- `battle_arena.gd::_release_army()`
- `battle_arena.gd::_on_command_issued()`
- `battle_command_overlay.gd::_input()`
- `battle_command_overlay.gd::_try_select_unit_at()`
- `battle_command_overlay.gd::_select_nearby_same_type()`
- `battle_command_overlay.gd::_finish_box_selection()`
- `battle_command_overlay.gd::_issue_command_to_selection()`

## Important Design Note

The overlay does not create tactical logic itself.

It only:

- manages selection
- mutates group membership in narrow cases
- emits commands

The battle scene writes those commands into `BattleGroup`, and the AI loop interprets them.
