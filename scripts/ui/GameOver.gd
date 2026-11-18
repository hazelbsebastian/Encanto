extends CanvasLayer
## Shown when the player's hearts reach zero. Pauses the game and offers a
## restart of the current location from the first enemy stage.

@onready var try_again_button: Button = $Panel/VBox/TryAgainButton
@onready var quit_button: Button = $Panel/VBox/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	try_again_button.pressed.connect(_on_try_again)
	quit_button.pressed.connect(_on_quit)
	Controls.focus(try_again_button)

func _on_try_again() -> void:
	Audio.play_sfx("click")
	get_tree().paused = false
	GameManager.restart_after_death()
	get_tree().reload_current_scene()

func _on_quit() -> void:
	Audio.play_sfx("click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/Title.tscn")
