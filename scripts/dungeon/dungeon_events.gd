extends Node

signal blessing_choices_requested(rewards: Array, title: String)
signal merchant_opened(items: Array, grid_pos: Vector2i)

var dm # DungeonManager - untyped to avoid circular dependency

# Cooldowns & flags
var _horde_cooldown: int = 0
var _horde_triggered_this_floor: bool = false
var _merchant_spawned: bool = false
var _blessing_used: bool = false  # mirrors run_state.blessing_used
var _altar_used_rooms: Array[Vector2i] = []
var _rooms_cleared_this_floor: int = 0
var _total_rooms_this_floor: int = 0

# Active buffs: {id, stat, value, original, duration, timer}
var _active_buffs: Array[Dictionary] = []

# Container for event-spawned nodes (interactables, fake chests, etc.)
var _event_container: Node2D

func setup(dungeon_manager) -> void:
	dm = dungeon_manager
	_event_container = Node2D.new()
	_event_container.name = "EventObjects"
	dm.add_child(_event_container)

func _process(delta: float) -> void:
	_tick_timed_buffs(delta)

# ── Main Hook ──────────────────────────────────────────────

func on_room_cleared(grid_pos: Vector2i, room_data: RoomData) -> void:
	_rooms_cleared_this_floor += 1
	_horde_cooldown = maxi(_horde_cooldown - 1, 0)

	# Horde Rush — combat rooms, floor 2+
	if room_data.type == RoomData.RoomType.COMBAT:
		_try_horde(grid_pos)

	# Mimic Chest — treasure rooms
	if room_data.type == RoomData.RoomType.TREASURE:
		_try_mimic(grid_pos)

	# Cursed Altar — combat rooms
	if room_data.type == RoomData.RoomType.COMBAT:
		_try_altar(grid_pos)

	# Blessing Shrine — combat rooms, once per run
	if room_data.type == RoomData.RoomType.COMBAT:
		_try_blessing(grid_pos)

	# Wandering Merchant — once per floor at 50%+ cleared
	_try_merchant()

func on_floor_changed() -> void:
	# Remove floor-duration buffs
	_remove_buffs_by_duration("floor")
	_merchant_spawned = false
	_horde_cooldown = 0
	_horde_triggered_this_floor = false
	_altar_used_rooms.clear()
	_rooms_cleared_this_floor = 0
	_total_rooms_this_floor = dm.run_state.floor_map.size()

	# Clear event objects from previous floor
	for child in _event_container.get_children():
		child.queue_free()

func on_floor_ready(start_grid: Vector2i) -> void:
	_spawn_elder_npc(start_grid)

# ── Event 1: Horde Rush ───────────────────────────────────

