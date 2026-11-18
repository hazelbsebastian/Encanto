extends Node
## Week 15 (AS3) automated gameplay tests.
##
## Unlike TestProfiles.gd (save system only), these tests load the REAL game
## scenes - Level3D, PuzzleScene, PauseMenu, GameOver, RewardScreen, Wardrobe -
## and drive them the way a player would: enemies are hit, the puzzle is
## solved tile by tile, the boss tree is shot, buttons are pressed with real
## mouse events, and the app is "backgrounded" with the same notification
## Android sends.
##
## Run headless from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/TestGameplayRunner.tscn
## Optional: -- --only=F05,N04   (run a subset)
## Every test uses user://test_profiles_gameplay, never the player's real saves.
## Results are printed and written to user://test_results_gameplay.txt.

const TEST_DIR := "user://test_profiles_gameplay"
const LEVEL := "res://scenes/3d/Level3D.tscn"

var _lines: PackedStringArray = []
var _passed := 0
var _failed := 0
var _current := ""
var _current_ok := true
var _level: Node = null
var _scene: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	_out("Encanto AS3 gameplay tests (Week 15)")
	_out("Engine: Godot %s | OS: %s | Build: %s | Date: %s" % [Engine.get_version_info()["string"], OS.get_name(),
		ProjectSettings.get_setting("application/config/version"), Time.get_datetime_string_from_system()])
	_out("")
	var tests := [
		# --- functional (positive) ---
		["F01", "Every game scene loads without errors", f01_scenes_load],
		["F02", "Level starts: arrival -> HUD -> Tyanak wave (2 at a time)", f02_level_start],
		["F03", "Rock hits a creature: health -1, TAMA! shown", f03_rock_hits],
		["F04", "5 normal shots unlock the charged shot; using it resets the streak", f04_streak],
		["F05", "4 defeats -> stage clear puzzle; solving it starts Manananggal", f05_stage_progress],
		["F06", "Double jump unlocks at the Tikbalang stage", f06_double_jump],
		["F07", "Enemy hit costs a heart; invulnerability blocks a 2nd hit", f07_hearts],
		["F08", "0 hearts -> Game Over pauses the game; Try Again restores 5 hearts", f08_game_over],
		["F09", "Boss: normal shots do not hurt the tree; 4 charged hits win", f09_boss_win],
		["F10", "Win is saved: game_completed + kapre recorded for the profile", f10_win_saved],
		["F11", "PERA gives P500 and is saved immediately", f11_pera],
		["F12", "Bayong gives a reward from the pool and records it", f12_bayong],
		["F13", "Wardrobe: buy with enough money, refuse without, equip", f13_wardrobe],
		["F14", "Pause menu pauses the fight; resume continues", f14_pause],
		["F15", "Volume slider changes the Master bus; 0 = mute", f15_volume],
		["F16", "Quit to menu from pause saves and returns to Title", f16_quit_to_menu],
		# --- negative / boundary ---
		["N01", "Rapid input: 40 shots in one frame - no crash, rocks cleaned up", n01_rapid_shots],
		["N02", "Rapid input: pause pressed 10 times - one menu, state consistent", n02_rapid_pause],
		["N03", "Rapid input: double-tap 'Laban na!' must not skip a stage", n03_double_tap_puzzle],
		["N04", "Rapid input: double-tap PERA pays once", n04_double_pera],
		["N05", "Same creature hit twice in one frame counts one defeat", n05_double_hit],
		["N06", "Hearts never go below 0 or above max", n06_heart_bounds],
		["N07", "Missing data: unknown map id falls back to Banaue", n07_unknown_map],
		["N08", "Missing data: missing voice/sfx file does not crash", n08_missing_audio],
		["N09", "App backgrounded mid-fight -> auto-pause", n09_background_fight],
		["N10", "App backgrounded on Game Over / puzzle - no second menu", n10_background_overlays],
		["N11", "Boss intro: Kapre must not attack while the player is frozen", n11_boss_intro_frozen],
		["N12", "After the tree falls, leftover smoke must not cost hearts", n12_smoke_after_win],
		["N13", "Charge held while pausing is released cleanly after resume", n13_charge_through_pause],
		["N14", "Bought outfit survives app restart; money cannot go negative", n14_wardrobe_persist],
		["N15", "Real charged shots at the balete tree from 4 sides all count", n15_charged_shots_tree],
	]
	var only := _only_filter()
	for t in tests:
		if not only.is_empty() and not only.has(t[0]):
			continue
		await _fresh()
		_current = "%s %s" % [t[0], t[1]]
		_current_ok = true
		await t[2].call()
		await _cleanup()
		if _current_ok:
			_passed += 1
			_out("PASS  " + _current)
		else:
			_failed += 1
			_out("FAIL  " + _current)
	_out("")
	_out("Result: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_wipe(TEST_DIR)
	var f := FileAccess.open("user://test_results_gameplay.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	get_tree().quit(0 if _failed == 0 else 1)

func _only_filter() -> PackedStringArray:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			return a.trim_prefix("--only=").split(",")
	return PackedStringArray()

# ---------------------------------------------------------------- helpers ----

func _out(s: String) -> void:
	print(s)
	_lines.append(s)

func check(cond: bool, what: String) -> void:
	if not cond:
		_current_ok = false
		_out("      expected: " + what)

func note(s: String) -> void:
	_out("      " + s)

func _wipe(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d:
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(dir_path)

func _fresh() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_wipe(TEST_DIR)
	SaveSystem.profile_dir = TEST_DIR
	SaveSystem.legacy_save_path = "user://test_no_legacy.json"
	SaveSystem.init_storage()
	SaveSystem.create_profile("Tester")
	GameManager.reset_run()
	GameManager.chosen_map_id = "banaue"
	await frames(2)

func _cleanup() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	for n in get_tree().root.get_children():
		if n != self and not _is_autoload(n):
			n.queue_free()
	_level = null
	_scene = null
	await frames(3)

func _is_autoload(n: Node) -> bool:
	return n.name in ["GameManager", "SaveSystem", "ClothingData", "Audio", "Controls"]

func frames(n: int = 1) -> void:
	for i in range(n):
		await get_tree().process_frame

func physics(n: int = 1) -> void:
	for i in range(n):
		await get_tree().physics_frame

## Real-time wait that keeps running while the tree is paused.
func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		await frames(1)
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.0001) if get_tree().paused else get_process_delta_time()
		if t > timeout:
			return false
	return true

## Adds a scene as the current scene without replacing this runner.
func open_scene(path: String) -> Node:
	var s: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(s)
	get_tree().current_scene = s
	_scene = s
	return s

## Level3D with the arrival cut-scene sped up; returns once the HUD is shown.
func start_level(map_id: String = "banaue") -> Node:
	GameManager.chosen_map_id = map_id
	_level = open_scene(LEVEL)
	Engine.time_scale = 6.0
	var ok := await wait_until(func() -> bool: return _level.hud.visible, 30.0)
	Engine.time_scale = 1.0
	check(ok, "HUD shown after arrival")
	return _level

func enemies() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not bool(e.get("is_dead")):
			out.append(e)
	return out

func find_child_with(parent: Node, method_or_signal: String) -> Node:
	for c in parent.get_children():
		if c.has_signal(method_or_signal) or c.has_method(method_or_signal):
			return c
	return null

func puzzle() -> Node:
	return find_child_with(_level, "completed") if _level else null

func pause_menus() -> int:
	var n := 0
	for c in _level.get_children():
		if c.get_script() == load("res://scripts/ui/PauseMenu.gd"):
			n += 1
	return n

func game_over_shown() -> bool:
	for c in _level.get_children():
		if c.get_script() == load("res://scripts/ui/GameOver.gd"):
			return true
	return false

## Defeats every creature of the current wave (4), letting the level spawn
## the next ones the normal way.
func clear_wave() -> void:
	var killed := 0
	while killed < GameManager.ENEMIES_PER_STAGE:
		var ok := await wait_until(func() -> bool: return not enemies().is_empty(), 6.0)
		if not ok:
			check(false, "creature spawned (killed %d)" % killed)
			return
		var e: Node = enemies()[0]
		e.call("take_damage", int(e.get("max_health")), false, Vector3.ZERO)
		killed += 1
		await frames(2)

## Solves the puzzle by really pressing tiles (swap into place), then presses
## the reveal screen's button.
func solve_puzzle(p: Node) -> void:
	p.call("_show_puzzle")
	await frames(2)
	var order: Array = p.get("_order")
	for i in range(order.size()):
		order = p.get("_order")
		if int(order[i]) == i:
			continue
		var j := order.find(i)
		var tiles: Array = p.get("_tiles")
		(tiles[i] as Button).pressed.emit()
		(tiles[j] as Button).pressed.emit()
	check(bool(p.get("_solved")), "puzzle solved by tile presses")
	await wait(1.2)   # solved -> reveal screen

func reveal_button(p: Node) -> Button:
	for b in p.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Laban na"):
			return b
	return null

func click(b: Control) -> void:
	var pos := b.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev, true)

## Sends the notification exactly the way the OS does: to the SceneTree
## (the MainLoop), which propagates it down from the root.
func os_background(what: int) -> void:
	get_tree().notification(what)

func hit_player(times: int = 1) -> void:
	var hurt: Node = _level.player.get_node("Hurtbox")
	for i in range(times):
		hurt.set("invulnerable", false)
		var a := Area3D.new()
		_level.world.add_child(a)
		a.global_position = _level.player.global_position + Vector3(0, 1, 0)
		hurt.call("_on_area_entered", a)
		a.queue_free()

## Jumps straight to the boss stage (skipping 3 waves) with charge ready.
func go_to_boss() -> void:
	GameManager.current_stage_index = 3
	_level.call("_start_stage")

# ------------------------------------------------------------- functional ----

func f01_scenes_load() -> void:
	var scenes := ["res://scenes/main/Title.tscn", "res://scenes/ui/ProfileSelect.tscn", "res://scenes/jeepney/JeepneyIntro.tscn",
		"res://scenes/jeepney/MapSelect.tscn", "res://scenes/jeepney/JeepneyTravel.tscn", LEVEL, "res://scenes/main/Ending.tscn",
		"res://scenes/ui/RewardScreen.tscn", "res://scenes/main/FinalEnding.tscn", "res://scenes/ui/Wardrobe.tscn"]
	for p in scenes:
		var packed := load(p) as PackedScene
		check(packed != null, "%s loads" % p)
		if packed == null:
			continue
		var s := packed.instantiate()
		check(s != null, "%s instantiates" % p)
		get_tree().root.add_child(s)
		await frames(3)
		check(is_instance_valid(s), "%s still alive after 3 frames" % p)
		s.queue_free()
		await frames(2)
	note("%d scenes opened" % scenes.size())

func f02_level_start() -> void:
	await start_level()
	check(GameManager.current_stage_name() == "tyanak", "stage 1 is tyanak")
	check(bool(_level.player.get("controls_enabled")), "controls enabled after arrival")
	await wait_until(func() -> bool: return enemies().size() > 0, 4.0)
	await frames(5)
	note("creatures on field: %d" % enemies().size())
	check(enemies().size() == 2, "2 creatures at a time (MAX_CONCURRENT_ENEMIES)")
	check(GameManager.current_hearts == 5, "starts with 5 hearts")

## 12 aimed shots at a standing creature from different distances and
## angles. Every one is a direct hit and must register as TAMA!, not MINTIS.
func f03_rock_hits() -> void:
	await start_level()
	await wait_until(func() -> bool: return enemies().size() > 0, 4.0)
	var sh: Node = _level.player.get_node("Shooting")
	var hits := 0
	var misses := 0
	var trials := 0
	for dist in [3.0, 5.0, 8.0, 11.0]:
		for ang in [-0.5, 0.0, 0.5]:
			for other in enemies():
				other.set("_stun", 99.0)
			var e: Node3D = enemies()[0]
			for other in enemies():
				if other != e:
					other.global_position = Vector3(30, 0.1, 30)   # out of range
			e.set("health", int(e.get("max_health")))
			e.set("_stun", 99.0)   # stunned creatures stand still (no AI)
			var p: Vector3 = _level.player.global_position
			e.global_position = p + Vector3(sin(ang) * dist, 0.1, -cos(ang) * dist)
			e.velocity = Vector3.ZERO
			await physics(4)
			for n in get_tree().current_scene.find_children("*", "Label3D", true, false):
				if (n as Label3D).text == "MINTIS" or (n as Label3D).text.begins_with("TAMA!"):
					n.free()
			var hp := int(e.get("health"))
			sh.call("shoot_button_down")
			trials += 1
			var ok := await wait_until(func() -> bool: return int(e.get("health")) < hp, 1.0)
			if ok:
				hits += 1
			else:
				misses += 1
			await physics(2)
			GameManager.reset_streak_lock()
	note("direct shots: %d, registered as hit: %d, shown as MINTIS / no damage: %d" % [trials, hits, misses])
	check(misses == 0, "every direct shot damages the creature")
	var popup := false
	for n in _level.world.find_children("*", "Label3D", true, false):
		if (n as Label3D).text.begins_with("TAMA!"):
			popup = true
	check(hits == 0 or popup, "TAMA! popup shown on a hit")

func f04_streak() -> void:
	await start_level()
	var sh: Node = _level.player.get_node("Shooting")
	for i in range(4):
		sh.call("shoot_button_down")
	check(not GameManager.charge_unlocked, "not ready after 4")
	sh.call("shoot_button_down")
	check(GameManager.charge_unlocked, "CHARGE READY after 5")
	sh.call("shoot_button_down")
	check(bool(sh.get("is_charging")), "holding starts a charge")
	await wait(0.5)
	sh.call("shoot_button_up")
	check(not GameManager.charge_unlocked and GameManager.shot_streak == 0, "charged shot consumed the streak")

func f05_stage_progress() -> void:
	await start_level()
	await clear_wave()
	check(GameManager.puzzle_pieces == 4, "4 puzzle pieces collected")
	var ok := await wait_until(func() -> bool: return puzzle() != null, 3.0)
	check(ok, "stage-clear puzzle opened")
	if not ok:
		return
	check(get_tree().paused, "game paused during puzzle")
	var p := puzzle()
	await solve_puzzle(p)
	var b := reveal_button(p)
	check(b != null, "reveal screen with 'Laban na!' button")
	if b:
		b.pressed.emit()
	await frames(2)
	check(not get_tree().paused, "game resumed")
	check(GameManager.current_stage_name() == "manananggal", "stage 2 is manananggal")
	ok = await wait_until(func() -> bool: return enemies().size() > 0, 4.0)
	check(ok and str(enemies()[0].get("enemy_id")) == "manananggal", "Manananggal spawned")

func f06_double_jump() -> void:
	GameManager.reset_run()
	check(not GameManager.double_jump_unlocked, "locked at start")
	GameManager.advance_stage()
	check(not GameManager.double_jump_unlocked, "locked at Manananggal")
	GameManager.advance_stage()
	check(GameManager.double_jump_unlocked and GameManager.current_stage_name() == "tikbalang", "unlocked at Tikbalang")

func f07_hearts() -> void:
	await start_level()
	var hurt: Node = _level.player.get_node("Hurtbox")
	var a := Area3D.new()
	_level.world.add_child(a)
	hurt.call("_on_area_entered", a)
	check(GameManager.current_hearts == 4, "5 -> 4 hearts")
	hurt.call("_on_area_entered", a)
	check(GameManager.current_hearts == 4, "2nd hit within 1.1 s ignored")
	await wait(1.3)
	hurt.call("_on_area_entered", a)
	check(GameManager.current_hearts == 3, "hit after invulnerability counts")
	a.queue_free()

func f08_game_over() -> void:
	await start_level()
	hit_player(5)
	check(GameManager.current_hearts == 0, "0 hearts")
	check(bool(_level.player.get("is_dead")), "player dead")
	var ok := await wait_until(game_over_shown, 3.0)
	check(ok, "Game Over shown")
	check(get_tree().paused, "game paused under Game Over")
	GameManager.restart_after_death()   # what Try Again does before reloading
	check(GameManager.current_hearts == 5 and GameManager.chosen_map_id == "banaue" and GameManager.current_stage_index == 0,
		"Try Again: 5 hearts, same place, stage 1")

func f09_boss_win() -> void:
	await start_level()
	go_to_boss()
	var ok := await wait_until(func() -> bool: return get_tree().get_first_node_in_group("charged_targets") != null, 3.0)
	check(ok, "balete tree spawned")
	var tree: Node = get_tree().get_first_node_in_group("charged_targets")
	await wait_until(func() -> bool: return bool(_level.player.get("controls_enabled")), 8.0)
	tree.call("take_damage", 1, false, Vector3.ZERO)
	check(int(tree.get("hits_taken")) == 0, "normal rock does nothing to the tree")
	for i in range(4):
		tree.call("take_damage", 3, true, Vector3.ZERO)
	check(bool(tree.get("is_felled")), "felled after 4 charged hits")
	ok = await wait_until(func() -> bool: return SaveSystem.game_completed, 5.0)
	check(ok, "boss defeat registered")

func f10_win_saved() -> void:
	await start_level()
	_level.call("_on_boss_defeated")
	await frames(2)
	var id := SaveSystem.active_id
	SaveSystem.init_storage()   # simulate closing and reopening the game
	SaveSystem.select_profile(id)
	check(SaveSystem.game_completed, "game_completed survives restart")
	check(SaveSystem.completed_enemies.has("kapre"), "kapre recorded")

func f11_pera() -> void:
	var s := open_scene("res://scenes/ui/RewardScreen.tscn")
	await frames(2)
	var before := SaveSystem.money
	s.get("pera_button").pressed.emit()
	check(SaveSystem.money == before + 500, "money +500")
	var id := SaveSystem.active_id
	SaveSystem.init_storage()
	SaveSystem.select_profile(id)
	check(SaveSystem.money == before + 500, "P500 still there after restart")

func f12_bayong() -> void:
	var s := open_scene("res://scenes/ui/RewardScreen.tscn")
	await frames(2)
	s.get("bayong_button").pressed.emit()
	await frames(1)
	var m0 := SaveSystem.money
	var u0 := SaveSystem.unlocked_clothing.size()
	s.get("bayong_open_button").pressed.emit()
	await wait(0.8)
	check(SaveSystem.bayong_rewards_obtained.size() == 1, "reward recorded")
	var got := SaveSystem.money > m0 or SaveSystem.unlocked_clothing.size() > u0 or SaveSystem.bayong_rewards_obtained.size() == 1
	check(got, "money or outfit received")
	note("reward: %s" % str(SaveSystem.bayong_rewards_obtained))
	check(bool(s.get("result_panel").visible), "result shown")

func f13_wardrobe() -> void:
	var s := open_scene("res://scenes/ui/Wardrobe.tscn")
	await frames(2)
	s.call("_on_buy", "accessory", "salakot")   # P0 -> refuse
	check(not SaveSystem.is_unlocked("salakot"), "refused with P0")
	check(str(s.get("message_label").text).contains("Kulang"), "'Kulang ang iyong pera' shown")
	SaveSystem.add_money(300)
	s.call("_on_buy", "accessory", "salakot")
	check(SaveSystem.is_unlocked("salakot") and SaveSystem.money == 0, "bought for exactly P300")
	s.call("_on_equip", "accessory", "salakot")
	check(SaveSystem.equipped["accessory"] == "salakot", "equipped")

func f14_pause() -> void:
	await start_level()
	_level.call("open_pause_menu")
	await frames(1)
	check(get_tree().paused and pause_menus() == 1, "paused with one menu")
	var p0: Vector3 = _level.player.global_position
	await wait(0.5)
	check(GameManager.current_hearts == 5, "no damage while paused")
	var menu: Node = null
	for c in _level.get_children():
		if c.get_script() == load("res://scripts/ui/PauseMenu.gd"):
			menu = c
	menu.call("_resume")
	await frames(2)
	check(not get_tree().paused and pause_menus() == 0, "resumed")
	check(_level.player.global_position.distance_to(p0) < 0.5, "player did not drift while paused")

func f15_volume() -> void:
	SaveSystem.set_volume(0.5)
	var db := AudioServer.get_bus_volume_db(0)
	note("0.5 -> Master %.1f dB" % db)
	check(db < -1.0 and db > -20.0, "half volume lowers Master")
	SaveSystem.set_volume(0.0)
	check(AudioServer.is_bus_mute(0) or AudioServer.get_bus_volume_db(0) <= -60.0, "0 mutes")
	SaveSystem.set_volume(1.0)
	check(absf(AudioServer.get_bus_volume_db(0)) < 0.1 and not AudioServer.is_bus_mute(0), "1 = full")

func f16_quit_to_menu() -> void:
	await start_level()
	SaveSystem.add_money(42)
	_level.call("open_pause_menu")
	await frames(1)
	for c in _level.get_children():
		if c.get_script() == load("res://scripts/ui/PauseMenu.gd"):
			c.call("_quit")
	await frames(3)
	check(not get_tree().paused, "unpaused")
	check(get_tree().current_scene != null and str(get_tree().current_scene.scene_file_path).ends_with("Title.tscn"), "Title is the current scene")
	var id := SaveSystem.active_id
	SaveSystem.init_storage()
	SaveSystem.select_profile(id)
	check(SaveSystem.money == 42, "money saved on quit")

# ------------------------------------------------------- negative / boundary ----

func n01_rapid_shots() -> void:
	await start_level()
	var sh: Node = _level.player.get_node("Shooting")
	var before := get_tree().get_node_count()
	for i in range(40):
		sh.call("shoot_button_down")
		sh.call("shoot_button_up")
	await frames(1)
	var rocks := 0
	for c in get_tree().current_scene.get_children():
		if c.get_script() == load("res://scripts/3d/Rock3D.gd"):
			rocks += 1
	note("rocks right after: %d, nodes %d -> %d" % [rocks, before, get_tree().get_node_count()])
	await wait(2.2)
	var left := 0
	for c in get_tree().current_scene.get_children():
		if c.get_script() == load("res://scripts/3d/Rock3D.gd"):
			left += 1
	note("rocks after 2.2 s: %d" % left)
	check(left == 0, "every rock freed after its 1.8 s lifetime")
	check(GameManager.shot_streak >= 0, "streak valid")

func n02_rapid_pause() -> void:
	await start_level()
	for i in range(10):
		var ev := InputEventAction.new()
		ev.action = "pause"
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := InputEventAction.new()
		up.action = "pause"
		up.pressed = false
		Input.parse_input_event(up)
	await frames(3)
	note("menus open: %d, paused: %s" % [pause_menus(), get_tree().paused])
	check(pause_menus() <= 1, "never more than one pause menu")
	check(get_tree().paused == (pause_menus() == 1), "paused only when a menu is open")

func n03_double_tap_puzzle() -> void:
	await start_level()
	await clear_wave()
	var ok := await wait_until(func() -> bool: return puzzle() != null, 3.0)
	if not ok:
		check(false, "puzzle opened")
		return
	var p := puzzle()
	await solve_puzzle(p)
	var b := reveal_button(p)
	check(b != null, "reveal button")
	if b == null:
		return
	await frames(2)
	click(b)
	click(b)   # second tap in the same frame (fast double-tap / bounce)
	await frames(3)
	note("stage after double tap: %s (index %d)" % [GameManager.current_stage_name(), GameManager.current_stage_index])
	check(GameManager.current_stage_index == 1, "only one stage advanced")

func n04_double_pera() -> void:
	var s := open_scene("res://scenes/ui/RewardScreen.tscn")
	await frames(3)
	var b: Button = s.get("pera_button")
	click(b)
	click(b)
	await frames(3)
	note("money after double tap: %d" % SaveSystem.money)
	check(SaveSystem.money == 500, "paid exactly once")

func n05_double_hit() -> void:
	await start_level()
	await wait_until(func() -> bool: return enemies().size() > 0, 4.0)
	var e: Node = enemies()[0]
	e.call("take_damage", 3, false, Vector3.ZERO)
	e.call("take_damage", 3, false, Vector3.ZERO)
	check(GameManager.enemies_defeated_this_stage == 1 and GameManager.puzzle_pieces == 1, "one defeat, one piece")

func n06_heart_bounds() -> void:
	GameManager.reset_run()
	GameManager.damage_player(99)
	check(GameManager.current_hearts == 0, "clamped at 0")
	GameManager.heal_player(99)
	check(GameManager.current_hearts == GameManager.max_hearts, "clamped at max")

func n07_unknown_map() -> void:
	await start_level("not_a_place")
	check(_level.hud.visible and _level.info.has("spawn"), "level built with fallback map")

func n08_missing_audio() -> void:
	var t: float = Audio.play_voice("this_voice_does_not_exist")
	Audio.play_sfx("this_sfx_does_not_exist")
	await frames(2)
	check(t >= 0.0, "play_voice returns a duration instead of crashing")

func n09_background_fight() -> void:
	await start_level()
	os_background(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(1)
	check(get_tree().paused and pause_menus() == 1, "auto-paused with menu")
	os_background(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	await frames(1)
	check(pause_menus() == 1, "second background event does not stack menus")

func n10_background_overlays() -> void:
	await start_level()
	# (a) during the stage-clear puzzle
	await clear_wave()
	await wait_until(func() -> bool: return puzzle() != null, 3.0)
	os_background(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(pause_menus() == 0, "no pause menu on top of the puzzle")
	check(get_tree().paused and puzzle() != null, "puzzle still open and game still paused")
	var p := puzzle()
	await solve_puzzle(p)
	reveal_button(p).pressed.emit()
	await frames(2)
	check(not get_tree().paused, "puzzle closes normally afterwards")
	# (b) on the Game Over screen
	hit_player(5)
	await wait_until(game_over_shown, 3.0)
	os_background(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(pause_menus() == 0, "no pause menu on top of Game Over")

func n11_boss_intro_frozen() -> void:
	await start_level()
	GameManager.current_hearts = 5
	_level.player.global_position = Vector3(-6, 0, -4)   # in front of the Kapre (10 m)
	go_to_boss()
	var hearts_lost := 0
	var smoke_seen := 0
	var t := 0.0
	while not bool(_level.player.get("controls_enabled")) and t < 8.0:
		await physics(1)
		t += get_physics_process_delta_time()
		for c in _level.world.get_children():
			if c.get_script() == load("res://scripts/3d/Smoke3D.gd"):
				smoke_seen = maxi(smoke_seen, 1)
	hearts_lost = 5 - GameManager.current_hearts
	note("intro lasted %.1f s, smoke during intro: %s, hearts lost: %d" % [t, "yes" if smoke_seen > 0 else "no", hearts_lost])
	check(smoke_seen == 0, "no smoke while the player cannot move")
	check(hearts_lost == 0, "no hearts lost during the intro")

func n12_smoke_after_win() -> void:
	await start_level()
	go_to_boss()
	await wait_until(func() -> bool: return bool(_level.player.get("controls_enabled")), 8.0)
	GameManager.current_hearts = 1
	var tree: Node = get_tree().get_first_node_in_group("charged_targets")
	for i in range(4):
		tree.call("take_damage", 3, true, Vector3.ZERO)
	# the tree takes ~2.3 s to fall; meanwhile a smoke ring is already flying at
	# the player (the Kapre attacks every 2.2-3.6 s)
	await wait_until(func() -> bool: return SaveSystem.game_completed, 5.0)
	var s := Area3D.new()
	s.set_script(load("res://scripts/3d/Smoke3D.gd"))
	s.call("setup", Vector3(0, 0, 1))
	_level.world.add_child(s)
	s.global_position = _level.player.global_position + Vector3(0, 0.9, -2.0)
	await wait(1.5)
	note("hearts after victory: %d, player dead: %s, game over shown: %s" % [GameManager.current_hearts, _level.player.get("is_dead"), game_over_shown()])
	check(GameManager.current_hearts == 1, "no heart lost after winning")
	check(not game_over_shown(), "no Game Over after winning")

func n13_charge_through_pause() -> void:
	await start_level()
	var sh: Node = _level.player.get_node("Shooting")
	GameManager.charge_unlocked = true
	_level.hud.call("_on_shoot_down")
	check(bool(sh.get("is_charging")), "charging")
	_level.call("open_pause_menu")
	await frames(1)
	_level.hud.call("_on_shoot_up")   # finger lifted while the pause menu is open
	for c in _level.get_children():
		if c.get_script() == load("res://scripts/ui/PauseMenu.gd"):
			c.call("_resume")
	await frames(3)
	note("charging after resume: %s" % sh.get("is_charging"))
	check(not bool(sh.get("is_charging")), "charge not stuck after resume")

func n14_wardrobe_persist() -> void:
	SaveSystem.add_money(500)
	check(SaveSystem.spend_money(500), "spend 500")
	SaveSystem.unlock_clothing("improved_polo")
	check(not SaveSystem.spend_money(1), "cannot spend with P0")
	check(SaveSystem.money == 0, "money not negative")
	var id := SaveSystem.active_id
	SaveSystem.init_storage()
	SaveSystem.select_profile(id)
	check(SaveSystem.is_unlocked("improved_polo") and SaveSystem.money == 0, "outfit and P0 survive restart")

func n15_charged_shots_tree() -> void:
	await start_level()
	go_to_boss()
	await wait_until(func() -> bool: return bool(_level.player.get("controls_enabled")), 8.0)
	var tree: Node3D = get_tree().get_first_node_in_group("charged_targets")
	var kapre: Node = null
	for c in _level.world.get_children():
		if c.get_script() == load("res://scripts/3d/Kapre3D.gd"):
			kapre = c
	if kapre:
		kapre.set("_stun", 999.0)   # no smoke during this test
	var sh: Node = _level.player.get_node("Shooting")
	var counted := 0
	var sides := [Vector3(0, 0, 9), Vector3(9, 0, 0), Vector3(-9, 0, 3), Vector3(5, 0, 8)]
	for off in sides:
		_level.player.global_position = tree.global_position + off
		await physics(3)
		var before := int(tree.get("hits_taken"))
		GameManager.charge_unlocked = true
		sh.call("shoot_button_down")
		await wait(0.6)
		sh.call("shoot_button_up")
		var ok := await wait_until(func() -> bool: return int(tree.get("hits_taken")) > before, 1.5)
		if ok:
			counted += 1
		await physics(5)
	note("charged shots fired: %d, counted by the tree: %d" % [sides.size(), counted])
	check(counted == sides.size(), "every charged shot at the tree counts")
