extends CharacterBody2D
class_name EnemyBase
## Shared health/defeat/attack-hitbox plumbing for every Filipino folklore
## creature. Concrete behaviour (movement + attack patterns) lives in the
## per-creature scripts that extend this class.

signal defeated

@export var max_health: int = 3
@export var enemy_id: String = "enemy"
@export var contact_damage: int = 1

var health: int
var is_dead: bool = false

const GRAVITY := 900.0

func _ready() -> void:
	health = max_health
	add_to_group("enemies")

func take_damage(amount: int, is_charged: bool = false) -> void:
	if is_dead:
		return
	health -= amount
	_on_hurt()
	if health <= 0:
		_die()

func _on_hurt() -> void:
	modulate = Color(1.6, 0.6, 0.6)
	var t := get_tree().create_timer(0.12)
	t.timeout.connect(func():
		if is_instance_valid(self):
			modulate = Color(1, 1, 1)
	)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	remove_from_group("enemies")
	set_physics_process(false)
	Audio.play_sfx("enemy_defeat")
	GameManager.register_enemy_defeated()
	_play_death_animation()
	defeated.emit()
	var t := get_tree().create_timer(0.9)
	t.timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

func _play_death_animation() -> void:
	pass # overridden per-enemy

## Spawns a temporary Area2D "attack hitbox" on layer 8 (enemy attacks) so the
## player's Hurtbox (mask includes layer 8) takes damage only while the
## attack is actually active, letting the player dodge/jump safely otherwise.
func spawn_attack_hitbox(local_offset: Vector2, size: Vector2, lifetime: float = 0.25) -> void:
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	get_tree().current_scene.add_child(area)
	area.global_position = global_position + local_offset
	Audio.play_sfx("enemy_attack")
	var t := get_tree().create_timer(lifetime)
	t.timeout.connect(func():
		if is_instance_valid(area):
			area.queue_free()
	)
