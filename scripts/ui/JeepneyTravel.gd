extends Control
## The jeepney drives from the middle of the screen off to the right, then a
## short loading transition leads into the chosen location's Level scene.

@onready var background: TextureRect = $Background
@onready var jeepney: TextureRect = $Jeepney
@onready var loading_label: Label = $LoadingLabel

func _ready() -> void:
	var map_id: String = GameManager.chosen_map_id if GameManager.chosen_map_id != "" else "banaue"
	var tex: Texture2D = load("res://assets/maps/bg_%s.png" % map_id)
	background.texture = tex
	loading_label.visible = false
	Audio.play_loop("engine", -10.0)
	jeepney.position = Vector2(280, 220)
	var tw := create_tween()
	tw.tween_property(jeepney, "position:x", 1050.0, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_on_drive_done)

func _on_drive_done() -> void:
	Audio.stop_loop()
	Audio.play_sfx("horn")
	loading_label.visible = true
	await get_tree().create_timer(1.1).timeout
	get_tree().change_scene_to_file("res://scenes/3d/Level3D.tscn")
