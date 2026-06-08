extends Node2D

## One-shot tutorial dungeon. Ten gated chambers in a row teaching every
## input the player needs. Detection uses Godot input actions directly, so the
## tutorial works for any class / loadout / save state.
##
## Rooms (left → right):
##   0  Movement       — WASD / arrows
##   1  Shoot          — hold Space or LMB to fire (kill 3 dummies)
##   2  Dash           — tap Space to roll (3 rolls)
##   3  Sprint         — hold Shift for weapon special (hold 2 s)
##   4  Stone Toss     — T to throw a rock (3 throws)
##   5  Shield + Parry — hold R to block; survive 6 s vs the archer
##   6  Sneak          — C to toggle stealth, then walk past
##   7  Spells F + G   — press both ability keys
##   8  Inventory      — I to open, then close
##   9  Capstone       — drop the warden to exit
##
## On exit it sets save_data.tutorial_completed = true and calls
## return_to_overworld().

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENV_TILESET := preload("res://assets/tilesets/environment_tileset.tres")
const TUTORIAL_BARREL := preload("res://scripts/dungeon/tutorial_barrel.gd")
const SKELETON_DEF := "res://resources/enemies/loy/undead/skeleton.tres"
const ARCHER_DEF := "res://resources/enemies/loy/undead/dark_archer.tres"

const TILE_SIZE := 8
# Room/corridor sizes in TILES (8 px each). Wall is 1 tile thick.
# Halved from the original (45×30) — smaller rooms feel closer with the camera.
const ROOM_TW := 22
const ROOM_TH := 16
const CORR_TW := 4
const CORR_TH := 4
const ROOM_W := ROOM_TW * TILE_SIZE   # 360
const ROOM_H := ROOM_TH * TILE_SIZE   # 240
const CORR_W := CORR_TW * TILE_SIZE   # 64
const CORR_H := CORR_TH * TILE_SIZE   # 56
const WALL_T := TILE_SIZE              # 8
const ROOM_GAP := ROOM_W + CORR_W     # 424

# Tile atlas coords. Source 0 = lofiEnvironment, theme_row 0 = grey.
const ATLAS_FLOOR := Vector2i(5, 0)
const ATLAS_WALL := Vector2i(4, 0)
const TILE_SOURCE := 0

const ROOM_COUNT := 11

const PROMPTS := [
	"1/11  MOVEMENT  —  WASD or arrow keys to walk.\nWalk to the next door.",
	"2/11  SHOOT  —  Hold SPACE or LEFT CLICK to fire.\nDrop the three skeletons.",
	"3/11  DASH  —  TAP SPACE (don't hold) to roll forward.\nRoll 3 times.",
	"4/11  SPRINT  —  Double-tap a direction (WW, AA, SS or DD) to start sprinting.\nSprint for 2 seconds total.",
	"5/11  STONE TOSS  —  Press T to throw a stone. Hit the BARRELS to blow up the skeletons behind them.",
	"6/11  SHIELD + PARRY  —  Press R to block with a shield or parry with a buckler.\nSurvive the archer.",
	"7/11  SNEAK  —  Press C to toggle sneak.\nSneak past the guards.",
	"8/11  SPELLS  —  F and G cast your equipped spells.\nPress both keys.",
	"9/11  LOCK-ON  —  Press TAB to lock onto the nearest enemy. Press TAB again to cycle.\nShots auto-aim. Drop all three.",
	"10/11  INVENTORY  —  Press B to open. Stats tab spends level points.\nOpen and close the inventory.",
	"11/11  CAPSTONE  —  Use everything you've learned.\nDrop the warden to leave.",
]

var _player: Node2D
var _camera: Camera2D
var _game_hud: CanvasLayer
var _inventory_screen: InventoryScreen
var _quest_log: QuestLog
var _loot_ui: LootBagUI
var _prompt_label: Label
var _progress_label: Label
var _skip_button: Button

var _doors: Array[StaticBody2D] = []
var _floor_layer: TileMapLayer
var _wall_layer: TileMapLayer
var _walls_body: StaticBody2D
var _room_completed: Array[bool] = []
var _armed: Dictionary = {}
var _enemy_container: Node2D
var _label_layer: CanvasLayer

