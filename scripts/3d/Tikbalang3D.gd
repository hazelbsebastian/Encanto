extends Enemy3D
## Tikbalang: tall horse-headed trickster. Stalks the player, then REARS UP
## (telegraph + whinny) and CHARGES in a straight line. Side-step the charge
## or double-jump over it (the double jump unlocks for this stage).

const SPEED := 3.6
const CHARGE_SPEED := 13.0

var _attack_t: float = 0.0
var _state: String = "stalk"
var _charge_dir: Vector3 = Vector3.FORWARD
var _state_t: float = 0.0

func _build() -> void:
	max_health = 3
	enemy_id = "tikbalang"
	aim_height = 1.5
	target_size = 1.1
	voice_id = "creature_tikbalang"
	voice_interval = Vector2(8, 13)
	j = Models.tikbalang(model)
	var body := CapsuleShape3D.new()
	body.radius = 0.4
	body.height = 2.6
	add_body_shape(body, Vector3(0, 1.3, 0))
	var hit := CapsuleShape3D.new()
	hit.radius = 0.55
	hit.height = 2.8
	add_hit_area(hit, Vector3(0, 1.4, 0))
	_attack_t = randf_range(2.0, 3.5)

func _think(delta: float) -> void:
	var p := player()
	if p == null:
		return
	_state_t += delta
	var hl: Node3D = j["hip_l"]
	var hr: Node3D = j["hip_r"]
	var torso: Node3D = j["torso"]
	var sl: Node3D = j["sh_l"]
	var sr: Node3D = j["sh_r"]
	match _state:
		"stalk":
			var d := face(p.global_position, delta, 5.0)
			var dist := global_position.distance_to(p.global_position)
			var want := d * SPEED if dist > 3.0 else -d * 1.5
			velocity.x = move_toward(velocity.x, want.x, 10 * delta)
			velocity.z = move_toward(velocity.z, want.z, 10 * delta)
			var ph := _anim_t * 8.0
			hl.rotation_degrees.x = sin(ph) * 30.0
			hr.rotation_degrees.x = -sin(ph) * 30.0
			sl.rotation_degrees.x = -sin(ph) * 25.0
			sr.rotation_degrees.x = sin(ph) * 25.0
			torso.rotation_degrees.x = lerpf(torso.rotation_degrees.x, -8.0, 6 * delta)
			_attack_t -= delta
			if _attack_t <= 0.0 and dist < 11.0:
				_state = "rear"
				_state_t = 0.0
				velocity = Vector3.ZERO
				Audio.voice_3d("creature_tikbalang", get_aim_point(), 4.0)
		"rear":
			_charge_dir = face(p.global_position, delta, 10.0)
			torso.rotation_degrees.x = lerpf(torso.rotation_degrees.x, 22.0, 10 * delta)
			sl.rotation_degrees.x = lerpf(sl.rotation_degrees.x, 150.0, 10 * delta)
			sr.rotation_degrees.x = lerpf(sr.rotation_degrees.x, 150.0, 10 * delta)
			if _state_t > 0.7:
				if _charge_dir == Vector3.ZERO:
					_charge_dir = forward()
				_state = "charge"
				_state_t = 0.0
				Audio.play_3d("gallop", global_position, 2.0)
				Audio.play_3d("whoosh", global_position)
				spawn_attack_hitbox(Vector3(0, 1.2, -0.6), Vector3(1.4, 2.2, 1.4), 0.7, true)
		"charge":
			velocity.x = _charge_dir.x * CHARGE_SPEED
			velocity.z = _charge_dir.z * CHARGE_SPEED
			torso.rotation_degrees.x = lerpf(torso.rotation_degrees.x, -28.0, 12 * delta)
			sl.rotation_degrees.x = lerpf(sl.rotation_degrees.x, 70.0, 12 * delta)
			sr.rotation_degrees.x = lerpf(sr.rotation_degrees.x, 70.0, 12 * delta)
			var ph := _anim_t * 16.0
			hl.rotation_degrees.x = sin(ph) * 50.0
			hr.rotation_degrees.x = -sin(ph) * 50.0
			if _state_t > 0.7:
				_state = "recover"
				_state_t = 0.0
		"recover":
			velocity.x = move_toward(velocity.x, 0, 25 * delta)
			velocity.z = move_toward(velocity.z, 0, 25 * delta)
			torso.rotation_degrees.x = lerpf(torso.rotation_degrees.x, 0.0, 6 * delta)
			if _state_t > 0.9:
				_state = "stalk"
				_attack_t = randf_range(2.8, 4.2)
