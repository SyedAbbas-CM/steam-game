class_name DialogueUI
extends CanvasLayer

## Simple text overlay at bottom of screen — no popup, no pause

signal dialogue_finished
signal choice_made(index: int)

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _options_container: HBoxContainer
var _full_text: String = ""
var _options: Array = []
var _selected_index: int = 0
var _portrait_rect: TextureRect
var _chars_texture: Texture2D
var _chars2_texture: Texture2D

# Typewriter effect
var _typewriter_active: bool = false
var _typewriter_timer: float = 0.0
var _typewriter_index: int = 0
const TYPEWRITER_SPEED: float = 0.03  # seconds per character
var _sfx_tick: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	add_to_group("dialogue_ui")
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

	# Text — RichTextLabel for visible_characters support
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.scroll_active = false
	_text_label.fit_content = true
	_text_label.add_theme_font_size_override("normal_font_size", 22)
	_text_label.add_theme_color_override("default_color", Color.WHITE)
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)

	# Options as horizontal buttons
	_options_container = HBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 8)
	_options_container.visible = false
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
	_text_label.visible_characters = 0
	_typewriter_active = true
	_typewriter_timer = 0.0
	_typewriter_index = 0
	_sfx_tick = 0
	_panel.visible = true

	# Hide options until text finishes
	_options_container.visible = false

	# Clear old option buttons
	for child in _options_container.get_children():
		child.queue_free()

	# Add option buttons (hidden until typewriter finishes)
	for i in range(options.size()):
		var btn = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
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
		btn.mouse_entered.connect(_on_option_hover.bind(i))
		_options_container.add_child(btn)

	_selected_index = 0

func _process(delta: float) -> void:
	if not _typewriter_active:
		return
	_typewriter_timer += delta
	var chars_to_show = int(_typewriter_timer / TYPEWRITER_SPEED)
	if chars_to_show > _typewriter_index:
		_typewriter_index = chars_to_show
		_text_label.visible_characters = _typewriter_index
		# Soft tick sound every 4 characters
		_sfx_tick += 1
		if _sfx_tick % 4 == 0:
			var sfx = get_node_or_null("/root/SFXManager")
			if sfx:
				sfx.play("blip", -20.0)
	if _typewriter_index >= _full_text.length():
		_finish_typewriter()

func _finish_typewriter() -> void:
	_typewriter_active = false
	_text_label.visible_characters = -1  # show all
	_options_container.visible = true
	_update_option_highlight()

func _on_option_pressed(index: int) -> void:
	if _typewriter_active:
		_finish_typewriter()
		return
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("blip", -4.0)
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

func _on_option_hover(index: int) -> void:
	if _typewriter_active:
		return
	_selected_index = index
	_update_option_highlight()

func _update_option_highlight() -> void:
	var buttons = _options_container.get_children()
	for i in range(buttons.size()):
		var btn = buttons[i] as Button
		if not btn:
			continue
		var style = StyleBoxFlat.new()
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		if i == _selected_index:
			style.bg_color = Color(0.3, 0.3, 0.4, 0.95)
			style.border_color = Color(1.0, 0.85, 0.4)
		else:
			style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
			style.border_color = Color(0.4, 0.35, 0.25)
		btn.add_theme_stylebox_override("normal", style)
		var hover = style.duplicate()
		hover.bg_color = Color(0.25, 0.25, 0.3, 0.95)
		btn.add_theme_stylebox_override("hover", hover)

func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if not (event is InputEventKey and event.pressed):
		# Consume interact action while dialogue is open
		if event.is_action_pressed("interact"):
			if _typewriter_active:
				_finish_typewriter()
			elif _options.size() == 1:
				_on_option_pressed(0)
			elif _options.size() > 1:
				_on_option_pressed(_selected_index)
			get_viewport().set_input_as_handled()
		return

	var key = event.keycode
	match key:
		KEY_SPACE, KEY_ENTER:
			if _typewriter_active:
				_finish_typewriter()
			elif _options.size() == 1:
				_on_option_pressed(0)
			elif _options.size() > 1:
				_on_option_pressed(_selected_index)
			get_viewport().set_input_as_handled()
		KEY_A, KEY_LEFT:
			if _typewriter_active:
				_finish_typewriter()
			elif _options.size() > 1:
				_selected_index = (_selected_index - 1 + _options.size()) % _options.size()
				_update_option_highlight()
				var sfx = get_node_or_null("/root/SFXManager")
				if sfx:
					sfx.play("blip", -8.0)
			get_viewport().set_input_as_handled()
		KEY_D, KEY_RIGHT:
			if _typewriter_active:
				_finish_typewriter()
			elif _options.size() > 1:
				_selected_index = (_selected_index + 1) % _options.size()
				_update_option_highlight()
				var sfx = get_node_or_null("/root/SFXManager")
				if sfx:
					sfx.play("blip", -8.0)
			get_viewport().set_input_as_handled()
		KEY_W, KEY_UP, KEY_S, KEY_DOWN:
			get_viewport().set_input_as_handled()
		KEY_E:
			if _typewriter_active:
				_finish_typewriter()
			elif _options.size() == 1:
				_on_option_pressed(0)
			elif _options.size() > 1:
				_on_option_pressed(_selected_index)
			get_viewport().set_input_as_handled()
