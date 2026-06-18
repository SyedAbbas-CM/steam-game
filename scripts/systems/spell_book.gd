class_name SpellBook
extends Node

var learned_spells: Array[SpellDefinition] = []
const MAX_SPELL_SLOTS = 10  # unified action bar: any of slots 0..9 (hotkeys 1..0) can hold a spell
var spell_slots: Array = [null, null, null, null, null, null, null, null, null, null]  # SpellDefinition or null
var slot_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

signal spell_learned(spell: SpellDefinition)
signal spell_equipped(slot: int, spell: SpellDefinition)
signal spell_unequipped(slot: int)
signal spell_cast(slot: int, spell: SpellDefinition)

# Spells granted by equipment (removed on unequip unless permanently learned)
var equipment_spells: Array[String] = []

func learn_spell(spell: SpellDefinition) -> void:
	# Don't learn duplicates
	for s in learned_spells:
		if s.id == spell.id:
			return
	learned_spells.append(spell)
	spell_learned.emit(spell)

func has_spell(spell_id: String) -> bool:
	for s in learned_spells:
		if s.id == spell_id:
			return true
	return false

func equip_spell(spell: SpellDefinition, slot: int) -> void:
	if slot < 0 or slot >= MAX_SPELL_SLOTS:
		return
	# Remove from any other slot first
	for i in range(MAX_SPELL_SLOTS):
		if spell_slots[i] and spell_slots[i].id == spell.id:
			spell_slots[i] = null
			spell_unequipped.emit(i)
	spell_slots[slot] = spell
	spell_equipped.emit(slot, spell)

func unequip_spell(slot: int) -> void:
	if slot < 0 or slot >= MAX_SPELL_SLOTS:
		return
	spell_slots[slot] = null
	spell_unequipped.emit(slot)

func can_cast(slot: int, player_mp: float) -> bool:
	if slot < 0 or slot >= MAX_SPELL_SLOTS:
		return false
	var spell = spell_slots[slot] as SpellDefinition
	if not spell:
		return false
	if slot_cooldowns[slot] > 0:
		return false
	if player_mp < spell.mp_cost:
		return false
	return true

## Spirit thresholds for spell slots (like DS2 attunement)
const SPIRIT_THRESHOLDS: Array[int] = [0, 2, 5, 8, 12, 16]

func get_max_slots(_level: int, spirit: int) -> int:
	var slots = 0
	for threshold in SPIRIT_THRESHOLDS:
		if spirit >= threshold:
			slots += 1
		else:
			break
	return slots

func tick_cooldowns(delta: float) -> void:
	for i in range(MAX_SPELL_SLOTS):
		if slot_cooldowns[i] > 0:
			slot_cooldowns[i] = maxf(slot_cooldowns[i] - delta, 0.0)

func cast_spell(slot: int, player: CharacterBody2D, aim_dir: Vector2) -> void:
	var spell = spell_slots[slot] as SpellDefinition
	if not spell:
		return

	spell_cast.emit(slot, spell)

	# SFX based on delivery type
	var sfx = player.get_node_or_null("/root/SFXManager")
	if sfx:
		match spell.delivery:
			SpellDefinition.DeliveryType.PROJECTILE:
				sfx.play("spell_b", -4.0, 0.1)
			SpellDefinition.DeliveryType.NOVA:
				sfx.play("area_effect_a", -3.0, 0.08)
			SpellDefinition.DeliveryType.SELF:
				sfx.play("heal_a", -4.0, 0.1)
			SpellDefinition.DeliveryType.TOUCH:
				sfx.play("attack_a", -3.0, 0.1)

	match spell.delivery:
		SpellDefinition.DeliveryType.PROJECTILE:
			_cast_projectile(spell, player, aim_dir)
		SpellDefinition.DeliveryType.NOVA:
			_cast_nova(spell, player)
		SpellDefinition.DeliveryType.SELF:
			_cast_self(spell, player)
		SpellDefinition.DeliveryType.TOUCH:
			_cast_touch(spell, player, aim_dir)

