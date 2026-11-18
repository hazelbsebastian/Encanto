extends Node
## Week 14 accessibility audit helper. Loads real screens, records the size of
## every visible button/label (in screen pixels at 960x540 and as an estimate
## in dp on a typical 6.5" 1080x2400 phone held landscape) and saves screenshots.
## Run (not headless):
##   Godot.exe --path . res://tests/AccessibilityAudit.tscn -- --run-tests --out=<folder> [--tag=before]

const DIR := "user://audit_profiles"
var out_dir := "user://audit"
var tag := "before"
var _report: PackedStringArray = []

## 960x540 canvas is scaled to the phone's 2400x1080 screen => factor 2.0 (height bound),
## and that phone is ~400 dpi => 1 dp = 2.5 px. So 1 canvas px ~= 0.8 dp.
const CANVAS_PX_TO_DP := 2.0 / 2.5

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		if a.begins_with("--tag="):
			tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_wipe()
	SaveSystem.profile_dir = DIR
	SaveSystem.legacy_save_path = "user://no_legacy.json"
	SaveSystem.init_storage()
	SaveSystem.create_profile("Tester")

	await _audit("res://scenes/main/Title.tscn", "title")
	if tag != "before":
		for n in ["Ana", "Ben", "Cara"]:
			SaveSystem.create_profile(n)
		await _audit("res://scenes/ui/ProfileSelect.tscn", "profiles_full")
	GameManager.reset_run()
	GameManager.chosen_map_id = "banaue"
	GameManager.chosen_map_name = "Banaue Rice Terraces"
	var lvl := await _audit("res://scenes/3d/Level3D.tscn", "gameplay_hud", 30)
	# wait for the jeepney arrival cinematic to finish and the HUD to appear
	var waited := 0
	while lvl and not lvl.hud.visible and waited < 2400:
		await get_tree().process_frame
		waited += 1
	if lvl:
		await _audit_existing(lvl, "gameplay_hud")
		# simulate the app losing focus (phone call / home button / alt-tab)
		lvl.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await get_tree().process_frame
		_report.append("CHECK   app focus-out pauses the game: %s" % ("PASS" if get_tree().paused else "FAIL"))
		if not get_tree().paused:
			lvl.open_pause_menu()
		await _audit_existing(lvl, "pause_menu")
	if lvl:
		get_tree().paused = false
		lvl.queue_free()
		await get_tree().process_frame
	await _audit("res://scenes/ui/Wardrobe.tscn", "wardrobe")
	await _audit("res://scenes/ui/RewardScreen.tscn", "reward")

	var f := FileAccess.open(out_dir.path_join("audit_%s.txt" % tag), FileAccess.WRITE)
	f.store_string("\n".join(_report) + "\n")
	f.close()
	_wipe()
	get_tree().quit()

func _audit(path: String, name: String, frames: int = 50) -> Node:
	var n: Node = load(path).instantiate()
	add_child(n)
	for i in frames:
		await get_tree().process_frame
	await _audit_existing(n, name)
	if name != "gameplay_hud":
		n.queue_free()
		await get_tree().process_frame
		return null
	return n

func _audit_existing(root: Node, name: String) -> void:
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [tag, name]))
	_report.append("== %s ==" % name)
	_walk(root)
	_report.append("")

func _walk(n: Node) -> void:
	if n is Control and (n as Control).is_visible_in_tree():
		var c := n as Control
		var r := c.get_global_rect()
		if c is BaseButton:
			var txt: String = (c as Button).text if c is Button else ""
			_report.append("BUTTON  %-28s %4dx%-4d px  ~%3dx%-3d dp  '%s'" % [c.name, r.size.x, r.size.y, r.size.x * CANVAS_PX_TO_DP, r.size.y * CANVAS_PX_TO_DP, txt.replace("\n", " ").left(30)])
		elif c is Label and (c as Label).text.strip_edges() != "":
			var fs := c.get_theme_font_size("font_size")
			_report.append("LABEL   %-28s font %2d px (~%2d dp)  '%s'" % [c.name, fs, fs * CANVAS_PX_TO_DP, (c as Label).text.replace("\n", " ").left(40)])
	for ch in n.get_children():
		_walk(ch)

func _wipe() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
