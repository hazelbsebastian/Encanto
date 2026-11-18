extends CanvasLayer
## Pause menu - opened with Esc / P / gamepad Start, or the on-screen pause
## button. Resume, adjust volume, see the controls, or quit to the title.

var _volume: HSlider

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	UIKit.dim(self, 0.6)
	var panel := UIKit.centered_panel(self, Vector2(420, 0))
	UIKit.pop_in(panel)
	var v := UIKit.vbox(panel, 12)
	UIKit.label(v, "NAKAHINTO", "HeaderLabel", 34)
	UIKit.label(v, "Paused", "HintLabel", 14)

	var resume := UIKit.button(v, "Ituloy ang Laro", true, UIKit.MIN_TOUCH)
	resume.pressed.connect(_resume)

	var vol_row := UIKit.hbox(v, 12)
	UIKit.label(vol_row, "Lakas ng tunog", "", 16, false)
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.custom_minimum_size = Vector2(200, 40)
	_volume.value = SaveSystem.volume
	_volume.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_volume)

	var quit := UIKit.button(v, "Bumalik sa Main Menu", false, UIKit.MIN_TOUCH)
	quit.pressed.connect(_quit)

	var controls := PanelContainer.new()
	controls.theme_type_variation = "CardPanel"
	v.add_child(controls)
	# Week 14: describe the controls the player is actually using
	var help := "GALAW: joystick sa kaliwa    TALON: berdeng button\nTIRA: pulang button (hawakan para mag-charge)\nCamera: i-drag ang screen    HINTO: II sa itaas"
	if not Controls.touch_mode:
		help = "Galaw: WASD o ← ↑ → ↓    Talon: SPACE\nTira: X (hawakan para mag-charge)\nCamera: Q / E o i-drag ang screen    Hinto: ESC / P"
	UIKit.label(controls, help, "HintLabel", 15)

	Controls.focus(resume)

func _on_volume_changed(value: float) -> void:
	SaveSystem.set_volume(value)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()

func _resume() -> void:
	SaveSystem.save_game()
	Audio.play_sfx("click")
	get_tree().paused = false
	queue_free()

func _quit() -> void:
	SaveSystem.save_game()
	Audio.play_sfx("click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/Title.tscn")
