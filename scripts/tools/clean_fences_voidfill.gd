@tool
extends SceneTree

## Removes void-fill tile (source 0, atlas 14,7) from Fences layer in overworld.tscn
## Does NOT re-pack — edits the scene resource directly and saves .tscn only.
## Then runs bake_chunks.gd to rebuild the .scn.
## Run: Godot --headless --path <project> --script res://scripts/tools/clean_fences_voidfill.gd

func _init() -> void:
	var scene_path := "res://scenes/overworld/overworld.tscn"
	print("=== Cleaning void-fill fences tiles from %s ===" % scene_path)

	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("Failed to load scene")
		quit(1)
		return

	var root := scene.instantiate()
	var fences := root.get_node_or_null("Fences") as TileMapLayer
	if not fences:
		push_error("No Fences layer")
		root.queue_free()
		quit(1)
		return

	var cells := fences.get_used_cells()
	print("Fences layer: %d total cells" % cells.size())

	var removed := 0
	for cell in cells:
		var source := fences.get_cell_source_id(cell)
		var atlas := fences.get_cell_atlas_coords(cell)
		if source == 0 and atlas == Vector2i(14, 7):
			fences.erase_cell(cell)
			removed += 1

	print("Removed %d void-fill (14,7) tiles" % removed)
	print("Remaining: %d cells" % fences.get_used_cells().size())

	if removed == 0:
		print("Nothing to clean!")
		root.queue_free()
		quit(0)
		return

	# Update the PackedScene state with changes and save .tscn
	# Use pack() but this is the scene as loaded — should preserve structure
	var err := scene.pack(root)
	if err != OK:
		push_error("Failed to pack: %s" % error_string(err))
		root.queue_free()
		quit(1)
		return

	err = ResourceSaver.save(scene, scene_path)
	if err != OK:
		push_error("Failed to save .tscn: %s" % error_string(err))
	else:
		print("Saved %s" % scene_path)

	root.queue_free()
	print("=== Done. Now run bake_chunks.gd to rebuild .scn ===")
	quit(0)
