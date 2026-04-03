class_name RewardScreen
extends CanvasLayer

signal reward_chosen(reward: Dictionary)

var rewards: Array[Dictionary] = []

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var cards_container: HBoxContainer = $Panel/VBox/Cards

func _ready() -> void:
	visible = false

func show_rewards(reward_list: Array[Dictionary], title: String = "Choose a Reward") -> void:
	rewards = reward_list
	title_label.text = title
	get_tree().paused = true
	visible = true

	# Clear old cards
	for child in cards_container.get_children():
		child.queue_free()

	# Create reward cards
	for i in range(rewards.size()):
		var card = _create_card(rewards[i], i)
		cards_container.add_child(card)

func _create_card(reward: Dictionary, index: int) -> Button:
	var btn = Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(90, 60)
	btn.text = reward.get("name", "???") + "\n" + reward.get("description", "")

	var rarity = reward.get("rarity", 0)
	match rarity:
		0: btn.modulate = Color.WHITE
		1: btn.modulate = Color.GREEN
		2: btn.modulate = Color.CYAN

	btn.pressed.connect(func(): _on_card_pressed(index))
	return btn

func _on_card_pressed(index: int) -> void:
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("bonus", -2.0, 0.0)
	var chosen = rewards[index]
	visible = false
	get_tree().paused = false
	reward_chosen.emit(chosen)
