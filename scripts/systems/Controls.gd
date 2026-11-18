extends Node
## Controls (autoload)
## Registers the game's input actions at startup so keyboard (and gamepad)
## work everywhere alongside the on-screen touch controls:
##   move_forward/back/left/right : W A S D  or  arrow keys, left stick
##   jump                         : Space, Z / gamepad A
##   shoot (hold = charge)        : X, J, K / gamepad X or RT
##   camera_left / camera_right   : Q / E, right stick (or drag the screen)
##   pause                        : Esc, P / gamepad Start
## Menus use Godot's built-in ui_* actions (arrows/Tab to move focus,
## Enter/Space to press, Esc to go back), which we extend with WASD.

const KEY_BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_Z],
	"shoot": [KEY_X, KEY_J, KEY_K],
	"camera_left": [KEY_Q],
	"camera_right": [KEY_E],
	"pause": [KEY_ESCAPE, KEY_P],
}

const JOY_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"shoot": [JOY_BUTTON_X],
	"pause": [JOY_BUTTON_START],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_forward": [JOY_BUTTON_DPAD_UP],
	"move_back": [JOY_BUTTON_DPAD_DOWN],
}

## Extra keys for menu navigation (on top of Godot's arrow-key defaults).
const UI_EXTRA_KEYS := {
	"ui_up": [KEY_W],
	"ui_down": [KEY_S],
	"ui_left": [KEY_A],
	"ui_right": [KEY_D],
	"ui_cancel": [KEY_BACKSPACE],
}

## Short labels shown on the on-screen buttons / hints.
const HINTS := {
	"move": "WASD  /  arrows",
	"jump": "SPACE",
	"camera": "Q / E",
	"shoot": "X",
	"pause": "ESC",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in KEY_BINDINGS:
		_ensure_action(action)
		for key: int in KEY_BINDINGS[action]:
			_add_key(action, key)
	for action: String in JOY_BUTTONS:
		for button: int in JOY_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button as JoyButton
			InputMap.action_add_event(action, ev)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("camera_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("camera_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	for action: String in UI_EXTRA_KEYS:
		for key: int in UI_EXTRA_KEYS[action]:
			_add_key(action, key)

func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)

func _add_key(action: String, key: int) -> void:
	_ensure_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key as Key
	InputMap.action_add_event(action, ev)

func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

## Give keyboard focus to a control once it is in the tree and visible, so
## every screen can be driven with arrows + Enter without touching the mouse.
func focus(control: Control) -> void:
	if control == null:
		return
	_focus_later.call_deferred(control)

func _focus_later(control: Control) -> void:
	if is_instance_valid(control) and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
		control.grab_focus()
