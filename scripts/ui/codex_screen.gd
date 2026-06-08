class_name CodexScreen
extends CanvasLayer

## In-game lore journal. Press N to toggle.
##
## v1: hardcoded entries in three categories (Story / Characters / World).
## Later: gate entries via QuestManager state — `unlocked_codex` array on save data.

const CODEX_ENTRIES := {
	"story": [
		{
			"title": "The Sundering",
			"body": "Long before Ravenhollow stood, something cracked the world open. \
The locals call it the Sundering. No record agrees on what tore the sky, only that \
the crack never sealed. Demons leak out of it, slow but constant. The Ashfields \
around Ravenhollow burned and never grew back."
		},
		{
			"title": "Hellgate",
			"body": "The wound at the heart of the world. Bards call it many things \
but the Wardens have one name for it. Whatever opened Hellgate was old, and what \
crawls out of it is older. The closer you walk to it, the harder it is to remember \
your own name."
		},
		{
			"title": "Ravenhollow's First Stones",
			"body": "Ravenhollow was not built. It was huddled. Refugees stacked the \
first walls from the foundations of older buildings whose names no one remembers. \
The Elder claims to remember the founders' names but writes them in no ledger."
		},
		{
			"title": "Act One — Ash on Your Boots",
			"body": "You woke in Ravenhollow. The Elder gave you a name and small work. \
The dead in the Barrows would not stay buried. The scarecrows in the Hollow Fields \
walked at night. Local trouble for a refugee to handle.",
			"act": 0
		},
		{
			"title": "Act Two — The Wardens Know",
			"body": "The Elder sent you north into the Wastes for a simple errand. You \
met Captain Coran instead. The Wardens are an old order. They patrol the roads and \
hunt what crawls out of Hellgate. They are losing ground.",
			"act": 1
		},
		{
			"title": "Act Three — Following the Cracks",
			"body": "The corruption you saw in the Hollow Fields is not random. It \
follows older fissures in the world. Coran sends you to Embermaw to close one of \
them. Something is buried under Ravenhollow that even the Elder will not name.",
			"act": 2
		},
		{
			"title": "Act Four — Older Wounds",
			"body": "The Wardens dispatch you across the Outlands. Frostgrave's armies \
froze in place during a war no one remembers winning. Ashheim still smolders. The \
Bone Quarry has been silent since the miners stopped digging.",
			"act": 3
		},
		{
			"title": "Act Five — The Gates Open",
			"body": "Ashglade and Gehinnom sit at Hellgate's doorstep. The demons \
there have names. Some have factions. One of them, the Speaker, sent you a letter.",
			"act": 4
		},
		{
			"title": "Act Six — Closing the Wound",
			"body": "Hellgate has ten floors. You walk them. At the bottom, you decide \
what comes through.",
			"act": 5
		},
	],
	"characters": [
		{
			"title": "The Elder",
			"body": "Leader of Ravenhollow. Knows more than he says. His name does not \
appear on any founders' ledger, but he speaks of the founders as if they were old \
friends. Sacrifices himself in the fourth act."
		},
		{
			"title": "Warden Coran",
			"body": "Captain of the Wardens in the Wastes. Recruited you informally \
after a single conversation. Stocky, scarred, dry-witted. Older than he looks."
		},
		{
			"title": "Captain Briard",
			"body": "Another Warden captain, posted in the Ironspine. Disagrees with \
Coran on tactics, doctrine, and most other things. Will offer you a deal Coran would \
not make."
		},
		{
			"title": "Dafydd",
			"body": "The last farmer in the Hollow Fields. Tends his land alone now. \
The Fire Beast in Embermaw ate something of his father's that he wants back."
		},
		{
			"title": "Skuld, Gravekeeper of the Barrows",
			"body": "Skuld can name every grave in the Barrows except three. She wants \
you to read those three for her, aloud, in the right order."
		},
		{
			"title": "Iola, Hermit of the Forest",
			"body": "Iola lives in a clearing in the Wastes where nothing else lives. \
She trades sample for sample. She is the one who first asks you to face the Forest \
Heart."
		},
		{
			"title": "The Bone Hermit",
			"body": "Buried beneath the Barrows mausoleum. He has been buried for a \
long time. He may have been one of the founders. He may be still breathing."
		},
		{
			"title": "The Speaker",
			"body": "A demon ambassador at Hellgate's threshold. Articulate. Patient. \
Wants to meet you, eventually. Whose mouth he speaks through varies."
		},
	],
	"world": [
		{
			"title": "The Ashfields",
			"body": "The scorched lands closest to Hellgate. Ravenhollow sits at the \
quietest edge. The further you walk into the Ashfields, the more the soil refuses to \
hold anything alive."
		},
		{
			"title": "Ravenhollow",
			"body": "Walled refugee village in the Ashfields. Town Hall in the centre, \
shops along the main road, an inn called the Crooked Beak, a quiet smithy. The north \
gate opens onto the Wastes."
		},
		{
			"title": "The Wastes (forest)",
			"body": "Forest north of Ravenhollow. The Wardens patrol the roads. \
Wagons get ambushed if no one is watching. Standing stones in a clearing hint at \
the Sundering. Most of the map is still empty."
		},
		{
			"title": "The Barrows",
			"body": "Graveyard south of Ravenhollow. The dead rise more nights than \
they used to. The mausoleum at the centre is sealed until the Bone Golem wakes it."
		},
		{
			"title": "The Hollow Fields",
			"body": "Open farmland east of Ravenhollow. Dafydd's land. The scarecrows \
walk at night. There is a mill that hasn't been used in years."
		},
		{
			"title": "Embermaw",
			"body": "Volcanic fissure south of the Hollow Fields. A lesser wound, \
older than Ravenhollow. The Fire Beast lives in the magma."
		},
		{
			"title": "Frostgrave",
			"body": "An army froze here in the middle of a battle and never finished \
dying. The slab in the centre names whoever opened the Sundering."
		},
		{
			"title": "Hellgate",
			"body": "The wound. Ten floors. Whatever it leads to has no name yet."
		},
	],
}