# Per-room progress trackers
var _current_room: int = 0
var _dash_taps: int = 0
var _sprint_held: float = 0.0
var _stone_throws: int = 0
var _shield_timer: float = 0.0
var _shield_started: bool = false
var _sneaked_once: bool = false
var _spell_f_pressed: bool = false
var _spell_g_pressed: bool = false
var _lock_on_presses: int = 0
var _inventory_was_open: bool = false
var _inventory_toggled: bool = false


func _ready() -> void:
	_room_completed.resize(ROOM_COUNT)
	for i in ROOM_COUNT:
		_room_completed[i] = false

	_enemy_container = Node2D.new()
	_enemy_container.name = "EnemyContainer"
	add_child(_enemy_container)

	var bullets := Node2D.new()
	bullets.name = "Bullets"
	bullets.add_to_group("bullets")
	add_child(bullets)

	_label_layer = CanvasLayer.new()
	_label_layer.layer = 50
	add_child(_label_layer)

	_build_world()
	_spawn_player()
	_setup_camera()
	_setup_hud()
	_setup_prompt_label()
	_setup_skip_button()
	_show_prompt(0)
	call_deferred("_arm_room", 0)

	# Hide the GameManager loading overlay now that the scene is ready
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("_hide_loading_screen"):
		gm._hide_loading_screen()


# --- World construction ---

func _build_world() -> void:
	# Floor + wall visuals via TileMapLayer so we get the actual dungeon tileset.
	# Z-indices mirror dungeon.tscn (floor=0, walls=2) — negative z hid the layers
	# behind the engine clear color in earlier revisions.
	_floor_layer = TileMapLayer.new()
	_floor_layer.name = "Floor"
	add_child(_floor_layer)
	_floor_layer.tile_set = ENV_TILESET
	_floor_layer.z_index = 0

	_wall_layer = TileMapLayer.new()
	_wall_layer.name = "Walls"
	add_child(_wall_layer)
	_wall_layer.tile_set = ENV_TILESET
	_wall_layer.z_index = 2

	# Single static body owns all wall colliders (cheaper than one body per wall)
	_walls_body = StaticBody2D.new()
	_walls_body.name = "WallsBody"
	_walls_body.collision_layer = 16
	_walls_body.collision_mask = 0
	add_child(_walls_body)

	for i in ROOM_COUNT:
		var cx: float = i * ROOM_GAP
		var tcx := int(round(cx / TILE_SIZE))
		_paint_floor_tiles(tcx, 0, ROOM_TW, ROOM_TH)
		_build_room_walls(cx, tcx, i)
		_paint_room_number(cx, i + 1)

		if i < ROOM_COUNT - 1:
			var corr_cx: float = cx + ROOM_W * 0.5 + CORR_W * 0.5
			var corr_tcx := int(round(corr_cx / TILE_SIZE))
			_paint_floor_tiles(corr_tcx, 0, CORR_TW, CORR_TH)
			# Corridor top + bottom walls
			_add_wall_rect_tiles(corr_tcx, -(CORR_TH / 2 + 1), CORR_TW, 1)
			_add_wall_rect_tiles(corr_tcx, CORR_TH / 2 + 1, CORR_TW, 1)
			# Door: visual wall tiles + a separate StaticBody2D so we can remove cleanly
			var door := _make_door(cx + ROOM_W * 0.5 + WALL_T * 0.5, 0, CORR_H + TILE_SIZE)
			door.name = "Door%d" % i
			_doors.append(door)

	# Exit pad past the final room — green floor + Area2D trigger
	var exit_cx: float = (ROOM_COUNT - 1) * ROOM_GAP + ROOM_W * 0.5 + CORR_W * 0.5
	var exit_tcx := int(round(exit_cx / TILE_SIZE))
	_paint_floor_tiles(exit_tcx, 0, CORR_TW, CORR_TH)
	var glow := ColorRect.new()
	glow.color = Color(0.3, 0.7, 0.3, 0.35)
	glow.size = Vector2(CORR_W, CORR_H)
	glow.position = Vector2(exit_cx - CORR_W * 0.5, -CORR_H * 0.5)
	glow.z_index = 1
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var exit_area := Area2D.new()
	exit_area.name = "ExitPad"
	exit_area.collision_layer = 0
	exit_area.collision_mask = 1
	var exit_shape := CollisionShape2D.new()
	var exit_rect := RectangleShape2D.new()
	exit_rect.size = Vector2(CORR_W, CORR_H)
	exit_shape.shape = exit_rect
	exit_area.add_child(exit_shape)
	exit_area.position = Vector2(exit_cx, 0)
	exit_area.body_entered.connect(_on_exit_entered)
	add_child(exit_area)


