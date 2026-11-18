extends Enemy3D
## Kapre - the final boss. A smoking giant that cannot be hurt by rocks.
## He blows rings of tabako smoke at the player (dodge them!), while the
## real target is his balete tree: break it with CHARGED shots (Level
## calls force_defeat() when the tree falls).

const SMOKE_SCRIPT := preload("res://scripts/3d/Smoke3D.gd")

var _attack_t: float = 2.5
## Week 15 fix D04: false during the intro cut-scene (the player cannot move
## yet) and after the tree is felled. Level3D switches it on and off.
var attacking: bool = false
var _laugh_t: float = 4.0

func _build() -> void:
	max_health = 99
	enemy_id = "kapre"
	aim_height = 3.5
	target_size = 2.4
	voice_id = ""
	j = Models.kapre(model)
	model.scale = Vector3.ONE * 1.1
	var body := CapsuleShape3D.new()
	body.radius = 1.2
	body.height = 5.0
	add_body_shape(body, Vector3(0, 2.5, 0))
	var hit := CapsuleShape3D.new()
	hit.radius = 1.4
	hit.height = 5.6
	add_hit_area(hit, Vector3(0, 2.8, 0))

func _ready() -> void:
	super._ready()
	# normal shots must not lock onto the (invulnerable) giant
	remove_from_group("enemies")
	_bar.visible = false

func _think(delta: float) -> void:
	var p := player()
	if p == null:
		return
	face(p.global_position, delta, 2.0)
	velocity.x = 0
	velocity.z = 0
	var torso: Node3D = j["torso"]
	torso.rotation_degrees.z = sin(_anim_t * 1.2) * 3.0
	var ember: Node3D = j["ember"]
	ember.scale = Vector3.ONE * (1.0 + sin(_anim_t * 5.0) * 0.25)
	if not attacking:
		return
	_attack_t -= delta
	if _attack_t <= 0.0:
		_attack_t = randf_range(2.2, 3.6)
		_blow_smoke(p)
	_laugh_t -= delta
	if _laugh_t <= 0.0:
		_laugh_t = randf_range(9.0, 14.0)
		Audio.voice_3d("creature_kapre", get_aim_point(), 6.0)

func _blow_smoke(p: Node3D) -> void:
	var head: Node3D = j["head"]
	var tw := create_tween()
	tw.tween_property(head, "rotation_degrees:x", -15.0, 0.25)
	tw.tween_property(head, "rotation_degrees:x", 8.0, 0.15)
	tw.tween_property(head, "rotation_degrees:x", 0.0, 0.3)
	var mouth := head.global_position + forward() * 1.2 + Vector3(0, -0.3, 0)
	var shots := 1 if randf() < 0.55 else 3
	for i in range(shots):
		var aim := (p.global_position + Vector3(0, 0.9, 0) - mouth).normalized()
		var spread := 0.0 if shots == 1 else (i - 1) * 0.35
		aim = aim.rotated(Vector3.UP, spread + randf_range(-0.12, 0.12))
		var s := Area3D.new()
		s.set_script(SMOKE_SCRIPT)
		s.call("setup", aim)
		get_parent().add_child(s)
		s.global_position = mouth
	Audio.play_3d("smoke_puff", mouth, 4.0)

## The Kapre shrugs off rocks.
func take_damage(_amount: int, _is_charged: bool = false, _at: Vector3 = Vector3.ZERO) -> void:
	M3.flash(model, Color(1, 1, 1), 0.08)
	FX.popup_text(get_parent(), get_aim_point() + Vector3(0, 1.5, 0), "Walang epekto!", Color(0.85, 0.85, 0.85))
	if randf() < 0.3:
		Audio.voice_3d("creature_kapre", get_aim_point(), 4.0)

func force_defeat() -> void:
	if is_dead:
		return
	is_dead = true
	Audio.voice_3d("creature_kapre", get_aim_point(), 6.0, 0.8)
	var tw := create_tween()
	tw.tween_property(model, "rotation_degrees:z", 80.0, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: FX.puff(get_parent(), global_position + Vector3(2, 0.5, 0), Color(0.5, 0.45, 0.4), 2.5, 14))
	tw.tween_interval(0.8)
	tw.tween_property(model, "scale", Vector3.ONE * 0.01, 1.0)
	defeated.emit()
