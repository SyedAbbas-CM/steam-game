class_name PetManager
extends Node

## Manages owned pets, their levels, XP, and active pet assignment

var all_pet_defs: Dictionary = {}  # pet_type -> PetDefinition
var owned_pets: Array = []  # [{type, name, level, xp, active}]
var active_pet_node: Node2D = null

func _ready() -> void:
	_load_pet_definitions()
	_load_state()

func _load_pet_definitions() -> void:
	for path in ResourceRegistry.pets():
		var pet = load(path) as PetDefinition
		if pet and pet.pet_type != "":
			all_pet_defs[pet.pet_type] = pet
	print("PetManager: Loaded " + str(all_pet_defs.size()) + " pet definitions")

func _load_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data and gm.save_data.get("pet_data"):
		owned_pets = gm.save_data.pet_data.duplicate(true)

func save_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.save_data:
		gm.save_data.pet_data = owned_pets.duplicate(true)

func buy_pet(pet_type: String) -> bool:
	if not all_pet_defs.has(pet_type):
		return false
	var def = all_pet_defs[pet_type]
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.spend_gold(def.cost):
		return false

	# Pick random name
	var pet_name = pet_type
	if def.possible_names.size() > 0:
		pet_name = def.possible_names[randi() % def.possible_names.size()]

	owned_pets.append({
		"type": pet_type,
		"name": pet_name,
		"level": 1,
		"xp": 0,
		"active": false,
	})
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("bonus", -3.0, 0.0)
	save_state()
	return true

func set_active_pet(index: int) -> void:
	for i in range(owned_pets.size()):
		owned_pets[i]["active"] = (i == index)
	save_state()

func get_active_pet() -> Dictionary:
	for pet in owned_pets:
		if pet.get("active", false):
			return pet
	return {}

func get_active_pet_def() -> PetDefinition:
	var pet = get_active_pet()
	if pet.is_empty():
		return null
	return all_pet_defs.get(pet.get("type", ""))

func add_pet_xp(amount: int) -> void:
	var pet = get_active_pet()
	if pet.is_empty():
		return
	var def = all_pet_defs.get(pet.get("type", ""))
	if not def:
		return

	pet["xp"] = int(pet.get("xp", 0)) + amount
	var level = int(pet.get("level", 1))
	var xp_needed = _xp_for_level(level + 1)

	while int(pet["xp"]) >= xp_needed and level < def.max_level:
		pet["xp"] = int(pet["xp"]) - xp_needed
		level += 1
		pet["level"] = level
		xp_needed = _xp_for_level(level + 1)

		# Check for evolution
		if def.evolve_level > 0 and level >= def.evolve_level and def.evolve_name != "":
			pet["name"] = def.evolve_name
			var sfx_ev = get_node_or_null("/root/SFXManager")
			if sfx_ev:
				sfx_ev.play("1up_b", 0.0, 0.0)
			print("Pet evolved into " + def.evolve_name + "!")

	save_state()

func _xp_for_level(level: int) -> int:
	return 50 + level * 25

func spawn_active_pet(parent: Node2D, near_position: Vector2) -> Node2D:
	var pet = get_active_pet()
	if pet.is_empty():
		return null
	var def = get_active_pet_def()
	if not def:
		return null

	var companion_scene = preload("res://scenes/companions/companion.tscn")
	var companion = companion_scene.instantiate()
	companion.global_position = near_position + Vector2(20, 20)

	# Create a CompanionDefinition from pet data
	var comp_def = CompanionDefinition.new()
	var stats = def.get_stats_at_level(int(pet.get("level", 1)))
	comp_def.companion_name = str(pet.get("name", def.pet_type))
	comp_def.hp = int(stats["hp"])
	comp_def.damage = int(stats["attack"])
	comp_def.attack_speed = 1.5
	comp_def.move_speed = 45.0
	comp_def.attack_range = def.search_distance * 8.0
	comp_def.follow_distance = 24.0

	parent.add_child(companion)
	companion.setup(comp_def, 0)
	active_pet_node = companion
	var sfx_sp = get_node_or_null("/root/SFXManager")
	if sfx_sp:
		sfx_sp.play("select_b", -4.0, 0.0)
	return companion
