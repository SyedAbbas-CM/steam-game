class_name WorldMap
extends Resource

## Master world map containing all zone references and connections.
## Used by the overworld to place zones and create transitions.

@export var zones: Array[LoyZoneData] = []

## Get a zone by its ID
func get_zone(zone_id: String) -> LoyZoneData:
	for z in zones:
		if z.id == zone_id:
			return z
	return null

## Get all zones that have dungeons
func get_dungeon_zones() -> Array[LoyZoneData]:
	for z in zones:
		if z.dungeon_count > 0:
			result.append(z)
	return result

## Get all town zones (have NPCs)
func get_town_zones() -> Array[LoyZoneData]:
	var result: Array[LoyZoneData] = []
	for z in zones:
		if z.npcs.size() > 0:
			result.append(z)
	return result
