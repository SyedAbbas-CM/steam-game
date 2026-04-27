# RED Doctrine Flow

## Purpose

This file explains the edited RED tactical doctrine in `battle_simple_ai.gd`.

This is the layer Claude was changing:

- group-level tactical assessment
- not per-unit movement math
- not projectile hit resolution

Primary source:

- [battle_simple_ai.gd#L1069](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1069)

## Strategic Reassessment Flow

```mermaid
flowchart TD
    A["_reassess_strategy()
    every 3s"] --> B["_update_army_phase()"]
    B --> C["focus fire selection"]
    C --> D["pincer / commander hunt / formation counter"]
    D --> E["per RED group assess_*()"]
    E --> F["BattleGroup.command updated"]
    E --> G["BattleGroup.formation_type updated"]
    E --> H["BattleGroup.target_x/y updated"]
```

## APPROACH Phase Doctrine

Source:

- [battle_simple_ai.gd#L1135](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1135)

```mermaid
flowchart LR
    A["ArmyPhase.APPROACH"] --> B{"unit type"}
    B -->|archer/mage/ranged infantry| C["_assess_ranged()"]
    B -->|everything else| D["command = ATTACK"]
```

What changed:

- earlier logic held cavalry back in `HOLD`
- current logic pushes almost everyone into `ATTACK`
- ranged still gets special positioning

Effect:

- the RED army enters contact more aggressively
- cavalry is less staged and more continuously involved

## Infantry Doctrine

Source:

- [battle_simple_ai.gd#L1220](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1220)

```mermaid
flowchart TD
    A["_assess_infantry()"] --> B{"cavalry nearby >= 3?"}
    B -->|yes| C["ATTACK + SHIELD_WALL"]
    B -->|no| D{"strength > 1.5?"}
    D -->|yes| E["CHARGE + WEDGE
    target weakest nearby enemy"]
    D -->|no| F{"strength < 0.8?"}
    F -->|yes| G["screen for friendly ranged center
    ATTACK + SHIELD_WALL"]
    F -->|no| H["default ATTACK"]
```

Key point:

- infantry no longer flips into `DEFENSIVE` or `RETREAT` here
- it always stays in an offensive command posture
- when outnumbered, it still tries to interpose between enemy and friendly ranged groups

Relevant helper:

- [battle_simple_ai.gd#L1871](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1871)

## Heavy Infantry Doctrine

Source:

- [battle_simple_ai.gd#L1261](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1261)

```mermaid
flowchart TD
    A["_assess_heavy_infantry()"] --> B{"cavalry nearby >= 2?"}
    B -->|yes| C["ATTACK + SHIELD_WALL"]
    B -->|no| D["ATTACK + BLOCK"]
```

Key point:

- heavy infantry has been simplified into an always-attack doctrine
- formation changes remain, command changes mostly do not

## Spear Doctrine

Source:

- [battle_simple_ai.gd#L1403](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1403)

```mermaid
flowchart TD
    A["_assess_spear()"] --> B{"cavalry nearby?"}
    B -->|yes| C["ATTACK + LINE"]
    B -->|no| D{"enemy cavalry group in reach?"}
    D -->|yes| E["intercept cavalry
    ATTACK + LINE"]
    D -->|no| F{"strength > 1.5?"}
    F -->|yes| G["CHARGE weakest enemy"]
    F -->|no| H["default ATTACK + LINE"]
```

Key point:

- spear doctrine now assumes anti-cavalry works through active combat, not passive standing

## Horse Archer Doctrine

Source:

- [battle_simple_ai.gd#L1439](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1439)

```mermaid
flowchart TD
    A["_assess_horse_archer()"] --> B["formation = LOOSE_LINE"]
    B --> C{"melee threats >= 2?"}
    C -->|yes| D["set kiting target pos
    command = ATTACK"]
    C -->|no| E{"exposed ranged target?"}
    E -->|yes| F["harass target
    command = ATTACK"]
    E -->|no| G["default ATTACK"]
```

Key point:

- horse archers no longer use `MOVE` for kiting in this doctrine layer
- they reposition under `ATTACK`, relying on attack-move behavior to keep shooting

## Ranged Doctrine

Source:

- [battle_simple_ai.gd#L1471](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L1471)

```mermaid
flowchart TD
    A["_assess_ranged()"] --> B["formation = LOOSE_LINE"]
    B --> C{"melee threats >= 2?"}
    C -->|yes| D["kite backward with slight strafe
    command = ATTACK"]
    C -->|no| E{"friendly infantry screen exists?"}
    E -->|yes| F["move behind infantry screen
    focus weakest enemy
    command = ATTACK"]
    E -->|no| G["focus weakest enemy
    command = ATTACK"]
```

Key point:

- ranged no longer uses `RETREAT`, `SCATTER`, or `MOVE` in this assessment block
- it always stays under `ATTACK`
- that means ranged units keep the ability to fire while repositioning

## What This Means Architecturally

```mermaid
flowchart LR
    OLD["mixed doctrine
    ATTACK / DEFENSIVE / RETREAT / SCATTER"] --> NEW["offensive doctrine
    mostly ATTACK
    formation and target pos carry the nuance"]
```

This is a major design shift:

- old design: command type encoded tactical stance
- new design: command is usually `ATTACK`, while formation and destination encode stance

## Risk

This simplification makes behavior easier to reason about, but it compresses tactical diversity:

- fewer explicit defensive modes
- less clear distinction between “fight here” and “reposition while fighting”
- more pressure on the per-unit `ATTACK` branch to behave correctly

The key execution layer for that is:

- [battle_simple_ai.gd#L456](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L456)
