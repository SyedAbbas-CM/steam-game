# System Rebuild Map

## Purpose

This diagram shows how to rebuild the RTS/AI subsystem into readable parts without rewriting the gameplay all at once.

## Current To Target

```mermaid
flowchart LR
    BA["battle_arena.gd
    1955 lines"] --> BA1["battle/setup
    terrain + region + spawn"]
    BA --> BA2["battle/runtime
    frame loop + integration"]
    BA --> BA3["battle/results
    rewards + persistence"]
    BA --> BA4["battle/command
    command mode + camera"]
    BA --> BA5["battle/runtime
    player bridge"]

    AI["battle_simple_ai.gd
    2538 lines"] --> AI1["battle/ai
    strategy planner"]
    AI --> AI2["battle/ai
    army phase controller"]
    AI --> AI3["battle/ai
    group doctrine"]
    AI --> AI4["battle/ai
    target selection"]
    AI --> AI5["battle/ai
    movement driver"]
    AI --> AI6["battle/ai
    attack driver"]
    AI --> AI7["battle/ai
    morale system"]
    AI --> AI8["battle/ai
    ability system"]
```

## First Extraction Order

1. move review-only docs and maps first
2. extract command semantics from `battle_simple_ai.gd`
3. extract movement driver from `battle_simple_ai.gd`
4. extract player bridge from `battle_arena.gd`
5. extract battle results/persistence from `battle_arena.gd`
6. extract army phase controller from `battle_simple_ai.gd`

## Why This Order

- command semantics and movement are the most confusing live behaviors
- player bridge is the strangest integration boundary
- rewards and persistence should not live in the frame orchestrator
- phase controller is easier to isolate once movement and command interpretation are explicit

## What Not To Split First

- `battle_unit_system.gd`
- `battle_projectile_system.gd`

Those files are dense, but they still have clearer responsibility boundaries than the two big orchestration files.
