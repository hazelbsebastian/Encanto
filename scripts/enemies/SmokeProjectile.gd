extends Area2D
## The Kapre's cigarette-smoke attack: travels in a random direction and
## deals damage to whatever it touches on the player's Hurtbox layer.

const SPEED := 190.0
const LIFETIME := 2.2

var direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0

const FRAMES := [
	preload("res://assets/weapons/smoke_0.png"),
	preload("res://assets/weapons/smoke_1.png"),
	preload("res://assets/weapons/smoke_2.png"),
]

@onready var sprite: Sprite2D = $Sprite2D

func setup(dir: Vector2) -> void:
	direction = dir.normalized()

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_life += delta
	sprite.texture = FRAMES[clampi(int(_life * 4.0) % 3, 0, 2)]
	sprite.modulate.a = clampf(1.0 - (_life / LIFETIME), 0.0, 1.0)
	if _life > LIFETIME:
		queue_free()
