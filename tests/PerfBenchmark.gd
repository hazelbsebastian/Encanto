extends Node
## Week 16 (SA6 / AS3) repeatable performance benchmark.
##
## Runs the SAME scripted scenario every time so builds can be compared:
##   Part A - load test: each of the 5 maps is loaded once; map-build time and
##            first-frame time are measured, then 3 s of the arrival view are
##            sampled (static scene: draw calls / objects / primitives).
##   Part B - gameplay: Banaue, 60 s of combat (player walks a fixed square and
##            taps SHOOT every 0.35 s, puzzles are solved automatically), then
##            15 s of the Kapre boss fight (smoke attacks; the player only
##            walks so the tree never falls and the run length is fixed).
## The player cannot die during the run (hurtbox off) so every run lasts the
## same time. Random spawns use a fixed seed.
##
## Must run WITH rendering (not --headless), vsync off, uncapped FPS:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tests/PerfBenchmark.tscn -- --label=baseline
## Writes user://perf/<label>_frames.csv and user://perf/<label>_summary.txt.

const LEVEL := "res://scenes/3d/Level3D.tscn"
const TEST_DIR := "user://test_profiles_perf"
const MAPS := ["banaue", "intramuros", "mayon", "chocolate_hills", "boracay"]
const COMBAT_SEC := 60.0
const BOSS_SEC := 15.0
const SHOT_EVERY := 0.30

var label := "run"
var phase := ""
var rows: PackedStringArray = []
var phase_frames: Dictionary = {}   # phase -> Array of Dictionaries
var load_lines: PackedStringArray = []
var focus_pauses_dismissed := 0
var _last_us := 0
var _level: Node = null
var _vp_rid: RID

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			label = a.trim_prefix("--label=")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	rows.append("t_s,phase,frame_ms,process_ms,physics_ms,render_cpu_ms,render_gpu_ms,draw_calls,objects,primitives,nodes,static_mem_mb,video_mem_mb")
	_run.call_deferred()

