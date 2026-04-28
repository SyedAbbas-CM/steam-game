class_name BattleRenderer
extends Node2D

# Mixed_Units.png: 983x1040, 80x80 cells
# Columns: 0=Inf, 1=HeavyInf, 2=Cav, 3=HeavyCav, 4=Archer, 5=Mage, 6=GiantInf, 7=GiantCav, 8=RangedInf, 9=Spear, 10=HorseArcher
# Row 4 = red (enemy), Row 11 = blue (player)
const CELL_SIZE := 80.0
const COLS := 9  # 9 unit types
const FACTION_ROWS := { 0: 4, 1: 11 }  # RED=row4, BLUE=row11
# UnitType index → spritesheet column
const SPRITE_COL := [0, 1, 2, 3, 4, 5, 9, 10, 8]
#                    INF HINF CAV HCAV ARCH MAGE SPEAR HARC RINF
const PROJECTILE_RADIUS := 4.0
const HP_BAR_HEIGHT := 3.0
const HP_BAR_OFFSET := 5.0

var atlas_texture: Texture2D
var units: BattleUnitSystem
var projectiles: BattleProjectileSystem
var world_size: Vector2
var selected_units: PackedInt32Array = PackedInt32Array()
var fog: BattleFogOfWar  # Set by battle_arena to hide fogged enemies
var cam: Camera2D  # For viewport culling

# Sprite2D pool for units (no ColorRect HP bars — drawn in _draw() for perf)
var _unit_sprites: Array[Sprite2D] = []
var _atlas_textures: Array[AtlasTexture] = []  # prebuilt per (faction, type) combo

func _ready() -> void:
	atlas_texture = preload("res://assets/sprites/Mixed_Units.png")
	_prebuild_atlas_textures()

