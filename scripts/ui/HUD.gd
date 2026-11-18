extends CanvasLayer
## Main gameplay HUD: hearts, stage name, puzzle-piece progress (real pieces
## of the next creature's picture), shot streak / charge indicator, pause
## button, virtual joystick, and the shoot/jump action buttons.
## Every on-screen action has a keyboard twin (see Controls.gd); the touch
## buttons light up when their key is held so both feel like one control.

const HEART_FULL := preload("res://assets/ui/heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/heart_empty.png")
const SHOOT_TEX := preload("res://assets/ui/button_shoot.png")
const CHARGE_TEX := preload("res://assets/ui/button_charge.png")

const PRESSED_TINT := Color(1.35, 1.3, 1.1)

@onready var hearts_box: HBoxContainer = $HeartsChip/HeartsBox
@onready var puzzle_chip: PanelContainer = $PuzzleChip
@onready var puzzle_box: HBoxContainer = $PuzzleChip/PuzzleBox
@onready var streak_label: Label = $StreakChip/StreakLabel
@onready var stage_label: Label = $StageChip/StageLabel
@onready var joystick: Control = $VirtualJoystick
@onready var shoot_button: TextureButton = $ShootButton
@onready var jump_button: TextureButton = $JumpButton
@onready var pause_button: Button = $PauseButton

var _piece_slots: Array[TextureRect] = []
var _pieces_for: String = ""
var _last_count: int = 0

func _ready() -> void:
	GameManager.hearts_changed.connect(_on_hearts_changed)
	GameManager.streak_changed.connect(_on_streak_changed)
	GameManager.puzzle_pieces_changed.connect(_on_puzzle_changed)
	_on_hearts_changed(GameManager.current_hearts, GameManager.max_hearts)
	_on_streak_changed(GameManager.shot_streak, GameManager.charge_unlocked)
	_on_puzzle_changed(GameManager.puzzle_pieces, GameManager.ENEMIES_PER_STAGE)

	shoot_button.button_down.connect(_on_shoot_down)
	shoot_button.button_up.connect(_on_shoot_up)
	jump_button.pressed.connect(_on_jump_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	$LookArea.gui_input.connect(_on_look_input)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and joystick:
		if player.has_method("set_move_vector"):
			player.call("set_move_vector", joystick.get("vector"))
		else:
			player.call("set_move_axis", joystick.get("axis"))
	# keyboard/gamepad feedback on the touch buttons
	shoot_button.modulate = PRESSED_TINT if (Input.is_action_pressed("shoot") or shoot_button.is_pressed()) else Color.WHITE
	jump_button.modulate = PRESSED_TINT if (Input.is_action_pressed("jump") or jump_button.is_pressed()) else Color.WHITE

func _update_stage_label() -> void:
	var stage := GameManager.current_stage_name()
	stage_label.text = GameManager.creature_name(stage).to_upper() if stage != "" else ""

func _on_hearts_changed(current: int, max_hearts: int) -> void:
	for c in hearts_box.get_children():
		c.queue_free()
	for i in range(max_hearts):
		var tex := TextureRect.new()
		tex.texture = HEART_FULL if i < current else HEART_EMPTY
		tex.custom_minimum_size = Vector2(30, 26)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_box.add_child(tex)

func _on_streak_changed(streak: int, charge_unlocked: bool) -> void:
	if charge_unlocked:
		streak_label.text = "CHARGE READY!  Hawakan ang TIRA / X"
		streak_label.modulate = Color(1.0, 0.85, 0.3)
		shoot_button.texture_normal = CHARGE_TEX
	else:
		streak_label.text = "Streak: %d / %d" % [streak, GameManager.STREAK_TO_UNLOCK_CHARGE]
		streak_label.modulate = Color(1, 1, 1)
		shoot_button.texture_normal = SHOOT_TEX

## Collected pieces show the real fragment of the next creature's picture;
## missing ones are dark silhouettes, so the puzzle is teased during play.
func _on_puzzle_changed(count: int, _total: int) -> void:
	_update_stage_label()
	var next_id := GameManager.next_creature()
	puzzle_chip.visible = next_id != ""
	if next_id == "":
		return
	if _pieces_for != next_id:
		_pieces_for = next_id
		_last_count = 0
		for c in puzzle_box.get_children():
			c.queue_free()
		_piece_slots.clear()
		for i in range(GameManager.PUZZLE_PIECES):
			var slot := TextureRect.new()
			slot.texture = GameManager.portrait_piece(next_id, i)
			slot.custom_minimum_size = Vector2(40, 40)
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_SCALE
			puzzle_box.add_child(slot)
			_piece_slots.append(slot)
	for i in range(_piece_slots.size()):
		var got := i < count
		_piece_slots[i].modulate = Color.WHITE if got else Color(0.1, 0.08, 0.12, 0.85)
		if got and i >= _last_count:
			_pop(_piece_slots[i])
	_last_count = count

func _pop(slot: Control) -> void:
	slot.pivot_offset = slot.custom_minimum_size * 0.5
	slot.scale = Vector2(1.6, 1.6)
	slot.create_tween().tween_property(slot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_shoot_down() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.get_node("Shooting").shoot_button_down()

func _on_shoot_up() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.get_node("Shooting").shoot_button_up()

func _on_jump_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.try_jump()

## Drag on any empty part of the screen (touch or mouse) to turn the camera.
func _on_look_input(event: InputEvent) -> void:
	var drag := Vector2.ZERO
	if event is InputEventScreenDrag:
		drag = (event as InputEventScreenDrag).relative
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available() and ((event as InputEventMouseMotion).button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
		drag = (event as InputEventMouseMotion).relative
	if drag != Vector2.ZERO:
		var rig := get_tree().get_first_node_in_group("camera_rig")
		if rig:
			rig.call("add_look", drag)

func _on_pause_pressed() -> void:
	var level := get_parent()
	if level and level.has_method("open_pause_menu"):
		level.open_pause_menu()
