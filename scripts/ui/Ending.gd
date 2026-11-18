extends Control
## Plays right after the Kapre falls: victory lines, then the player boards
## the jeepney again and rides off before handing over to the reward screen.

@onready var background: TextureRect = $Background
@onready var line_label: Label = $LinePanel/LineLabel
@onready var jeepney: TextureRect = $Jeepney
@onready var victory_img: TextureRect = $VictoryImage

func _ready() -> void:
	var map_id: String = GameManager.chosen_map_id if GameManager.chosen_map_id != "" else "banaue"
	background.texture = load("res://assets/maps/bg_%s.png" % map_id)
	jeepney.visible = false
	Audio.play_sfx("victory")
	line_label.text = "\"Kongrats! Natalo mo ang Kapre!\""
	await get_tree().create_timer(2.4).timeout
	if not is_instance_valid(self):
		return
	line_label.text = "\"Natapos mo ang iyong paglalakbay!\""
	await get_tree().create_timer(2.4).timeout
	if not is_instance_valid(self):
		return
	victory_img.visible = false
	jeepney.visible = true
	jeepney.position = Vector2(300, 220)
	Audio.play_loop("engine", -10.0)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(jeepney, "position:x", 1050.0, 1.8)
	tw.tween_callback(_on_done)

func _on_done() -> void:
	Audio.stop_loop()
	get_tree().change_scene_to_file("res://scenes/ui/RewardScreen.tscn")
