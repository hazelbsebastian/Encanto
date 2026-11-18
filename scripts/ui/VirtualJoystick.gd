extends Control
## Mobile-style virtual joystick (bottom-left). Works with touch AND mouse
## drag so it is also testable from the Godot editor. `vector` is the full
## 2D stick direction (x = right, y = down/back) used for 3D movement;
## `axis` (x only) is kept for older callers.

@export var max_radius: float = 36.0
var axis: float = 0.0
var vector: Vector2 = Vector2.ZERO

@onready var knob: TextureRect = $Knob

var _center: Vector2
var _dragging: bool = false
var _touch_index: int = -1

func _ready() -> void:
	add_to_group("joystick")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = knob.position + knob.size * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_touch_index = event.index
			_update(event.position)
		elif event.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag:
		if _dragging and event.index == _touch_index:
			_update(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_update(event.position)
		else:
			_reset()
	elif event is InputEventMouseMotion and _dragging:
		_update(event.position)

func _update(local_pos: Vector2) -> void:
	var offset := local_pos - _center
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	knob.position = _center + offset - knob.size * 0.5
	axis = offset.x / max_radius
	vector = offset / max_radius

func _reset() -> void:
	_dragging = false
	_touch_index = -1
	knob.position = _center - knob.size * 0.5
	axis = 0.0
	vector = Vector2.ZERO
