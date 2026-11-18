extends EnemyBase
## Tikbalang: faster than the Tyanak, dashes at the player with quick
## attacks. This is the stage that unlocks the player's double jump, since a
## single jump only carries the player onto the Tikbalang's horse-body area -
## a second jump is needed to clear it safely.

const SPEED := 150.0
const DASH_SPEED := 260.0
const ATTACK_INTERVAL := 3.2
const ATTACK_RANGE := 46.0

@onready var sprite: AnimatedSprite2D = $Sprite

var _attack_timer: float = 0.0
var _attacking: bool = false

func _ready() -> void:
	super._ready()
	max_health = 3
	enemy_id = "tikbalang"
	health = max_health
	_attack_timer = randf_range(1.0, ATTACK_INTERVAL)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var dir: float = signf(player.global_position.x - global_position.x)
		sprite.flip_h = dir < 0
		if _attacking:
			velocity.x = dir * DASH_SPEED
		else:
			velocity.x = dir * SPEED
			_attack_timer -= delta
			if _attack_timer <= 0.0 and abs(player.global_position.x - global_position.x) < ATTACK_RANGE:
				_do_attack()
	move_and_slide()
	if not _attacking:
		sprite.play("run")

func _do_attack() -> void:
	_attacking = true
	_attack_timer = ATTACK_INTERVAL
	sprite.play("attack")
	spawn_attack_hitbox(Vector2(0, -20), Vector2(34, 46), 0.3)
	var t := get_tree().create_timer(0.4)
	t.timeout.connect(func(): _attacking = false)

func _play_death_animation() -> void:
	sprite.play("death")
