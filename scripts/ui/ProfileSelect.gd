extends Control
## Profile screen (Week 13 / PT5): pick, create, reset or delete a local
## player profile. Everything is stored only on this device (SaveSystem).
## Fully keyboard-driven like the other menus: arrows + Enter, Esc = back.

const ERROR_COLOR := Color(1.0, 0.55, 0.45)
const OK_COLOR := Color(0.65, 0.95, 0.6)

var _list: VBoxContainer
var _new_row: HBoxContainer
var _name_edit: LineEdit
var _create_button: Button
var _message: Label
var _back_button: Button
var _confirm_delete_id: String = ""

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/maps/bg_banaue.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	UIKit.dim(self, 0.55)

	var panel := UIKit.centered_panel(self, Vector2(560, 0))
	var v := UIKit.vbox(panel, 6)
	UIKit.label(v, "SINO ANG MAGLALARO?", "HeaderLabel", 26)
	UIKit.label(v, "Choose your player profile", "AccentLabel", 16)

	_list = UIKit.vbox(v, 6)

	var new_row := UIKit.hbox(v, 10)
	_new_row = new_row
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Bagong palayaw (nickname)"
	_name_edit.max_length = SaveSystem.NAME_MAX
	_name_edit.custom_minimum_size = Vector2(300, UIKit.MIN_TOUCH)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_create())
	_name_edit.text_changed.connect(func(_t: String) -> void: _show(""))
	new_row.add_child(_name_edit)
	_create_button = UIKit.button(new_row, "GUMAWA", true, UIKit.MIN_TOUCH)
	_create_button.custom_minimum_size.x = 130
	_create_button.pressed.connect(_on_create)

	_message = UIKit.label(v, "", "", 15)
	_message.visible = false
	UIKit.label(v, "Saved only on this device. Use a nickname - not your full name.", "HintLabel", 13)

	_back_button = UIKit.button(v, "BUMALIK", false, UIKit.MIN_TOUCH)
	_back_button.pressed.connect(_on_back)

	SaveSystem.save_failed.connect(_on_save_failed)
	_refresh()
	var notice := SaveSystem.take_notice()
	if notice != "":
		_show(notice)
	UIKit.pop_in(panel)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _back_button.visible:
		get_viewport().set_input_as_handled()
		_on_back()

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var first_focus: Control = null
	for p in SaveSystem.profiles:
		var id: String = p["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_list.add_child(row)
		var is_active: bool = id == SaveSystem.active_id
		var play := Button.new()
		play.text = ("▶ " if is_active else "") + str(p["name"])
		play.custom_minimum_size = Vector2(230, UIKit.MIN_TOUCH)
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		play.theme_type_variation = "GoldButton" if is_active else ""
		play.pressed.connect(_on_select.bind(id))
		row.add_child(play)
		if is_active:
			var reset := Button.new()
			reset.text = "I-RESET"
			reset.tooltip_text = "Clear money and outfits for this profile"
			reset.custom_minimum_size = Vector2(100, UIKit.MIN_TOUCH)
			reset.pressed.connect(_on_reset.bind(reset))
			row.add_child(reset)
		var del := Button.new()
		del.text = "SIGURADO?" if _confirm_delete_id == id else "BURAHIN"
		del.custom_minimum_size = Vector2(110, UIKit.MIN_TOUCH)
		del.pressed.connect(_on_delete.bind(id))
		row.add_child(del)
		if first_focus == null or is_active:
			first_focus = play
	var full := SaveSystem.profiles.size() >= SaveSystem.MAX_PROFILES
	# When the device is full the create row is hidden (keeps all buttons at
	# full touch size on a 540 px tall screen) and a hint explains why.
	_new_row.visible = not full
	if full:
		_list.add_child(_hint("Max %d profiles - burahin ang isa para gumawa ng bago." % SaveSystem.MAX_PROFILES))
	_back_button.visible = SaveSystem.has_active_profile()
	if SaveSystem.profiles.is_empty():
		_list.add_child(_hint("Wala pang profile. Type a nickname below to start."))
		first_focus = _name_edit
	Controls.focus(first_focus if first_focus else _name_edit)

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "HintLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _show(text: String, is_error: bool = false) -> void:
	_message.text = text
	_message.visible = text != ""
	_message.add_theme_color_override("font_color", ERROR_COLOR if is_error else OK_COLOR)

func _on_create() -> void:
	Audio.play_sfx("click")
	var r := SaveSystem.create_profile(_name_edit.text)
	if not r["ok"]:
		_show(r["error"], true)
		Controls.focus(_name_edit)
		return
	_name_edit.text = ""
	_go_title()

func _on_select(id: String) -> void:
	Audio.play_sfx("click")
	if SaveSystem.select_profile(id):
		_go_title()
	else:
		_show(SaveSystem.last_error, true)

func _on_reset(button: Button) -> void:
	Audio.play_sfx("click")
	if button.text != "SIGURADO?":
		button.text = "SIGURADO?"
		_show("Press again to clear this profile's money and outfits.", true)
		return
	if SaveSystem.reset_profile():
		_show("Progress for %s was reset." % SaveSystem.active_profile_name())
	_refresh()

func _on_delete(id: String) -> void:
	Audio.play_sfx("click")
	if _confirm_delete_id != id:
		_confirm_delete_id = id
		_show("Press SIGURADO? to delete this profile and its save for good.", true)
		_refresh()
		return
	_confirm_delete_id = ""
	if SaveSystem.delete_profile(id):
		_show("Profile deleted.")
	else:
		_show(SaveSystem.last_error, true)
	_refresh()

func _on_save_failed(message: String) -> void:
	_show(message, true)

func _on_back() -> void:
	Audio.play_sfx("click")
	_go_title()

func _go_title() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Title.tscn")