func _build_room_walls(cx: float, tcx: int, idx: int) -> void:
	# Top + bottom walls span the full room
	_add_wall_rect_tiles(tcx, -(ROOM_TH / 2 + 1), ROOM_TW, 1)
	_add_wall_rect_tiles(tcx, ROOM_TH / 2 + 1, ROOM_TW, 1)
	# First room left wall and last room right wall (no backtrack / no walk past exit)
	if idx == 0:
		_add_wall_rect_tiles(tcx - (ROOM_TW / 2 + 1), 0, 1, ROOM_TH)
	if idx == ROOM_COUNT - 1:
		_add_wall_rect_tiles(tcx + ROOM_TW / 2 + 1, 0, 1, ROOM_TH)
	# Side stubs so each side has a corridor slit, not a full opening
	var stub_h: int = (ROOM_TH - CORR_TH) / 2
	if idx < ROOM_COUNT - 1:
		var sx := tcx + ROOM_TW / 2 + 1
		_add_wall_rect_tiles(sx, -(ROOM_TH / 2 - stub_h / 2), 1, stub_h)
		_add_wall_rect_tiles(sx, ROOM_TH / 2 - stub_h / 2, 1, stub_h)
	if idx > 0:
		var sx2 := tcx - (ROOM_TW / 2 + 1)
		_add_wall_rect_tiles(sx2, -(ROOM_TH / 2 - stub_h / 2), 1, stub_h)
		_add_wall_rect_tiles(sx2, ROOM_TH / 2 - stub_h / 2, 1, stub_h)


func _paint_floor_tiles(center_tx: int, center_ty: int, tw: int, th: int) -> void:
	var x0 := center_tx - tw / 2
	var y0 := center_ty - th / 2
	for ty in th:
		for tx in tw:
			_floor_layer.set_cell(Vector2i(x0 + tx, y0 + ty), TILE_SOURCE, ATLAS_FLOOR)


func _add_wall_rect_tiles(center_tx: int, center_ty: int, tw: int, th: int) -> void:
	# Paints wall tiles AND adds a single rectangle collider for the whole strip
	var x0 := center_tx - tw / 2
	var y0 := center_ty - th / 2
	for ty in th:
		for tx in tw:
			_wall_layer.set_cell(Vector2i(x0 + tx, y0 + ty), TILE_SOURCE, ATLAS_WALL)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tw * TILE_SIZE, th * TILE_SIZE)
	shape.shape = rect
	shape.position = Vector2(center_tx * TILE_SIZE, center_ty * TILE_SIZE)
	_walls_body.add_child(shape)


func _make_door(x: float, y: float, height: float) -> StaticBody2D:
	# A self-contained body so removing it on completion is safe
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = Vector2(x, y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WALL_T, height)
	shape.shape = rect
	body.add_child(shape)
	# Paint wall tiles where the door sits
	var t_x := int(round(x / TILE_SIZE))
	var t_y0 := int(round((y - height * 0.5) / TILE_SIZE))
	var t_h := int(round(height / TILE_SIZE))
	for ty in t_h:
		_wall_layer.set_cell(Vector2i(t_x, t_y0 + ty), TILE_SOURCE, ATLAS_WALL)
	body.set_meta("tile_x", t_x)
	body.set_meta("tile_y0", t_y0)
	body.set_meta("tile_h", t_h)
	add_child(body)
	return body


func _paint_room_number(cx: float, num: int) -> void:
	var lbl := Label.new()
	lbl.text = str(num)
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	lbl.position = Vector2(cx - 16, -ROOM_H * 0.5 + 16)
	lbl.z_index = 3
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)


# --- Player + HUD setup ---

func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(-ROOM_W * 0.25, 0)
	add_child(_player)
	if _player.has_node("EquipmentManager"):
		var em = _player.get_node("EquipmentManager")
		if em.base_stats:
			em.base_stats.move_speed *= 0.25
			em.base_stats.bullet_speed *= 0.25
	if "in_dungeon" in _player:
		_player.in_dungeon = true


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.zoom = Vector2(5.5, 5.5)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_player.add_child(_camera)
	_camera.make_current()


