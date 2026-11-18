extends Node
## Renders the profile screens with a throw-away profile folder and saves
## PNG screenshots for the Week 13 evidence file.
## Run (not headless - it needs a renderer):
##   Godot.exe --path . res://tests/CaptureEvidence.tscn -- --run-tests --out=<folder>

const DIR := "user://capture_profiles"
var out_dir := "user://evidence"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_wipe()
	SaveSystem.profile_dir = DIR
	SaveSystem.legacy_save_path = "user://no_legacy.json"
	SaveSystem.init_storage()

	# 1. First launch: no profiles yet.
	var ps := await _show_scene("res://scenes/ui/ProfileSelect.tscn")
	await _shot("E1_first_launch_profile_screen")

	# 2. Invalid nickname is rejected with a message.
	ps._name_edit.text = "<script>"
	ps._on_create()
	await _shot("E2_invalid_name_rejected")
	ps._name_edit.text = "A"
	ps._on_create()
	await _shot("E3_too_short_name_rejected")
	ps.queue_free()

	# 3. Two profiles, one active, with progress.
	SaveSystem.create_profile("Hazel")
	SaveSystem.add_money(1250)
	SaveSystem.create_profile("Kuya Ben")
	SaveSystem.select_profile(SaveSystem.profiles[0]["id"])
	ps = await _show_scene("res://scenes/ui/ProfileSelect.tscn")
	await _shot("E4_profile_list_active_profile")
	ps.queue_free()

	# 4. Title screen shows the active player and their own money.
	var t := await _show_scene("res://scenes/main/Title.tscn")
	await _shot("E5_title_shows_active_player")
	t.queue_free()

	# 5. Damaged save -> backup restored, player is told.
	var id: String = SaveSystem.active_id
	SaveSystem.add_money(50)
	var bytes := FileAccess.get_file_as_bytes(SaveSystem._save_path(id))
	bytes[60] = bytes[60] ^ 0xFF
	var f := FileAccess.open(SaveSystem._save_path(id), FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	SaveSystem.init_storage()
	t = await _show_scene("res://scenes/main/Title.tscn")
	await _shot("E6_damaged_save_backup_restored")
	t.queue_free()

	_wipe()
	print("Evidence saved to ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()

func _show_scene(path: String) -> Node:
	var n: Node = load(path).instantiate()
	add_child(n)
	return n

func _shot(file_name: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file_name + ".png"))
	print("saved ", file_name)

func _wipe() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
