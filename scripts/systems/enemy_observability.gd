extends Node

# Debug-only enemy spawn telemetry. Records the final composed EnemyDefinition
# after dungeon scaling, elite promotion, archetypes, affixes, and phase setup.

const LOG_DIR := "user://enemy_observability"
const MAX_RECENT_EVENTS := 256

var _enabled: bool = false
var _run_id: String = ""
var _events: Array[Dictionary] = []
var _counts_by_name: Dictionary = {}
var _counts_by_room: Dictionary = {}
var _counts_by_archetype: Dictionary = {}
var _counts_by_affix: Dictionary = {}
var _counts_by_tag: Dictionary = {}
var _jsonl_path: String = ""
var _summary_path: String = ""

func _ready() -> void:
	_enabled = OS.is_debug_build() or OS.has_feature("editor")
	set_process(_enabled)
	if _enabled:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))

func is_enabled() -> bool:
	return _enabled

func begin_dungeon_run(context: Dictionary = {}) -> void:
	if not _enabled:
		return
	_run_id = "%s_%d" % [String(context.get("dungeon", "dungeon")).replace(" ", "_"), Time.get_unix_time_from_system()]
	_events.clear()
	_counts_by_name.clear()
	_counts_by_room.clear()
	_counts_by_archetype.clear()
	_counts_by_affix.clear()
	_counts_by_tag.clear()
	_jsonl_path = "%s/%s_spawns.jsonl" % [LOG_DIR, _run_id]
	_summary_path = "%s/%s_summary.txt" % [LOG_DIR, _run_id]
	print("[EnemyObs] logging to %s" % ProjectSettings.globalize_path(_summary_path))
	_append_jsonl({
		"event": "begin_run",
		"run_id": _run_id,
		"context": context,
		"time_msec": Time.get_ticks_msec(),
	})

func end_dungeon_run(context: Dictionary = {}) -> void:
	if not _enabled or _run_id == "":
		return
	_append_jsonl({
		"event": "end_run",
		"run_id": _run_id,
		"context": context,
		"time_msec": Time.get_ticks_msec(),
	})
	write_summary()

func record_enemy_spawn(enemy: Node, definition: Resource, context: Dictionary = {}) -> void:
	if not _enabled or definition == null:
		return
	if _run_id == "":
		begin_dungeon_run(context)

	var event := _build_spawn_event(enemy, definition, context)
	_events.append(event)
	if _events.size() > MAX_RECENT_EVENTS:
		_events.pop_front()

	_count(_counts_by_name, String(event.get("enemy_name", "Unknown")))
	_count(_counts_by_room, String(event.get("room_type", "unknown")))
	var archetype := String(event.get("archetype", ""))
	if archetype != "":
		_count(_counts_by_archetype, archetype)
	for affix in event.get("affixes", []):
		_count(_counts_by_affix, String(affix))
	for tag in event.get("search_tags", []):
		_count(_counts_by_tag, String(tag))

	_append_jsonl(event)
	if bool(event.get("is_major", false)) or _events.size() % 10 == 0:
		write_summary()
	if bool(event.get("is_major", false)):
		print("[EnemyObs] %s room=%s floor=%s hp=%s dmg=%s atk=%s phases=%s arch=%s affixes=%s summons=%s tags=%s" % [
			event.get("enemy_name", "Unknown"),
			event.get("room_type", "?"),
			event.get("floor", "?"),
			event.get("max_hp", "?"),
			event.get("attack_damage", "?"),
			event.get("attack_type", "?"),
			event.get("boss_phases", "?"),
			event.get("archetype", ""),
			str(event.get("affixes", [])),
			event.get("summon_phase_count", 0),
			str(event.get("search_tags", [])),
		])

