extends Node3D
## Third-person chase camera. Follows the player smoothly; turn it with
## Q / E, the right stick, or by dragging anywhere on the screen (touch or
## mouse - the HUD's look area forwards drags to add_look()). Supports
## screen shake and scripted "cinematic" shots for cutscenes.

const DISTANCE := 8.0
const HEIGHT := 1.5
const TURN_SPEED := 2.4

var target: Node3D
var yaw: float = 0.0
var pitch: float = deg_to_rad(-22.0)
var cinematic: bool = false

var _cam: Camera3D
var _shake: float = 0.0
var _focus: Vector3
var _from: Transform3D
var _to: Transform3D
var _following: bool = false

func _ready() -> void:
	add_to_group("camera_rig")
	top_level = true
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.1
	_cam.far = 600.0
	add_child(_cam)
	_cam.current = true

func camera() -> Camera3D:
	return _cam

func snap() -> void:
	if target:
		_focus = target.global_position + Vector3(0, HEIGHT, 0)
		_place(1.0)

## Drag-to-look from the HUD (pixels).
func add_look(delta_px: Vector2) -> void:
	yaw -= delta_px.x * 0.006
	pitch = clampf(pitch - delta_px.y * 0.004, deg_to_rad(-55), deg_to_rad(-5))

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if cinematic:
		return
	var turn := Input.get_axis("camera_left", "camera_right")
	yaw -= turn * TURN_SPEED * delta
	if target:
		var goal := target.global_position + Vector3(0, HEIGHT, 0)
		_focus = _focus.lerp(goal, clampf(8.0 * delta, 0, 1))
	_place(delta)

func _place(delta: float) -> void:
	var offset := Vector3(0, 0, DISTANCE).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	global_position = _focus
	_cam.global_position = _focus + offset
	_cam.look_at(_focus, Vector3.UP)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
		_cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.35

## Fly the camera to a shot (position + look target) over `time` seconds.
func cinematic_to(pos: Vector3, look: Vector3, time: float = 1.5) -> Tween:
	cinematic = true
	_from = _cam.global_transform
	_to = Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)
	_following = false
	var tw := create_tween()
	tw.tween_method(_blend, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Return from a cinematic shot to following the player.
func release(time: float = 1.0) -> void:
	if not cinematic:
		return
	_from = _cam.global_transform
	_following = true
	var tw := create_tween()
	tw.tween_method(_blend, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_end_cinematic)

func _blend(t: float) -> void:
	if _following:
		var offset := Vector3(0, 0, DISTANCE).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
		var goal := (target.global_position + Vector3(0, HEIGHT, 0)) if target else _focus
		_to = Transform3D(Basis.IDENTITY, goal + offset).looking_at(goal, Vector3.UP)
	_cam.global_transform = _from.interpolate_with(_to, t)

func _end_cinematic() -> void:
	cinematic = false
	snap()
