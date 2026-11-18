extends Enemy3D
## Manananggal: the torso flies on bat wings, circling above the player and
## DIVING at them; the separated lower body walks the ground and KICKS.
## Both halves share one health pool - hitting either one hurts her.

const WALK_SPEED := 2.6
const ORBIT_RADIUS := 5.5
const FLY_HEIGHT := 3.6

var upper: Node3D
var ju: Dictionary = {}
var _dive_t: float = 0.0
var _diving: bool = false
var _kick_t: float = 0.0
var _orbit_a: float = 0.0
var _flap_t: float = 0.0
var _flap_count: int = 0

func _build() -> void:
	max_health = 4
	enemy_id = "manananggal"
	aim_height = 1.0
	target_size = 1.0
	voice_id = "creature_manananggal"
	voice_interval = Vector2(7, 12)
	j = Models.manananggal_lower(model)
	var legs := CapsuleShape3D.new()
	legs.radius = 0.3
	legs.height = 1.2
	add_body_shape(legs, Vector3(0, 0.6, 0))
	var hit_low := CapsuleShape3D.new()
	hit_low.radius = 0.4
	hit_low.height = 1.3
	add_hit_area(hit_low, Vector3(0, 0.65, 0))
	# the flying torso moves independently of the legs
	upper = Node3D.new()
	upper.name = "UpperBody"
	upper.top_level = true
	add_child(upper)
	ju = Models.manananggal_upper(upper)
	var hit_up := SphereShape3D.new()
	hit_up.radius = 0.75
	add_hit_area(hit_up, Vector3(0, 0.1, 0), upper)
	_orbit_a = randf() * TAU
	_dive_t = randf_range(3.0, 5.0)
	_kick_t = randf_range(2.0, 4.0)
	upper.global_position = global_position + Vector3(0, FLY_HEIGHT, 0)

func get_aim_point() -> Vector3:
	return upper.global_position if is_instance_valid(upper) else global_position + Vector3(0, 1, 0)

func _think(delta: float) -> void:
	var p := player()
	if p == null:
		return
	# ---- lower body: walk + kick
	var d := face(p.global_position, delta, 6.0)
	var dist := global_position.distance_to(p.global_position)
	_kick_t -= delta
	if _kick_t <= 0.0 and dist < 1.9:
		_kick_t = randf_range(3.0, 4.5)
		var kick_leg: Node3D = j["hip_r"]
		var tw := create_tween()
		tw.tween_property(kick_leg, "rotation_degrees:x", 80.0, 0.12)
		tw.tween_property(kick_leg, "rotation_degrees:x", 0.0, 0.3)
		spawn_attack_hitbox(Vector3(0, 0.6, -0.8), Vector3(1.0, 1.0, 1.0), 0.3)
	var want := d * WALK_SPEED if dist > 1.4 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, want.x, 12 * delta)
	velocity.z = move_toward(velocity.z, want.z, 12 * delta)
	var ph := _anim_t * 7.0
	var hl: Node3D = j["hip_l"]
	var hr: Node3D = j["hip_r"]
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	hl.rotation_degrees.x = sin(ph) * 35.0 if moving else 0.0
	if _kick_t > 0.4:
		hr.rotation_degrees.x = -sin(ph) * 35.0 if moving else 0.0

	# ---- upper body: flap, orbit, bob, dive
	_flap_t += delta * (9.0 if not _diving else 3.0)
	var wings: Array = ju["wings"]
	for i in range(wings.size()):
		var w: Node3D = wings[i]
		w.rotation_degrees.z = sin(_flap_t) * 40.0 * (1.0 if i == 0 else -1.0)
	var flaps := int(_flap_t / TAU)
	if flaps != _flap_count:
		_flap_count = flaps
		if not _diving:
			Audio.play_3d("wing_flap", upper.global_position, -10.0)
	if not _diving:
		_orbit_a += delta * 0.6
		var goal := p.global_position + Vector3(cos(_orbit_a) * ORBIT_RADIUS, FLY_HEIGHT + sin(_anim_t * 2.0) * 0.4, sin(_orbit_a) * ORBIT_RADIUS)
		upper.global_position = upper.global_position.lerp(goal, clampf(2.0 * delta, 0, 1))
		var look := p.global_position - upper.global_position
		look.y = 0
		if look.length() > 0.1:
			upper.rotation.y = lerp_angle(upper.rotation.y, atan2(-look.x, -look.z), clampf(6 * delta, 0, 1))
		_dive_t -= delta
		if _dive_t <= 0.0:
			_start_dive(p)

func _start_dive(p: Node3D) -> void:
	_diving = true
	_dive_t = randf_range(4.0, 6.0)
	Audio.voice_3d("creature_manananggal", upper.global_position, 3.0)
	Audio.play_3d("whoosh", upper.global_position)
	var target := p.global_position + Vector3(0, 0.9, 0)
	var overshoot := upper.global_position.lerp(target, 1.35)
	overshoot.y = maxf(0.8, overshoot.y)
	var body: Node3D = ju["body"]
	var tw := create_tween()
	tw.tween_property(body, "rotation_degrees:x", -50.0, 0.25)
	tw.tween_interval(0.35)  # telegraph: she hangs in the air, then swoops
	tw.tween_callback(_dive_hitbox)
	tw.tween_property(upper, "global_position", overshoot, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "rotation_degrees:x", 0.0, 0.3)
	tw.tween_callback(func() -> void: _diving = false)

func _dive_hitbox() -> void:
	if is_dead or not is_instance_valid(upper):
		return
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.9
	cs.shape = sph
	area.add_child(cs)
	upper.add_child(area)
	get_tree().create_timer(0.7, false).timeout.connect(area.queue_free)

func _play_death() -> void:
	super._play_death()
	if is_instance_valid(upper):
		var tw := upper.create_tween()
		var ground := Vector3(upper.global_position.x, 0.3, upper.global_position.z)
		tw.tween_property(upper, "global_position", ground, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(upper, "scale", Vector3.ONE * 0.01, 0.5)
