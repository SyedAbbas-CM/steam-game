extends "res://scripts/dungeon/traps/dungeon_trap.gd"

## Proximity alarm bell — alerts enemies in nearby rooms when player gets close.
## Destructible: 3 bullet hits to destroy before it rings.

const PROXIMITY_RANGE_SQ = 144.0  # 12px = 1.5 tiles, squared
const BELL_SPRITE = Vector2i(9, 8)  # source 1
const MAX_HP = 3

var _hp: int = MAX_HP
var _rang: bool = false
var _alert_grid_distance: int = 2  # alert enemies in rooms within this grid distance

func _ready() -> void:
	super._ready()
	collision_layer = 32  # trap layer
	collision_mask = 4  # player bullets
	monitoring = false
	monitorable = true

func activate() -> void:
	if _active:
		return
	_active = true
	set_physics_process(true)
	if not area_entered.is_connected(_on_bullet_hit):
		area_entered.connect(_on_bullet_hit)

func _on_bullet_hit(area: Node2D) -> void:
	if _rang:
		return
	if area is Area2D and area.collision_layer & 4:
		_hp -= 1
		_play_sfx("click", -4.0, 0.1)
		var vfx = get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.hit_spark(global_position, Color(0.8, 0.7, 0.3))
		if _hp <= 0:
			# Destroyed before ringing
			if vfx:
				vfx.death_burst(global_position, Color(0.7, 0.6, 0.2), 0)
			_play_sfx("impact_b", -3.0, 0.1)
			deco_layer.erase_cell(origin + tile_pos)
			queue_free()

func _physics_process(_delta: float) -> void:
	if _rang or not _active:
		return
	var p = _find_player()
	if p and global_position.distance_squared_to(p.global_position) <= PROXIMITY_RANGE_SQ:
		_ring()

func _ring() -> void:
	_rang = true
	set_physics_process(false)

	_play_sfx("bell", -2.0, 0.05)
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.shockwave(global_position, 40.0, Color(1.0, 0.9, 0.3, 0.6))

	# Alert all enemies in nearby rooms
	var dm = _find_dungeon_manager()
	if dm:
		var nearby_rooms = _get_nearby_grid_positions(dm, room_grid_pos, _alert_grid_distance)
		for enemy in dm.enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			var egp = enemy.get_meta("grid_pos", Vector2i(-999, -999))
			if egp in nearby_rooms:
				if enemy.has_method("_on_awareness_alert"):
					enemy._on_awareness_alert()
				elif "awareness" in enemy:
					enemy.awareness = 1.0

	# Remove bell tile and self after ringing
	deco_layer.erase_cell(origin + tile_pos)
	# Brief delay before cleanup so VFX plays
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)

func _find_dungeon_manager() -> Node:
	var nodes = get_tree().get_nodes_in_group("dungeon_manager")
	if nodes.size() > 0:
		return nodes[0]
	return null

func _get_nearby_grid_positions(dm: Node, center: Vector2i, max_dist: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not dm.run_state or not dm.run_state.floor_map:
		return result
	for gp in dm.run_state.floor_map:
		var dist = absi(gp.x - center.x) + absi(gp.y - center.y)
		if dist <= max_dist:
			result.append(gp)
	return result
