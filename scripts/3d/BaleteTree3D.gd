extends Node3D
## The Kapre's balete tree - the real target of the boss fight. Normal
## rocks just knock on the bark; only CHARGED shots crack it. After enough
## charged hits it shakes, creaks and falls, and `fallen` is emitted.

signal fallen
signal needs_charge

@export var hits_to_fell: int = 4

var hits_taken: int = 0
var is_felled: bool = false
var j: Dictionary = {}
var _hint_cooldown: float = 0.0
var _label: Label3D

func _ready() -> void:
	add_to_group("charged_targets")
	j = Models.balete(self)
	# solid trunk so the player can't walk through it
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 7.0
	cs.shape = cyl
	cs.position = Vector3(0, 3.5, 0)
	body.add_child(cs)
	add_child(body)
	var area := Area3D.new()
	area.set_script(preload("res://scripts/3d/EnemyHit3D.gd"))
	area.set("owner_enemy", self)
	var acs := CollisionShape3D.new()
	var acyl := CylinderShape3D.new()
	acyl.radius = 2.0
	acyl.height = 8.0
	acs.shape = acyl
	acs.position = Vector3(0, 4.0, 0)
	area.add_child(acs)
	add_child(area)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 64
	_label.pixel_size = 0.008
	_label.outline_size = 10
	_label.modulate = Color(1, 0.8, 0.3)
	_label.position = Vector3(0, 13.5, 0)
	add_child(_label)
	_update_label()

func _process(delta: float) -> void:
	_hint_cooldown -= delta

func get_aim_point() -> Vector3:
	return global_position + Vector3(0, 3.0, 0)

func get_target_size() -> float:
	return 2.6

func _update_label() -> void:
	var s := "PUNO  "
	for i in range(hits_to_fell):
		s += "■" if i >= hits_taken else "□"
	_label.text = s

func take_damage(_amount: int, is_charged: bool, _at: Vector3 = Vector3.ZERO) -> void:
	if is_felled:
		return
	var trunk: Node3D = j["trunk"]
	if not is_charged:
		Audio.play_3d("tree_hit", get_aim_point(), -4.0)
		if _hint_cooldown <= 0.0:
			_hint_cooldown = 6.0
			needs_charge.emit()
		return
	hits_taken += 1
	_update_label()
	Audio.play_3d("tree_hit", get_aim_point(), 4.0, 0.7)
	M3.flash(trunk, Color(1, 0.7, 0.3), 0.15)
	FX.puff(get_parent(), get_aim_point(), Color(0.45, 0.32, 0.2), 1.2, 10)
	var tw := create_tween()
	for k in range(4):
		tw.tween_property(trunk, "rotation_degrees:z", 4.0 * (1 if k % 2 == 0 else -1), 0.06)
	tw.tween_property(trunk, "rotation_degrees:z", 0.0, 0.08)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.call("shake", 0.3)
	if hits_taken >= hits_to_fell:
		_fall()

func _fall() -> void:
	is_felled = true
	remove_from_group("charged_targets")
	_label.visible = false
	Audio.play_3d("tree_fall", get_aim_point(), 8.0)
	var trunk: Node3D = j["trunk"]
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(trunk, "rotation_degrees:z", 88.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		FX.puff(get_parent(), global_position + Vector3(-6, 0.5, 0), Color(0.5, 0.42, 0.3), 3.0, 18)
		var rig := get_tree().get_first_node_in_group("camera_rig")
		if rig:
			rig.call("shake", 0.8)
		fallen.emit()
	)