func _try_horde(grid_pos: Vector2i) -> void:
	if _horde_cooldown > 0:
		return

	# Guaranteed first horde: if 50%+ rooms cleared and none yet, force it
	var horde_chance = 0.15
	if not _horde_triggered_this_floor and _total_rooms_this_floor > 0:
		var ratio = float(_rooms_cleared_this_floor) / float(_total_rooms_this_floor)
		if ratio >= 0.5:
			horde_chance = 1.0

	if randf() > horde_chance:
		return

	_horde_cooldown = 3
	_horde_triggered_this_floor = true
	print("EVENT: Horde Rush triggered at %s" % str(grid_pos))

	# Flash HUD
	var hud = _get_hud()
	if hud:
		hud.flash_text("HORDE!", Color.RED, 2.0)

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("alarm", -2.0, 0.0)
	# Delayed rumble SFX
	if is_inside_tree():
		get_tree().create_timer(1.0).timeout.connect(func():
			var sfx2 = get_node_or_null("/root/SFXManager")
			if sfx2:
				sfx2.play("impact_a", -6.0, 0.0)
		)

	# Pick a visited room 2 rooms away from current
	var spawn_grid = _find_horde_spawn_room(grid_pos)
	if spawn_grid == Vector2i(-999, -999):
		spawn_grid = grid_pos

	var room_data = dm.run_state.floor_map.get(spawn_grid) as RoomData
	if not room_data:
		return

	# Scale horde size by floor: floor 1 = 3-5, floor 2+ = 5-8
	var count: int
	if dm.run_state.current_floor <= 1:
		count = randi_range(3, 5)
	else:
		count = randi_range(5, 8)
	var positions = dm._get_valid_spawn_positions(spawn_grid, room_data, count)
	var enemy_scene = preload("res://scenes/enemy.tscn")

	var loy_pool = dm._get_loy_enemy_pool()
	var biome_pool = dm.current_biome.enemy_pool if dm.current_biome and dm.current_biome.enemy_pool.size() > 0 else []
	var weak_def = dm._get_weakest_enemy(loy_pool, biome_pool)
	if not weak_def:
		return

	for i in range(mini(count, positions.size())):
		var def = weak_def.duplicate()
		# Scale to current floor
		var floor_num = dm.run_state.current_floor
		var min_dmg = 1 + floor_num
		def.attack_damage = maxi(min_dmg, def.attack_damage)
		def.max_hp = int(def.max_hp * (1.0 + floor_num * 0.1))

		var enemy = enemy_scene.instantiate()
		enemy.global_position = positions[i]
		enemy.setup(def)
		enemy._nav = dm.nav
		enemy.set_meta("grid_pos", spawn_grid)
		# NOT bound to room alive counter — independent bonus kills
		dm.enemy_container.add_child(enemy)

func _find_horde_spawn_room(from: Vector2i) -> Vector2i:
	# BFS to find a visited room ~2 rooms away
	var visited: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	var candidates: Array[Vector2i] = []
	while queue.size() > 0:
		var pos = queue.pop_front()
		var dist = visited[pos]
		if dist >= 2:
			candidates.append(pos)
			continue
		var rd = dm.run_state.floor_map.get(pos) as RoomData
		if not rd:
			continue
		for dir_name in rd.connections:
			var neighbor = rd.connections[dir_name]
			if not visited.has(neighbor):
				var state = dm.room_states.get(neighbor)
				if state and state["visited"]:
					visited[neighbor] = dist + 1
					queue.append(neighbor)
	if candidates.size() > 0:
		return candidates[randi() % candidates.size()]
	return Vector2i(-999, -999)

# ── Event 2: Mimic Chest ──────────────────────────────────

func _try_mimic(grid_pos: Vector2i) -> void:
	if randf() > 0.20:
		return

	print("EVENT: Mimic Chest triggered at %s" % str(grid_pos))

	var center = dm._grid_to_world_center(grid_pos)

	# Create fake chest Area2D
	var fake_chest = Area2D.new()
	fake_chest.collision_layer = 0
	fake_chest.collision_mask = 1
	fake_chest.position = center
	fake_chest.name = "MimicChest"

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	fake_chest.add_child(shape)

	# Sprite: use barrel/chest decoration from dungeon features (source 1, row 0)
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/lofi_dungeon_features.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(8 * 3, 0, 8, 8)  # chest-like decoration
	fake_chest.add_child(sprite)

	fake_chest.body_entered.connect(_on_mimic_triggered.bind(fake_chest, grid_pos))
	_event_container.add_child(fake_chest)

