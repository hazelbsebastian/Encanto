extends Area3D
## Hittable area on an enemy (physics layer 2). Rocks call receive_hit(),
## which is forwarded to the owning creature's take_damage().

var owner_enemy: Node = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false

func receive_hit(amount: int, is_charged: bool, at: Vector3 = Vector3.ZERO) -> void:
	var target := owner_enemy if owner_enemy else get_parent()
	if target and target.has_method("take_damage"):
		target.call("take_damage", amount, is_charged, at)
