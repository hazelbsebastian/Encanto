extends Node
## Week 17 (PT7) evidence screenshots of the release-candidate screens:
## settings panel, How to Play, Credits (top and license part), and the
## wardrobe with the Traditional Kerchief equipped. Uses a throw-away profile.
## Run (needs a renderer, not headless):
##   Godot.exe --path . res://tests/CaptureRelease.tscn -- --out=<folder>

const DIR := "user://capture_release"
var out_dir := "user://evidence_release"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_wipe()
	SaveSystem.profile_dir = DIR
	SaveSystem.legacy_save_path = "user://no_legacy.json"
	SaveSystem.init_storage()
	SaveSystem.create_profile("Hazel")
	_run.call_deferred()

func _run() -> void:
	var t := _show("res://scenes/main/Title.tscn")
	await _shot("R1_title")
	(t.get_node("VBox/MenuGrid/SettingsButton") as Button).pressed.emit()
	await _shot("R2_settings_panel")
	(t.get_node("SettingsPanel/VBox/InfoRow/HowToButton") as Button).pressed.emit()
	await _shot("R3_how_to_play")
	var hs := (t.get("_info") as Node).find_child("Scroll", true, false) as ScrollContainer
	hs.scroll_vertical = 300
	await _shot("R3b_how_to_play_filipino_games")
	t.call("_close_info")
	(t.get_node("SettingsPanel/VBox/InfoRow/CreditsButton") as Button).pressed.emit()
	await _shot("R4_credits_top")
	var scroll := (t.get("_info") as Node).find_child("Scroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 1100
	await _shot("R5_credits_license")
	t.queue_free()
	SaveSystem.unlock_clothing("kerchief")
	SaveSystem.equip("accessory", "kerchief")
	_show("res://scenes/ui/Wardrobe.tscn")
	await _shot("R6_wardrobe_kerchief_icon")
	_wipe()
	print("Evidence saved to ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()

func _show(path: String) -> Node:
	var n: Node = load(path).instantiate()
	add_child(n)
	return n

func _shot(file_name: String) -> void:
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))
	print("saved ", file_name)

func _wipe() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
