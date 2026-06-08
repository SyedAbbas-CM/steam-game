extends Node2D

## Stealth Test Arena
## Demonstrates: vision cones, patrol, noise alerts, stealth kills, ambush bonus.
##
## Layout: a small room with internal walls forming corridors and cover.
## 3 guards patrol fixed paths. Vision cones are drawn.
##
## Controls:
##   C        — toggle sneak (slower move, dampened noise)
##   E        — stealth kill (when prompt shows behind unaware guard)
##   R        — reset arena
##   ESC / Q  — return to overworld

const GUARD_SCRIPT := preload("res://scripts/test/stealth_guard.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

const ARENA_W := 640.0
const ARENA_H := 480.0

@onready var guard_container: Node2D = $GuardContainer
@onready var wall_container: Node2D = $WallContainer
@onready var info_label: Label = $LabelLayer/InfoLabel
@onready var hint_label: Label = $LabelLayer/HintLabel

var _player: Node


func _ready() -> void:
	_build_floor()
	_build_walls()
	_spawn_player()
	call_deferred("_spawn_guards")
	_update_info()


func _process(_delta: float) -> void:
	_update_hint()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_R:
				_reset()
			KEY_ESCAPE, KEY_Q:
				get_tree().change_scene_to_file("res://scenes/overworld/overworld.tscn")


func _build_floor() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.10)
	bg.size = Vector2(ARENA_W, ARENA_H)
	bg.position = -bg.size * 0.5
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Grid
	var grid = Node2D.new()
	grid.set_script(GDScript.new())
	grid.set_script(_make_grid_script())
	grid.z_index = -9
	add_child(grid)


func _make_grid_script() -> GDScript:
	var s = GDScript.new()
	s.source_code = """extends Node2D
func _ready(): queue_redraw()
func _draw():
	var w = 640.0
	var h = 480.0
	var step = 16.0
	var col = Color(1,1,1,0.05)
	var x = -w*0.5
	while x <= w*0.5:
		draw_line(Vector2(x, -h*0.5), Vector2(x, h*0.5), col, 1.0)
		x += step
	var y = -h*0.5
	while y <= h*0.5:
		draw_line(Vector2(-w*0.5, y), Vector2(w*0.5, y), col, 1.0)
		y += step
"""
	s.reload()
	return s


func _build_walls() -> void:
	# Border
	_add_wall(Vector2(0, -ARENA_H * 0.5), Vector2(ARENA_W, 8))
	_add_wall(Vector2(0, ARENA_H * 0.5), Vector2(ARENA_W, 8))
	_add_wall(Vector2(-ARENA_W * 0.5, 0), Vector2(8, ARENA_H))
	_add_wall(Vector2(ARENA_W * 0.5, 0), Vector2(8, ARENA_H))
	# Internal cover — gives the player corners to hide behind
	# Top-left pillar
	_add_wall(Vector2(-180, -120), Vector2(60, 24))
	# Right cover wall (vertical with gap)
	_add_wall(Vector2(120, -150), Vector2(24, 100))
	_add_wall(Vector2(120, 60), Vector2(24, 140))
	# Center pillar
	_add_wall(Vector2(0, 40), Vector2(80, 24))
	# Bottom-left L
	_add_wall(Vector2(-180, 140), Vector2(140, 24))
	_add_wall(Vector2(-260, 80), Vector2(24, 100))


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var sb = StaticBody2D.new()
	sb.position = pos
	sb.collision_layer = 16
	sb.collision_mask = 0
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	sb.add_child(shape)
	var visual = ColorRect.new()
	visual.color = Color(0.25, 0.27, 0.30)
	visual.size = size
	visual.position = -size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb.add_child(visual)
	wall_container.add_child(sb)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(-280, 200)  # bottom-left corner
	add_child(_player)


func _spawn_guards() -> void:
	# Guard 1: patrols top corridor horizontally
	_spawn_guard(Vector2(-100, -180), [
		Vector2(-100, -180),
		Vector2(180, -180),
	])
	# Guard 2: patrols right vertical corridor
	_spawn_guard(Vector2(240, -80), [
		Vector2(240, -80),
		Vector2(240, 160),
	])
	# Guard 3: patrols around the center pillar
	_spawn_guard(Vector2(-60, 90), [
		Vector2(-60, 90),
		Vector2(60, 90),
		Vector2(60, -20),
		Vector2(-60, -20),
	])


func _spawn_guard(spawn_pos: Vector2, path: Array) -> void:
	var g = CharacterBody2D.new()
	g.set_script(GUARD_SCRIPT)
	g.position = spawn_pos
	var typed_path: Array[Vector2] = []
	for p in path:
		typed_path.append(p)
	g.waypoints = typed_path
	guard_container.add_child(g)


func _reset() -> void:
	for child in guard_container.get_children():
		child.queue_free()
	if is_instance_valid(_player):
		_player.position = Vector2(-280, 200)
	call_deferred("_spawn_guards")


func _update_info() -> void:
	if not info_label:
		return
	info_label.text = "STEALTH TEST ARENA\n" + \
		"C: sneak  |  E: stealth kill (from behind)  |  R: reset  |  ESC: exit\n" + \
		"Vision cones: white=unaware, yellow=suspicious, red=alert"


func _update_hint() -> void:
	if not hint_label:
		return
	var remaining = 0
	for g in guard_container.get_children():
		if is_instance_valid(g) and g.state != g.State.DEAD:
			remaining += 1
	hint_label.text = "Guards remaining: %d" % remaining
	if remaining == 0:
		hint_label.text += "   —  Cleared! Press R to reset."