func _setup_hud() -> void:
	_game_hud = SigilHUD.new() if (UIPrefs.use_sigil_hud and not TouchControls.is_mobile()) else GameHUD.new()
	add_child(_game_hud)
	_game_hud.setup(_player)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		_game_hud.set_gold(gm.save_data.gold)

	_inventory_screen = InventoryScreen.new()
	add_child(_inventory_screen)
	_inventory_screen.setup(_player.equipment_manager)

	_loot_ui = LootBagUI.new()
	add_child(_loot_ui)
	_loot_ui.setup(_player.equipment_manager)

	_quest_log = QuestLog.new()
	add_child(_quest_log)


func _setup_prompt_label() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = 24
	panel.offset_bottom = 130
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.88)
	style.border_color = Color(0.6, 0.5, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	_label_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_prompt_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_progress_label)


func _setup_skip_button() -> void:
	_skip_button = Button.new()
	_skip_button.text = "Skip Tutorial"
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.add_theme_font_size_override("font_size", 16)
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.anchor_top = 0.0
	_skip_button.offset_left = -160
	_skip_button.offset_right = -16
	_skip_button.offset_top = 16
	_skip_button.offset_bottom = 48
	_skip_button.pressed.connect(_on_skip_pressed)
	_label_layer.add_child(_skip_button)


func _show_prompt(idx: int) -> void:
	if _prompt_label:
		_prompt_label.text = PROMPTS[idx]
	_progress_label.text = ""


func _set_progress(text: String) -> void:
	if _progress_label:
		_progress_label.text = text


# --- Per-frame tracking + room progression ---

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	# Inventory latch is set inside the room 9 case — no per-frame edge work here.

	# Update current_room from player x position. floor() keeps the player
	# "in" the current room while crossing the corridor — the prompt only
	# flips when they actually enter the next room's tile bounds. round()
	# flipped at the corridor midpoint, which spoiled the last room's prompt.
	var px := _player.global_position.x
	var idx := int(floor((px + ROOM_W * 0.5) / ROOM_GAP))
	idx = clamp(idx, 0, ROOM_COUNT - 1)
	if idx != _current_room:
		_current_room = idx
		_show_prompt(idx)
		_arm_room(idx)

	_update_room_logic(delta)


func _update_room_logic(delta: float) -> void:
	# Top up MP + stamina in the spell room so F/G can always fire, regardless
	# of equipped weapon/class costs.
	if _current_room == 7 and _player:
		if "mp" in _player and "max_mp" in _player:
			_player.mp = _player.max_mp
		if "stamina" in _player and "max_stamina" in _player:
			_player.stamina = _player.max_stamina

	match _current_room:
		0:
			if not _room_completed[0] and _player.global_position.x > -ROOM_W * 0.25:
				_complete_room(0)
		1:
			# Combat: clear the dummies. Auto-pass if armed and no enemies left.
			if not _room_completed[1] and _was_armed(1) and _alive_in_room(1) == 0:
				_complete_room(1)
		2:
			# Dash: rising-edge press counts. Tap, don't hold.
			if not _room_completed[2]:
				if Input.is_action_just_pressed("dash"):
					_dash_taps += 1
				_set_progress("Rolls: %d / 3" % _dash_taps)
				if _dash_taps >= 3:
					_complete_room(2)
		3:
			# Sprint: accumulate time the player is actually sprinting (any path:
			# double-tap WASD or SHIFT-on-empty-weapon both set _is_sprinting).
			if not _room_completed[3]:
				if _player.get("_is_sprinting"):
					_sprint_held += delta
				_set_progress("Sprinting: %.1f / 2.0 s" % _sprint_held)
				if _sprint_held >= 2.0:
					_complete_room(3)
		4:
			# Stone toss: kill the three targets. Player learns by aiming and tossing.
			if not _room_completed[4]:
				if Input.is_action_just_pressed("stone_toss"):
					_stone_throws += 1
				var alive := _alive_in_room(4)
				_set_progress("Targets left: %d   (T tosses, throws made: %d)" % [alive, _stone_throws])
				if _was_armed(4) and alive == 0:
					_complete_room(4)
		5:
			# Shield + parry: timer ticks unconditionally while in the room so
			# the door cannot get stuck. Either survive 5 s OR drop the archer.
			if not _room_completed[5]:
				_shield_timer += delta
				var alive := _alive_in_room(5)
				_set_progress("Hold R to block — %.1f / 5.0 s    Archer left: %d" % [_shield_timer, alive])
				if _shield_timer >= 5.0 or (_was_armed(5) and alive == 0):
					_complete_room(5)
		6:
			# Sneak: detect a C press while in the room. (The old "cross the room"
			# threshold lived past the room-flip point, so the door never opened.)
			if not _room_completed[6]:
				if Input.is_action_just_pressed("sneak_toggle"):
					_sneaked_once = true
				_set_progress("Press C to sneak — %s" % ("done" if _sneaked_once else "waiting"))
				if _sneaked_once:
					_complete_room(6)
		7:
			# Spells: press F and G
			if not _room_completed[7]:
				if Input.is_action_just_pressed("spell_slot_1"):
					_spell_f_pressed = true
				if Input.is_action_just_pressed("spell_slot_2"):
					_spell_g_pressed = true
				_set_progress("F: %s   G: %s" % [
					"DONE" if _spell_f_pressed else "press F",
					"DONE" if _spell_g_pressed else "press G",
				])
				if _spell_f_pressed and _spell_g_pressed:
					_complete_room(7)
		8:
			# Lock-on: count TAB presses (acquire + cycle) and require all enemies dead
			if not _room_completed[8]:
				if Input.is_action_just_pressed("lock_on"):
					_lock_on_presses += 1
				var alive := _alive_in_room(8)
				_set_progress("TAB presses: %d / 2   Targets left: %d" % [_lock_on_presses, alive])
				if _was_armed(8) and _lock_on_presses >= 2 and alive == 0:
					_complete_room(8)
		9:
			# Inventory: latch when the screen opens. Just opening it once counts
			# — the user can close it however they like. Open→close edge detection
			# was unreliable because CanvasLayer.visible doesn't track the panel.
			if not _room_completed[9]:
				if _inventory_screen and _inventory_screen.is_open():
					_inventory_was_open = true
				_set_progress("Press B to open the inventory." if not _inventory_was_open else "Done — door open.")
				if _inventory_was_open:
					_complete_room(9)
		10:
			# Capstone
			if not _room_completed[10] and _was_armed(10) and _alive_in_room(10) == 0:
				_complete_room(10)


