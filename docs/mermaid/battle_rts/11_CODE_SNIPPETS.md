# RTS Code Snippets

## Purpose

These are small excerpts from the critical hubs so you can study the shape of the system before opening the full files.

## 1. Command Write Boundary

Source:

- [battle_arena.gd#L1162](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd#L1162)

```gdscript
func _on_command_issued(group_id: int, cmd: int, target_x: float, target_y: float) -> void:
	var group := commander.get_group(group_id)
	if not group:
		return
	group.command = cmd
	group.target_x = target_x
	group.target_y = target_y

	for i in units.count:
		if units.alive[i] == 1 and units.group_id[i] == group_id:
			units.target_unit[i] = -1
	ai.clear_paths_for_group(group_id)
```

What to notice:

- this is the real command boundary
- command changes are not abstract; they directly rewrite simulation state

## 2. Per-Unit AI Root

Source:

- [battle_simple_ai.gd#L281](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L281)

```gdscript
func update(dt: float) -> void:
	_battle_time += dt
	_retarget_timer += dt
	_morale_timer += dt

	if _flow_recompute_timer >= FLOW_RECOMPUTE_INTERVAL:
		_recompute_flow_fields()

	_check_commander_deaths()

	if _retarget_timer >= RETARGET_INTERVAL:
		_retarget_dead_groups()

	if _retarget_timer == 0.0:
		_update_formation_bonuses()

	if _strategy_timer >= STRATEGY_INTERVAL:
		_reassess_strategy()

	for i in _units.count:
		...
```

What to notice:

- strategy, formation maintenance, and per-unit runtime all live in one method tree
- this is why the file feels monolithic

## 3. Command Dispatch

Source:

- [battle_simple_ai.gd#L428](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L428)

```gdscript
match cmd:
	BattleCommander.CommandType.MOVE:
		_units.target_unit[i] = -1
		_do_movement_toward_pos(i, Vector2(grp.target_x, grp.target_y), dt, true)
	BattleCommander.CommandType.ATTACK:
		_update_target(i)
		...
	BattleCommander.CommandType.HOLD:
		_update_target(i)
		_do_attack_any(i)
	BattleCommander.CommandType.DEFENSIVE:
		_do_cluster(i, dt)
		_update_target(i)
		_do_attack_any(i)
	BattleCommander.CommandType.FOLLOW:
		_do_follow_player(i, dt)
```

What to notice:

- all command semantics are encoded here
- if behavior feels wrong, it is usually this dispatch or its callees

## 4. Movement Core

Source:

- [battle_simple_ai.gd#L2179](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2179)

```gdscript
func _do_movement_toward_pos(i: int, target_pos: Vector2, dt: float, force_move: bool = false, use_flow: bool = true) -> void:
	var dx := target_pos.x - _units.x[i]
	var dy := target_pos.y - _units.y[i]
	var dist := sqrt(dx * dx + dy * dy)

	var nx := dx / dist
	var ny := dy / dist

	if use_flow and not is_player_command and _flow and _flow.is_valid() and dist > 80.0:
		var field_name := _get_flow_field_for_unit(i)
		var flow_dir := _flow.get_flow_direction(field_name, _units.x[i], _units.y[i])
		...

	if _flow and _flow.is_valid():
		var avoid_dir := _flow.get_avoidance_dir(_units.x[i], _units.y[i], move_dir, 48.0)
		...

	_units.vx[i] += move_x * acc * dt * 60.0
	_units.vy[i] += move_y * acc * dt * 60.0
```

What to notice:

- direct heading, flow field, and avoidance are blended together
- player orders are protected by `is_player_command`

## 5. Attack Core

Source:

- [battle_simple_ai.gd#L2283](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_simple_ai.gd#L2283)

```gdscript
func _do_attack(i: int) -> void:
	var target := _units.target_unit[i]
	...
	if dist > atk_range:
		return
	if _flow and not _flow.has_line_of_sight(...):
		return

	var cooldown: float = BattleUnitSystem.UNIT_STATS["attack_cooldown"][t]
	...
	if _battle_time - _units.last_attack_time[i] < cooldown:
		return

	_units.last_attack_time[i] = _battle_time
	...
	_projectiles.spawn(
		_units.x[i], _units.y[i],
		nx * bullet_spd, ny * bullet_spd,
		bullet_dmg, bullet_mass,
		_units.faction[i], t, _units.group_formation[i]
	)
```

What to notice:

- attack does not directly damage units
- it emits projectile state, and later systems resolve the hit

## 6. Battle Frame Loop

Source:

- [battle_arena.gd#L1192](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd#L1192)

```gdscript
func _physics_process(delta: float) -> void:
	units.build_spatial_hash()
	units.update_formation_bonuses(commander)
	ai.update(dt)
	projectiles.update(dt, units, ..., _blocked_tiles)
	_check_soa_projectiles_vs_player()
	_check_player_bullets_vs_soa()
	collision.resolve(units, dt, _blocked_tiles)
	_resolve_player_unit_collision()
	_check_player_abilities_vs_soa()
	_update_unit_physics(dt, ox, oy, bw, bh)
```

What to notice:

- this file is the runtime integration hub
- AI is only one stage in a larger simulation chain

## 7. Player Bridge

Source:

- [battle_arena.gd#L1816](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd#L1816)
- [battle_arena.gd#L1862](/Users/developer-cloudprimero/Desktop/Godot/new-game-project/scripts/battle/battle_arena.gd#L1862)

```gdscript
func _check_player_bullets_vs_soa() -> void:
	var nearby := units.get_nearby(bx, by, 40.0)
	for idx in nearby:
		if units.faction[idx] != BattleUnitSystem.Faction.RED:
			continue
		if dist < units.radius[idx] + hit_r:
			units.damage(idx, float(bdmg), angle, false)

func _check_soa_projectiles_vs_player() -> void:
	for i in projectiles.count:
		if projectiles.proj_faction[i] != BattleUnitSystem.Faction.RED:
			continue
		if dist < player_r + 3.0:
			player.take_damage(int(dmg_val), proj_pos)
```

What to notice:

- the battle system is not purely SoA
- there is a manual bridge both directions
