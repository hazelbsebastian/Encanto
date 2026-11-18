extends CharacterBody2D
## Handles movement, jumping (incl. double jump once unlocked) and drives
## the AnimatedSprite2D's animation state. Shooting lives in PlayerShooting.gd
## and health/damage lives in PlayerHealth.gd (on the Hurtbox child).

signal died

const WALK_SPEED := 90.0
const RUN_SPEED := 170.0
const JUMP_VELOCITY := -340.0
const GRAVITY := 900.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var accessory_icon: Sprite2D = $AccessoryIcon

var facing_dir: int = 1
var jumps_used: int = 0
var is_dead: bool = false

var _override_anim: String = ""
var _override_timer: float = 0.0
var joystick_axis: float = 0.0

func _ready() -> void:
	apply_outfit()

## Cosmetic wardrobe: tints the sprite with the equipped top's colour and
## shows/hides the accessory overlay. (The generated sprite is a single flat
## image, so the tint applies to the whole body rather than just the shirt -
## a simple but honest way to make purchased/obtained outfits visible.)
func apply_outfit() -> void:
	var top_id: String = SaveSystem.equipped.get("top", "basic_polo")
	var top_item: Dictionary = ClothingData.get_item(top_id)
	sprite.modulate = top_item.get("tint", Color(1, 1, 1))

	var acc_id: String = SaveSystem.equipped.get("accessory", "")
	var acc_item: Dictionary = ClothingData.get_item(acc_id)
	var icon_path: String = acc_item.get("icon", "")
	if icon_path != "":
		accessory_icon.texture = load(icon_path)
		accessory_icon.visible = true
	else:
		accessory_icon.visible = false

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	var kb_axis := Input.get_axis("move_left", "move_right")
	var axis := joystick_axis if abs(joystick_axis) > 0.15 else kb_axis

	var speed := RUN_SPEED if abs(axis) > 0.6 else WALK_SPEED
	velocity.x = axis * speed

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		jumps_used = 0

	if abs(axis) > 0.05:
		facing_dir = 1 if axis > 0 else -1
		sprite.flip_h = facing_dir < 0
		accessory_icon.position.x = abs(accessory_icon.position.x) * facing_dir

	move_and_slide()
	_update_animation(axis, delta)

	if Input.is_action_just_pressed("jump"):
		try_jump()

func try_jump() -> void:
	if is_dead:
		return
	var max_jumps := 2 if GameManager.double_jump_unlocked else 1
	if is_on_floor() or jumps_used < max_jumps:
		velocity.y = JUMP_VELOCITY
		jumps_used += 1
		Audio.play_sfx("jump")

func set_move_axis(v: float) -> void:
	joystick_axis = v

func set_temporary_animation(anim_name: String, duration: float) -> void:
	_override_anim = anim_name
	_override_timer = duration
	sprite.play(anim_name)

func play_death() -> void:
	is_dead = true
	sprite.play("death")
	died.emit()

func play_victory() -> void:
	_override_anim = "victory"
	_override_timer = 999.0
	sprite.play("victory")

func clear_victory() -> void:
	_override_anim = ""

func _update_animation(axis: float, delta: float) -> void:
	if _override_timer > 0.0:
		_override_timer -= delta
		if _override_timer > 0.0:
			return
		_override_anim = ""

	if not is_on_floor():
		sprite.play("fall" if velocity.y > 0 else "jump")
		return

	if abs(axis) > 0.6:
		sprite.play("run")
	elif abs(axis) > 0.05:
		sprite.play("walk")
	else:
		sprite.play("idle")