func _on_mimic_triggered(body: Node2D, fake_chest: Area2D, grid_pos: Vector2i) -> void:
	if not body.is_in_group("player"):
		return
	if not is_instance_valid(fake_chest):
		return

	# Remove fake chest
	fake_chest.queue_free()

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("alarm", -2.0, 0.0)

	var hud = _get_hud()
	if hud:
		hud.flash_text("MIMIC!", Color.ORANGE, 1.5)

	# Spawn mimic: strongest enemy from pool, 3x HP, gold tint, CHARGE attack
	var loy_pool = dm._get_loy_enemy_pool()
	var biome_pool = dm.current_biome.enemy_pool if dm.current_biome and dm.current_biome.enemy_pool.size() > 0 else []

	var strongest: EnemyDefinition = null
	for entry in loy_pool:
		var def = dm._load_enemy_by_name(str(entry.get("type", "")))
		if def and (not strongest or def.max_hp > strongest.max_hp):
			strongest = def
	if not strongest:
		for def in biome_pool:
			if not strongest or def.max_hp > strongest.max_hp:
				strongest = def
	if not strongest:
		return

	var def = strongest.duplicate()
	def.max_hp *= 3
	def.move_speed *= 1.5
	def.attack_type = EnemyDefinition.AttackType.CHARGE
	def.sprite_color = Color.GOLD
	def.enemy_name = "Mimic " + def.enemy_name

	var floor_num = dm.run_state.current_floor
	def.attack_damage = maxi(2 + floor_num, def.attack_damage)

	var center = dm._grid_to_world_center(grid_pos)
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = center
	enemy.setup(def)
	enemy._nav = dm.nav
	enemy.set_meta("grid_pos", grid_pos)
	# On mimic death → spawn real chest loot
	enemy.tree_exited.connect(_on_mimic_killed.bind(grid_pos))
	dm.enemy_container.add_child(enemy)

func _on_mimic_killed(grid_pos: Vector2i) -> void:
	# Deferred so the enemy is fully removed first
	dm.call_deferred("_spawn_chest_loot", grid_pos)

# ── Event 3: Cursed Altar ─────────────────────────────────

func _try_altar(grid_pos: Vector2i) -> void:
	if grid_pos in _altar_used_rooms:
		return
	var altar_chance = 0.08 + 0.06 * maxf(0, 3 - dm.run_state.current_floor)
	if randf() > altar_chance:
		return

	print("EVENT: Cursed Altar spawned at %s" % str(grid_pos))

	var center = dm._grid_to_world_center(grid_pos)

	var altar = Area2D.new()
	altar.collision_layer = 0
	altar.collision_mask = 1
	altar.position = center + Vector2(0, 16)  # offset from room center
	altar.name = "CursedAltar"

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	altar.add_child(shape)

	# Sprite: use decoration tile (source 1, pillar/altar look)
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/lofi_dungeon_features.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(8 * 4, 8 * 2, 8, 8)  # stone pillar/altar
	sprite.modulate = Color(0.8, 0.4, 1.0)  # purple tint
	altar.add_child(sprite)

	# Prompt label
	var prompt = Label.new()
	prompt.text = "Pray"
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-12, -14)
	prompt.visible = false
	altar.add_child(prompt)
	altar.set_meta("prompt_label", prompt)
	altar.set_meta("altar_grid_pos", grid_pos)

	altar.body_entered.connect(_on_altar_body_entered.bind(altar))
	altar.body_exited.connect(_on_altar_body_exited.bind(altar))
	_event_container.add_child(altar)

	# Register with DungeonManager's interact system
	dm._nearby_interact_areas  # ensure it exists
	altar.set_meta("event_type", "altar")

