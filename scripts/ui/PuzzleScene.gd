extends CanvasLayer
## Stage-clear sequence, shown after all 4 enemies of a stage are defeated.
## Every defeated enemy dropped one piece of the NEXT creature's picture, so:
##   1) CONGRATS  - you beat the stage and collected all the pieces
##   2) PUZZLE    - swap the scrambled pieces until the picture is whole
##   3) REVEAL    - the finished picture shows who you fight next
## then `completed` is emitted and the level starts the next enemy wave.
## Works with touch/mouse (tap two pieces to swap them) and keyboard/gamepad
## (arrows/WASD to move, Enter/Space to pick, Esc to cancel a pick).

signal completed

const TILE_SIZE := Vector2(156, 156)

var defeated_id: String = ""
var next_id: String = ""
var congrats_text: String = ""
var lore_text: String = ""
var unlock_text: String = ""

var _root: Control
var _order: Array[int] = []
var _tiles: Array[Button] = []
var _selected: int = -1
var _moves: int = 0
var _solved: bool = false
var _moves_label: Label
var _hint_label: Label

func setup(cfg: Dictionary) -> void:
	defeated_id = str(cfg.get("defeated", ""))
	next_id = str(cfg.get("next", ""))
	congrats_text = str(cfg.get("congrats", ""))
	lore_text = str(cfg.get("lore", ""))
	unlock_text = str(cfg.get("unlock", ""))

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	UIKit.dim(self, 0.74)
	_show_congrats()

# ------------------------------------------------------------- helpers --
func _new_screen(min_size: Vector2) -> VBoxContainer:
	if is_instance_valid(_root):
		_root.queue_free()
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_root = holder
	var panel := UIKit.centered_panel(holder, min_size)
	UIKit.pop_in(panel)
	return UIKit.vbox(panel, 12)

# ------------------------------------------------------ 1) CONGRATS ------
func _show_congrats() -> void:
	Audio.play_sfx("gong")
	Audio.play_voice("narrator_kongrats")
	var v := _new_screen(Vector2(620, 0))
	UIKit.label(v, "KONGRATS!", "TitleLabel", 52)
	UIKit.label(v, "Natalo mo ang lahat ng %s!" % GameManager.creature_name(defeated_id), "HeaderLabel", 24)

	var row := UIKit.hbox(v, 18)
	# the defeated creature, stamped "TALO!"
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	row.add_child(card)
	var defeated_pic := TextureRect.new()
	defeated_pic.texture = GameManager.portrait(defeated_id)
	defeated_pic.custom_minimum_size = Vector2(150, 150)
	defeated_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	defeated_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	defeated_pic.modulate = Color(0.65, 0.6, 0.6)
	card.add_child(defeated_pic)
	var stamp := Label.new()
	stamp.text = "TALO!"
	stamp.theme_type_variation = "HeaderLabel"
	stamp.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
	stamp.add_theme_font_size_override("font_size", 34)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.rotation_degrees = -14
	stamp.pivot_offset = Vector2(75, 75)
	defeated_pic.add_child(stamp)
	stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var info := UIKit.vbox(row, 10)
	info.custom_minimum_size = Vector2(380, 0)
	var text := UIKit.label(info, congrats_text, "", 18)
	text.custom_minimum_size = Vector2(380, 0)
	UIKit.label(info, "Mga nakuhang piraso ng larawan:", "AccentLabel", 15)
	var pieces := UIKit.hbox(info, 8)
	for i in range(GameManager.PUZZLE_PIECES):
		var p := TextureRect.new()
		p.texture = GameManager.portrait_piece(next_id, i)
		p.custom_minimum_size = Vector2(54, 54)
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_SCALE
		p.modulate = Color(0.08, 0.06, 0.1)  # silhouette until the puzzle is solved
		pieces.add_child(p)
		var tw := p.create_tween()
		tw.tween_interval(0.25 + i * 0.12)
		tw.tween_property(p, "modulate", Color(0.35, 0.3, 0.4), 0.25)

	var go := UIKit.button(v, "Buuin ang Larawan  ▶", true, 54)
	go.pressed.connect(_show_puzzle)
	UIKit.key_hint(v, "ENTER / tap")
	Controls.focus(go)

