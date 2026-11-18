extends Control
## Title screen. Fully keyboard-driven (arrows/WASD + Enter, Esc closes the
## settings panel) as well as touch/mouse.

@onready var money_label: Label = $MoneyChip/Row/MoneyLabel
@onready var title_label: Label = $VBox/TitleLabel
@onready var play_button: Button = $VBox/PlayButton
@onready var settings_button: Button = $VBox/SettingsButton
@onready var settings_dim: ColorRect = $SettingsDim
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VBox/VolumeSlider
@onready var close_button: Button = $SettingsPanel/VBox/CloseButton
@onready var farmer: TextureRect = $Farmer

static var _welcomed: bool = false

func _ready() -> void:
	money_label.text = "₱%d" % SaveSystem.money
	play_button.pressed.connect(_on_play)
	$VBox/WardrobeButton.pressed.connect(_on_wardrobe)
	settings_button.pressed.connect(_on_settings_open)
	$VBox/ExitButton.pressed.connect(_on_exit)
	close_button.pressed.connect(_on_settings_close)
	var bus := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus))
	volume_slider.value_changed.connect(_on_volume_changed)
	settings_panel.visible = false
	settings_dim.visible = false
	# gentle idle motion so the menu feels alive
	var tw := create_tween().set_loops()
	tw.tween_property(title_label, "position:y", title_label.position.y - 4.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title_label, "position:y", title_label.position.y, 1.4).set_trans(Tween.TRANS_SINE)
	var ft := create_tween().set_loops()
	ft.tween_property(farmer, "scale", Vector2(1.0, 1.02), 0.9).set_trans(Tween.TRANS_SINE)
	ft.tween_property(farmer, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	farmer.pivot_offset = Vector2(30, 84)
	Controls.focus(play_button)
	Audio.stop_ambient()
	Audio.play_music("music_title")
	if not _welcomed:
		_welcomed = true
		get_tree().create_timer(0.6).timeout.connect(func() -> void: Audio.play_voice("narrator_welcome"))

func _unhandled_input(event: InputEvent) -> void:
	if settings_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_settings_close()

func _on_play() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/jeepney/JeepneyIntro.tscn")

func _on_wardrobe() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/Wardrobe.tscn")

func _on_settings_open() -> void:
	Audio.play_sfx("click")
	settings_dim.visible = true
	settings_panel.visible = true
	_set_menu_focusable(false)
	UIKit.pop_in(settings_panel)
	Controls.focus(volume_slider)

func _on_settings_close() -> void:
	Audio.play_sfx("click")
	settings_panel.visible = false
	settings_dim.visible = false
	_set_menu_focusable(true)
	Controls.focus(settings_button)

## Keep keyboard focus trapped inside the settings panel while it is open.
func _set_menu_focusable(on: bool) -> void:
	for c in $VBox.get_children():
		if c is Button:
			(c as Button).focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE

func _on_volume_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(value, 0.01, 1.0)))

func _on_exit() -> void:
	get_tree().quit()
