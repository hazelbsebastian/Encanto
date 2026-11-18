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

## Week 14 accessibility: hint text was 12 px light text straight on the 3D
## scene (hard to read on grass/sand) and always named keyboard keys, even on
## phones. Now: 15 px on a dark chip, placed under its control, and worded
## for the input the player is using (see Controls.touch_mode).
const HINT_FONT := 15
const HINT_TEXT := {
	"touch": {"MoveKey": "GALAW", "ShootKey": "TIRA", "JumpKey": "TALON", "PauseKey": "HINTO",
		"LookHint": "I-drag ang screen para iikot ang camera"},
	"keys": {"MoveKey": "WASD / ← ↑ → ↓", "ShootKey": "X", "JumpKey": "SPACE", "PauseKey": "ESC",
		"LookHint": "Q / E o i-drag ang screen para iikot ang camera"},
}

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

var _last_hearts: int = -1
var _hurt_flash: ColorRect
var _hit_label: Label

func _ready() -> void:
	add_to_group("hud")
	_build_feedback_layer()
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
	Controls.input_mode_changed.connect(func(_t: bool) -> void: _apply_hints())
	get_viewport().size_changed.connect(_layout_hints)
	_apply_hints()

## Week 14 (playtest P3): clearer feedback. A red screen-edge flash when a
## heart is lost and a "TAMA!" confirmation when a throw hits.
func _build_feedback_layer() -> void:
	_hurt_flash = ColorRect.new()
	_hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; uniform float strength = 0.0; void fragment() { vec2 d = abs(UV - 0.5) * 2.0; float e = smoothstep(0.55, 1.0, max(d.x, d.y)); COLOR = vec4(0.85, 0.05, 0.05, e * strength); }"
	mat.shader = sh
	_hurt_flash.material = mat
	add_child(_hurt_flash)
	move_child(_hurt_flash, 1)
	_hit_label = Label.new()
	_hit_label.text = "TAMA!"
	_hit_label.add_theme_font_size_override("font_size", 30)
	_hit_label.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
	_hit_label.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.02))
	_hit_label.add_theme_constant_override("outline_size", 8)
	_hit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hit_label.position = Vector2(-80, 150)
	_hit_label.size = Vector2(160, 40)
	_hit_label.modulate.a = 0.0
	_hit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hit_label)

func show_hit_confirm() -> void:
	_hit_label.modulate.a = 1.0
	_hit_label.pivot_offset = _hit_label.size * 0.5
	_hit_label.scale = Vector2(1.4, 1.4)
	var tw := _hit_label.create_tween()
	tw.tween_property(_hit_label, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(0.35)
	tw.tween_property(_hit_label, "modulate:a", 0.0, 0.3)

func _flash_hurt() -> void:
	var mat := _hurt_flash.material as ShaderMaterial
	mat.set_shader_parameter("strength", 0.9)
	var tw := _hurt_flash.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), 0.9, 0.0, 0.6)

func _apply_hints() -> void:
	var words: Dictionary = HINT_TEXT["touch" if Controls.touch_mode else "keys"]
	for key: String in words:
		var l := get_node_or_null(key) as Label
		if l == null:
			continue
		l.text = words[key]
		l.add_theme_font_size_override("font_size", HINT_FONT)
		l.add_theme_color_override("font_color", Color(1, 0.96, 0.87))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.05, 0.03, 0.82)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 2
		sb.content_margin_bottom = 3
		l.add_theme_stylebox_override("normal", sb)
	_layout_hints.call_deferred()

## Centre each hint under the control it describes, kept inside the screen.
func _layout_hints() -> void:
	var view := get_viewport().get_visible_rect().size
	var pairs := {"MoveKey": joystick, "ShootKey": shoot_button, "JumpKey": jump_button, "PauseKey": pause_button}
	for key: String in pairs:
		var l := get_node_or_null(key) as Label
		var target := pairs[key] as Control
		if l == null or target == null:
			continue
		_place(l, target.get_global_rect(), view)
	var look := get_node_or_null("LookHint") as Label
	if look:
		look.set_anchors_preset(Control.PRESET_TOP_LEFT)
		look.size = Vector2.ZERO
		look.reset_size()
		look.position = Vector2((view.x - look.size.x) * 0.5, view.y - look.size.y - 8)

func _place(l: Label, under: Rect2, view: Vector2) -> void:
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.size = Vector2.ZERO
	l.reset_size()
	var x := under.get_center().x - l.size.x * 0.5
	var y := under.end.y + 2
	l.position = Vector2(clampf(x, 4, view.x - l.size.x - 4), minf(y, view.y - l.size.y - 2))

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
	var lost := _last_hearts >= 0 and current < _last_hearts
	_last_hearts = current
	if lost:
		_flash_hurt()
	for c in hearts_box.get_children():
		c.queue_free()
	for i in range(max_hearts):
		var tex := TextureRect.new()
		tex.texture = HEART_FULL if i < current else HEART_EMPTY
		tex.custom_minimum_size = Vector2(30, 26)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_box.add_child(tex)
		if lost and i == current:
			_pop(tex)   # the heart that was just lost pops so the player notices

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
