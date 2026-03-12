class_name TileInspector
extends CanvasLayer

## Lightweight popup for inspecting overworld tiles.
## Shows tile name + description when player presses E near objects.

var _panel: PanelContainer
var _name_label: Label
var _desc_label: Label
var _hide_timer: Timer
var _is_visible: bool = false

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.05
	_panel.anchor_bottom = 0.05
	_panel.offset_left = -140
	_panel.offset_right = 140
	_panel.offset_top = 0
	_panel.offset_bottom = 70

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_desc_label)

	_panel.visible = false
	add_child(_panel)

	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = 2.5
	_hide_timer.timeout.connect(_hide)
	add_child(_hide_timer)

func show_info(tile_name: String, description: String) -> void:
	_name_label.text = tile_name
	_desc_label.text = description
	_desc_label.visible = description != ""
	_panel.visible = true
	_is_visible = true
	_hide_timer.start()

func hide_info() -> void:
	_panel.visible = false
	_is_visible = false
	_hide_timer.stop()

func _hide() -> void:
	hide_info()

func is_open() -> bool:
	return _is_visible
