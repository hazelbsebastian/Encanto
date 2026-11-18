extends CharacterBody3D
## The farmer in 3D: camera-relative movement (WASD / arrows / joystick),
## jump + double jump, a procedurally animated low-poly body, wardrobe
## colours, and hooks used by the HUD (try_jump, set_move_vector) and by
## Shooting3D / PlayerHurtbox3D.

signal died

const RUN_SPEED := 6.5
const ACCEL := 40.0
const AIR_ACCEL := 16.0
const JUMP_VELOCITY := 8.2
const GRAVITY := 22.0
const TURN_SPEED := 12.0

var is_dead: bool = false
var facing: Vector3 = Vector3.FORWARD
var jumps_used: int = 0
var joystick_vec: Vector2 = Vector2.ZERO
var arena_radius: float = 21.0
var controls_enabled: bool = true

var model: Node3D
var j: Dictionary = {}
var shirt_mat := StandardMaterial3D.new()
var pants_mat := StandardMaterial3D.new()

var _anim_t: float = 0.0
var _override: String = ""
var _override_time: float = 0.0
var _was_on_floor: bool = true
var _step_t: float = 0.0
var _victory: bool = false

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 16
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	shape.shape = cap
	shape.position = Vector3(0, 0.88, 0)
	add_child(shape)
	model = M3.pivot(self, Vector3.ZERO, "Model")
	shirt_mat.roughness = 0.9
	pants_mat.roughness = 0.9
	j = Models.farmer(model, shirt_mat, pants_mat)
	apply_outfit()

## Wardrobe: tints the shirt/pants materials and shows the equipped hat.
func apply_outfit() -> void:
	var top: Dictionary = ClothingData.get_item(str(SaveSystem.equipped.get("top", "basic_polo")))
	var bottom: Dictionary = ClothingData.get_item(str(SaveSystem.equipped.get("bottom", "basic_pants")))
	var top_tint: Color = top.get("tint", Color.WHITE)
	var bottom_tint: Color = bottom.get("tint", Color.WHITE)
	shirt_mat.albedo_color = Color(0.96, 0.95, 0.9) * top_tint
	pants_mat.albedo_color = Color(0.42, 0.32, 0.22) * bottom_tint
	var hat: Node3D = j["hat"]
	for c in hat.get_children():
		c.queue_free()
	match str(SaveSystem.equipped.get("accessory", "none")):
		"salakot":
			Models.salakot(hat)
		"kerchief":
			Models.kerchief(hat)

func set_move_vector(v: Vector2) -> void:
	joystick_vec = v

func set_move_axis(v: float) -> void:
	joystick_vec = Vector2(v, 0)

func _input_vector() -> Vector2:
	if not controls_enabled:
		return Vector2.ZERO
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return joystick_vec if joystick_vec.length() > 0.15 else kb

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if is_dead or _victory or not controls_enabled:
		velocity.x = move_toward(velocity.x, 0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0, ACCEL * delta)
		move_and_slide()
		_animate(delta, Vector2(velocity.x, velocity.z).length())
		return

	var input := _input_vector()
	var cam := get_viewport().get_camera_3d()
	var cam_basis := cam.global_transform.basis if cam else Basis.IDENTITY
	var fwd := -cam_basis.z
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	var wish := right * input.x - fwd * input.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target := wish * RUN_SPEED
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if wish.length() > 0.1 and _override != "shoot" and _override != "charge":
		facing = wish.normalized()

	if is_on_floor():
		jumps_used = 0
	if Input.is_action_just_pressed("jump"):
		try_jump()

	move_and_slide()
	_keep_in_arena()

	if is_on_floor() and not _was_on_floor:
		Audio.play_sfx("land", -8.0)
	_was_on_floor = is_on_floor()

	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flat_speed > 1.0:
		_step_t += delta * flat_speed
		if _step_t > 2.2:
			_step_t = 0.0
			Audio.play_sfx("footstep", -14.0, randf_range(0.9, 1.1))
	_animate(delta, flat_speed)

func _keep_in_arena() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > arena_radius:
		flat = flat.normalized() * arena_radius
		global_position.x = flat.x
		global_position.z = flat.y

func try_jump() -> void:
	if is_dead or not controls_enabled:
		return
	var max_jumps := 2 if GameManager.double_jump_unlocked else 1
	if not is_on_floor() and jumps_used == 0:
		jumps_used = 1  # walked off an edge: that counts as the first jump
	if is_on_floor() or jumps_used < max_jumps:
		var first := jumps_used == 0
		velocity.y = JUMP_VELOCITY * (1.0 if first else 0.9)
		jumps_used += 1
		Audio.play_sfx("jump", -2.0, 1.0 if first else 1.25)

