extends Node2D
## Manananggal - upper body. Flies in a bobbing pattern above/behind the
## lower body and periodically dives toward the player, locking its
## horizontal direction at the start of the dive so the attack only
## threatens along that line (the player dodges by moving left/right).

const FLY_HEIGHT := -100.0
const BOB_AMPLITUDE := 6.0
const DIVE_LOW := -18.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var root: EnemyBase = get_parent()

var _t: float = 0.0
var _dive_timer: float = randf_range(2.5, 4.5)
var _diving: bool = false
var _dead: bool = false

func _process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	if not _diving:
		position.y = FLY_HEIGHT + sin(_t * 2.0) * BOB_AMPLITUDE
		position.x = sin(_t * 1.3) * 10.0
		sprite.play("fly")
		if is_instance_valid(root) and not root.is_dead:
			_dive_timer -= delta
			if _dive_timer <= 0.0:
				_start_dive()

func _start_dive() -> void:
	_diving = true
	_dive_timer = randf_range(3.5, 5.5)
	var player := get_tree().get_first_node_in_group("player")
	var dive_dir := 1
	if player:
		var s: float = signf(player.global_position.x - global_position.x)
		dive_dir = int(s) if s != 0 else 1
	sprite.play("dive")
	sprite.flip_h = dive_dir < 0
	var tw := create_tween()
	tw.tween_property(self, "position:y", DIVE_LOW, 0.35)
	tw.parallel().tween_property(self, "position:x", position.x + dive_dir * 36.0, 0.35)
	tw.tween_callback(_spawn_dive_hit)
	tw.tween_interval(0.15)
	tw.tween_property(self, "position:y", FLY_HEIGHT, 0.4)
	tw.tween_callback(func(): _diving = false)

func _spawn_dive_hit() -> void:
	if is_instance_valid(root) and not root.is_dead:
		root.spawn_attack_hitbox(position, Vector2(26, 48), 0.3)

func play_death() -> void:
	_dead = true
	sprite.play("death")
