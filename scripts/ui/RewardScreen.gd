extends Control
## "Pera o Bayong" - the final progression reward. PERA gives a fixed amount
## of money; BAYONG opens a traditional basket for a random reward (money or
## a wardrobe unlock) drawn from ClothingData's expandable reward pool.

const PERA_AMOUNT := 500

@onready var choice_panel: Panel = $ChoicePanel
@onready var pera_button: Button = $ChoicePanel/VBox/ButtonsRow/PeraButton
@onready var bayong_button: Button = $ChoicePanel/VBox/ButtonsRow/BayongButton

@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBox/ResultLabel
@onready var continue_button: Button = $ResultPanel/VBox/ContinueButton

@onready var bayong_panel: Panel = $BayongPanel
@onready var bayong_image: TextureRect = $BayongPanel/VBox/BayongImage
@onready var bayong_open_button: Button = $BayongPanel/VBox/OpenButton

const BAYONG_CLOSED := preload("res://assets/ui/bayong_closed.png")
const BAYONG_OPEN := preload("res://assets/ui/bayong_open.png")

func _ready() -> void:
	result_panel.visible = false
	bayong_panel.visible = false
	pera_button.pressed.connect(_on_pera)
	bayong_button.pressed.connect(_on_bayong_open_screen)
	bayong_open_button.pressed.connect(_on_bayong_open)
	continue_button.pressed.connect(_on_continue)
	Controls.focus(pera_button)
	Audio.play_music("music_title")
	Audio.play_voice("narrator_pera_o_bayong")

func _on_pera() -> void:
	Audio.play_sfx("coin")
	SaveSystem.add_money(PERA_AMOUNT)
	choice_panel.visible = false
	result_label.text = "+₱%d\n\nNakuha mo ang ₱%d!" % [PERA_AMOUNT, PERA_AMOUNT]
	result_panel.visible = true
	Controls.focus(continue_button)
	Audio.play_voice("narrator_nakuha")

func _on_bayong_open_screen() -> void:
	Audio.play_sfx("click")
	choice_panel.visible = false
	bayong_panel.visible = true
	bayong_image.texture = BAYONG_CLOSED
	Controls.focus(bayong_open_button)

func _on_bayong_open() -> void:
	Audio.play_sfx("bayong_open")
	bayong_open_button.disabled = true
	bayong_image.texture = BAYONG_OPEN
	bayong_image.pivot_offset = bayong_image.size * 0.5
	var tw := create_tween()
	tw.tween_property(bayong_image, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(bayong_image, "scale", Vector2(1.0, 1.0), 0.15)
	var reward: Dictionary = ClothingData.random_bayong_reward()
	var text := ""
	if reward["type"] == "money":
		SaveSystem.add_money(int(reward["amount"]))
		text = "Nakuha mo: ₱%d!" % int(reward["amount"])
		SaveSystem.add_bayong_reward_record("money_%d" % int(reward["amount"]))
	else:
		var item_id: String = reward["id"]
		var was_new := not SaveSystem.is_unlocked(item_id)
		SaveSystem.unlock_clothing(item_id)
		SaveSystem.add_bayong_reward_record(item_id)
		var item_name: String = ClothingData.get_item(item_id).get("name", item_id)
		text = "Nakuha mo: %s!" % item_name
		if was_new:
			text += "\nBagong Damit!"
	await get_tree().create_timer(0.6).timeout
	bayong_panel.visible = false
	result_label.text = text
	result_panel.visible = true
	Controls.focus(continue_button)
	Audio.play_voice("narrator_nakuha")

func _on_continue() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/main/FinalEnding.tscn")
