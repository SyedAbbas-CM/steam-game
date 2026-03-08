class_name DialogueUI
extends CanvasLayer

## Simple text overlay at bottom of screen — no popup, no pause

signal dialogue_finished
signal choice_made(index: int)

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _options_container: HBoxContainer
var _full_text: String = ""
var _options: Array = []
var _portrait_rect: TextureRect
var _chars_texture: Texture2D
var _chars2_texture: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_chars_texture = load("res://assets/sprites/loy/chars.png") as Texture2D
	_chars2_texture = load("res://assets/sprites/loy/chars2.png") as Texture2D
	_build_ui()

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.show_dialogue_requested.connect(_on_show_dialogue)

func _build_ui() -> void:
	# Bottom bar panel — simple, small, no dimmer
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -180
	_panel.offset_bottom = -20

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.border_color = Color(0.5, 0.4, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_panel.add_child(hbox)

	# Small portrait
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(96, 96)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hbox.add_child(_portrait_rect)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)

	# Name
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_name_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_name_label)

	# Text
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 22)
	_text_label.add_theme_color_override("font_color", Color.WHITE)
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)

	# Options as horizontal buttons
	_options_container = HBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_options_container)

func _set_portrait(tile_index: int) -> void:
	if tile_index <= 0:
		_portrait_rect.texture = null
		_portrait_rect.visible = false
		return
	_portrait_rect.visible = true
	var tex = _chars_texture if tile_index < 256 else _chars2_texture
	var idx = tile_index % 256
	var col = idx % 16
	var row = idx / 16
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(col * 32, row * 32, 32, 32)
	_portrait_rect.texture = atlas

func show_dialogue(npc_name: String, portrait: int, text: String, options: Array) -> void:
	_name_label.text = npc_name
	_set_portrait(portrait)
	_options = options
	_full_text = text.replace(" / / ", "\n").replace(" / ", "\n")
	_text_label.text = _full_text
	_panel.visible = true

	# Clear old option buttons
	for child in _options_container.get_children():
		child.queue_free()

	# Add option buttons
	for i in range(options.size()):
		var btn = Button.new()
		btn.text = options[i]
		btn.add_theme_font_size_override("font_size", 20)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		btn_style.border_color = Color(0.4, 0.35, 0.25)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(2)
		btn_style.content_margin_left = 10
		btn_style.content_margin_right = 10
		btn_style.content_margin_top = 3
		btn_style.content_margin_bottom = 3
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover = btn_style.duplicate()
		hover.bg_color = Color(0.25, 0.25, 0.3, 0.95)
		btn.add_theme_stylebox_override("hover", hover)
		btn.pressed.connect(_on_option_pressed.bind(i))
		_options_container.add_child(btn)

func _on_option_pressed(index: int) -> void:
	_panel.visible = false
	choice_made.emit(index)
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm._waiting_for_dialogue = false
		qm.on_dialogue_choice(index)

func _on_show_dialogue(npc_name: String, portrait: int, text: String, options: Array) -> void:
	show_dialogue(npc_name, portrait, text, options)

func is_open() -> bool:
	return _panel.visible

func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	# Space/Enter to pick first option if only one
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if _options.size() == 1:
				_on_option_pressed(0)
