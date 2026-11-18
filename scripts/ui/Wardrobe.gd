extends Control
## Clothing / wardrobe menu: buy items with money earned from PERA rewards,
## equip anything already unlocked (purchased or won from the Bayong), and
## see the (simplified) cosmetic preview update live.

@onready var money_label: Label = $MoneyLabel
@onready var tabs: TabContainer = $Tabs
@onready var preview: TextureRect = $Preview
@onready var accessory_preview: TextureRect = $AccessoryPreview
@onready var back_button: Button = $BackButton
@onready var message_label: Label = $MessageLabel

var category_lists: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for cat in ClothingData.CATEGORIES:
		category_lists[cat] = tabs.get_node(cat.capitalize() + "/List")
	_refresh_all()
	_focus_first_row()

func _refresh_all() -> void:
	money_label.text = "₱%d" % SaveSystem.money
	for cat in ClothingData.CATEGORIES:
		_refresh_category(cat)
	_update_preview()

func _refresh_category(cat: String) -> void:
	var list: VBoxContainer = category_lists[cat]
	for c in list.get_children():
		c.queue_free()
	for item_id in ClothingData.items_in_category(cat):
		var item: Dictionary = ClothingData.get_item(item_id)
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var name_label := Label.new()
		name_label.text = item["name"]
		name_label.custom_minimum_size = Vector2(260, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var status_label := Label.new()
		var action_button := Button.new()
		action_button.custom_minimum_size = Vector2(130, UIKit.MIN_TOUCH)
		var unlocked: bool = SaveSystem.is_unlocked(item_id)
		var is_equipped: bool = SaveSystem.equipped.get(cat, "") == item_id

		if is_equipped:
			status_label.text = "EQUIPPED"
			action_button.text = "Equipped"
			action_button.disabled = true
		elif unlocked:
			status_label.text = "Owned"
			action_button.text = "ISUOT"
			action_button.theme_type_variation = "GoldButton"
			action_button.pressed.connect(_on_equip.bind(cat, item_id))
		else:
			status_label.text = "₱%d" % int(item["price"])
			action_button.text = "BILHIN"
			action_button.pressed.connect(_on_buy.bind(cat, item_id))

		status_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(status_label)
		row.add_child(action_button)
		list.add_child(card)

func _on_equip(cat: String, item_id: String) -> void:
	Audio.play_sfx("click")
	SaveSystem.equip(cat, item_id)
	message_label.text = ""
	_refresh_all()
	_focus_first_row()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.apply_outfit()

func _on_buy(cat: String, item_id: String) -> void:
	var item: Dictionary = ClothingData.get_item(item_id)
	if SaveSystem.spend_money(int(item["price"])):
		Audio.play_sfx("coin")
		SaveSystem.unlock_clothing(item_id)
		message_label.text = "Nabili mo na ang outfit!"
		message_label.modulate = Color(0.4, 1.0, 0.4)
		_refresh_all()
		_focus_first_row()
	else:
		Audio.play_sfx("click")
		message_label.text = "Kulang ang iyong pera."
		message_label.modulate = Color(1.0, 0.4, 0.4)

func _update_preview() -> void:
	var top_id: String = SaveSystem.equipped.get("top", "basic_polo")
	preview.modulate = ClothingData.get_item(top_id).get("tint", Color(1, 1, 1))
	var acc_id: String = SaveSystem.equipped.get("accessory", "")
	var acc: Dictionary = ClothingData.get_item(acc_id)
	var icon_path: String = acc.get("icon", "")
	if icon_path != "":
		accessory_preview.texture = load(icon_path)
		accessory_preview.visible = true
	else:
		accessory_preview.visible = false

## Keyboard: focus the first usable button of the visible tab. The tab bar
## itself is reachable with Up, and Left/Right on it switches tabs.
func _focus_first_row() -> void:
	var list: VBoxContainer = category_lists[ClothingData.CATEGORIES[tabs.current_tab]]
	for card in list.get_children():
		if card.is_queued_for_deletion():
			continue
		for b in card.get_child(0).get_children():
			if b is Button and not (b as Button).disabled:
				Controls.focus(b as Button)
				return
	Controls.focus(back_button)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

func _on_back() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/main/Title.tscn")
