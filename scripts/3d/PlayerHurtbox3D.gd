extends Area3D
## Player hurtbox: enemy attack hitboxes and the Kapre's smoke live on
## physics layer 8. Taking a hit costs a heart, knocks the farmer back and
## gives a short blinking invulnerability window.

signal player_died

const INVULN_TIME := 1.1

var invulnerable: bool = false
var _flash_time: float = 0.0

@onready var player: CharacterBody3D = get_parent()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 8
	monitorable = false
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0, 0.88, 0)
	add_child(shape)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	var model := player.get("model") as Node3D
	if model == null:
		return
	if invulnerable and not bool(player.get("is_dead")):
		_flash_time += delta
		model.visible = int(_flash_time * 14.0) % 2 == 0
	else:
		model.visible = true

func _on_area_entered(area: Area3D) -> void:
	if invulnerable or bool(player.get("is_dead")):
		return
	Audio.play_sfx("damage")
	Audio.play_voice("player_aray")
	player.call("set_temporary_animation", "hurt", 0.35)
	player.call("knockback", area.global_position, 7.0)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.call("shake", 0.35)
	var dead := GameManager.damage_player(1)
	invulnerable = true
	_flash_time = 0.0
	get_tree().create_timer(INVULN_TIME, false).timeout.connect(func() -> void: invulnerable = false)
	if dead:
		player.call("play_death")
		Audio.play_sfx("game_over")
		player_died.emit()
