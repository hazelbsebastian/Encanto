extends Control
## Lets the player pick one of five Philippine locations. Cards are built in
## code from MAPS so new destinations can be added just by extending the
## array. Arrow keys / WASD move between cards, Enter picks, Esc goes back.

const MAPS := [
	{"id": "banaue", "name": "Banaue Rice Terraces", "place": "Ifugao", "thumb": "res://assets/maps/bg_banaue_thumb.png"},
	{"id": "intramuros", "name": "Intramuros", "place": "Maynila", "thumb": "res://assets/maps/bg_intramuros_thumb.png"},
	{"id": "mayon", "name": "Mayon Volcano", "place": "Albay", "thumb": "res://assets/maps/bg_mayon_thumb.png"},
	{"id": "chocolate_hills", "name": "Chocolate Hills", "place": "Bohol", "thumb": "res://assets/maps/bg_chocolate_hills_thumb.png"},
	{"id": "boracay", "name": "Boracay", "place": "Aklan", "thumb": "res://assets/maps/bg_boracay_thumb.png"},
]

const CARD_SIZE := Vector2(270, 176)

@onready var grid: GridContainer = $Grid
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
@onready var dialogue_label: Label = $DialogueLayer/Panel/Label

var _cards: Array[Button] = []
var _chosen: bool = false

func _ready() -> void:
	for m: Dictionary in MAPS:
		var card := _make_card(m)
		grid.add_child(card)
		_cards.append(card)
	Controls.focus(_cards[0])

func _make_card(m: Dictionary) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "TileButton"
	btn.custom_minimum_size = CARD_SIZE
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(_on_map_selected.bind(m))
	btn.focus_entered.connect(_on_card_focus.bind(btn, true))
	btn.focus_exited.connect(_on_card_focus.bind(btn, false))
	btn.mouse_entered.connect(func() -> void: btn.grab_focus())

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_top = 8
	v.offset_right = -8
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)

	var pic := TextureRect.new()
	pic.texture = load(str(m["thumb"])) as Texture2D
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)

	var name_label := Label.new()
	name_label.text = str(m["name"])
	name_label.theme_type_variation = "HudLabel"
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_label)

	var place := Label.new()
	place.text = str(m["place"])
	place.theme_type_variation = "HintLabel"
	place.add_theme_font_size_override("font_size", 13)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(place)
	return btn

func _on_card_focus(btn: Button, focused: bool) -> void:
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05) if focused else Vector2.ONE, 0.12)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _chosen:
		get_viewport().set_input_as_handled()
		Audio.play_sfx("click")
		get_tree().change_scene_to_file("res://scenes/jeepney/JeepneyIntro.tscn")

func _on_map_selected(m: Dictionary) -> void:
	if _chosen:
		return
	_chosen = true
	Audio.play_sfx("click")
	for c in _cards:
		c.disabled = c != get_viewport().gui_get_focus_owner()
		c.focus_mode = Control.FOCUS_NONE
	GameManager.chosen_map_id = str(m["id"])
	GameManager.chosen_map_name = str(m["name"])
	dialogue_label.text = "\"Sa %s, manong.\"" % m["name"]
	dialogue_layer.visible = true
	var t := Audio.play_voice("player_sa_" + str(m["id"]))
	await get_tree().create_timer(maxf(1.4, t + 0.1)).timeout
	dialogue_label.text = "Manong: \"Sige! Tara na!\""
	t = Audio.play_voice("driver_tara")
	await get_tree().create_timer(maxf(1.2, t)).timeout
	get_tree().change_scene_to_file("res://scenes/jeepney/JeepneyTravel.tscn")
