extends Enemy3D
## Tyanak: small, fast, crawls toward the player and LUNGES with a bite.
## Dodge by jumping over it or side-stepping the lunge.

const SPEED := 3.4
const LUNGE_RANGE := 3.0

var _attack_t: float = 0.0
var _lunging: bool = false

func _build() -> void:
	max_health = 2
	enemy_id = "tyanak"
	aim_height = 0.35
	target_size = 0.7
	voice_id = "creature_tyanak"
	voice_interval = Vector2(5, 10)
	j = Models.tyanak(model)
	model.get_child(0).scale = Vector3.ONE * 1.35
	var body := CapsuleShape3D.new()
	body.radius = 0.3
	body.height = 0.8
	add_body_shape(body, Vector3(0, 0.35, 0))
	var hit := SphereShape3D.new()
	hit.radius = 0.5
	add_hit_area(hit, Vector3(0, 0.35, 0))
	_attack_t = randf_range(1.5, 3.0)

func _think(delta: float) -> void:
	var p := player()
	if p == null:
		return
	var d := face(p.global_position, delta, 10.0)
	var dist := global_position.distance_to(p.global_position)
	_attack_t -= delta
	if _lunging:
		if is_on_floor() and velocity.y <= 0.0:
			_lunging = false
	elif _attack_t <= 0.0 and dist < LUNGE_RANGE:
		_lunge(d)
	else:
		var want := d * SPEED if dist > 1.2 else Vector3.ZERO
		velocity.x = move_toward(velocity.x, want.x, 20 * delta)
		velocity.z = move_toward(velocity.z, want.z, 20 * delta)
	# crawl animation
	var ph := _anim_t * 12.0
	var limbs: Array = j["limbs"]
	for i in range(limbs.size()):
		var l: Node3D = limbs[i]
		var offset := PI if (i == 1 or i == 2) else 0.0
		l.rotation_degrees.x = sin(ph + offset) * 35.0
	var head: Node3D = j["head"]
	head.rotation_degrees.z = sin(_anim_t * 3.0) * 8.0

func _lunge(dir: Vector3) -> void:
	_lunging = true
	_attack_t = randf_range(2.4, 3.8)
	velocity = dir * 8.0 + Vector3.UP * 5.0
	Audio.voice_3d("creature_tyanak", get_aim_point(), 2.0, 1.2)
	spawn_attack_hitbox(Vector3(0, 0.35, -0.5), Vector3(0.9, 0.7, 1.0), 0.45, true)
