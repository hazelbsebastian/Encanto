extends Area3D
## The Kapre's tabako smoke ring: drifts toward where the player was,
## grows and fades. Touching it costs a heart (layer 8).

const SPEED := 6.5
const LIFETIME := 3.4

var direction: Vector3 = Vector3.FORWARD
var _life: float = 0.0
var _mat := StandardMaterial3D.new()
var _visual: Node3D

func setup(dir: Vector3) -> void:
	direction = dir.normalized()

func _ready() -> void:
	add_to_group("boss_smoke")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.7
	cs.shape = sph
	add_child(cs)
	_mat.albedo_color = Color(0.78, 0.78, 0.8, 0.8)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 1.0
	_visual = Node3D.new()
	add_child(_visual)
	M3.torus(_visual, 0.35, 0.75, _mat, Vector3.ZERO, Vector3(90, 0, 0))
	for k in range(5):
		M3.sphere(_visual, randf_range(0.25, 0.4), _mat, Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), Vector3.ONE, 8)

func _physics_process(delta: float) -> void:
	_life += delta
	global_position += direction * SPEED * delta
	if global_position.y > 0.9:
		global_position.y -= 1.2 * delta
	_visual.rotation.y += delta * 2.0
	_visual.scale = Vector3.ONE * (0.8 + _life * 0.35)
	_mat.albedo_color.a = clampf(0.85 - _life / LIFETIME * 0.8, 0.05, 0.85)
	if _life > LIFETIME:
		queue_free()
