extends Node2D
## Drives one full playthrough of a chosen location: arrival cutscene ->
## Tyanak wave -> stage clear -> Manananggal wave -> stage clear -> Tikbalang
## wave -> stage clear -> Kapre boss fight -> ending. Each "stage clear" is
## the PuzzleScene sequence: Congrats -> picture puzzle made of the pieces the
## enemies dropped (it shows the NEXT creature) -> reveal -> next wave.
## Attach to the Level scene root.

const LEVEL_WIDTH := 1600.0
const GROUND_Y := 460.0

const MAP_TEXTURES := {
	"banaue": preload("res://assets/maps/bg_banaue.png"),
	"intramuros": preload("res://assets/maps/bg_intramuros.png"),
	"mayon": preload("res://assets/maps/bg_mayon.png"),
	"chocolate_hills": preload("res://assets/maps/bg_chocolate_hills.png"),
	"boracay": preload("res://assets/maps/bg_boracay.png"),
}

const ENEMY_SCENES := {
	"tyanak": preload("res://scenes/enemies/Tyanak.tscn"),
	"manananggal": preload("res://scenes/enemies/Manananggal.tscn"),
	"tikbalang": preload("res://scenes/enemies/Tikbalang.tscn"),
}

const PUZZLE_SCENE := preload("res://scenes/puzzles/PuzzleScene.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/GameOver.tscn")
const TREE_SCENE := preload("res://scenes/enemies/Tree.tscn")
const KAPRE_SCENE := preload("res://scenes/enemies/Kapre.tscn")

const PAUSE_SCENE := preload("res://scenes/ui/PauseMenu.tscn")

## Text for each stage-clear sequence, keyed by the stage just finished.
const PUZZLE_CONFIG := {
	"tyanak": {
		"next": "manananggal",
		"congrats": "Bawat Tyanak na natalo mo ay nag-iwan ng isang piraso ng larawan. Buuin ito para makilala ang susunod mong kalaban!",
		"lore": "Babaeng humihiwalay ang katawan tuwing gabi at lumilipad gamit ang malalaking pakpak ng paniki. Mag-ingat sa kanyang pagsisid mula sa langit!",
		"unlock": "",
	},
	"manananggal": {
		"next": "tikbalang",
		"congrats": "Napalayas mo ang mga Manananggal! Nakuha mo na ang lahat ng piraso - buuin ang larawan para makita kung sino ang naghihintay.",
		"lore": "May ulo at paa ng kabayo, naglalagalag sa kawayanan at nagliligaw ng mga manlalakbay. Mabilis siyang tumakbo at sumipa!",
		"unlock": "Bagong kakayahan: DOUBLE JUMP! Pindutin ulit ang TALON habang nasa ere.",
	},
	"tikbalang": {
		"next": "kapre",
		"congrats": "Natalo mo ang mga Tikbalang! Isang huling kalaban na lang... buuin ang larawan para makilala siya.",
		"lore": "Higanteng nakatira sa puno ng balete at laging may tabako. Hindi siya tinatablan ng bato - patumbahin ang kanyang puno gamit ang CHARGED SHOT!",
		"unlock": "Tip: 5 sunod-sunod na tira = CHARGE READY. Hawakan ang TIRA (X) para mag-charge.",
	},
}

const STAGE_TITLES := {
	"tyanak": "Unang Yugto: TYANAK",
	"manananggal": "Ikalawang Yugto: MANANANGGAL",
	"tikbalang": "Ikatlong Yugto: TIKBALANG",
	"kapre": "Huling Laban: KAPRE",
}

const MAX_CONCURRENT_ENEMIES := 2

@onready var background: Sprite2D = $Background
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var jeepney: Sprite2D = $JeepneyArrival
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
@onready var dialogue_label: Label = $DialogueLayer/Panel/Label
@onready var hud: CanvasLayer = $HUD

var _spawned_this_stage: int = 0
var _active_enemies: Array = []
var _boss_started: bool = false
var _dialogue_token: int = 0
var _stage_clearing: bool = false

func _ready() -> void:
	# Note: GameManager.reset_run() already happened back in JeepneyIntro,
	# before the map was chosen - don't reset here or chosen_map_id is lost.
	_setup_background()
	_setup_camera()
	player.global_position = Vector2(230, GROUND_Y)
	player.set_physics_process(false)
	hud.visible = false
	player.get_node("Hurtbox").player_died.connect(_on_player_died)
	await get_tree().create_timer(0.4).timeout
	_play_arrival_sequence()

func _setup_background() -> void:
	var tex: Texture2D = MAP_TEXTURES.get(GameManager.chosen_map_id, MAP_TEXTURES["banaue"])
	background.texture = tex
	background.centered = false
	var tex_size := tex.get_size()
	background.scale = Vector2(LEVEL_WIDTH / tex_size.x, 540.0 / tex_size.y)
	background.position = Vector2.ZERO