func _prebuild_atlas_textures() -> void:
	# Build AtlasTexture for each (faction, unit_type) combo using SPRITE_COL mapping
	# Index = faction * COLS + unit_type
	_atlas_textures.resize(2 * COLS)
	for fac in [0, 1]:
		var row: int = FACTION_ROWS[fac]
		for type_idx in range(COLS):
			var at := AtlasTexture.new()
			at.atlas = atlas_texture
			var sheet_col: int = SPRITE_COL[type_idx]
			at.region = Rect2(sheet_col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			_atlas_textures[fac * COLS + type_idx] = at

func initialize(unit_system: BattleUnitSystem, proj_system: BattleProjectileSystem) -> void:
	units = unit_system
	projectiles = proj_system

func ensure_sprite_pool(count: int) -> void:
	# Grow pool if needed — sprites only, HP bars drawn in _draw()
	while _unit_sprites.size() < count:
		var spr := Sprite2D.new()
		spr.visible = false
		add_child(spr)
		_unit_sprites.append(spr)

var _view_rect: Rect2 = Rect2()  # Cached viewport rect in world coords

func _compute_view_rect() -> Rect2:
	if not cam or not is_instance_valid(cam):
		return Rect2(-1e9, -1e9, 2e9, 2e9)  # No culling
	var vp_size := get_viewport_rect().size
	var half_w := vp_size.x / (2.0 * cam.zoom.x)
	var half_h := vp_size.y / (2.0 * cam.zoom.y)
	var center := cam.global_position
	# Add margin so units near edges aren't popped
	var margin := 100.0
	return Rect2(center.x - half_w - margin, center.y - half_h - margin,
				(half_w + margin) * 2.0, (half_h + margin) * 2.0)

func update_visuals() -> void:
	if not units:
		return

	ensure_sprite_pool(units.count)
	_view_rect = _compute_view_rect()

	for i in units.count:
		var spr := _unit_sprites[i]

		if units.alive[i] == 0:
			spr.visible = false
			continue

		# Viewport culling — skip off-screen units
		if not _view_rect.has_point(Vector2(units.x[i], units.y[i])):
			spr.visible = false
			continue

		# Fog of war: hide enemy units in fogged areas
		if fog and fog.enabled and units.faction[i] == BattleUnitSystem.Faction.RED:
			if not fog.is_cell_visible(units.x[i], units.y[i]):
				spr.visible = false
				continue

		spr.visible = true
		spr.position = Vector2(units.x[i], units.y[i])

		var tex_idx := units.faction[i] * COLS + units.unit_type[i]
		if spr.texture != _atlas_textures[tex_idx]:
			spr.texture = _atlas_textures[tex_idx]

		var display_size := units.radius[i] * 2.5
		var tex_scale := display_size / CELL_SIZE
		spr.scale = Vector2(tex_scale, tex_scale)

		var mod := Color.WHITE
		if units.scatter_time[i] > 0.0:
			# Rapid white flash for scattered/panicked units
			var flash := sin(units.scatter_time[i] * 20.0) * 0.5 + 0.5
			mod = Color(1.0, 1.0, 1.0, 0.5 + flash * 0.5)
		elif units.stagger_time[i] > 0.0:
			mod = Color(1.0, 0.85, 0.85, 0.9)  # Slight red tint + minor fade
		if units.morale[i] < 20.0:
			mod = Color(1.0, 0.7, 0.7, mod.a)
		if units.burn_time[i] > 0.0:
			mod = Color(1.0, 0.5, 0.2, mod.a)
		if units.ability_active[i] == 1:
			mod = Color(mod.r * 1.2, mod.g * 1.2, mod.b * 1.4, mod.a)
		spr.modulate = mod

	for i in range(units.count, _unit_sprites.size()):
		_unit_sprites[i].visible = false

	queue_redraw()

func _draw() -> void:
	# Draw HP bars, commander rings, veteran pips — only for visible (on-screen, alive) units
	if units:
		for i in units.count:
			if units.alive[i] == 0:
				continue
			# Viewport culling
			var upos := Vector2(units.x[i], units.y[i])
			if not _view_rect.has_point(upos):
				continue
			# Skip fogged enemies
			if fog and fog.enabled and units.faction[i] == BattleUnitSystem.Faction.RED:
				if not fog.is_cell_visible(units.x[i], units.y[i]):
					continue
			var display_size := units.radius[i] * 2.5

			# Commander crown visual
			if units.is_commander[i] == 1:
				var ring_r := display_size * 0.55
				draw_arc(upos, ring_r, 0, TAU, 20, Color(1.0, 0.85, 0.2, 0.9), 2.5)
				# Crown: 3 triangular points above the unit
				var crown_y := upos.y - display_size * 0.6
				var crown_w := display_size * 0.4
				var crown_h := display_size * 0.25
				var crown_color := Color(1.0, 0.85, 0.2, 0.95)
				# Crown base
				draw_line(Vector2(upos.x - crown_w, crown_y), Vector2(upos.x + crown_w, crown_y), crown_color, 2.0)
				# Three spikes
				for spike: int in [-1, 0, 1]:
					var sx: float = upos.x + float(spike) * crown_w * 0.7
					draw_line(Vector2(sx, crown_y), Vector2(sx, crown_y - crown_h), crown_color, 2.0)
					# Gem on tip
					draw_circle(Vector2(sx, crown_y - crown_h), 2.0, crown_color)

			# Veteran pips (1-3 small dots above unit)
			var vet := units.veteran_rank[i]
			if vet > 0:
				var pip_y := units.y[i] - display_size * 0.5 - HP_BAR_OFFSET - 5.0
				var pip_count := mini(vet, 3)
				var pip_start_x := units.x[i] - float(pip_count - 1) * 3.0
				var pip_color := Color(1.0, 1.0, 0.3) if vet >= 3 else Color(0.8, 0.8, 0.8)
				for p in pip_count:
					draw_circle(Vector2(pip_start_x + p * 6.0, pip_y), 2.0, pip_color)

			# HP bar
			var bar_w := display_size * 0.8
			var bar_x := units.x[i] - bar_w * 0.5
			var bar_y := units.y[i] - display_size * 0.5 - HP_BAR_OFFSET
			var hp_ratio := units.hp[i] / units.max_hp[i]
			draw_rect(Rect2(bar_x, bar_y, bar_w, HP_BAR_HEIGHT), Color(0.2, 0.2, 0.2))
			var bar_color: Color
			if hp_ratio < 0.3:
				bar_color = Color.RED
			elif hp_ratio < 0.6:
				bar_color = Color.YELLOW
			else:
				bar_color = Color.GREEN
			draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, HP_BAR_HEIGHT), bar_color)

		# Draw selection rings
		for idx in selected_units:
			if idx < units.count and units.alive[idx] == 1:
				var r := units.radius[idx] * 1.5
				var pos := Vector2(units.x[idx], units.y[idx])
				draw_arc(pos, r, 0, TAU, 24, Color(0.3, 1.0, 0.3, 0.9), 2.0)

	# Draw projectiles
	if not projectiles:
		return
	for i in projectiles.count:
		if projectiles.alive[i] == 0:
			continue
		var pos := Vector2(projectiles.x[i], projectiles.y[i])
		if projectiles.is_splash[i] == 1:
			# Fireball: larger, orange glow
			var glow_color := Color(1.0, 0.5, 0.1, 0.7)
			draw_circle(pos, PROJECTILE_RADIUS * 2.5, glow_color)
			draw_circle(pos, PROJECTILE_RADIUS * 1.5, Color(1.0, 0.8, 0.2))
		else:
			var color := Color(0.3, 0.6, 1.0) if projectiles.proj_faction[i] == BattleUnitSystem.Faction.BLUE else Color(1.0, 0.4, 0.3)
			draw_circle(pos, PROJECTILE_RADIUS, color)
