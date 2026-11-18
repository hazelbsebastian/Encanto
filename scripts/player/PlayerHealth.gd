extends Area2D
## Player hurtbox: detects enemy bodies / enemy attacks and applies damage,
## with a short invulnerability window and a flashing effect.

signal player_died

const INVULN_TIME := 1.0

var invulnerable: bool = false
var _flash_time: float = 0.0

@onready var player: CharacterBody2D = get_parent()

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if invulnerable:
		_flash_time += delta
		player.sprite.visible = int(_flash_time * 12.0) % 2 == 0
	else:
		player.sprite.visible = true

func _on_area_entered(area: Area2D) -> void:
	_maybe_take_hit()

func _on_body_entered(body: Node) -> void:
	_maybe_take_hit()

func _maybe_take_hit(amount: int = 1) -> void:
	if invulnerable or player.is_dead:
		return
	Audio.play_sfx("damage")
	player.set_temporary_animation("hurt", 0.35)
	var dead := GameManager.damage_player(amount)
	invulnerable = true
	_flash_time = 0.0
	var t := get_tree().create_timer(INVULN_TIME)
	t.timeout.connect(func(): invulnerable = false; player.sprite.visible = true)
	if dead:
		player.play_death()
		Audio.play_sfx("game_over")
		player_died.emit()