func _setup_camera() -> void:
	camera.limit_left = 0
	camera.limit_right = int(LEVEL_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 540
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0

func show_dialogue(text: String, duration: float) -> void:
	# A token makes sure an older line's timer can't hide a newer line early.
	_dialogue_token += 1
	var token := _dialogue_token
	dialogue_label.text = text
	dialogue_layer.visible = true
	await get_tree().create_timer(duration, false).timeout
	if is_instance_valid(dialogue_layer) and token == _dialogue_token:
		dialogue_layer.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause_menu()

## Also called by the HUD's on-screen pause button.
func open_pause_menu() -> void:
	if get_tree().paused or not hud.visible or bool(player.get("is_dead")):
		return
	Audio.play_sfx("click")
	get_tree().current_scene.add_child(PAUSE_SCENE.instantiate())

func _play_arrival_sequence() -> void:
	jeepney.visible = true
	jeepney.position = Vector2(150, GROUND_Y - 30)
	await show_dialogue("Bayad ko, manong.", 1.6)
	var tw := create_tween()
	tw.tween_property(jeepney, "position:x", LEVEL_WIDTH + 200, 1.6)
	await tw.finished
	jeepney.visible = false
	player.set_physics_process(true)
	hud.visible = true
	_start_stage()

func _start_stage() -> void:
	var stage := GameManager.current_stage_name()
	if stage == "kapre":
		_start_boss()
		return
	_spawned_this_stage = 0
	_active_enemies.clear()
	show_dialogue(str(STAGE_TITLES.get(stage, "")), 2.0)
	_spawn_until_full(stage)

func _spawn_until_full(stage: String) -> void:
	while _active_enemies.size() < MAX_CONCURRENT_ENEMIES and _spawned_this_stage < GameManager.ENEMIES_PER_STAGE:
		_spawn_enemy(stage)

func _spawn_enemy(stage: String) -> void:
	var scene: PackedScene = ENEMY_SCENES[stage]
	var enemy = scene.instantiate()
	add_child(enemy)
	var spawn_x := clampf(player.global_position.x + randf_range(260.0, 480.0) * (1 if randf() > 0.3 else -1), 80.0, LEVEL_WIDTH - 80.0)
	enemy.global_position = Vector2(spawn_x, GROUND_Y)
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
	_active_enemies.append(enemy)
	_spawned_this_stage += 1

func _on_enemy_defeated(enemy: Node) -> void:
	Audio.play_sfx("puzzle_pickup")
	_active_enemies.erase(enemy)
	var stage := GameManager.current_stage_name()
	if GameManager.stage_wave_complete():
		if _stage_clearing:
			return
		_stage_clearing = true
		# let the last enemy's death animation play before the pop-up
		await get_tree().create_timer(1.1, false).timeout
		if not is_instance_valid(self) or bool(player.get("is_dead")):
			return
		_start_puzzle(stage)
	else:
		_spawn_until_full(stage)

func _start_puzzle(stage: String) -> void:
	var cfg: Dictionary = PUZZLE_CONFIG.get(stage, {})
	if cfg.is_empty():
		return
	var data := cfg.duplicate()
	data["defeated"] = stage
	var puzzle = PUZZLE_SCENE.instantiate()
	puzzle.setup(data)  # before add_child: the pop-up builds itself in _ready
	puzzle.completed.connect(_on_puzzle_completed)
	get_tree().current_scene.add_child(puzzle)

func _on_puzzle_completed() -> void:
	_stage_clearing = false
	GameManager.advance_stage()
	_start_stage()

func _start_boss() -> void:
	if _boss_started:
		return
	_boss_started = true
	var tree = TREE_SCENE.instantiate()
	add_child(tree)
	tree.global_position = Vector2(LEVEL_WIDTH * 0.62, GROUND_Y)

	var kapre = KAPRE_SCENE.instantiate()
	add_child(kapre)
	kapre.global_position = Vector2(LEVEL_WIDTH * 0.5, GROUND_Y)

	tree.fallen.connect(func():
		kapre.force_defeat()
		_on_boss_defeated()
	)
	show_dialogue("Huling Laban: KAPRE!  Tirahin ang PUNO gamit ang charged shot (hawakan ang X)!", 3.5)

func _on_boss_defeated() -> void:
	SaveSystem.mark_enemy_completed("kapre")
	SaveSystem.mark_game_completed()
	player.set_physics_process(false)
	hud.visible = false
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func():
		player.play_victory()
		get_tree().change_scene_to_file("res://scenes/main/Ending.tscn")
	)

func _on_player_died() -> void:
	hud.visible = false
	var go = GAME_OVER_SCENE.instantiate()
	get_tree().current_scene.add_child(go)
