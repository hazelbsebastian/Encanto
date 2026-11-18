extends Node
## GameManager (autoload)
## Holds the transient state of the current playthrough/run: which map was
## chosen, which enemy stage we are on, hearts, shot streak, unlocked
## abilities, puzzle pieces collected, etc. Persistent progression (money,
## clothing) lives in SaveSystem.

signal hearts_changed(current: int, max_hearts: int)
signal streak_changed(streak: int, charge_unlocked: bool)
signal puzzle_pieces_changed(count: int, total: int)

const STAGES := ["tyanak", "manananggal", "tikbalang", "kapre"]
const ENEMIES_PER_STAGE := 4
const STREAK_TO_UNLOCK_CHARGE := 5

const CREATURE_NAMES := {
	"tyanak": "Tyanak",
	"manananggal": "Manananggal",
	"tikbalang": "Tikbalang",
	"kapre": "Kapre",
}
## Each defeated enemy drops one piece of the NEXT creature's picture; the
## puzzle between stages reassembles it to reveal who comes next.
const PUZZLE_GRID := 2
const PUZZLE_PIECES := PUZZLE_GRID * PUZZLE_GRID

var chosen_map_id: String = ""
var chosen_map_name: String = ""

var max_hearts: int = 3
var current_hearts: int = 3

var current_stage_index: int = 0
var enemies_defeated_this_stage: int = 0
var puzzle_pieces: int = 0

var shot_streak: int = 0
var charge_unlocked: bool = false
var double_jump_unlocked: bool = false

var run_active: bool = false

func reset_run() -> void:
	chosen_map_id = ""
	chosen_map_name = ""
	max_hearts = 5
	current_hearts = max_hearts
	current_stage_index = 0
	enemies_defeated_this_stage = 0
	puzzle_pieces = 0
	shot_streak = 0
	charge_unlocked = false
	double_jump_unlocked = false
	run_active = true
	hearts_changed.emit(current_hearts, max_hearts)
	streak_changed.emit(shot_streak, charge_unlocked)
	puzzle_pieces_changed.emit(puzzle_pieces, ENEMIES_PER_STAGE)

func restart_after_death() -> void:
	var map_id := chosen_map_id
	var map_name := chosen_map_name
	reset_run()
	chosen_map_id = map_id
	chosen_map_name = map_name

func current_stage_name() -> String:
	if current_stage_index >= 0 and current_stage_index < STAGES.size():
		return STAGES[current_stage_index]
	return ""

func creature_name(id: String) -> String:
	return str(CREATURE_NAMES.get(id, id.capitalize()))

## The creature whose picture this stage's enemies are dropping pieces of.
func next_creature(stage: String = "") -> String:
	if stage == "":
		stage = current_stage_name()
	var i := STAGES.find(stage)
	if i >= 0 and i + 1 < STAGES.size():
		return str(STAGES[i + 1])
	return ""

func portrait(creature_id: String) -> Texture2D:
	return load("res://assets/puzzles/portrait_%s.png" % creature_id) as Texture2D

## One square piece (row-major index) of a creature's portrait.
func portrait_piece(creature_id: String, index: int) -> AtlasTexture:
	var tex := portrait(creature_id)
	if tex == null:
		return null
	var piece := AtlasTexture.new()
	piece.atlas = tex
	var cell := tex.get_size() / float(PUZZLE_GRID)
	piece.region = Rect2(Vector2(index % PUZZLE_GRID, floori(index / float(PUZZLE_GRID))) * cell, cell)
	return piece

func register_enemy_defeated() -> void:
	enemies_defeated_this_stage += 1
	puzzle_pieces += 1
	puzzle_pieces_changed.emit(puzzle_pieces, ENEMIES_PER_STAGE)

func stage_wave_complete() -> bool:
	return enemies_defeated_this_stage >= ENEMIES_PER_STAGE

func advance_stage() -> void:
	current_stage_index += 1
	enemies_defeated_this_stage = 0
	puzzle_pieces = 0
	puzzle_pieces_changed.emit(puzzle_pieces, ENEMIES_PER_STAGE)
	if current_stage_index == 2:
		double_jump_unlocked = true

func register_shot(is_charged: bool) -> void:
	if is_charged:
		shot_streak = 0
	else:
		shot_streak += 1
		if shot_streak >= STREAK_TO_UNLOCK_CHARGE:
			charge_unlocked = true
	streak_changed.emit(shot_streak, charge_unlocked)

func reset_streak_lock() -> void:
	# Called after a charged shot is consumed - player must build a new streak.
	shot_streak = 0
	charge_unlocked = false
	streak_changed.emit(shot_streak, charge_unlocked)

func damage_player(amount: int = 1) -> bool:
	current_hearts = max(0, current_hearts - amount)
	hearts_changed.emit(current_hearts, max_hearts)
	return current_hearts <= 0

func heal_player(amount: int = 1) -> void:
	current_hearts = min(max_hearts, current_hearts + amount)
	hearts_changed.emit(current_hearts, max_hearts)
