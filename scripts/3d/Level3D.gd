extends Node3D
## Drives one playthrough of a chosen location in full 3D:
## jeepney arrival ("Bayad ko, manong.") -> Tyanak wave -> stage clear ->
## Manananggal wave -> stage clear -> Tikbalang wave -> stage clear ->
## Kapre boss (break his balete tree with charged shots) -> ending.
## Each "stage clear" is the PuzzleScene pop-up: Congrats -> picture puzzle
## of the NEXT creature -> reveal -> next wave.

const PLAYER_SCRIPT := preload("res://scripts/3d/Player3D.gd")
const SHOOTING_SCRIPT := preload("res://scripts/3d/Shooting3D.gd")
const HURTBOX_SCRIPT := preload("res://scripts/3d/PlayerHurtbox3D.gd")
const RIG_SCRIPT := preload("res://scripts/3d/CameraRig3D.gd")
const TREE_SCRIPT := preload("res://scripts/3d/BaleteTree3D.gd")

const ENEMY_SCRIPTS := {
	"tyanak": preload("res://scripts/3d/Tyanak3D.gd"),
	"manananggal": preload("res://scripts/3d/Manananggal3D.gd"),
	"tikbalang": preload("res://scripts/3d/Tikbalang3D.gd"),
}
const KAPRE_SCRIPT := preload("res://scripts/3d/Kapre3D.gd")

