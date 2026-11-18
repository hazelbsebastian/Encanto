extends Area2D
## Sits on an enemy's hittable Area2D (layer 2). Forwards rock impacts to the
## owning enemy's take_damage(). Also used, unmodified, as the Kapre's tree
## weak-point hitbox (see Tree.gd, which overrides receive_hit behaviour by
## living on its own node instead of forwarding to a parent enemy).

@export var owner_enemy_path: NodePath = ".."

func receive_hit(amount: int, is_charged: bool) -> void:
	var enemy := get_node(owner_enemy_path)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(amount, is_charged)
