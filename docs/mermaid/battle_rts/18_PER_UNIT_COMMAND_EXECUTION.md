# Per-Unit Command Execution

## Purpose

This file explains what happens after the doctrine layer writes `BattleGroup.command`.

This is the bridge between:

- group-level tactics
- individual unit behavior

Primary source:

- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428)

## Group Command To Unit Behavior

```mermaid
flowchart TD
    A["BattleGroup.command set by assess_*()"] --> B["ai.update() reads gid + command"]
    B --> C{"command"}
    C -->|MOVE| D["pure move branch"]
    C -->|ATTACK| E["attack-move branch"]
    C -->|HOLD| F["hold and fire only"]
    C -->|DEFENSIVE| G["cluster and fight"]
    C -->|SCATTER| H["spread out and fight"]
    C -->|FOLLOW| I["shadow player and fight"]
    C -->|CHARGE| J["rush and attack"]
    C -->|RETREAT| K["fall back and only fight if very close"]
```

## Why The New Doctrine Matters

The recent doctrine edits bias RED groups toward `ATTACK`.

That means the `ATTACK` branch now carries much more of the tactical burden.

## ATTACK Branch

Source:

- [battle_simple_ai.gd#L456](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L456)

```mermaid
flowchart TD
    A["command = ATTACK"] --> B{"group has target_x/y?"}
    B -->|yes| C["distance to destination"]
    C --> D{"destination reached?"}
    D -->|yes| E["_do_combat()"]
    D -->|no| F["_update_target()"]
    F --> G{"enemy in about 300px?"}
    G -->|yes| H["_do_movement()
    _do_attack()"]
    G -->|no| I["_do_movement_toward_pos(... force_move=true)"]
    B -->|no| E
```

Meaning:

- `ATTACK` is not “stand still and attack”
- `ATTACK` is “move toward the tactical destination, but engage enemies when they become tactically relevant”

## MOVE Branch

Source:

- [battle_simple_ai.gd#L429](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L429)

```mermaid
flowchart TD
    A["command = MOVE"] --> B["target_unit = -1"]
    B --> C["brake perpendicular velocity"]
    C --> D["_do_movement_toward_pos(... force_move=true)"]
    D --> E["no attack path"]
```

Meaning:

- this is the actual “ignore combat and move” path
- if doctrine stops using `MOVE`, units will rarely hard-disengage

## Ranged Reposition Under ATTACK

The recent edits made ranged and horse archers reposition using `ATTACK`, not `MOVE`.

That means:

```mermaid
flowchart TD
    A["ranged assess_*() sets target_x/y"] --> B["command = ATTACK"]
    B --> C["per-unit ATTACK branch"]
    C --> D["if enemy close enough
    move+fire"]
    C --> E["if enemy not close enough
    advance toward target pos"]
```

This is why the recent Claude changes matter:

- the doctrine says “kite and keep shooting”
- the unit execution layer makes that possible only because `ATTACK` contains both movement and attack

## Infantry Screening Under ATTACK

For edited infantry doctrine:

```mermaid
flowchart TD
    A["infantry assess sets screen_pos"] --> B["command = ATTACK"]
    B --> C["move toward screen_pos"]
    C --> D{"enemy enters combat distance?"}
    D -->|yes| E["break from movement and fight"]
    D -->|no| F["keep moving to screen_pos"]
```

This is a subtle but important behavior:

- infantry no longer uses explicit defensive command types to screen
- it screens by destination geometry while staying in attack-move mode

## Per-Unit Status Gates Before Commands

Source:

- [battle_simple_ai.gd#L334](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L334)

```mermaid
flowchart TD
    A["unit enters frame"] --> B["burn"]
    B --> C["commander debuff tick"]
    C --> D["stagger check"]
    D --> E["scatter check"]
    E --> F["morale hesitation"]
    F --> G["ability update"]
    G --> H["route check"]
    H --> I["only then read command"]
```

So even if doctrine says `ATTACK`, the unit may still:

- skip action due to stagger
- flee due to scatter
- hesitate due to morale
- rout due to low hp and local inferiority

## Practical Reading Advice

If you want to understand one surprising unit action, inspect in this order:

1. what `assess_*()` wrote into the group
2. what `command` branch the unit entered
3. whether status gates blocked normal execution
4. what `_update_target()` selected
5. what `_do_movement_toward_pos()` and `_do_attack()` did

## Key References

- [battle_simple_ai.gd#L1135](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1135)
- [battle_simple_ai.gd#L1220](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1220)
- [battle_simple_ai.gd#L1261](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1261)
- [battle_simple_ai.gd#L1403](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1403)
- [battle_simple_ai.gd#L1439](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1439)
- [battle_simple_ai.gd#L1471](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1471)
- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428)
