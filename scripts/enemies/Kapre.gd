extends EnemyBase
## Kapre - final boss. Huge and mostly stationary; cannot be hurt by shooting
## its body directly. Instead it launches cigarette smoke in random
## directions that the player must dodge, while the real weak point is the
## Tree behind it (see Tree.gd), which the player must break with charged
## shots. When the tree falls, Level calls force_defeat() on the Kapre.

const SMOKE_SCENE := preload("res://scenes/enemies/SmokeProjectile.tscn")

@onready var sprite: AnimatedSprite2D = $Sprite

var _attack_timer: float = randf_range(1.5, 3.0)

func _ready() -> void:
	super._ready()
	max_health = 999999
	enemy_id = "kapre"
	health = max_health
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	velocity = Vector2.ZERO
	move_and_slide()
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_smoke()
		_attack_timer = randf_range(2.5, 4.5)

func take_damage(amount: int, is_charged: bool = false) -> void:
	# The Kapre's body cannot be hurt directly - only the tree matters.
	modulate = Color(1.2, 1.2, 1.2)
	var t := get_tree().create_timer(0.1)
	t.timeout.connect(func():
		if is_instance_valid(self):
			modulate = Color(1, 1, 1)
	)

func _attack_smoke() -> void:
	sprite.play("attack")
	Audio.play_sfx("enemy_attack")
	var angle := randf_range(0.0, TAU)
	var dir := Vector2(cos(angle), sin(angle) * 0.5)
	var smoke = SMOKE_SCENE.instantiate()
	get_tree().current_scene.add_child(smoke)
	smoke.global_position = global_position + Vector2(20, -70)
	smoke.setup(dir)
	var t := get_tree().create_timer(0.4)
	t.timeout.connect(func():
		if is_instance_valid(self) and not is_dead:
			sprite.play("idle")
	)

func force_defeat() -> void:
	if is_dead:
		return
	is_dead = true
	remove_from_group("enemies")
	set_physics_process(false)
	sprite.play("death")
	Audio.play_sfx("enemy_defeat")
	defeated.emit()
	var t := get_tree().create_timer(1.4)
	t.timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
