extends Node
## Handles the Palsuot/Sumpak weapon: auto-targeted normal shots that build a
## streak, and a manually-aimed charged shot once the streak unlocks it.
## Attach to a plain Node child of the Player so movement/health stay
## in their own scripts.

const ROCK_SCENE := preload("res://scenes/player/RockProjectile.tscn")
const CHARGE_MAX_TIME := 1.2
const NORMAL_DAMAGE := 1
const CHARGED_DAMAGE := 3
const AUTO_TARGET_RANGE := 520.0
const CHARGE_TEXTURES := [
	preload("res://assets/ui/effect_charge_0.png"),
	preload("res://assets/ui/effect_charge_1.png"),
	preload("res://assets/ui/effect_charge_2.png"),
]

@onready var player: CharacterBody2D = get_parent()
@onready var muzzle: Marker2D = get_parent().get_node("MuzzlePoint")
@onready var charge_effect: Sprite2D = get_parent().get_node("ChargeEffect")

var is_charging: bool = false
var charge_time: float = 0.0
var _prev_key_down: bool = false

func _process(delta: float) -> void:
	# Keyboard / gamepad "shoot" action alongside the on-screen shoot button.
	var key_down := Input.is_action_pressed("shoot")
	if key_down and not _prev_key_down:
		shoot_button_down()
	elif not key_down and _prev_key_down:
		shoot_button_up()
	_prev_key_down = key_down

	if is_charging:
		charge_time = min(CHARGE_MAX_TIME, charge_time + delta)
		var t := charge_time / CHARGE_MAX_TIME
		charge_effect.visible = true
		charge_effect.scale = Vector2.ONE * (0.6 + t * 1.4) * 0.5
		charge_effect.texture = CHARGE_TEXTURES[clampi(int(t * 3.0), 0, 2)]
		charge_effect.position = Vector2(14 * player.facing_dir, -14)

func shoot_button_down() -> void:
	if player.is_dead:
		return
	if GameManager.charge_unlocked:
		is_charging = true
		charge_time = 0.0
		Audio.play_sfx("charge")
	else:
		_fire_normal()

func shoot_button_up() -> void:
	if not is_charging:
		return
	_fire_charged(charge_time / CHARGE_MAX_TIME)
	is_charging = false
	charge_effect.visible = false
	GameManager.reset_streak_lock()

func _fire_normal() -> void:
	if player.is_dead:
		return
	var target := _find_nearest_enemy()
	var dir := Vector2(player.facing_dir, 0)
	if target:
		dir = (target.global_position - muzzle.global_position).normalized()
	_spawn_rock(dir, NORMAL_DAMAGE, false)
	player.set_temporary_animation("shoot", 0.18)
	Audio.play_sfx("shoot")
	GameManager.register_shot(false)

func _fire_charged(power: float) -> void:
	if player.is_dead:
		return
	var dir := Vector2(player.facing_dir, 0.0)
	if Input.is_action_pressed("aim_up"):
		dir.y = -0.7
	elif Input.is_action_pressed("aim_down"):
		dir.y = 0.7
	dir = dir.normalized()
	_spawn_rock(dir, int(CHARGED_DAMAGE * max(0.4, power)), true)
	player.set_temporary_animation("shoot", 0.25)
	Audio.play_sfx("charge_release")
	GameManager.register_shot(true)

func _spawn_rock(dir: Vector2, damage: int, charged: bool) -> void:
	var rock = ROCK_SCENE.instantiate()
	get_tree().current_scene.add_child(rock)
	rock.global_position = muzzle.global_position
	rock.setup(dir, damage, charged)

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := AUTO_TARGET_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := player.global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best
