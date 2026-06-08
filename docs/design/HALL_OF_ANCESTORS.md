# Hall of Ancestors

## Purpose

Replace the current post-death dead-end with a persistent meta-progression hub.

Current MVP loop:
1. Hero dies in dungeon or overworld.
2. GameManager snapshots the dead hero's inventory, item states, gold, and run summary.
3. Character data is wiped as before.
4. Player is sent to `Hall of Ancestors`.
5. Player selects up to 3 legacy items from the dead hero.
6. Soul Points are awarded based on run progress and player level.
7. Player may buy Hall upgrades.
8. Player returns to class selection for the next heir.

## Current scaffolding

### Scene
- `res://scenes/ui/hall_of_ancestors.tscn`
- Script: `res://scripts/ui/hall_of_ancestors.gd`

### SaveData additions
- `soul_points`
- `legacy_vault_items`
- `legacy_vault_item_states`
- `pending_legacy_items`
- `pending_legacy_item_states`
- `last_death_inventory_items`
- `last_death_item_states`
- `last_death_gold`
- `last_death_run_summary`
- `ancestor_records`

### GameManager hooks
- `on_character_death(run_state = null)`
- `go_to_hall_of_ancestors()`
- `finalize_hall_legacy_selection(selected_indices)`
- `buy_hall_upgrade(upgrade_id)`
- `get_hall_upgrade_level(upgrade_id)`
- `get_hall_upgrade_cost(upgrade_id)`
- `get_legacy_vault_capacity()`

## Real upgrades in MVP

### Gold Retention
- Increases the fraction of the dead hero's gold transferred back to persistent gold.
- Base: 20%
- Each level: +10%
- Cap: 5

### Legacy Vault
- Increases the persistent Hall vault capacity.
- Base capacity: 6
- Each level: +2
- Cap: 3

## Soul Point formula

Current formula in `GameManager._calculate_soul_points_gain()`:
- Base: 10
- `+3` per level above 1
- `+4` per dungeon floor reached
- `+1` per 10 enemies killed
- `+1` per 2 rooms cleared

This is intentionally conservative for the first pass.

## Death-source handling

### Dungeon death
- Uses the existing `RunState`.
- Full run summary is available.

### Overworld death
- No `RunState` required.
- Hall still receives item snapshot and a minimal summary.

## What is intentionally not done yet

- Physical navigable cathedral scene
- Ghost replay mirror
- Division/army carryover
- Spell formula preservation
- Bounty board
- Hall-grown room unlocks
- Heirloom level gates
- Full vault management UI

## Next implementation targets

1. Add `Vault` section UI for stored legacy items.
2. Add `Legacy Blueprint` preservation choice on death.
3. Add `Bounty Board` fed by killer/boss metadata.
4. Replace flat UI with a diegetic cathedral layout.
5. Add world/logistics upgrades that affect RTS and dungeon systems.
