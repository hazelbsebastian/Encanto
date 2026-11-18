extends Node
## The sumpak (bamboo rock-shooter) in 3D.
## - Tap SHOOT / X: a rock auto-aims at the nearest creature (a gold ring
##   marks the current target) and builds the shot streak.
## - After 5 in a row "CHARGE READY": HOLD to charge, release for a big
##   rock. Charged shots prefer the Kapre's balete tree - the only thing
##   that can break it.
## The HUD calls shoot_button_down/up for the touch button.

const ROCK_SCRIPT := preload("res://scripts/3d/Rock3D.gd")
const CHARGE_MAX_TIME := 1.2
const NORMAL_DAMAGE := 1
const CHARGED_DAMAGE := 3
const TARGET_RANGE := 24.0

@onready var player: CharacterBody3D = get_parent()

var is_charging: bool = false
var charge_time: float = 0.0
var _prev_key_down: bool = false
var _target: Node3D = null
var _retarget_t: float = 0.0
var _marker: Node3D
var _charge_orb: MeshInstance3D
var _charge_light: OmniLight3D

func _ready() -> void:
	_marker = Node3D.new()
	_marker.top_level = true
	player.add_child.call_deferred(_marker)
	M3.torus(_marker, 0.55, 0.7, M3.mat(Color(1, 0.8, 0.25), 0.4, 2.0), Vector3(0, 0.05, 0))
	M3.torus(_marker, 0.85, 0.92, M3.mat(Color(1, 0.9, 0.5, 0.6), 0.4, 1.5), Vector3(0, 0.05, 0))
	_marker.visible = false

func _process(delta: float) -> void:
	# keyboard / gamepad "shoot" action alongside the on-screen button
	var key_down := Input.is_action_pressed("shoot")
	if key_down and not _prev_key_down:
		shoot_button_down()
	elif not key_down and _prev_key_down:
		shoot_button_up()
	_prev_key_down = key_down

	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = 0.12
		var t := _find_target(false)
		if t != _target and t != null:
			Audio.play_sfx("lock_on", -12.0)
		_target = t
	if is_instance_valid(_target) and not bool(player.get("is_dead")):
		_marker.visible = true
		var p := _target.global_position
		_marker.global_position = Vector3(p.x, p.y + 0.02, p.z)
		_marker.rotate_y(delta * 2.0)
		var s := 1.0 + sin(Time.get_ticks_msec() / 180.0) * 0.06
		_marker.scale = Vector3(s, 1, s) * _target_size(_target)
	else:
		_marker.visible = false

	if is_charging:
		charge_time = minf(CHARGE_MAX_TIME, charge_time + delta)
		var t := charge_time / CHARGE_MAX_TIME
		player.call("set_temporary_animation", "charge", 0.2)
		if is_instance_valid(_charge_orb):
			_charge_orb.scale = Vector3.ONE * (0.4 + t * 1.2)
			_charge_light.light_energy = 1.0 + t * 3.0

func _target_size(t: Node3D) -> float:
	if t.has_method("get_target_size"):
		return float(t.call("get_target_size"))
	return 1.0

func shoot_button_down() -> void:
	if bool(player.get("is_dead")) or not bool(player.get("controls_enabled")):
		return
	if GameManager.charge_unlocked:
		is_charging = true
		charge_time = 0.0
		Audio.play_sfx("charge")
		_spawn_charge_orb()
	else:
		_fire(false, 0.0)

func shoot_button_up() -> void:
	if not is_charging:
		return
	is_charging = false
	_fire(true, charge_time / CHARGE_MAX_TIME)
	if is_instance_valid(_charge_orb):
		_charge_orb.queue_free()
	GameManager.reset_streak_lock()

func _spawn_charge_orb() -> void:
	var muzzle: Node3D = player.get("j")["muzzle"]
	_charge_orb = M3.sphere(muzzle, 0.14, M3.mat(Color(1, 0.62, 0.2, 0.85), 0.3, 3.0), Vector3.ZERO, Vector3.ONE, 12)
	_charge_light = OmniLight3D.new()
	_charge_light.light_color = Color(1, 0.6, 0.2)
	_charge_light.omni_range = 3.0
	_charge_orb.add_child(_charge_light)

func _fire(charged: bool, power: float) -> void:
	if bool(player.get("is_dead")):
		return
	var target := _find_target(charged)
	var muzzle: Node3D = player.get("j")["muzzle"]
	var from := muzzle.global_position
	var dir: Vector3 = player.get("facing")
	if target:
		player.call("face_towards", target.global_position)
		from = muzzle.global_position
		dir = (_aim_point(target) - from).normalized()
	player.call("set_temporary_animation", "shoot", 0.25)
	var rock := Area3D.new()
	rock.set_script(ROCK_SCRIPT)
	get_tree().current_scene.add_child(rock)
	rock.global_position = from
	var dmg := NORMAL_DAMAGE if not charged else int(ceil(CHARGED_DAMAGE * maxf(0.4, power)))
	rock.call("setup", dir, dmg, charged)
	if charged:
		Audio.play_sfx("charge_release")
		var rig := get_tree().get_first_node_in_group("camera_rig")
		if rig:
			rig.call("shake", 0.2)
	else:
		Audio.play_sfx("shoot", 0.0, randf_range(0.95, 1.08))
	GameManager.register_shot(charged)

func _aim_point(t: Node3D) -> Vector3:
	if t.has_method("get_aim_point"):
		return t.call("get_aim_point")
	return t.global_position + Vector3(0, 0.8, 0)

## Charged shots prefer the boss tree ("charged_targets"); otherwise the
## nearest living creature in range.
func _find_target(charged: bool) -> Node3D:
	var best: Node3D = null
	var best_d := TARGET_RANGE
	if charged:
		for t in get_tree().get_nodes_in_group("charged_targets"):
			var n := t as Node3D
			if n and is_instance_valid(n):
				var d := player.global_position.distance_to(n.global_position)
				if d < 40.0:
					return n
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var d := player.global_position.distance_to(_aim_point(n))
		if d < best_d:
			best_d = d
			best = n
	return best