# ---------------------------------------------------------------- sampling --
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		return
	var frame_ms := (now - _last_us) / 1000.0
	_last_us = now
	_dismiss_focus_pause()
	if phase == "":
		return
	var r := {
		"frame_ms": frame_ms,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu(),
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"static_mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}
	if not phase_frames.has(phase):
		phase_frames[phase] = []
	(phase_frames[phase] as Array).append(r)
	rows.append("%.3f,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%.2f,%.2f" % [now / 1e6, phase, frame_ms, r.process_ms, r.physics_ms,
		r.render_cpu_ms, r.render_gpu_ms, r.draw_calls, r.objects, r.primitives, r.nodes, r.static_mem_mb, r.video_mem_mb])

## Level3D pauses itself when the window loses focus (Week 14/15 feature).
## If that happens during a benchmark run it is undone and counted.
func _dismiss_focus_pause() -> void:
	if _level == null or not is_instance_valid(_level) or not get_tree().paused:
		return
	for c in _level.get_children():
		if c.get_script() == load("res://scripts/ui/PauseMenu.gd"):
			c.queue_free()
			get_tree().paused = false
			focus_pauses_dismissed += 1

# ---------------------------------------------------------------- scenario --
func _run() -> void:
	_fresh_profile()
	await _frames(10)
	# ---- Part A: load every map
	for m in MAPS:
		GameManager.reset_run()
		GameManager.chosen_map_id = m
		var t0 := Time.get_ticks_usec()
		_level = (load(LEVEL) as PackedScene).instantiate()
		get_tree().root.add_child(_level)
		get_tree().current_scene = _level
		var t1 := Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var t2 := Time.get_ticks_usec()
		load_lines.append("%-16s build+ready %7.1f ms   first frame drawn %7.1f ms" % [m, (t1 - t0) / 1000.0, (t2 - t0) / 1000.0])
		await _frames(5)
		phase = "map_" + m
		await _wait(3.0)
		phase = ""
		_level.queue_free()
		_level = null
		await _frames(5)
	# ---- Part B: gameplay on Banaue
	GameManager.reset_run()
	GameManager.chosen_map_id = "banaue"
	seed(16)
	_level = (load(LEVEL) as PackedScene).instantiate()
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	Engine.time_scale = 6.0
	while not _level.hud.visible:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_level.player.get_node("Hurtbox").set("enabled", false)
	phase = "combat"
	await _play(COMBAT_SEC, false)
	_go_to_boss()
	phase = "boss"
	await _play(BOSS_SEC, true)
	phase = ""
	_release_inputs()
	_write_results()
	get_tree().quit(0)

func _play(duration: float, boss: bool) -> void:
	var shooting: Node = _level.player.get_node("Shooting")
	var t := 0.0
	var shot_t := 0.0
	var held := false
	var wall_start := Time.get_ticks_msec()
	var next_log := 0.0
	while t < duration:
		if t >= next_log:
			print("[bench] %s t=%.0f s stage=%d paused=%s" % [phase, t, GameManager.current_stage_index, get_tree().paused])
			next_log += 10.0
		if Time.get_ticks_msec() - wall_start > int(duration * 1000) + 60000:
			push_warning("benchmark guard: %s did not finish in time" % phase)
			return
		await get_tree().process_frame
		if not is_instance_valid(_level) or not _level.is_inside_tree():
			push_warning("level left the tree at %s t=%.1f" % [phase, t])
			return
		var dt := get_process_delta_time()
		var p := _puzzle()
		if p != null:
			print("[bench] puzzle at t=%.1f" % t)
			await _solve(p)
			continue
		if get_tree().paused:
			continue
		t += dt
		# walk a fixed circle: alternate directions every 2 s
		var seg := int(t / 2.0) % 4
		_release_inputs()
		Input.action_press(["move_forward", "move_right", "move_back", "move_left"][seg])
		shot_t -= dt
		# Boss stage: walk only, never shoot - the tree must not fall, so
		# every run lasts exactly as long (Kapre smoke attacks still run).
		if GameManager.current_stage_index >= 3:
			if held:
				shooting.call("shoot_button_up")
				held = false
			continue
		if shot_t <= 0.0:
			if held:
				shooting.call("shoot_button_up")
				held = false
				shot_t = SHOT_EVERY
			else:
				shooting.call("shoot_button_down")
				held = true
				shot_t = 0.05

func _release_inputs() -> void:
	for a in ["move_forward", "move_right", "move_back", "move_left"]:
		Input.action_release(a)

func _go_to_boss() -> void:
	if bool(_level.get("_boss_started")):
		return
	_level.set("_spawned_this_stage", GameManager.ENEMIES_PER_STAGE)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.free()
	(_level.get("_active_enemies") as Array).clear()
	GameManager.current_stage_index = 3
	_level.call("_start_stage")

func _puzzle() -> Node:
	for c in _level.get_children():
		if c.has_signal("completed"):
			return c
	return null

func _solve(p: Node) -> void:
	await _wait(1.0)
	if not is_instance_valid(p):
		return
	p.call("_show_puzzle")
	await _frames(2)
	var order: Array = p.get("_order")
	for i in range(order.size()):
		order = p.get("_order")
		if int(order[i]) == i:
			continue
		var j := order.find(i)
		var tiles: Array = p.get("_tiles")
		(tiles[i] as Button).pressed.emit()
		(tiles[j] as Button).pressed.emit()
	await _wait(1.5)
	if not is_instance_valid(p):
		return
	for b in p.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Laban na"):
			(b as Button).pressed.emit()
			break
	await _frames(3)

# ---------------------------------------------------------------- results --
func _write_results() -> void:
	DirAccess.make_dir_recursive_absolute("user://perf")
	var f := FileAccess.open("user://perf/%s_frames.csv" % label, FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	var s: PackedStringArray = []
	s.append("Encanto performance benchmark - label: %s" % label)
	s.append("Build %s | Godot %s | %s | %s" % [ProjectSettings.get_setting("application/config/version"),
		Engine.get_version_info()["string"], OS.get_name(), Time.get_datetime_string_from_system()])
	s.append("GPU: %s (%s) | CPU: %s x%d" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(),
		OS.get_processor_name(), OS.get_processor_count()])
	s.append("Renderer: %s | window %s | vsync off, max_fps 0 | focus pauses dismissed: %d" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), str(get_window().size), focus_pauses_dismissed])
	s.append("")
	s.append("LOAD TIMES (Level3D instantiate + map build, and until the first frame is drawn)")
	s.append_array(load_lines)
	s.append("")
	s.append("%-20s %6s %7s %7s %7s %7s %7s %7s %6s %7s %7s %8s %7s %7s %7s" % ["phase", "frames", "avgFPS", "avg ms", "med ms",
		"p95 ms", "p99 ms", "max ms", ">33ms", "1%lowFPS", "draws", "prims", "rcpums", "rgpums", "memMB"])
	for ph in phase_frames.keys():
		var arr: Array = phase_frames[ph]
		var ft: Array = arr.map(func(r: Dictionary) -> float: return r.frame_ms)
		ft.sort()
		var n := ft.size()
		var total := 0.0
		for v in ft:
			total += v
		var avg := total / n
		var worst := ft.slice(int(n * 0.99), n)
		var worst_avg := 0.0
		for v in worst:
			worst_avg += v
		worst_avg /= maxf(1.0, worst.size())
		var hitches := ft.filter(func(v: float) -> bool: return v > 33.3).size()
		s.append("%-20s %6d %7.1f %7.2f %7.2f %7.2f %7.2f %7.2f %6d %7.1f %7.0f %8.0f %7.2f %7.2f %7.1f" % [ph, n, 1000.0 / avg, avg,
			ft[n / 2], ft[int(n * 0.95)], ft[int(n * 0.99)], ft[n - 1], hitches, 1000.0 / worst_avg,
			_mean(arr, "draw_calls"), _mean(arr, "primitives"), _mean(arr, "render_cpu_ms"), _mean(arr, "render_gpu_ms"),
			_max(arr, "static_mem_mb")])
	var all: Array = []
	for ph in ["combat", "boss"]:
		if phase_frames.has(ph):
			all.append_array(phase_frames[ph])
	if not all.is_empty():
		s.append("")
		s.append("Gameplay (combat+boss): nodes start %d -> end %d, max %d | static mem start %.1f MB -> end %.1f MB, peak %.1f MB | video mem peak %.1f MB | max draw calls %d" % [
			all[0].nodes, all[-1].nodes, _max(all, "nodes"), all[0].static_mem_mb, all[-1].static_mem_mb, _max(all, "static_mem_mb"),
			_max(all, "video_mem_mb"), _max(all, "draw_calls")])
	var txt := "\n".join(s) + "\n"
	print(txt)
	var g := FileAccess.open("user://perf/%s_summary.txt" % label, FileAccess.WRITE)
	g.store_string(txt)
	g.close()

func _mean(arr: Array, key: String) -> float:
	var t := 0.0
	for r in arr:
		t += float(r[key])
	return t / maxf(1.0, arr.size())

func _max(arr: Array, key: String) -> float:
	var m := -INF
	for r in arr:
		m = maxf(m, float(r[key]))
	return m

# ---------------------------------------------------------------- helpers --
func _fresh_profile() -> void:
	var d := DirAccess.open(TEST_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
	SaveSystem.profile_dir = TEST_DIR
	SaveSystem.legacy_save_path = "user://test_no_legacy.json"
	SaveSystem.init_storage()
	SaveSystem.create_profile("Bench")

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
