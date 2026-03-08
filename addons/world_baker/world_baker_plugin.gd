@tool
extends EditorPlugin

var _button: Button

func _enter_tree() -> void:
	_button = Button.new()
	_button.text = "🍞 Bake World"
	_button.tooltip_text = "Bake overworld.tscn tiles into chunk files for fast runtime loading"
	_button.pressed.connect(_on_bake_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _button)

func _exit_tree() -> void:
	if _button:
		remove_control_from_container(CONTAINER_TOOLBAR, _button)
		_button.queue_free()

func _on_bake_pressed() -> void:
	_button.text = "⏳ Baking..."
	_button.disabled = true

	# Save all open scenes first
	EditorInterface.save_all_scenes()

	# Run bake script in background
	var godot_path = OS.get_executable_path()
	var project_path = ProjectSettings.globalize_path("res://")
	var script_path = "scripts/tools/bake_chunks.gd"

	var output: Array = []
	var exit_code = OS.execute(godot_path, [
		"--headless",
		"--path", project_path,
		"--script", script_path,
	], output, true)

	var output_text = "\n".join(output)
	print(output_text)

	if exit_code == 0 and "DONE" in output_text:
		_button.text = "✅ Baked!"
		print("World Baker: Success!")
		# Refresh the editor's filesystem so it sees new chunk files
		EditorInterface.get_resource_filesystem().scan()
	else:
		_button.text = "❌ Failed"
		push_error("World Baker: Bake failed (exit code %d)" % exit_code)
		push_error(output_text)

	# Reset button after 3 seconds
	await get_tree().create_timer(3.0).timeout
	_button.text = "🍞 Bake World"
	_button.disabled = false
