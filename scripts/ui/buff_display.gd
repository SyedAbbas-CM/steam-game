class_name BuffDisplay
extends Node2D

# Floating buff/debuff icons above the player sprite.
# Buffs = colored squares with countdown. Debuffs = status effect icons with red border.

const ICON_SIZE := 6.0
const ICON_GAP := 2.0
const OFFSET_Y := -16.0
const PULSE_THRESHOLD := 3.0  # seconds remaining to start pulsing

const BUFF_COLORS := {
	"armor": Color(0.9, 0.8, 0.2),
	"xp": Color(0.7, 0.3, 1.0),
	"speed": Color(0.3, 0.9, 1.0),
	"damage": Color(1.0, 0.3, 0.2),
	"fire_rate": Color(1.0, 0.6, 0.2),
}

const DEBUFF_COLORS := {
	"BURNING": Color(1.0, 0.5, 0.2),
	"SLOWED": Color(0.4, 0.6, 1.0),
	"POISONED": Color(0.5, 1.0, 0.3),
}

var _status_mgr: StatusEffectManager
var _pulse_time := 0.0

func setup(status_manager: StatusEffectManager) -> void:
	_status_mgr = status_manager
	position = Vector2(0, OFFSET_Y)

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

func _draw() -> void:
	if not _status_mgr:
		return

	var icons: Array[Dictionary] = []

	# Collect active buffs
	var buffs = _status_mgr.get_all_buffs()
	for bname in buffs:
		var timer: float = buffs[bname]["timer"]
		var color: Color = BUFF_COLORS.get(bname, Color(0.8, 0.8, 0.8))
		icons.append({"color": color, "timer": timer, "is_debuff": false})

	# Collect active debuffs
	for effect in _status_mgr.active_effects:
		var type_name := ""
		match effect.type:
			StatusEffect.Type.BURNING: type_name = "BURNING"
			StatusEffect.Type.SLOWED: type_name = "SLOWED"
			StatusEffect.Type.POISONED: type_name = "POISONED"
		if type_name != "":
			var color: Color = DEBUFF_COLORS.get(type_name, Color.RED)
			icons.append({"color": color, "timer": effect.duration, "is_debuff": true})

	if icons.is_empty():
		return

	# Center the icon row
	var total_width = icons.size() * ICON_SIZE + (icons.size() - 1) * ICON_GAP
	var start_x = -total_width * 0.5

	for i in icons.size():
		var icon = icons[i]
		var x = start_x + i * (ICON_SIZE + ICON_GAP)
		var rect = Rect2(x, 0, ICON_SIZE, ICON_SIZE)
		var alpha := 1.0

		# Pulse when expiring soon
		if icon["timer"] < PULSE_THRESHOLD:
			alpha = 0.4 + 0.6 * abs(sin(_pulse_time * 4.0))

		var col: Color = icon["color"]
		col.a = alpha

		# Draw filled square
		draw_rect(rect, col)

		# Debuffs get a red border
		if icon["is_debuff"]:
			var border_col = Color(1.0, 0.2, 0.2, alpha)
			draw_rect(rect, border_col, false, 1.0)
		else:
			var border_col = Color(1.0, 1.0, 1.0, alpha * 0.5)
			draw_rect(rect, border_col, false, 0.5)

		# Timer text
		var timer_val = int(ceil(icon["timer"]))
		var font = ThemeDB.fallback_font
		if font:
			var font_size := 4
			var text = str(timer_val)
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_x = x + (ICON_SIZE - text_size.x) * 0.5
			var text_y = ICON_SIZE + font_size + 1.0
			var text_col = Color(1.0, 1.0, 1.0, alpha)
			draw_string(font, Vector2(text_x, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
