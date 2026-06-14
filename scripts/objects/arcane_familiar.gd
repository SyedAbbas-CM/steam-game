extends Node2D
class_name ArcaneFamiliar

## Wizard summon: a small floating wisp that follows the player, auto-targets the
## nearest enemy within range, and fires homing bolts. Holding the scout_view
## key (V) redirects it toward the player's aim cursor instead of an enemy.
##
## Pure timer-based lifetime — no damage state, no HP. Despawns when expired.

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const FIRE_INTERVAL := 1.1   # seconds between shots
const LIFETIME := 15.0
const TARGET_RANGE := 110.0  # how far it'll seek enemies
const FOLLOW_SPEED := 220.0  # how fast it catches up to the player
const FOLLOW_OFFSET := Vector2(22.0, -16.0)  # rest position relative to player

var player: Node2D
var _life_remaining: float = LIFETIME
var _fire_cooldown: float = 0.0
var _sprite: Sprite2D
var _glow: ColorRect
var _bob_t: float = 0.0


func _ready() -> void:
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Tiny procedural wisp — single bright pixel cluster with a soft halo.
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for x in 6:
		for y in 6:
			var d = Vector2(x - 2.5, y - 2.5).length()
			if d < 1.5:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.5, 1.0))
			elif d < 2.5:
				img.set_pixel(x, y, Color(0.85, 0.7, 1.0, 0.85))
	_sprite.texture = ImageTexture.create_from_image(img)
	add_child(_sprite)
	_glow = ColorRect.new()
	_glow.color = Color(0.5, 0.7, 1.0, 0.35)
	_glow.size = Vector2(14, 14)
	_glow.position = -_glow.size * 0.5
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.z_index = -1
	add_child(_glow)


func _process(delta: float) -> void:
	_life_remaining -= delta
	if _life_remaining <= 0.0:
		_pop_and_die()
		return
	if not is_instance_valid(player):
		_pop_and_die()
		return

	# Idle bob so it feels alive
	_bob_t += delta * 4.0
	var bob_y := sin(_bob_t) * 1.5

	# Move toward target follow position
	var directed: bool = Input.is_action_pressed("scout_view")
	var anchor: Vector2
	if directed:
		var aim := _player_aim()
		anchor = player.global_position + aim * 60.0
	else:
		anchor = player.global_position + FOLLOW_OFFSET
	var to_anchor := anchor - global_position
	var step := FOLLOW_SPEED * delta
	if to_anchor.length() <= step:
		global_position = anchor
	else:
		global_position += to_anchor.normalized() * step
	_sprite.position.y = bob_y

	# Fire at the nearest enemy in range
	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		var target := _pick_target()
		if target:
			_fire_cooldown = FIRE_INTERVAL
			_shoot(target)


func _player_aim() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.RIGHT
	if "touch_controls" in player and player.touch_controls and player.touch_controls.visible:
		var ti = player.touch_controls.get_aim_input()
		if ti.length() > 0.1:
			return ti.normalized()
	var mp := player.get_global_mouse_position()
	var d := mp - player.global_position
	return d.normalized() if d.length() > 0.1 else Vector2.RIGHT


func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_dist := TARGET_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _shoot(target: Node2D) -> void:
	var dir := (target.global_position - global_position).normalized()
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.is_player_bullet = true
	bullet.damage = 6
	bullet.speed = 220.0
	bullet.lifetime = 1.0
	bullet.bullet_sprite_index = 224  # magical bolt
	get_tree().current_scene.add_child(bullet)
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("shoot_a", -16.0, 0.2, 1.4)


func _pop_and_die() -> void:
	var vfx = get_node_or_null("/root/VFXManager")
	if vfx and vfx.has_method("shockwave"):
		vfx.shockwave(global_position, 14.0, Color(0.6, 0.8, 1.0, 0.7))
	queue_free()
