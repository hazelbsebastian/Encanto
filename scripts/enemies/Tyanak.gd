extends EnemyBase
## Tyanak: small, fast, crawls along the ground and chases the player.
## Attacks roughly every 5 seconds. The player avoids it by jumping.

const SPEED := 95.0
const ATTACK_INTERVAL := 5.0
const ATTACK_RANGE := 26.0

@onready var sprite: AnimatedSprite2D = $Sprite

var _attack_timer: float = 0.0
var _attacking: bool = false

func _ready() -> void:
	super._ready()
	max_health = 2
	enemy_id = "tyanak"
	health = max_health
	_attack_timer = randf_range(1.0, ATTACK_INTERVAL)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := get_tree().get_first_node_in_group("player")
	if player and not _attacking:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * SPEED
		sprite.flip_h = dir < 0
		_attack_timer -= delta
		if _attack_timer <= 0.0 and global_position.distance_to(player.global_position) < ATTACK_RANGE * 4.0:
			_do_attack()
	move_and_slide()
	if not _attacking:
		sprite.play("crawl")

func _do_attack() -> void:
	_attacking = true
	_attack_timer = ATTACK_INTERVAL
	sprite.play("attack")
	velocity.x = 0
	spawn_attack_hitbox(Vector2(0, -6), Vector2(30, 20), 0.3)
	var t := get_tree().create_timer(0.5)
	t.timeout.connect(func(): _attacking = false)

func _play_death_animation() -> void:
	sprite.play("death")
