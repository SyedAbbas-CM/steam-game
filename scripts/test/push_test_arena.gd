extends Node2D

# Push / Weight Test Arena
# Spawns the player and a row of enemies of increasing weight (mass) so you can
# walk into them, dash, sprint, and feel how collision shoves and bounces work.
#
# Controls (in addition to normal player controls):
#   R         — wipe all enemies and respawn the default lineup
#   1         — spawn another LIGHT enemy (Goblin Mage, weight 0.5)
#   2         — spawn another NORMAL enemy (Orc, weight 1.0)
#   3         — spawn another LARGE enemy (Cyclops, weight 2.5)
#   4         — spawn another BOSS  enemy (Medusa, weight 5.0)
#   5         — spawn a packed row of all four side by side
#   F1        — toggle floating weight labels above enemies
#   ESC / Q   — return to the overworld

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

const LIGHT_DEF_PATH  := "res://resources/enemies/loy/orc/goblin_mage.tres"
const NORMAL_DEF_PATH := "res://resources/enemies/loy/orc/orc.tres"
const LARGE_DEF_PATH  := "res://resources/enemies/loy/orc/cyclops.tres"
const BOSS_DEF_PATH   := "res://resources/enemies/loy/magical/medusa.tres"

@onready var enemy_container: Node2D = $EnemyContainer
@onready var label_layer: CanvasLayer = $LabelLayer
@onready var info_label: Label = $LabelLayer/InfoLabel
@onready var player: Node2D = $Player

var _show_labels: bool = true
var _spawn_x_step: float = 32.0


func _ready() -> void:
	# Defer one frame so the player's _ready() runs first (it sets up equipment etc.)
	call_deferred("_spawn_default_lineup")
	_update_info_text()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_R:
			_clear_enemies()
			_spawn_default_lineup()
		KEY_1:
			_spawn_at_random(LIGHT_DEF_PATH)
		KEY_2:
			_spawn_at_random(NORMAL_DEF_PATH)
		KEY_3:
			_spawn_at_random(LARGE_DEF_PATH)
		KEY_4:
			_spawn_at_random(BOSS_DEF_PATH)
		KEY_5:
			_clear_enemies()
			_spawn_packed_row()
		KEY_F1:
			_show_labels = not _show_labels
			for child in label_layer.get_children():
				if child is Label and child != info_label:
					child.visible = _show_labels
		KEY_ESCAPE, KEY_Q:
			_exit_to_overworld()


func _exit_to_overworld() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("return_to_overworld"):
		gm.return_to_overworld()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _spawn_default_lineup() -> void:
	# Row of one of each weight class, spread out, around player spawn at (0,0)
	var base_x := -120.0
	var spacing := 60.0
	var y := -40.0
	_spawn(LIGHT_DEF_PATH,  Vector2(base_x + spacing * 0, y), "LIGHT (0.5x)")
	_spawn(NORMAL_DEF_PATH, Vector2(base_x + spacing * 1, y), "NORMAL (1.0x)")
	_spawn(LARGE_DEF_PATH,  Vector2(base_x + spacing * 2, y), "LARGE (2.5x)")
	_spawn(BOSS_DEF_PATH,   Vector2(base_x + spacing * 3, y), "BOSS (5.0x)")


func _spawn_packed_row() -> void:
	# Cluster them together so you can ram a wall of mixed-weight enemies
	var paths := [LIGHT_DEF_PATH, NORMAL_DEF_PATH, LARGE_DEF_PATH, BOSS_DEF_PATH]
	var labels := ["LIGHT", "NORMAL", "LARGE", "BOSS"]
	for i in paths.size():
		_spawn(paths[i], Vector2(-50.0 + i * 18.0, -30.0), labels[i])


func _spawn_at_random(path: String) -> void:
	var pos := Vector2(randf_range(-150.0, 150.0), randf_range(-100.0, 100.0))
	# Avoid spawning right on the player
	if pos.distance_to(player.global_position) < 30.0:
		pos += Vector2(40.0, 0.0)
	var def := load(path) as EnemyDefinition
	var label := ""
	if def:
		match def.size_class:
			EnemyDefinition.SizeClass.NORMAL:
				label = "0.5x" if def.preferred_distance >= 30.0 and def.bullet_count > 1 else "1.0x"
			EnemyDefinition.SizeClass.LARGE:
				label = "2.5x"
			EnemyDefinition.SizeClass.BOSS:
				label = "5.0x"
	_spawn(path, pos, label)


func _spawn(def_path: String, pos: Vector2, label_text: String) -> void:
	var def := load(def_path) as EnemyDefinition
	if def == null:
		push_warning("Could not load enemy def: %s" % def_path)
		return
	var enemy = ENEMY_SCENE.instantiate()
	enemy_container.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(def)
	if label_text != "":
		_attach_weight_label(enemy, label_text)


func _attach_weight_label(enemy: Node2D, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label_layer.add_child(lbl)
	lbl.visible = _show_labels
	# Track the enemy each frame
	lbl.set_meta("target", enemy)
	lbl.set_script(_make_follower_script())


func _make_follower_script() -> Script:
	var src := """extends Label
func _process(_dt):
	var t = get_meta(\"target\") if has_meta(\"target\") else null
	if t == null or not is_instance_valid(t):
		queue_free(); return
	var cam = get_viewport().get_camera_2d()
	if cam == null: return
	var screen_pos = (t.global_position - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5
	position = screen_pos + Vector2(-size.x * 0.5, -28)
"""
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s


func _clear_enemies() -> void:
	for child in enemy_container.get_children():
		child.queue_free()
	# Also clear floating labels
	for child in label_layer.get_children():
		if child is Label and child != info_label:
			child.queue_free()


func _update_info_text() -> void:
	info_label.text = "PUSH TEST ARENA\n" \
		+ "Hold Ctrl/Cmd: braced push mode (slow, more inertia, shove enemies)\n" \
		+ "R: respawn lineup   1/2/3/4: add light/normal/large/boss   5: packed row   F1: toggle labels   ESC/Q: exit"