func _cast_projectile(spell: SpellDefinition, player: CharacterBody2D, aim_dir: Vector2) -> void:
	if not player.is_inside_tree():
		return
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullets_container = player.get_tree().get_first_node_in_group("bullets")
	if not bullets_container:
		bullets_container = player.get_tree().current_scene

	var count = maxi(1, spell.bullet_count)

	for i in range(count):
		var angle_offset = 0.0
		var b = bullet_scene.instantiate()
		b.global_position = player.global_position

		match spell.bullet_behavior:
			0:  # Straight — parallel offset, same direction
				if count > 1:
					var perp = aim_dir.rotated(PI / 2.0)
					var spacing = 6.0
					var lateral = (float(i) - (count - 1) / 2.0) * spacing
					b.global_position += perp * lateral
			1:  # Homing — small initial spread, then seek targets
				if count > 1:
					angle_offset = (float(i) / float(count - 1) - 0.5) * 0.3
				b.homing_strength = 5.0
			2:  # Spread — wide fan
				if count > 1:
					var total_spread = PI / 4.0 + (count - 2) * 0.1
					total_spread = minf(total_spread, PI)
					angle_offset = (float(i) / float(count - 1) - 0.5) * total_spread

		var dir = aim_dir.rotated(angle_offset)
		b.direction = dir
		b.is_player_bullet = true
		b.speed = 200.0
		b.damage = spell.magnitude
		b.lifetime = 2.0
		# Set enchant type + distinct sprite based on effect
		b.enchant_type = _effect_to_enchant(spell.effect_type)
		b.bullet_sprite_index = _effect_to_sprite(spell.effect_type)
		# Apply duration-based status effects via bullet meta
		if spell.duration > 0:
			match spell.effect_type:
				SpellDefinition.EffectType.ICE_DAMAGE:
					b.set_meta("apply_slowed", spell.duration)
				SpellDefinition.EffectType.FIRE_DAMAGE:
					b.set_meta("apply_burning", spell.duration)
				SpellDefinition.EffectType.POISON_DAMAGE:
					b.set_meta("apply_poison", spell.duration)
				SpellDefinition.EffectType.LIGHTNING_DAMAGE:
					b.set_meta("apply_stunned", minf(spell.duration, 2.0))
				SpellDefinition.EffectType.HOLY_DAMAGE:
					b.set_meta("apply_weakened", spell.duration)
				SpellDefinition.EffectType.DARK_DAMAGE:
					b.set_meta("apply_feared", spell.duration)
		bullets_container.add_child(b)

func _cast_nova(spell: SpellDefinition, player: CharacterBody2D) -> void:
	if not player.is_inside_tree():
		return
	var in_ow = player.get_tree().current_scene and player.get_tree().current_scene.name == "Overworld"
	var radius = (32.0 + spell.magnitude * 0.5) * (4.0 if in_ow else 1.0)
	var enemies = player.get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = player.global_position.distance_to(e.global_position)
		if dist < radius:
			if e.has_method("take_damage"):
				e.take_damage(spell.magnitude)
			# Apply status based on effect type
			if e.has_method("apply_status") and spell.duration > 0:
				_apply_spell_status(e, spell)
	# Visual flash + VFX
	var color = _effect_flash_color(spell.effect_type)
	player.sprite.modulate = color
	var tween = player.create_tween()
	tween.tween_property(player.sprite, "modulate", Color.WHITE, 0.3)
	var vfx_n = player.get_node_or_null("/root/VFXManager")
	if vfx_n:
		vfx_n.shockwave(player.global_position, radius, Color(color.r, color.g, color.b, 0.5))
		vfx_n.shake(1.5, 0.12)

