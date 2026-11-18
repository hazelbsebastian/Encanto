extends Control

@onready var driver: TextureRect = $Driver
@onready var continue_button: Button = $DialogueBox/VBox/ContinueButton

const TALK_FRAMES := [
	preload("res://assets/jeepney/driver_talk_0.png"),
	preload("res://assets/jeepney/driver_talk_1.png"),
]

var _t: float = 0.0

func _ready() -> void:
	# Every playthrough (fresh from the title screen, or "Play Again" from the
	# ending) passes through this scene, so this is the one place a new run
	# is reset - before the map is chosen, so chosen_map_id survives.
	GameManager.reset_run()
	continue_button.pressed.connect(_on_continue)
	Audio.play_sfx("horn")
	Audio.play_music("music_title")
	get_tree().create_timer(0.7).timeout.connect(func() -> void: Audio.play_voice("driver_san_punta"))
	Controls.focus(continue_button)

func _process(delta: float) -> void:
	_t += delta
	driver.texture = TALK_FRAMES[int(_t * 3.0) % 2]

func _on_continue() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/jeepney/MapSelect.tscn")