func _was_armed(idx: int) -> bool:
	return _armed.get(idx, false)


func _arm_room(idx: int) -> void:
	if _armed.get(idx, false):
		return
	_armed[idx] = true
	match idx:
		1:
			# Three weak skeletons — kill with hold-to-fire
			var cx1: float = ROOM_GAP * 1
			_tag_room(_spawn_dummy(Vector2(cx1 - 30, -15), 6), 1)
			_tag_room(_spawn_dummy(Vector2(cx1, 0), 6), 1)
			_tag_room(_spawn_dummy(Vector2(cx1 + 30, 15), 6), 1)
		4:
			# Three barrel + skeleton pairs. Stone hits barrel → barrel explodes
			# → skeleton in the blast dies. Teaches stone toss AND environmental kills.
			var room_cx: float = ROOM_GAP * 4
			var pairs := [Vector2(0, -28), Vector2(20, 0), Vector2(0, 28)]
			for offset in pairs:
				var enemy := _spawn_dummy(Vector2(room_cx + 50, 0) + offset, 15)
				if enemy:
					enemy.speed = 0.0
					enemy.shoot_interval = 9999.0
					_tag_room(enemy, 4)
				# Barrel sits a few pixels in front of the enemy (toward the player)
				_spawn_barrel(Vector2(room_cx + 35, 0) + offset)
		5:
			# Killable archer — survive timer OR drop it. Low HP since the room
			# is about blocking, not a damage check.
			var atk := _spawn_dummy_from(ARCHER_DEF, Vector2(ROOM_GAP * 5 + 50, 0), 15)
			if atk:
				atk.shoot_interval = 2.0
				atk.speed = 0.0
				_tag_room(atk, 5)
		6:
			# Three harmless guards — slow, don't shoot. Sneak through or kill.
			var cx6: float = ROOM_GAP * 6
			for offset in [Vector2(0, -28), Vector2(20, 0), Vector2(0, 28)]:
				var guard := _spawn_dummy(Vector2(cx6, 0) + offset, 18)
				if guard:
					guard.speed = 6.0
					guard.shoot_interval = 9999.0
					_tag_room(guard, 6)
		7:
			# Spell room — three skeletons to practice F / G casts on.
			# Mana is auto-replenished while you're in this room (see _update_room_logic).
			var cx7: float = ROOM_GAP * 7
			for offset in [Vector2(30, -25), Vector2(40, 0), Vector2(30, 25)]:
				var t := _spawn_dummy(Vector2(cx7, 0) + offset, 20)
				if t:
					t.speed = 0.0
					t.shoot_interval = 9999.0
					_tag_room(t, 7)
		8:
			# Lock-on room — three skeletons in a row so cycling matters.
			var cx8: float = ROOM_GAP * 8
			for offset in [Vector2(40, -25), Vector2(50, 0), Vector2(40, 25)]:
				var t := _spawn_dummy(Vector2(cx8, 0) + offset, 18)
				if t:
					t.speed = 8.0  # slight motion so lock-on feels meaningful
					t.shoot_interval = 9999.0
					_tag_room(t, 8)
		10:
			# Capstone warden — tougher archer plus two skeleton flankers.
			var boss := _spawn_dummy_from(ARCHER_DEF, Vector2(ROOM_GAP * 10 + 20, 0), 120)
			if boss:
				boss.shoot_interval = 1.0
				_tag_room(boss, 10)
			var cx10: float = ROOM_GAP * 10
			for offset in [Vector2(0, -32), Vector2(0, 32)]:
				var flanker := _spawn_dummy(Vector2(cx10 + 35, 0) + offset, 40)
				if flanker:
					flanker.speed = 22.0
					_tag_room(flanker, 10)


