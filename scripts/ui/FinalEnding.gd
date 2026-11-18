extends Control

func _ready() -> void:
	$VBox/PlayAgainButton.pressed.connect(_on_play_again)
	$VBox/WardrobeButton.pressed.connect(_on_wardrobe)
	$VBox/MainMenuButton.pressed.connect(_on_main_menu)
	Audio.play_sfx("victory")
	Controls.focus($VBox/PlayAgainButton)

func _on_play_again() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/jeepney/JeepneyIntro.tscn")

func _on_wardrobe() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/Wardrobe.tscn")

func _on_main_menu() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/main/Title.tscn")