# -------------------------------------------------------- 2) PUZZLE ------
func _show_puzzle() -> void:
	Audio.play_sfx("click")
	Audio.play_voice("narrator_buuin")
	var v := _new_screen(Vector2(740, 0))
	UIKit.label(v, "Buuin ang Larawan", "HeaderLabel", 30)
	var row := UIKit.hbox(v, 22)

	var frame := PanelContainer.new()
	frame.theme_type_variation = "CardPanel"
	row.add_child(frame)
	var grid := GridContainer.new()
	grid.columns = GameManager.PUZZLE_GRID
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	frame.add_child(grid)

	_order = _scrambled_order()
	_tiles.clear()
	for i in range(GameManager.PUZZLE_PIECES):
		var b := Button.new()
		b.theme_type_variation = "TileButton"
		b.custom_minimum_size = TILE_SIZE
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_tile_pressed.bind(i))
		grid.add_child(b)
		_tiles.append(b)
	_refresh_tiles()

	var side := UIKit.vbox(row, 12)
	side.custom_minimum_size = Vector2(300, 0)
	UIKit.label(side, "Sino kaya ang susunod mong kalaban?", "AccentLabel", 18)
	_hint_label = UIKit.label(side, "Pumili ng dalawang piraso para pagpalitin.", "", 17)
	UIKit.key_hint(side, "↑ ↓ ← →   pumili ng piraso")
	UIKit.key_hint(side, "ENTER / tap   kunin at ilipat")
	UIKit.key_hint(side, "ESC   kanselahin ang napili")
	_moves_label = UIKit.label(side, "Galaw: 0", "HintLabel", 14)
	Controls.focus(_tiles[0])

## A derangement: no piece starts in its correct slot (never pre-solved).
func _scrambled_order() -> Array[int]:
	var order: Array[int] = []
	for i in range(GameManager.PUZZLE_PIECES):
		order.append(i)
	while true:
		order.shuffle()
		var ok := true
		for i in range(order.size()):
			if order[i] == i:
				ok = false
				break
		if ok:
			return order
	return order

func _refresh_tiles() -> void:
	for i in range(_tiles.size()):
		_tiles[i].icon = GameManager.portrait_piece(next_id, _order[i])
		_tiles[i].set_pressed_no_signal(i == _selected)

func _on_tile_pressed(idx: int) -> void:
	if _solved:
		return
	if _selected == -1:
		_selected = idx
		Audio.play_sfx("puzzle_pickup")
		_hint_label.text = "Ngayon, piliin kung saan ito ilalagay."
	elif _selected == idx:
		_selected = -1
		_hint_label.text = "Pumili ng dalawang piraso para pagpalitin."
	else:
		var a := _selected
		var tmp: int = _order[a]
		_order[a] = _order[idx]
		_order[idx] = tmp
		_selected = -1
		_moves += 1
		_moves_label.text = "Galaw: %d" % _moves
		Audio.play_sfx("puzzle_swap")
		for t: Button in [_tiles[a], _tiles[idx]]:
			t.modulate = Color(1.6, 1.4, 0.9)
			t.create_tween().tween_property(t, "modulate", Color.WHITE, 0.25)
		_hint_label.text = "Pumili ng dalawang piraso para pagpalitin."
	_refresh_tiles()
	if _is_solved():
		_on_solved()

func _is_solved() -> bool:
	for i in range(_order.size()):
		if _order[i] != i:
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _selected != -1 and not _solved:
		_selected = -1
		_refresh_tiles()
		_hint_label.text = "Pumili ng dalawang piraso para pagpalitin."
		get_viewport().set_input_as_handled()

func _on_solved() -> void:
	_solved = true
	Audio.play_sfx("puzzle_complete")
	Audio.play_voice("narrator_tama")
	_hint_label.text = "Tama! Nabuo ang larawan!"
	_hint_label.add_theme_color_override("font_color", Color(0.6, 1, 0.55))
	for t in _tiles:
		t.focus_mode = Control.FOCUS_NONE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := t.create_tween()
		tw.tween_property(t, "modulate", Color(1.5, 1.4, 1.1), 0.18)
		tw.tween_property(t, "modulate", Color.WHITE, 0.3)
	var timer := get_tree().create_timer(1.0, true)
	timer.timeout.connect(_show_reveal)

# -------------------------------------------------------- 3) REVEAL ------
func _show_reveal() -> void:
	Audio.play_sfx("gong")
	Audio.play_voice("narrator_next_" + next_id)
	var v := _new_screen(Vector2(640, 0))
	UIKit.label(v, "Ang susunod mong kalaban:", "AccentLabel", 18)
	var row := UIKit.hbox(v, 20)
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	row.add_child(card)
	var pic := TextureRect.new()
	pic.texture = GameManager.portrait(next_id)
	pic.custom_minimum_size = Vector2(250, 250)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card.add_child(pic)

	var info := UIKit.vbox(row, 12)
	info.custom_minimum_size = Vector2(320, 0)
	UIKit.label(info, GameManager.creature_name(next_id).to_upper(), "TitleLabel", 34 if next_id.length() > 8 else 44, false)
	var lore := UIKit.label(info, lore_text, "", 17)
	lore.custom_minimum_size = Vector2(320, 0)
	if unlock_text != "":
		var chip := PanelContainer.new()
		chip.theme_type_variation = "HudChip"
		info.add_child(chip)
		UIKit.label(chip, unlock_text, "AccentLabel", 16)

	var go := UIKit.button(v, "Laban na!  ▶", true, 56)
	go.pressed.connect(_finish)
	UIKit.key_hint(v, "ENTER / tap")
	Controls.focus(go)

func _finish() -> void:
	Audio.play_sfx("click")
	Audio.play_voice("narrator_laban")
	get_tree().paused = false
	completed.emit()
	queue_free()