func _cast_self(spell: SpellDefinition, player: CharacterBody2D) -> void:
	match spell.effect_type:
		SpellDefinition.EffectType.HEAL_SELF:
			if player.has_method("heal"):
				player.heal(spell.magnitude)
		SpellDefinition.EffectType.SHIELD_BUFF:
			if player.has_method("add_shield"):
				player.add_shield(spell.magnitude)
		SpellDefinition.EffectType.SPEED_BUFF:
			if player.status_effects:
				player.status_effects.apply_buff("speed", spell.duration, spell.magnitude * 0.01)
		SpellDefinition.EffectType.DAMAGE_BUFF:
			if player.status_effects:
				player.status_effects.apply_buff("damage", spell.duration, spell.magnitude * 0.01)
	# Visual
	player.sprite.modulate = Color(0.5, 1.0, 0.5)
	var tween = player.create_tween()
	tween.tween_property(player.sprite, "modulate", Color.WHITE, 0.3)

func _cast_touch(spell: SpellDefinition, player: CharacterBody2D, aim_dir: Vector2) -> void:
	if not player.is_inside_tree():
		return
	var in_ow_t = player.get_tree().current_scene and player.get_tree().current_scene.name == "Overworld"
	var ow_s = 4.0 if in_ow_t else 1.0
	var radius = 24.0 * ow_s
	var cone_angle = 0.8  # ~45 degrees half-angle
	var kb_force = 200.0 * ow_s
	var enemies = player.get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var to_enemy = (e.global_position - player.global_position)
		var dist = to_enemy.length()
		if dist > radius:
			continue
		# Cone check
		var angle = aim_dir.angle_to(to_enemy.normalized())
		if absf(angle) > cone_angle:
			continue
		if e.has_method("take_damage"):
			e.take_damage(spell.magnitude)
		# Apply status effects
		if e.has_method("apply_status") and spell.duration > 0:
			_apply_spell_status(e, spell)
		# Knockback
		e.velocity = to_enemy.normalized() * kb_force
	# Visual
	var color = _effect_flash_color(spell.effect_type)
	player.sprite.modulate = color
	var tween = player.create_tween()
	tween.tween_property(player.sprite, "modulate", Color.WHITE, 0.2)

## Learn a spell granted by an equipped item (temporary until unequipped)
func learn_spell_from_equipment(spell_id: String) -> void:
	if spell_id not in equipment_spells:
		equipment_spells.append(spell_id)
	var spell = _load_spell(spell_id)
	if spell and not has_spell(spell_id):
		learn_spell(spell)

## Remove a spell granted by equipment (unless permanently learned via scroll)
func unlearn_spell_from_equipment(spell_id: String) -> void:
	equipment_spells.erase(spell_id)
	if not is_permanently_learned(spell_id):
		_remove_spell(spell_id)

## Check if spell was learned permanently (via scroll, not equipment)
func is_permanently_learned(spell_id: String) -> bool:
	return has_spell(spell_id) and spell_id not in equipment_spells

## Mark a spell as permanently learned (e.g. from scroll)
func mark_permanently_learned(spell_id: String) -> void:
	equipment_spells.erase(spell_id)

## Load a SpellDefinition by id from resources/spells/
func _load_spell(spell_id: String) -> SpellDefinition:
	var path = "res://resources/spells/%s.tres" % spell_id
	if ResourceLoader.exists(path):
		return load(path) as SpellDefinition
	return null

## Remove a spell from learned list and unequip from all slots
func _remove_spell(spell_id: String) -> void:
	for i in range(learned_spells.size() - 1, -1, -1):
		if learned_spells[i].id == spell_id:
			learned_spells.remove_at(i)
	for i in range(MAX_SPELL_SLOTS):
		if spell_slots[i] and spell_slots[i].id == spell_id:
			spell_slots[i] = null
			spell_unequipped.emit(i)