func _tag_room(enemy: Node, idx: int) -> void:
	if enemy:
		enemy.set_meta("tutorial_room", idx)


func _spawn_dummy(pos: Vector2, hp_override: int) -> Node:
	return _spawn_dummy_from(SKELETON_DEF, pos, hp_override)


func _alive_in_room(room_idx: int) -> int:
	# Count only enemies tagged with this tutorial room. Leftover skeletons
	# from earlier rooms (e.g. sneak guards the player slipped past) no
	# longer count toward later objectives.
	var n := 0
	for child in _enemy_container.get_children():
		if child.has_meta("tutorial_room") and int(child.get_meta("tutorial_room")) == room_idx:
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				n += 1
	return n


func _spawn_barrel(pos: Vector2) -> Node:
	var barrel := TUTORIAL_BARREL.new()
	barrel.global_position = pos
	add_child(barrel)
	return barrel


func _spawn_dummy_from(def_path: String, pos: Vector2, hp_override: int) -> Node:
	var def := load(def_path) as EnemyDefinition
	if not def:
		return null
	var clone := def.duplicate()
	clone.max_hp = hp_override
	# Strip shield + armor so the HP override actually represents the kill count.
	# Without this, dark_archer's stock 8 shield_hp made it feel invincible.
	clone.shield_hp = 0
	clone.armor = 0
	var enemy = ENEMY_SCENE.instantiate()
	_enemy_container.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(clone)
	return enemy


func _complete_room(idx: int) -> void:
	if _room_completed[idx]:
		return
	_room_completed[idx] = true
	if idx < _doors.size():
		var door := _doors[idx]
		# Clear the wall tiles the door painted, and disable + free the body so
		# the player can never get blocked by a partially-removed door.
		if door.has_meta("tile_x"):
			var t_x: int = door.get_meta("tile_x")
			var t_y0: int = door.get_meta("tile_y0")
			var t_h: int = door.get_meta("tile_h")
			for ty in t_h:
				_wall_layer.erase_cell(Vector2i(t_x, t_y0 + ty))
		door.collision_layer = 0
		door.queue_free()
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("door_open", -2.0)
	_set_progress("Done — door open.")
	if idx + 1 < ROOM_COUNT:
		_arm_room(idx + 1)


func _on_exit_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_finish_tutorial(false)


func _on_skip_pressed() -> void:
	_finish_tutorial(true)


func _finish_tutorial(skipped: bool) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		gm.save_data.tutorial_completed = true
		# Skipped runs go straight to town quietly — no Elder pitch dialogue.
		gm.save_data.tutorial_just_completed = not skipped
		gm.save_data.save_to_slot()
	if skipped:
		print("TutorialDungeon: skipped")
	else:
		print("TutorialDungeon: completed")
	if gm and gm.has_method("return_to_overworld"):
		gm.return_to_overworld()
	else:
		get_tree().change_scene_to_file("res://scenes/overworld/overworld.scn")
