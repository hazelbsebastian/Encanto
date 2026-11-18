extends Area2D
## The rock fired by the player's Palsuot/Sumpak. Normal shots do 1 damage
## and auto-target; charged shots do more damage and can hit the Kapre's
## tree weak point.

const SPEED := 420.0
const CHARGED_SPEED := 520.0
const LIFETIME := 2.5

var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var is_charged: bool = false
var _life: float = 0.0

func setup(dir: Vector2, dmg: int, charged: bool) -> void:
	direction = dir
	damage = dmg
	is_charged = charged
	rotation = dir.angle()
	if charged:
		scale = Vector2(1.8, 1.8)
		modulate = Color(1.0, 0.75, 0.4)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var speed := CHARGED_SPEED if is_charged else SPEED
	position += direction * speed * delta
	_life += delta
	if _life > LIFETIME:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("receive_hit"):
		area.receive_hit(damage, is_charged)
		queue_free()
