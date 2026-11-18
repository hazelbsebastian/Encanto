extends EnemyBase
## Manananggal - lower body. Runs along the ground toward the player and
## periodically kicks (the player must jump over it to avoid damage). Shares
## its health pool with the flying upper body (see ManananggalUpper.gd),
## since defeating either half defeats the whole creature.

const SPEED := 80.0
const ATTACK_INTERVAL := 4.5
const ATTACK_RANGE := 40.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var upper: Node2D = $Upper

var _attack_timer: float = 0.0
var _attacking: bool = false

func _ready() -> void:
	super._ready()
	max_health = 4
	enemy_id = "manananggal"
	health = max_health
	_attack_timer = randf_range(1.5, ATTACK_INTERVAL)

func _physics_process(delta: float) -> void:
	if is_dead:
		upper.visible = false
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := get_tree().get_first_node_in_group("player")
	if player and not _attacking:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * SPEED
		sprite.flip_h = dir < 0
		_attack_timer -= delta
		if _attack_timer <= 0.0 and abs(player.global_position.x - global_position.x) < ATTACK_RANGE:
			_do_kick()
	move_and_slide()
	if not _attacking:
		sprite.play("run")

func _do_kick() -> void:
	_attacking = true
	_attack_timer = ATTACK_INTERVAL
	sprite.play("attack")
	velocity.x = 0
	spawn_attack_hitbox(Vector2(0, -10), Vector2(40, 24), 0.35)
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func(): _attacking = false)

func _play_death_animation() -> void:
	sprite.play("death")
	if upper.has_method("play_death"):
		upper.play_death()