func write_summary() -> void:
	if not _enabled or _summary_path == "":
		return
	var lines: Array[String] = []
	lines.append("Enemy Observability Summary")
	lines.append("Run: %s" % _run_id)
	lines.append("Events: %d" % _events.size())
	lines.append("")
	lines.append("By Enemy")
	lines.append_array(_format_counts(_counts_by_name))
	lines.append("")
	lines.append("By Room")
	lines.append_array(_format_counts(_counts_by_room))
	lines.append("")
	lines.append("By Archetype")
	lines.append_array(_format_counts(_counts_by_archetype))
	lines.append("")
	lines.append("By Affix")
	lines.append_array(_format_counts(_counts_by_affix))
	lines.append("")
	lines.append("By Search Tag")
	lines.append_array(_format_counts(_counts_by_tag))
	lines.append("")
	lines.append("Major Spawns")
	for event in _events:
		if bool(event.get("is_major", false)):
			lines.append("- F%s %s %s hp=%s dmg=%s pool=%s arch=%s affixes=%s summons=%s tags=%s" % [
				event.get("floor", "?"),
				event.get("room_type", "?"),
				event.get("enemy_name", "Unknown"),
				event.get("max_hp", "?"),
				event.get("attack_damage", "?"),
				str(event.get("attack_pool", [])),
				event.get("archetype", ""),
				str(event.get("affixes", [])),
				event.get("summon_phase_count", 0),
				str(event.get("search_tags", [])),
			])

	var file := FileAccess.open(_summary_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
		file.close()

func get_recent_events() -> Array[Dictionary]:
	return _events.duplicate(true)

func get_summary_path() -> String:
	return ProjectSettings.globalize_path(_summary_path) if _summary_path != "" else ""

func get_jsonl_path() -> String:
	return ProjectSettings.globalize_path(_jsonl_path) if _jsonl_path != "" else ""

func search_recent(query: String) -> Array[Dictionary]:
	var terms: Array[String] = []
	for raw in query.to_lower().split(" ", false):
		var term := raw.strip_edges()
		if term != "":
			terms.append(term)
	var matches: Array[Dictionary] = []
	for event in _events:
		var haystack := JSON.stringify(event).to_lower()
		var ok := true
		for term in terms:
			if not haystack.contains(term):
				ok = false
				break
		if ok:
			matches.append(event)
	return matches

func _build_spawn_event(enemy: Node, definition: Resource, context: Dictionary) -> Dictionary:
	var attack_pool: Array = []
	if definition.has_meta("generated_attack_pool"):
		for attack_id in definition.get_meta("generated_attack_pool"):
			attack_pool.append(_attack_name(int(attack_id)))

	var affixes: Array[String] = []
	if definition.has_meta("generated_affix_ids"):
		for affix in definition.get_meta("generated_affix_ids"):
			affixes.append(String(affix))

	var movement := _movement_summary(definition.get("movement_pattern"))
	var summon_def = definition.get("summon_definition")
	var event := {
		"event": "enemy_spawn",
		"run_id": _run_id,
		"time_msec": Time.get_ticks_msec(),
		"enemy_instance_id": enemy.get_instance_id() if enemy else 0,
		"enemy_name": String(definition.get("enemy_name")),
		"resource_path": String(definition.resource_path),
		"floor": int(context.get("floor", 0)),
		"room_grid": str(context.get("room_grid", Vector2i.ZERO)),
		"room_type": String(context.get("room_type", "unknown")),
		"encounter_type": String(context.get("encounter_type", "unknown")),
		"spawn_reason": String(context.get("spawn_reason", "room_spawn")),
		"source_pool": String(context.get("source_pool", "")),
		"recommended_level": int(context.get("recommended_level", 0)),
		"player_level": int(context.get("player_level", 1)),
		"overlevel": int(context.get("overlevel", 0)),
		"level_scale": float(context.get("level_scale", 1.0)),
		"dmg_scale": float(context.get("dmg_scale", 1.0)),
		"room_hp_mult": float(context.get("room_hp_mult", 1.0)),
		"room_damage_mult": float(context.get("room_damage_mult", 1.0)),
		"max_hp": int(definition.get("max_hp")),
		"attack_damage": int(definition.get("attack_damage")),
		"contact_damage": int(definition.get("contact_damage")),
		"armor": int(definition.get("armor")),
		"level": int(definition.get("level")),
		"size_class": _size_name(int(definition.get("size_class"))),
		"attack_type": _attack_name(int(definition.get("attack_type"))),
		"phase_2_attack": _attack_name(int(definition.get("phase_2_attack"))),
		"phase_3_attack": _attack_name(int(definition.get("phase_3_attack"))),
		"phase_2_bullet_count": int(definition.get("phase_2_bullet_count")),
		"phase_3_bullet_count": int(definition.get("phase_3_bullet_count")),
		"attack_speed": float(definition.get("attack_speed")),
		"bullet_speed": float(definition.get("bullet_speed")),
		"bullet_count": int(definition.get("bullet_count")),
		"bomb_aoe_radius": float(definition.get("bomb_aoe_radius")),
		"bomb_flight_time": float(definition.get("bomb_flight_time")),
		"movement": movement,
		"boss_phases": int(definition.get("boss_phases")),
		"boss_state_count": definition.get("boss_states").size(),
		"summon_on_phase_change": bool(definition.get("summon_on_phase_change")),
		"summon_phase_count": int(definition.get("summon_phase_count")),
		"summon_count": int(definition.get("summon_count")),
		"summon_definition": String(summon_def.enemy_name) if summon_def else "",
		"archetype": String(definition.get_meta("generated_archetype_id")) if definition.has_meta("generated_archetype_id") else "",
		"generated_tier": String(definition.get_meta("generated_tier")) if definition.has_meta("generated_tier") else "",
		"affixes": affixes,
		"attack_pool": attack_pool,
		"melee_secondary": _attack_name(int(definition.get_meta("melee_secondary"))) if definition.has_meta("melee_secondary") else "",
		"status_effect": String(definition.get("bullet_status_effect")),
		"status_duration": float(definition.get("bullet_status_duration")),
		"is_major": _is_major_spawn(definition, context),
	}
	event["search_tags"] = _build_search_tags(event)
	return event

func _append_jsonl(payload: Dictionary) -> void:
	if _jsonl_path == "":
		return
	var file := FileAccess.open(_jsonl_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_jsonl_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.close()

func _is_major_spawn(definition: Resource, context: Dictionary) -> bool:
	var room_type := String(context.get("room_type", ""))
	return room_type in ["ELITE", "SUPER_ELITE", "BOSS"] \
		or int(definition.get("size_class")) >= 1 \
		or bool(definition.get("summon_on_phase_change")) \
		or definition.has_meta("generated_archetype_id")

func _count(dict: Dictionary, key: String) -> void:
	dict[key] = int(dict.get(key, 0)) + 1

func _format_counts(dict: Dictionary) -> Array[String]:
	var keys := dict.keys()
	keys.sort_custom(func(a, b): return int(dict[a]) > int(dict[b]))
	var out: Array[String] = []
	for key in keys:
		out.append("- %s: %d" % [String(key), int(dict[key])])
	return out

func _build_search_tags(event: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	_add_tag(tags, String(event.get("room_type", "")).to_lower())
	_add_tag(tags, String(event.get("spawn_reason", "")).to_lower())
	_add_tag(tags, String(event.get("size_class", "")).to_lower())
	_add_tag(tags, String(event.get("generated_tier", "")).to_lower())
	_add_tag(tags, String(event.get("archetype", "")).to_lower())
	for affix in event.get("affixes", []):
		_add_tag(tags, String(affix).to_lower())

	var all_attacks: Array[String] = [
		String(event.get("attack_type", "")),
		String(event.get("phase_2_attack", "")),
		String(event.get("phase_3_attack", "")),
		String(event.get("melee_secondary", "")),
	]
	for attack in event.get("attack_pool", []):
		all_attacks.append(String(attack))
	var uses_summon_attack := false
	for attack in all_attacks:
		var lower: String = attack.to_lower()
		if lower == "" or lower == "none":
			continue
		_add_tag(tags, lower)
		if lower.contains("bomb") or lower in ["artillery", "mortar", "meteor_shower", "fire_rain"]:
			_add_tag(tags, "bomb")
			_add_tag(tags, "artillery")
		if lower.contains("mine"):
			_add_tag(tags, "mine")
			_add_tag(tags, "area_denial")
		if lower.contains("summon"):
			uses_summon_attack = true
			_add_tag(tags, "summoner")
		if lower.contains("poison"):
			_add_tag(tags, "green")
			_add_tag(tags, "poison")
		if lower.contains("barrier") or lower.contains("wall"):
			_add_tag(tags, "wall")
			_add_tag(tags, "area_denial")

	var status: String = String(event.get("status_effect", "")).to_lower()
	if status != "":
		_add_tag(tags, status)
	if status.contains("poison"):
		_add_tag(tags, "green")
		_add_tag(tags, "poison")

	var movement: Dictionary = event.get("movement", {})
	var movement_path := String(movement.get("path", "")).to_lower()
	if movement_path != "":
		_add_tag(tags, movement_path.get_file().get_basename())
		if movement_path.contains("orbit"):
			_add_tag(tags, "orbit")
		if movement_path.contains("hold") or movement_path.contains("anchor"):
			_add_tag(tags, "stationary")
	if float(movement.get("approach_weight", 1.0)) <= 0.35 and float(movement.get("hold_weight", 0.0)) >= 0.35:
		_add_tag(tags, "stationary")

	var phase_summons := bool(event.get("summon_on_phase_change", false)) and int(event.get("summon_phase_count", 0)) > 0
	var direct_summons := uses_summon_attack and int(event.get("summon_count", 0)) > 0
	if phase_summons or direct_summons:
		_add_tag(tags, "summoner")
		_add_tag(tags, "adds")
	if String(event.get("summon_definition", "")) != "" and (phase_summons or direct_summons):
		_add_tag(tags, "minions")
	if int(event.get("bullet_count", 0)) >= 5 or int(event.get("phase_2_bullet_count", 0)) >= 8 or int(event.get("phase_3_bullet_count", 0)) >= 8:
		_add_tag(tags, "bullet_spam")
	if float(event.get("bomb_aoe_radius", 0.0)) > 20.0:
		_add_tag(tags, "large_aoe")
	return tags

func _add_tag(tags: Array[String], tag: String) -> void:
	tag = tag.strip_edges().replace(" ", "_")
	if tag == "" or tag == "unknown":
		return
	if tag not in tags:
		tags.append(tag)

func _attack_name(value: int) -> String:
	for key in EnemyDefinition.AttackType.keys():
		if int(EnemyDefinition.AttackType[key]) == value:
			return String(key)
	return str(value)

func _size_name(value: int) -> String:
	for key in EnemyDefinition.SizeClass.keys():
		if int(EnemyDefinition.SizeClass[key]) == value:
			return String(key)
	return str(value)

func _movement_summary(movement) -> Dictionary:
	if movement == null:
		return {}
	return {
		"path": String(movement.resource_path),
		"move_type": int(movement.get("move_type")),
		"approach_weight": float(movement.get("approach_weight")),
		"hold_weight": float(movement.get("hold_weight")),
		"retreat_weight": float(movement.get("retreat_weight")),
		"orbit_radius": float(movement.get("orbit_radius")),
		"preferred_distance": float(movement.get("preferred_distance")),
	}
