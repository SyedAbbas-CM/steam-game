# RTS Unit Runtime Behavior

## Purpose

This file explains what one battle unit actually does during the AI update loop.

## Per-Unit Tick

```mermaid
flowchart TD
    A["unit enters ai.update() loop"] --> B{"alive?"}
    B -->|no| Z["skip"]
    B -->|yes| C["burn tick"]
    C --> D["commander debuff timer"]
    D --> E{"staggered?"}
    E -->|yes| E1["count down stagger
    skip rest of frame"]
    E -->|no| F{"scattered?"}
    F -->|yes| F1["forced flee movement
    restore group when done"]
    F -->|no| G{"morale hesitation?"}
    G -->|yes| G1["apply short stagger"]
    G -->|no| H["charge timer / ability update"]
    H --> I{"route?"}
    I -->|yes| I1["_do_rout()"]
    I -->|no| J["read BattleGroup.command"]
    J --> K["run command branch"]
    K --> L["morale recovery phase later"]
```

Primary code:

- [battle_simple_ai.gd#L281](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L281)

## Command Branches

```mermaid
flowchart LR
    MOVE["MOVE"] --> M["clear target
    move to point"]
    ATTACK["ATTACK"] --> A["attack-move
    fight if enemy close"]
    HOLD["HOLD"] --> H["stop moving
    attack in range"]
    DEF["DEFENSIVE"] --> D["cluster
    fight nearby"]
    SCAT["SCATTER"] --> S["spread out
    fight individually"]
    FOLLOW["FOLLOW"] --> F["shadow player
    attack threats"]
    CHARGE["CHARGE"] --> C["rush target
    boosted speed"]
    RET["RETREAT"] --> R["fall back
    only fight if very close"]
```

Primary code:

- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428)

## Targeting Logic

```mermaid
flowchart TD
    A["_update_target()"] --> B{"current target still valid?"}
    B -->|yes| C["keep target"]
    B -->|no| D["find nearest enemy SoA unit"]
    D --> E["RED also compares player distance"]
    E --> F{"player closer and inside engage range?"}
    F -->|yes| G["target = PLAYER_TARGET_ID"]
    F -->|no| H["target = nearest SoA enemy"]
```

Primary code:

- [battle_simple_ai.gd#L2044](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2044)

## Movement Composition

```mermaid
flowchart TD
    A["desired target position"] --> B["direct heading"]
    B --> C{"use flow field?"}
    C -->|yes| D["blend objective flow with direct heading"]
    C -->|no| E["keep direct heading"]
    D --> F["local wall avoidance"]
    E --> F
    F --> G["formation speed modifier"]
    G --> H["morale speed modifier"]
    H --> I["commander-debuff speed modifier"]
    I --> J["ranged spacing / kiting rules"]
    J --> K["write vx/vy/facing"]
```

Primary code:

- [battle_simple_ai.gd#L2179](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2179)

## Attack Composition

```mermaid
flowchart TD
    A["_do_attack()"] --> B{"in range?"}
    B -->|no| Z["no attack"]
    B -->|yes| C{"LOS clear?"}
    C -->|no| Z
    C -->|yes| D["cooldown from unit type"]
    D --> E["morale modifies cooldown"]
    E --> F["commander debuff modifies cooldown"]
    F --> G["line formation bonus may speed attacks"]
    G --> H["compute projectile damage"]
    H --> I["morale / commander / charge modifiers"]
    I --> J["spawn projectile"]
```

Primary code:

- [battle_simple_ai.gd#L2283](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2283)

## Damage And Morale Flow

```mermaid
flowchart TD
    A["projectile hit or player bridge hit"] --> B["BattleUnitSystem.damage()"]
    B --> C["counter multiplier"]
    C --> D["terrain multiplier"]
    D --> E["formation counter multiplier"]
    E --> F["directional front/flank/rear multiplier"]
    F --> G["morale damage-taken modifier"]
    G --> H["support / formation / scatter modifiers"]
    H --> I["hp reduced"]
    I --> J["morale reduced"]
    J --> K{"hp <= 0?"}
    K -->|yes| L["alive = 0"]
```

Primary code:

- [battle_unit_system.gd#L340](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_unit_system.gd#L340)

## What Your Units Were Doing In The Logged Battle

Based on your log:

- BLUE heavy infantry were mostly a slow durable front line.
- BLUE horse archers were mobile ranged units likely getting targeted by RED archers and infantry pressure.
- RED had no cavalry, so its behavior was mostly infantry line pressure plus ranged support.
- RED phase control looked partially bypassed because it started in `ENGAGED` immediately.
- Your own command logs show several manual `HOLD`, `ATTACK`, and `SCATTER` commands being written into BLUE groups.

## Reading Anchors

- [battle_simple_ai.gd#L281](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L281)
- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428)
- [battle_simple_ai.gd#L2044](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2044)
- [battle_simple_ai.gd#L2179](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2179)
- [battle_simple_ai.gd#L2283](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2283)
- [battle_unit_system.gd#L340](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_unit_system.gd#L340)
