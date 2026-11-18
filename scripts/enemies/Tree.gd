extends StaticBody2D
## The Kapre's tree - the real target of the boss fight. Normal rocks just
## bounce off; only charged shots chip away at it. Once enough charged hits
## land, the tree shakes, falls, and the boss encounter ends.

signal fallen

const TEX_FULL := preload("res://assets/enemies/tree_full.png")
const TEX_SHAKE := preload("res://assets/enemies/tree_shake.png")
const TEX_FALLING := preload("res://assets/enemies/tree_falling.png")
const TEX_FALLEN := preload("res://assets/enemies/tree_fallen.png")

@export var hits_to_fell: int = 4

var hits_taken: int = 0
var is_felled: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func take_damage(amount: int, is_charged: bool) -> void:
	if is_felled:
		return
	if not is_charged:
		Audio.play_sfx("enemy_attack")
		return
	hits_taken += 1
	Audio.play_sfx("damage")
	sprite.texture = TEX_SHAKE
	var t := get_tree().create_timer(0.25)
	t.timeout.connect(func():
		if is_instance_valid(self) and not is_felled:
			sprite.texture = TEX_FULL
	)
	if hits_taken >= hits_to_fell:
		_fall()

func _fall() -> void:
	is_felled = true
	sprite.texture = TEX_FALLING
	Audio.play_sfx("enemy_defeat")
	var t := get_tree().create_timer(0.9)
	t.timeout.connect(func():
		if is_instance_valid(self):
			sprite.texture = TEX_FALLEN
			fallen.emit()
	)