func _on_altar_body_entered(body: Node2D, altar: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = altar.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = true
	if not altar in dm._nearby_interact_areas:
		dm._nearby_interact_areas.append(altar)
	if TouchControls.is_mobile():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.show_interact_button("Pray")

func _on_altar_body_exited(body: Node2D, altar: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = altar.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = false
	dm._nearby_interact_areas.erase(altar)
	if TouchControls.is_mobile() and dm._nearby_interact_areas.is_empty():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.hide_interact_button()

func try_interact(area: Area2D) -> bool:
	var event_type = area.get_meta("event_type", "")
	match event_type:
		"altar":
			_use_altar(area)
			return true
		"blessing":
			_use_blessing(area)
			return true
		"merchant":
			_use_merchant(area)
			return true
		"elder_npc":
			_use_elder_npc(area)
			return true
		"trap_lever":
			_toggle_trap_lever(area)
			return true
	return false

func _use_altar(altar: Area2D) -> void:
	var grid_pos = altar.get_meta("altar_grid_pos") as Vector2i
	_altar_used_rooms.append(grid_pos)

	var cost = 15 + dm.run_state.current_floor * 5
	var gm = get_node_or_null("/root/GameManager")
	var gold = gm.save_data.gold if gm and gm.save_data else dm.run_state.run_gold
	var hud = _get_hud()

	if gold < cost:
		if hud:
			hud.flash_text("Not enough gold! (%d)" % cost, Color.GRAY, 1.5)
		return

	# Deduct gold
	if gm and gm.save_data:
		gm.save_data.gold -= cost
		gm.gold_changed.emit(gm.save_data.gold)
	else:
		dm.run_state.run_gold -= cost

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("magic_a", -2.0, 0.0)

	# Disable altar
	dm._nearby_interact_areas.erase(altar)
	altar.queue_free()

	# 60% buff, 40% debuff
	if randf() < 0.6:
		_apply_altar_buff()
	else:
		_apply_altar_debuff()

func _apply_altar_buff() -> void:
	var buffs = [
		{id = "altar_damage", stat = "damage_mult", value = 0.3, label = "+30% Damage"},
		{id = "altar_speed", stat = "move_speed", value = 0.25, label = "+25% Speed"},
		{id = "altar_hp", stat = "max_hp", value = 0.2, label = "+20% Max HP"},
	]
	var pick = buffs[randi() % buffs.size()]
	_apply_buff(pick["id"], pick["stat"], pick["value"], "floor")

	var hud = _get_hud()
	if hud:
		hud.flash_text("Blessed: " + pick["label"], Color.GREEN, 2.0)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx and dm.player:
		vfx.level_up_burst(dm.player.global_position)

func _apply_altar_debuff() -> void:
	var debuffs = [
		{id = "altar_slow", stat = "move_speed", value = -0.25, label = "-25% Speed", timer = 90.0},
		{id = "altar_weak", stat = "damage_mult", value = -0.3, label = "-30% Damage", timer = 90.0},
		{id = "altar_poison", stat = "poison_tick", value = 1.0, label = "Poison Tick", timer = 90.0},
	]
	var pick = debuffs[randi() % debuffs.size()]

	if pick["stat"] == "poison_tick":
		_active_buffs.append({
			"id": pick["id"], "stat": "poison_tick", "value": pick["value"],
			"original": 0.0, "duration": "timed", "timer": pick["timer"],
			"poison_timer": 0.0,
		})
		# Apply purple tint
		if dm.player:
			dm.player.modulate = dm.player.modulate.lerp(Color(0.7, 0.3, 1.0), 0.4)
	else:
		_apply_buff(pick["id"], pick["stat"], pick["value"], "timed", pick["timer"])

	var hud = _get_hud()
	if hud:
		hud.flash_text("Cursed: " + pick["label"], Color(0.8, 0.3, 1.0), 2.0)

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("debuff", -2.0, 0.0)

# ── Event 4: Wandering Merchant ───────────────────────────

func _try_merchant() -> void:
	if _merchant_spawned:
		return
	if _total_rooms_this_floor <= 0:
		return
	var ratio = float(_rooms_cleared_this_floor) / float(_total_rooms_this_floor)
	if ratio < 0.7:
		return
	# 30% chance per room clear after 70% threshold
	if randf() > 0.30:
		return

	_merchant_spawned = true
	print("EVENT: Wandering Merchant spawned!")

	# Pick a random cleared combat room (not current)
	var candidates: Array[Vector2i] = []
	for gp in dm.room_states:
		if gp == dm.run_state.current_grid_pos:
			continue
		var st = dm.room_states[gp]
		if st["cleared"]:
			var rd = dm.run_state.floor_map.get(gp) as RoomData
			if rd and rd.type == RoomData.RoomType.COMBAT:
				candidates.append(gp)

	if candidates.size() == 0:
		return

	var merchant_grid = candidates[randi() % candidates.size()]
	var center = dm._grid_to_world_center(merchant_grid)

	var merchant = Area2D.new()
	merchant.collision_layer = 0
	merchant.collision_mask = 1
	merchant.position = center + Vector2(8, 0)
	merchant.name = "WanderingMerchant"

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	merchant.add_child(shape)

	# Sprite: LoY char tile 48 = shopkeeper (chars.png, 16x16 grid, 32x32 px each)
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/loy/chars.png")
	sprite.region_enabled = true
	var col = 48 % 16
	var row = 48 / 16
	sprite.region_rect = Rect2(col * 32, row * 32, 32, 32)
	sprite.scale = Vector2(0.25, 0.25)  # scale down to dungeon tile size
	merchant.add_child(sprite)

	# Prompt
	var prompt = Label.new()
	prompt.text = "Shop"
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color.YELLOW)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-12, -14)
	prompt.visible = false
	merchant.add_child(prompt)
	merchant.set_meta("prompt_label", prompt)
	merchant.set_meta("event_type", "merchant")
	merchant.set_meta("merchant_grid", merchant_grid)

	merchant.body_entered.connect(_on_merchant_body_entered.bind(merchant))
	merchant.body_exited.connect(_on_merchant_body_exited.bind(merchant))
	_event_container.add_child(merchant)

	# Notify HUD
	var hud = _get_hud()
	if hud:
		hud.flash_text("A Merchant has appeared!", Color.YELLOW, 2.0)