const PUZZLE_SCENE := preload("res://scenes/puzzles/PuzzleScene.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/GameOver.tscn")
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
		"lore": "May ulo at paa ng kabayo, naglalagalag sa kawayanan. Bigla siyang sumusugod nang diretso - umiwas o tumalon!",
		"unlock": "Bagong kakayahan: DOUBLE JUMP! Pindutin ulit ang TALON habang nasa ere.",
	},
	"tikbalang": {
		"next": "kapre",
		"congrats": "Natalo mo ang mga Tikbalang! Isang huling kalaban na lang... buuin ang larawan para makilala siya.",
		"lore": "Higanteng nakatira sa puno ng balete at laging may tabako. Hindi siya tinatablan ng bato - patumbahin ang kanyang PUNO gamit ang CHARGED SHOT!",
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

var arena_radius: float = MapBuilder3D.ARENA
var info: Dictionary = {}

@onready var hud: CanvasLayer = $HUD
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
@onready var dialogue_label: Label = $DialogueLayer/Panel/Label

var player: CharacterBody3D
var rig: Node3D
var world: Node3D
var jeep: Node3D
var jeep_j: Dictionary = {}

var _spawned_this_stage: int = 0
var _active_enemies: Array[Node] = []
var _boss_started: bool = false
var _dialogue_token: int = 0
var _stage_clearing: bool = false
var _heartbeat_t: float = 0.0
var _charge_was_ready: bool = false
var _kapre: Node3D

func _ready() -> void:
	add_to_group("level")
	var map_id := GameManager.chosen_map_id if GameManager.chosen_map_id != "" else "banaue"
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	info = MapBuilder3D.build(world, map_id)
	_spawn_player()
	_spawn_camera()
	hud.visible = false
	dialogue_layer.visible = false
	GameManager.streak_changed.connect(_on_streak_changed)
	GameManager.hearts_changed.connect(_on_hearts_changed)
	Audio.play_ambient(str(info.get("ambient", "amb_countryside")))
	Audio.play_music("music_explore")
	_play_arrival_sequence()

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	var shooting := Node.new()
	shooting.name = "Shooting"
	shooting.set_script(SHOOTING_SCRIPT)
	player.add_child(shooting)
	var hurt := Area3D.new()
	hurt.name = "Hurtbox"
	hurt.set_script(HURTBOX_SCRIPT)
	player.add_child(hurt)
	player.position = info["spawn"]
	add_child(player)
	player.set("arena_radius", arena_radius)
	player.set("controls_enabled", false)
	player.visible = false
	hurt.connect("player_died", _on_player_died)

func _spawn_camera() -> void:
	rig = Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(RIG_SCRIPT)
	add_child(rig)
	rig.set("target", player)
	rig.set("yaw", 0.0)
	rig.call("snap")

# ------------------------------------------------------------ dialogue --
func show_dialogue(text: String, duration: float) -> void:
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

## Week 14 (pause behaviour): leaving the app - a call, a notification, the
## home button, or alt-tab on PC - pauses the fight instead of letting the
## creatures keep attacking while the player is away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and hud != null:
			open_pause_menu()

## Also called by the HUD's on-screen pause button.
func open_pause_menu() -> void:
	if get_tree().paused or not hud.visible or bool(player.get("is_dead")):
		return
	Audio.play_sfx("click")
	add_child(PAUSE_SCENE.instantiate())

# ------------------------------------------------------------- arrival --
func _play_arrival_sequence() -> void:
	jeep = Node3D.new()
	jeep.name = "Jeepney"
	world.add_child(jeep)
	jeep_j = Models.jeepney(jeep)
	var from: Vector3 = info["jeep_from"]
	var to: Vector3 = info["jeep_to"]
	jeep.global_position = from
	jeep.look_at(to + (to - from), Vector3.UP)
	# cinematic: watch the jeepney pull in
	var side := (to - from).normalized().cross(Vector3.UP)
	var cam_pos := to + side * 11.0 + Vector3(0, 3.5, 0) - (to - from).normalized() * 4.0
	rig.call("cinematic_to", cam_pos, to + Vector3(0, 1.2, 0), 0.01)
	Audio.play_loop("engine", -8.0)
	Audio.play_sfx("horn")
	var tw := create_tween()
	tw.tween_property(jeep, "global_position", to, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_spin_wheels, 0.0, 30.0, 3.0)
	await tw.finished
	Audio.stop_loop()
	Audio.play_sfx("jeep_brake", -6.0)
	var t := Audio.play_voice("driver_andito_na")
	show_dialogue("Manong: \"Andito na tayo!\"", maxf(1.6, t))
	await get_tree().create_timer(maxf(1.4, t), false).timeout
	# the farmer hops out of the back
	var back := jeep.global_transform * Vector3(0, 0, 3.6)
	player.global_position = Vector3(back.x, 0, back.z)
	player.visible = true
	player.call("face_towards", Vector3.ZERO)
	var land := player.create_tween()
	player.scale = Vector3.ONE * 0.8
	land.tween_property(player, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	FX.puff(world, player.global_position, Color(0.8, 0.75, 0.65), 0.5, 6)
	t = Audio.play_voice("player_bayad")
	show_dialogue("\"Bayad ko, manong.\"", maxf(1.6, t + 0.3))
	await get_tree().create_timer(maxf(1.4, t + 0.2), false).timeout
	t = Audio.play_voice("driver_ingat")
	show_dialogue("Manong: \"Sige, ingat ka!\"", maxf(1.4, t))
	await get_tree().create_timer(0.6, false).timeout
	# jeepney drives away
	Audio.play_loop("engine", -8.0)
	Audio.play_sfx("horn")
	var exit: Vector3 = info["jeep_exit"]
	var tw2 := create_tween()
	tw2.tween_callback(func() -> void: jeep.look_at(jeep.global_position + (exit - jeep.global_position) * 2.0, Vector3.UP))
	tw2.tween_property(jeep, "global_position", exit, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.parallel().tween_method(_spin_wheels, 0.0, 40.0, 3.2)
	tw2.tween_callback(func() -> void:
		Audio.stop_loop()
		jeep.queue_free()
	)
	# camera swings behind the player, control starts
	var to_center := (Vector3.ZERO - player.global_position)
	rig.set("yaw", atan2(-to_center.x, -to_center.z))
	rig.call("release", 1.2)
	await get_tree().create_timer(1.2, false).timeout
	player.set("controls_enabled", true)
	hud.visible = true
	_start_stage()

func _spin_wheels(angle: float) -> void:
	if not is_instance_valid(jeep):
		return
	for w in jeep_j.get("wheels", []):
		(w as Node3D).rotation.x = -angle

# -------------------------------------------------------------- stages --
func _start_stage() -> void:
	var stage := GameManager.current_stage_name()
	Audio.play_sfx("kulintang")
	Audio.play_voice("narrator_stage_" + stage)
	show_dialogue(str(STAGE_TITLES.get(stage, "")), 2.4)
	if stage == "kapre":
		_start_boss()
		return
	if stage == "tikbalang":
		get_tree().create_timer(3.0, false).timeout.connect(func() -> void: Audio.play_voice("narrator_double_jump"))
	if stage == "tyanak":
		# Week 14 (playtest P1: unsure what happens when an enemy gets close)
		var tip := "Tip: Batuhin ang Tyanak gamit ang TIRA bago siya makalapit. Kapag tinamaan ka niya, mababawasan ang PUSO mo." if Controls.touch_mode 			else "Tip: Batuhin ang Tyanak gamit ang X bago siya makalapit. Kapag tinamaan ka niya, mababawasan ang PUSO mo."
		get_tree().create_timer(2.6, false).timeout.connect(func() -> void: show_dialogue(tip, 5.0))
	_spawned_this_stage = 0
	_active_enemies.clear()
	await get_tree().create_timer(1.2, false).timeout
	_spawn_until_full(stage)

func _spawn_until_full(stage: String) -> void:
	while _active_enemies.size() < MAX_CONCURRENT_ENEMIES and _spawned_this_stage < GameManager.ENEMIES_PER_STAGE:
		_spawn_enemy(stage)

func _spawn_enemy(stage: String) -> void:
	var enemy := CharacterBody3D.new()
	enemy.set_script(ENEMY_SCRIPTS[stage])
	# somewhere around the player, inside the arena, not on top of them
	var p := player.global_position
	var pos := Vector3.ZERO
	for i in range(12):
		var a := randf() * TAU
		var d := randf_range(9.0, 14.0)
		pos = p + Vector3(cos(a) * d, 0, sin(a) * d)
		if Vector2(pos.x, pos.z).length() < arena_radius - 1.0:
			break
	var flat := Vector2(pos.x, pos.z).limit_length(arena_radius - 1.0)
	enemy.position = Vector3(flat.x, 0.1, flat.y)
	world.add_child(enemy)
	enemy.connect("defeated", _on_enemy_defeated.bind(enemy))
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
		# let the last creature's death animation play before the pop-up
		await get_tree().create_timer(1.4, false).timeout
		if not is_instance_valid(self) or bool(player.get("is_dead")):
			return
		_start_puzzle(stage)
	else:
		await get_tree().create_timer(0.8, false).timeout
		_spawn_until_full(stage)

func _start_puzzle(stage: String) -> void:
	var cfg: Dictionary = PUZZLE_CONFIG.get(stage, {})
	if cfg.is_empty():
		return
	var data := cfg.duplicate()
	data["defeated"] = stage
	var puzzle := PUZZLE_SCENE.instantiate()
	puzzle.call("setup", data)
	puzzle.connect("completed", _on_puzzle_completed)
	add_child(puzzle)

func _on_puzzle_completed() -> void:
	_stage_clearing = false
	GameManager.advance_stage()
	_start_stage()

# ---------------------------------------------------------------- boss --
func _start_boss() -> void:
	if _boss_started:
		return
	_boss_started = true
	Audio.play_music("music_boss")
	var tree := Node3D.new()
	tree.set_script(TREE_SCRIPT)
	tree.position = info["tree"]
	world.add_child(tree)
	var kapre := CharacterBody3D.new()
	kapre.set_script(KAPRE_SCRIPT)
	kapre.position = info["kapre"]
	world.add_child(kapre)
	_kapre = kapre
	tree.connect("needs_charge", _on_tree_needs_charge)
	tree.connect("fallen", _on_tree_fallen)
	# boss intro shot
	player.set("controls_enabled", false)
	var kp: Vector3 = info["kapre"]
	rig.call("cinematic_to", kp + Vector3(6, 4, 12), kp + Vector3(0, 4.5, 0), 1.2)
	await get_tree().create_timer(1.4, false).timeout
	Audio.voice_3d("creature_kapre", kp + Vector3(0, 4, 0), 6.0)
	show_dialogue("Huling Laban: KAPRE!  Tirahin ang PUNO gamit ang charged shot!", 3.5)
	await get_tree().create_timer(2.2, false).timeout
	rig.call("release", 1.0)
	await get_tree().create_timer(1.0, false).timeout
	player.set("controls_enabled", true)

func _on_tree_needs_charge() -> void:
	show_dialogue("Hindi tinatablan! Kailangan ng CHARGED SHOT (hawakan ang X).", 3.0)

func _on_tree_fallen() -> void:
	if is_instance_valid(_kapre):
		_kapre.call("force_defeat")
	_on_boss_defeated()

func _on_boss_defeated() -> void:
	SaveSystem.mark_enemy_completed("kapre")
	SaveSystem.mark_game_completed()
	player.set("controls_enabled", false)
	hud.visible = false
	Audio.stop_music(1.5)
	Audio.play_sfx("victory")
	await get_tree().create_timer(1.0, false).timeout
	var t := Audio.play_voice("narrator_panalo")
	player.call("play_victory")
	rig.call("cinematic_to", player.global_position + player.get("facing") * 5.0 + Vector3(0, 2.2, 0), player.global_position + Vector3(0, 1.2, 0), 1.5)
	await get_tree().create_timer(maxf(2.0, t), false).timeout
	Audio.play_voice("player_yes")
	await get_tree().create_timer(2.0, false).timeout
	Audio.stop_ambient()
	get_tree().change_scene_to_file("res://scenes/main/Ending.tscn")

# ------------------------------------------------------------ feedback --
func _on_streak_changed(_streak: int, charge_unlocked: bool) -> void:
	if charge_unlocked and not _charge_was_ready:
		Audio.play_voice("narrator_charge")
	_charge_was_ready = charge_unlocked

func _on_hearts_changed(current: int, _max_hearts: int) -> void:
	_heartbeat_t = 0.0 if current == 1 else -1.0

func _process(delta: float) -> void:
	if _heartbeat_t >= 0.0 and hud.visible and not bool(player.get("is_dead")):
		_heartbeat_t -= delta
		if _heartbeat_t <= 0.0:
			_heartbeat_t = 1.3
			Audio.play_sfx("heartbeat", -4.0)

func _on_player_died() -> void:
	hud.visible = false
	_dialogue_token += 1
	dialogue_layer.visible = false
	Audio.stop_music(1.0)
	get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
		Audio.play_voice("narrator_talo")
		add_child(GAME_OVER_SCENE.instantiate())
	)