func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0
	if d.length() > 0.05:
		facing = d.normalized()
		model.rotation.y = atan2(-facing.x, -facing.z)

func knockback(from: Vector3, strength: float = 6.0) -> void:
	var d := global_position - from
	d.y = 0
	d = d.normalized() if d.length() > 0.01 else -facing
	velocity += d * strength + Vector3.UP * 4.0

func set_temporary_animation(anim_name: String, duration: float) -> void:
	if _override == "death":
		return
	_override = anim_name
	_override_time = duration

func play_death() -> void:
	is_dead = true
	_override = "death"
	_override_time = 0.0
	died.emit()

func play_victory() -> void:
	_victory = true
	_override = "victory"
	_override_time = 999.0

func clear_victory() -> void:
	_victory = false
	_override = ""

# ------------------------------------------------------------ animation --
func _animate(delta: float, speed: float) -> void:
	_anim_t += delta
	if _override_time > 0.0:
		_override_time -= delta
		if _override_time <= 0.0 and _override != "death":
			_override = ""
	var target_yaw := atan2(-facing.x, -facing.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0, 1))

	var body: Node3D = j["body"]
	var torso: Node3D = j["torso"]
	var hl: Node3D = j["hip_l"]
	var hr: Node3D = j["hip_r"]
	var sl: Node3D = j["sh_l"]
	var sr: Node3D = j["sh_r"]
	var gun: Node3D = j["gun"]
	var k := clampf(12.0 * delta, 0, 1)

	var leg_l := 0.0
	var leg_r := 0.0
	var arm_l := 0.0
	var arm_r := 0.0
	var arm_l_z := 0.0
	var arm_r_z := 0.0
	var lean := 0.0
	var bob := 0.0
	var body_x := 0.0
	if _override == "death":
		body_x = -85.0
		bob = 0.15
	elif _override == "victory":
		arm_l = 170.0 + sin(_anim_t * 8.0) * 12.0
		arm_r = 170.0 - sin(_anim_t * 8.0) * 12.0
		arm_l_z = -20.0
		arm_r_z = 20.0
		bob = absf(sin(_anim_t * 6.0)) * 0.12
	elif not is_on_floor():
		leg_l = 35.0
		leg_r = -20.0
		arm_l = 120.0
		arm_r = 100.0
		arm_l_z = -30.0
		arm_r_z = 30.0
	elif speed > 0.5:
		var ph := _anim_t * (6.0 + speed * 1.1)
		var amp := clampf(speed / RUN_SPEED, 0.3, 1.0)
		leg_l = sin(ph) * 45.0 * amp
		leg_r = -sin(ph) * 45.0 * amp
		arm_l = -sin(ph) * 40.0 * amp
		arm_r = sin(ph) * 40.0 * amp
		lean = -10.0 * amp
		bob = absf(sin(ph)) * 0.06 * amp
	else:
		bob = sin(_anim_t * 2.2) * 0.012
		arm_l_z = -4.0
		arm_r_z = 4.0
	if _override == "shoot":
		arm_r = 85.0
		arm_r_z = 0.0
		lean = -4.0
	elif _override == "hurt":
		lean = 18.0
		arm_l = 40.0
		arm_r = 40.0
	elif _override == "charge":
		arm_r = 80.0
		arm_l = 70.0
		arm_l_z = 20.0

	hl.rotation_degrees.x = lerpf(hl.rotation_degrees.x, leg_l, k)
	hr.rotation_degrees.x = lerpf(hr.rotation_degrees.x, leg_r, k)
	sl.rotation_degrees.x = lerpf(sl.rotation_degrees.x, arm_l, k)
	sr.rotation_degrees.x = lerpf(sr.rotation_degrees.x, arm_r, k)
	sl.rotation_degrees.z = lerpf(sl.rotation_degrees.z, arm_l_z - 6.0, k)
	sr.rotation_degrees.z = lerpf(sr.rotation_degrees.z, arm_r_z + 6.0, k)
	torso.rotation_degrees.x = lerpf(torso.rotation_degrees.x, lean, k)
	body.rotation_degrees.x = lerpf(body.rotation_degrees.x, body_x, clampf(5.0 * delta, 0, 1))
	body.position.y = lerpf(body.position.y, bob, k)
	var aiming := _override == "shoot" or _override == "charge"
	gun.rotation_degrees.x = lerpf(gun.rotation_degrees.x, -85.0 if aiming else 0.0, k)