func _on_merchant_body_entered(body: Node2D, merchant: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = merchant.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = true
	if not merchant in dm._nearby_interact_areas:
		dm._nearby_interact_areas.append(merchant)
	if TouchControls.is_mobile():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.show_interact_button("Shop")

func _on_merchant_body_exited(body: Node2D, merchant: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = merchant.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = false
	dm._nearby_interact_areas.erase(merchant)
	if TouchControls.is_mobile() and dm._nearby_interact_areas.is_empty():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.hide_interact_button()

const MERCHANT_COST = 500
const MERCHANT_DURATION = 20.0

func _use_merchant(merchant: Area2D) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return

	# Check gold
	if not gm.has_method("spend_gold") or not gm.spend_gold(MERCHANT_COST):
		var hud = _get_hud()
		if hud:
			hud.flash_text("Need %d gold!" % MERCHANT_COST, Color(1.0, 0.4, 0.4), 1.5)
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("click", -4.0, 0.0)
		return

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("select_b", -3.0, 0.0)

	# Generate 3-5 random items at floor level
	var item_pool = ItemPool.new()
	var bd = dm.current_biome.base_difficulty if dm.current_biome else 0
	var item_count = randi_range(3, 5)
	var items = item_pool.get_random_items(item_count, dm.run_state.current_floor, bd)

	var grid_pos = merchant.get_meta("merchant_grid", Vector2i.ZERO) as Vector2i
	merchant_opened.emit(items, grid_pos)

	# Merchant disappears after 20 seconds
	var timer = get_tree().create_timer(MERCHANT_DURATION)
	timer.timeout.connect(func():
		if is_instance_valid(merchant):
			dm._nearby_interact_areas.erase(merchant)
			merchant.queue_free()
	)

# ── Event 5: Blessing Shrine ──────────────────────────────

func _try_blessing(grid_pos: Vector2i) -> void:
	if dm.run_state.blessing_used:
		return
	var blessing_chance = 0.10 + 0.08 * maxf(0, 3 - dm.run_state.current_floor)
	if randf() > blessing_chance:
		return

	print("EVENT: Blessing Shrine spawned at %s" % str(grid_pos))

	var center = dm._grid_to_world_center(grid_pos)

	var shrine = Area2D.new()
	shrine.collision_layer = 0
	shrine.collision_mask = 1
	shrine.position = center + Vector2(0, -16)
	shrine.name = "BlessingShrine"

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	shrine.add_child(shape)

	# Sprite: orb/shrine decoration
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/lofi_dungeon_features.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(8 * 5, 8 * 2, 8, 8)  # glowing orb/gem
	sprite.modulate = Color(0.4, 1.0, 0.6)  # green tint
	shrine.add_child(sprite)

	# Prompt
	var prompt = Label.new()
	prompt.text = "Bless"
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-12, -14)
	prompt.visible = false
	shrine.add_child(prompt)
	shrine.set_meta("prompt_label", prompt)
	shrine.set_meta("event_type", "blessing")
	shrine.set_meta("blessing_grid_pos", grid_pos)

	shrine.body_entered.connect(_on_shrine_body_entered.bind(shrine))
	shrine.body_exited.connect(_on_shrine_body_exited.bind(shrine))
	_event_container.add_child(shrine)

func _on_shrine_body_entered(body: Node2D, shrine: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = shrine.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = true
	if not shrine in dm._nearby_interact_areas:
		dm._nearby_interact_areas.append(shrine)
	if TouchControls.is_mobile():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.show_interact_button("Bless")

func _on_shrine_body_exited(body: Node2D, shrine: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = shrine.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = false
	dm._nearby_interact_areas.erase(shrine)
	if TouchControls.is_mobile() and dm._nearby_interact_areas.is_empty():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.hide_interact_button()

func _use_blessing(shrine: Area2D) -> void:
	dm.run_state.blessing_used = true
	dm._nearby_interact_areas.erase(shrine)
	shrine.queue_free()

	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("heal_a", -2.0, 0.0)

	# Emit signal so dungeon_scene shows RewardScreen with 3 blessing choices
	var blessings: Array[Dictionary] = []
	var all_blessings = [
		{"type": "blessing", "id": "swift", "label": "Swift", "desc": "+30% Move Speed", "stat": "move_speed", "value": 0.3, "duration": "floor"},
		{"type": "blessing", "id": "mighty", "label": "Mighty", "desc": "+40% Damage", "stat": "damage_mult", "value": 0.4, "duration": "floor"},
		{"type": "blessing", "id": "fortified", "label": "Fortified", "desc": "+25% Max HP", "stat": "max_hp", "value": 0.25, "duration": "permanent"},
		{"type": "blessing", "id": "regeneration", "label": "Regeneration", "desc": "+2 HP/sec", "stat": "regen", "value": 2.0, "duration": "floor"},
		{"type": "blessing", "id": "lucky", "label": "Lucky", "desc": "+50% Gold Drops", "stat": "gold_mult", "value": 0.5, "duration": "floor"},
	]
	all_blessings.shuffle()
	for i in range(mini(3, all_blessings.size())):
		blessings.append(all_blessings[i])

	blessing_choices_requested.emit(blessings, "Shrine Blessing")

func apply_blessing(blessing: Dictionary) -> void:
	var bid = str(blessing.get("id", ""))
	var stat = str(blessing.get("stat", ""))
	var value = float(blessing.get("value", 0))
	var duration = str(blessing.get("duration", "floor"))

	_apply_buff(bid, stat, value, duration)

	var hud = _get_hud()
	if hud:
		hud.flash_text(str(blessing.get("label", "Blessed")) + "!", Color(0.4, 1.0, 0.6), 2.0)

	var vfx = get_node_or_null("/root/VFXManager")
	if vfx and dm.player:
		vfx.level_up_burst(dm.player.global_position)

# ── Event 6: Elder NPC ────────────────────────────────────

func _spawn_elder_npc(start_grid: Vector2i) -> void:
	var center = dm._grid_to_world_center(start_grid)

	var elder = Area2D.new()
	elder.collision_layer = 0
	elder.collision_mask = 1
	elder.position = center + Vector2(12, -8)
	elder.name = "ElderNPC"

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	elder.add_child(shape)

	# Sprite: LoY chars.png tile 16 (elder/grey robed figure)
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/loy/chars.png")
	sprite.region_enabled = true
	var col = 16 % 16
	var row = 16 / 16
	sprite.region_rect = Rect2(col * 32, row * 32, 32, 32)
	sprite.scale = Vector2(0.25, 0.25)
	elder.add_child(sprite)

	# Prompt
	var prompt = Label.new()
	prompt.text = "Talk"
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-12, -14)
	prompt.visible = false
	elder.add_child(prompt)
	elder.set_meta("prompt_label", prompt)
	elder.set_meta("event_type", "elder_npc")

	elder.body_entered.connect(_on_elder_body_entered.bind(elder))
	elder.body_exited.connect(_on_elder_body_exited.bind(elder))
	_event_container.add_child(elder)

func _on_elder_body_entered(body: Node2D, elder: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = elder.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = true
	if not elder in dm._nearby_interact_areas:
		dm._nearby_interact_areas.append(elder)
	if TouchControls.is_mobile():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.show_interact_button("Talk")

func _on_elder_body_exited(body: Node2D, elder: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var prompt = elder.get_meta("prompt_label") as Label
	if prompt:
		prompt.visible = false
	dm._nearby_interact_areas.erase(elder)
	if TouchControls.is_mobile() and dm._nearby_interact_areas.is_empty():
		var tc = get_tree().get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.hide_interact_button()

var _philosopher_quotes: Array[String] = [
	"The creatures you fight are shadows of something you cannot see.",
	"Doubt everything. What survives your questioning is worth keeping.",
	"You descend deeper. Each step changes you — not just your position, but your nature.",
	"Every creature here is a mirror. What does it reflect about you?",
	"Act only by rules you'd want every adventurer to follow.",
	"The wound is where understanding enters.",
	"Courage is not fearlessness. It is the balance between cowardice and recklessness.",
]

func _use_elder_npc(_elder: Area2D) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("select_b", -3.0, 0.0)

	var dialogue := ""
	# 30% chance for a philosopher quote
	if randf() < 0.3 and _philosopher_quotes.size() > 0:
		var quote = _philosopher_quotes[randi() % _philosopher_quotes.size()]
		dialogue = "Old words carved on the wall read: \"%s\"" % quote
	else:
		var floor_num = dm.run_state.current_floor
		match floor_num:
			1:
				dialogue = "Be careful adventurer. These crypts grow more dangerous the deeper you go. Clear each room to proceed."
			2:
				dialogue = "The creatures here spit venom. Watch for poison and stay on the move."
			3:
				dialogue = "These catacombs hold the most dangerous undead. Mummies and vampires lurk below. Steel yourself."
			_:
				dialogue = "You've ventured deep. May the light guide your path, adventurer."

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.show_dialogue_requested.emit("Elder", dialogue, [])

# ── Trap Lever ────────────────────────────────────────────

func _toggle_trap_lever(area: Area2D) -> void:
	if area.has_method("toggle"):
		area.toggle()
	var hud = _get_hud()
	if hud:
		hud.flash_text("Lever toggled!", Color(0.8, 0.7, 0.3), 1.0)

# ── Buff/Debuff System ────────────────────────────────────

func _apply_buff(id: String, stat: String, value: float, duration: String, timer: float = -1.0) -> void:
	var player = dm.player
	if not player:
		return

	var original: float = 0.0
	var em = player.equipment_manager if player.has_method("get") or "equipment_manager" in player else null
	if not em:
		# Try direct access
		if "equipment_manager" in player:
			em = player.equipment_manager

	match stat:
		"damage_mult":
			original = em.base_stats.damage_mult if em else 1.0
			if em:
				em.base_stats.damage_mult += value
				em.stats_changed.emit()
		"move_speed":
			original = em.base_stats.move_speed if em else 100.0
			if em:
				em.base_stats.move_speed *= (1.0 + value)
				em.stats_changed.emit()
		"max_hp":
			original = float(player.max_hp)
			var bonus = int(original * value)
			player.max_hp += bonus
			player.hp += bonus
			player.hp_changed.emit(player.hp)
		"regen":
			original = 0.0  # no baseline regen
		"gold_mult":
			original = 0.0  # handled in gold pickup logic

	var buff = {
		"id": id, "stat": stat, "value": value, "original": original,
		"duration": duration, "timer": timer,
	}
	_active_buffs.append(buff)

	# Visual tint
	if player:
		if value > 0:
			player.modulate = player.modulate.lerp(Color(0.5, 1.0, 0.5), 0.3)
		elif value < 0:
			player.modulate = player.modulate.lerp(Color(0.7, 0.3, 1.0), 0.3)

func _remove_buff(buff: Dictionary) -> void:
	var player = dm.player
	if not player:
		return

	var em = null
	if "equipment_manager" in player:
		em = player.equipment_manager

	match buff["stat"]:
		"damage_mult":
			if em:
				em.base_stats.damage_mult -= buff["value"]
				em.stats_changed.emit()
		"move_speed":
			if em:
				em.base_stats.move_speed /= (1.0 + buff["value"])
				em.stats_changed.emit()
		"max_hp":
			if buff["duration"] != "permanent":
				var bonus = int(buff["original"] * buff["value"])
				player.max_hp -= bonus
				player.hp = mini(player.hp, player.max_hp)
				player.hp_changed.emit(player.hp)
		"regen", "gold_mult", "poison_tick":
			pass  # No stat to restore

	_active_buffs.erase(buff)

	# Reset tint if no more buffs
	if _active_buffs.size() == 0 and player:
		player.modulate = Color.WHITE

func _remove_buffs_by_duration(duration: String) -> void:
	var to_remove: Array[Dictionary] = []
	for buff in _active_buffs:
		if buff["duration"] == duration:
			to_remove.append(buff)
	for buff in to_remove:
		_remove_buff(buff)

func _tick_timed_buffs(delta: float) -> void:
	var to_remove: Array[Dictionary] = []
	for buff in _active_buffs:
		if buff["duration"] == "timed" and buff["timer"] > 0:
			buff["timer"] -= delta
			if buff["timer"] <= 0:
				to_remove.append(buff)

		# Poison tick
		if buff["stat"] == "poison_tick":
			buff["poison_timer"] = buff.get("poison_timer", 0.0) + delta
			if buff["poison_timer"] >= 3.0:
				buff["poison_timer"] -= 3.0
				if dm.player and dm.player.hp > 1:
					dm.player.hp -= 1
					dm.player.hp_changed.emit(dm.player.hp)

		# Regen tick
		if buff["stat"] == "regen":
			buff["regen_timer"] = buff.get("regen_timer", 0.0) + delta
			if buff["regen_timer"] >= 1.0:
				buff["regen_timer"] -= 1.0
				if dm.player and dm.player.hp < dm.player.max_hp:
					var heal = int(buff["value"])
					dm.player.hp = mini(dm.player.hp + heal, dm.player.max_hp)
					dm.player.hp_changed.emit(dm.player.hp)

	for buff in to_remove:
		_remove_buff(buff)

# ── Helpers ────────────────────────────────────────────────

func _get_hud() -> GameHUD:
	var scene = dm.get_parent()
	if scene and "game_hud" in scene:
		return scene.game_hud
	return null

func get_gold_mult() -> float:
	var mult = 1.0
	for buff in _active_buffs:
		if buff["stat"] == "gold_mult":
			mult += buff["value"]
	return mult