const TAB_LABELS := ["Story", "Characters", "World"]
const TAB_KEYS := ["story", "characters", "world"]

var _open: bool = false
var _selected_tab: int = 0
var _selected_entry: int = 0

var _overlay: ColorRect
var _root_panel: PanelContainer
var _tab_btns: Array[Button] = []
var _entry_list: VBoxContainer
var _entry_buttons: Array[Button] = []
var _content_title: Label
var _content_body: RichTextLabel


func _ready() -> void:
	layer = 110
	add_to_group("codex_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_N and not _any_other_ui_open():
			toggle()
			get_viewport().set_input_as_handled()
		elif _open and k.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func _any_other_ui_open() -> bool:
	# Don't open if another modal is open
	var inv = get_tree().get_first_node_in_group("inventory_screen")
	if inv and inv.has_method("is_open") and inv.is_open():
		return true
	var dialogue = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue and dialogue.has_method("is_open") and dialogue.is_open():
		return true
	return false


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_select_tab(_selected_tab)


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false


func _build_ui() -> void:
	var ashfields_theme = load("res://assets/themes/ashfields_theme.tres") as Theme

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.65)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_root_panel = PanelContainer.new()
	if ashfields_theme:
		_root_panel.theme = ashfields_theme
	_root_panel.anchor_left = 0.08
	_root_panel.anchor_right = 0.92
	_root_panel.anchor_top = 0.08
	_root_panel.anchor_bottom = 0.92
	add_child(_root_panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	_root_panel.add_child(root_vbox)

	# Title row: "CODEX" header + close button
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(title_row)

	var title = Label.new()
	title.text = "CODEX"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.918, 0.702, 0.031))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 3)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var hint = Label.new()
	hint.text = "[N] toggle   [Esc] close"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.659, 0.635, 0.616))
	title_row.add_child(hint)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(close)
	title_row.add_child(close_btn)

	# Tab bar
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tab_bar)
	for i in TAB_LABELS.size():
		var btn = Button.new()
		btn.text = TAB_LABELS[i]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(140, 36)
		btn.pressed.connect(_select_tab.bind(i))
		tab_bar.add_child(btn)
		_tab_btns.append(btn)

	# Main body: [entry list | content]
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body)

	# Left: entry list (scrollable)
	var list_scroll = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(260, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_scroll)

	_entry_list = VBoxContainer.new()
	_entry_list.add_theme_constant_override("separation", 4)
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_entry_list)

	# Right: content panel
	var content_panel = PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content_panel)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	content_panel.add_child(content_vbox)

	_content_title = Label.new()
	_content_title.add_theme_font_size_override("font_size", 24)
	_content_title.add_theme_color_override("font_color", Color(0.918, 0.702, 0.031))
	_content_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_content_title.add_theme_constant_override("outline_size", 2)
	content_vbox.add_child(_content_title)

	var sep = HSeparator.new()
	content_vbox.add_child(sep)

	_content_body = RichTextLabel.new()
	_content_body.fit_content = false
	_content_body.scroll_active = true
	_content_body.bbcode_enabled = true
	_content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_body.add_theme_font_size_override("normal_font_size", 18)
	_content_body.add_theme_color_override("default_color", Color(0.973, 0.980, 0.984))
	content_vbox.add_child(_content_body)


func _select_tab(idx: int) -> void:
	_selected_tab = clampi(idx, 0, TAB_LABELS.size() - 1)
	_selected_entry = 0
	_refresh_tab_buttons()
	_rebuild_entry_list()
	_refresh_content()


func _refresh_tab_buttons() -> void:
	for i in _tab_btns.size():
		var btn = _tab_btns[i]
		if i == _selected_tab:
			btn.add_theme_color_override("font_color", Color(0.918, 0.702, 0.031))
		else:
			btn.add_theme_color_override("font_color", Color(0.659, 0.635, 0.616))


func _rebuild_entry_list() -> void:
	for c in _entry_list.get_children():
		c.queue_free()
	_entry_buttons.clear()

	var key = TAB_KEYS[_selected_tab]
	var entries: Array = CODEX_ENTRIES.get(key, [])
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var btn = Button.new()
		btn.text = entry.get("title", "?")
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 38)
		btn.pressed.connect(_select_entry.bind(i))
		_entry_list.add_child(btn)
		_entry_buttons.append(btn)
	_refresh_entry_buttons()


func _select_entry(idx: int) -> void:
	_selected_entry = idx
	_refresh_entry_buttons()
	_refresh_content()


func _refresh_entry_buttons() -> void:
	for i in _entry_buttons.size():
		var btn = _entry_buttons[i]
		if i == _selected_entry:
			btn.add_theme_color_override("font_color", Color(0.918, 0.702, 0.031))
		else:
			btn.add_theme_color_override("font_color", Color(0.973, 0.980, 0.984))


func _refresh_content() -> void:
	var key = TAB_KEYS[_selected_tab]
	var entries: Array = CODEX_ENTRIES.get(key, [])
	if _selected_entry >= entries.size():
		_content_title.text = ""
		_content_body.text = ""
		return
	var entry: Dictionary = entries[_selected_entry]
	_content_title.text = entry.get("title", "")
	_content_body.text = entry.get("body", "")
