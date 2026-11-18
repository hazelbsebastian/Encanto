extends Area3D
## A rock fired from the sumpak. Flies straight (slight drop), hits enemy
## hit-areas (layer 2) or the ground/world (layer 16), with an impact puff.

const SPEED := 24.0
const CHARGED_SPEED := 28.0
const LIFETIME := 1.8

var direction: Vector3 = Vector3.FORWARD
var damage: int = 1
var is_charged: bool = false
var _life: float = 0.0
var _vel: Vector3
var _done: bool = false

func setup(dir: Vector3, dmg: int, charged: bool) -> void:
	direction = dir.normalized()
	damage = dmg
	is_charged = charged
	_vel = direction * (CHARGED_SPEED if charged else SPEED)
	var r := 0.16 if charged else 0.09
	var col := Color(1, 0.62, 0.25) if charged else Color(0.55, 0.52, 0.48)
	Models.rock(self, Vector3.ZERO, r, col)
	if charged:
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.6, 0.2)
		l.light_energy = 2.5
		l.omni_range = 3.0
		add_child(l)
		M3.sphere(self, r * 1.8, M3.mat(Color(1, 0.7, 0.3, 0.35), 0.3, 2.0), Vector3.ZERO, Vector3.ONE, 10)
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r * 2.2
	shape.shape = sph
	add_child(shape)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 | 16
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_vel.y -= 2.0 * delta
	global_position += _vel * delta
	rotation += Vector3(8, 5, 3) * delta
	_life += delta
	if _life > LIFETIME:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _done or not area.has_method("receive_hit"):
		return
	area.call("receive_hit", damage, is_charged, global_position)
	_impact(true)

func _on_body_entered(_body: Node3D) -> void:
	if not _done:
		_impact(false)

func _impact(hit_enemy: bool) -> void:
	_done = true
	# Week 14 (playtest P3: "could not tell whether my action was successful"):
	# a hit is always audible (not distance-faded) and a miss is marked.
	if hit_enemy:
		Audio.play_sfx("rock_hit")
	else:
		FX.popup_text(get_tree().current_scene, global_position + Vector3(0, 0.6, 0), "MINTIS", Color(0.82, 0.82, 0.82))
	FX.puff(get_tree().current_scene, global_position, Color(1, 0.8, 0.4) if is_charged else Color(0.85, 0.8, 0.7), 0.6 if is_charged else 0.3)
	queue_free()