func _apply_spell_status(enemy: Node, spell: SpellDefinition) -> void:
	match spell.effect_type:
		SpellDefinition.EffectType.ICE_DAMAGE:
			enemy.apply_status("SLOWED", spell.duration)
		SpellDefinition.EffectType.FIRE_DAMAGE:
			enemy.apply_status("BURNING", spell.duration)
		SpellDefinition.EffectType.POISON_DAMAGE:
			enemy.apply_status("POISONED", spell.duration)
		SpellDefinition.EffectType.LIGHTNING_DAMAGE:
			enemy.apply_status("STUNNED", minf(spell.duration, 2.0))
		SpellDefinition.EffectType.HOLY_DAMAGE:
			enemy.apply_status("WEAKENED", spell.duration)
		SpellDefinition.EffectType.DARK_DAMAGE:
			enemy.apply_status("FEARED", spell.duration)

func _effect_to_enchant(effect: SpellDefinition.EffectType) -> int:
	match effect:
		SpellDefinition.EffectType.FIRE_DAMAGE: return 0      # FIRE
		SpellDefinition.EffectType.ICE_DAMAGE: return 1        # ICE
		SpellDefinition.EffectType.LIGHTNING_DAMAGE: return 3   # LIGHTNING
		SpellDefinition.EffectType.POISON_DAMAGE: return 2      # POISON
		SpellDefinition.EffectType.HOLY_DAMAGE: return 4        # HOLY
		SpellDefinition.EffectType.DARK_DAMAGE: return 5        # DARK
	return -1

# Distinct bullet sprites per effect type (lofi_obj.png, 16 cols)
# Row 8=128, Row 9=144, Row 10=160, Row 11=176, Row 12=192, Row 14=224
func _effect_to_sprite(effect: SpellDefinition.EffectType) -> int:
	match effect:
		SpellDefinition.EffectType.FIRE_DAMAGE: return 144     # red star (row 9, col 0)
		SpellDefinition.EffectType.ICE_DAMAGE: return 176      # blue star (row 11, col 0)
		SpellDefinition.EffectType.LIGHTNING_DAMAGE: return 145 # yellow bolt (row 9, col 1)
		SpellDefinition.EffectType.POISON_DAMAGE: return 160   # green star (row 10, col 0)
		SpellDefinition.EffectType.HOLY_DAMAGE: return 128     # white star (row 8, col 0)
		SpellDefinition.EffectType.DARK_DAMAGE: return 192     # pink star (row 12, col 0)
		SpellDefinition.EffectType.HEAL_SELF: return 161       # green orb (row 10, col 1)
		SpellDefinition.EffectType.SHIELD_BUFF: return 177     # blue orb (row 11, col 1)
		SpellDefinition.EffectType.SPEED_BUFF: return 129      # white orb (row 8, col 1)
		SpellDefinition.EffectType.DAMAGE_BUFF: return 193     # pink orb (row 12, col 1)
	return 224  # default blue magic

func _effect_flash_color(effect: SpellDefinition.EffectType) -> Color:
	match effect:
		SpellDefinition.EffectType.FIRE_DAMAGE: return Color(2, 1, 0.5)
		SpellDefinition.EffectType.ICE_DAMAGE: return Color(0.5, 0.8, 2.0)
		SpellDefinition.EffectType.LIGHTNING_DAMAGE: return Color(1.5, 1.5, 0.3)
		SpellDefinition.EffectType.POISON_DAMAGE: return Color(0.5, 2.0, 0.5)
		SpellDefinition.EffectType.HOLY_DAMAGE: return Color(2, 2, 1.5)
		SpellDefinition.EffectType.DARK_DAMAGE: return Color(0.8, 0.3, 1.5)
		SpellDefinition.EffectType.HEAL_SELF: return Color(0.5, 1.5, 0.5)
		SpellDefinition.EffectType.SHIELD_BUFF: return Color(1, 1.5, 2)
		SpellDefinition.EffectType.SPEED_BUFF: return Color(1.5, 1.5, 0.5)
		SpellDefinition.EffectType.DAMAGE_BUFF: return Color(2, 0.5, 0.5)
	return Color.WHITE
