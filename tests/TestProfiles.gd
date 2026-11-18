extends Node
## Automated PT5 tests for SaveSystem (local profiles + protected saves).
##
## Run headless from the project folder:
##   Godot_v4.x_console.exe --headless --path . res://tests/TestRunner.tscn -- --run-tests
## Every test uses user://test_profiles, never the player's real saves.
## Results are printed and written to user://test_results.txt.

const TEST_DIR := "user://test_profiles"
const TEST_LEGACY := "user://test_legacy_save.json"

var _lines: PackedStringArray = []
var _passed := 0
var _failed := 0
var _current := ""
var _current_ok := true

func _ready() -> void:
	_out("Encanto PT5 profile/save tests")
	_out("Engine: Godot %s | OS: %s | Date: %s" % [Engine.get_version_info()["string"], OS.get_name(), Time.get_datetime_string_from_system()])
	_out("")
	var tests := [
		["T01", "Create a valid profile", t01_create_valid],
		["T02", "Reject invalid nicknames", t02_invalid_names],
		["T03", "Profile limit (4) enforced", t03_profile_limit],
		["T04", "Progress persists after restart", t04_persistence],
		["T05", "Save file is not readable plain text", t05_not_plaintext],
		["T06", "Edited save is rejected, backup restored", t06_tamper_main],
		["T07", "Save and backup both damaged -> safe fresh start", t07_tamper_both],
		["T08", "Another profile's save cannot be loaded", t08_ownership],
		["T09", "Unknown / path-like profile id refused", t09_bad_id],
		["T10", "Out-of-range values are sanitised on load", t10_sanitize],
		["T11", "Reset profile clears progress, keeps name", t11_reset],
		["T12", "Delete profile removes all its files", t12_delete],
		["T13", "Damaged profile list is rebuilt", t13_index_rebuild],
		["T14", "Signed out: nothing is saved, clear message", t14_signed_out],
		["T15", "Spending rules (negative / not enough money)", t15_spend],
		["T16", "Storage write failure is reported, no crash", t16_write_failure],
		["T17", "Old plain-text save migrated and deleted", t17_legacy],
		["T18", "Interrupted save (leftover .tmp) keeps last good data", t18_interrupted],
	]
	for t in tests:
		_fresh()
		_current = "%s %s" % [t[0], t[1]]
		_current_ok = true
		t[2].call()
		if _current_ok:
			_passed += 1
			_out("PASS  " + _current)
		else:
			_failed += 1
			_out("FAIL  " + _current)
	_out("")
	_out("Result: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	_wipe(TEST_DIR)
	var f := FileAccess.open("user://test_results.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	get_tree().quit(0 if _failed == 0 else 1)

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

## Clean folder + fresh SaveSystem state for every test.
func _fresh() -> void:
	_wipe(TEST_DIR)
	if FileAccess.file_exists(TEST_LEGACY):
		DirAccess.remove_absolute(TEST_LEGACY)
	SaveSystem.profile_dir = TEST_DIR
	SaveSystem.legacy_save_path = TEST_LEGACY
	SaveSystem.init_storage()

## Simulates closing and reopening the game.
func _restart() -> void:
	SaveSystem.init_storage()

func _flip_byte(path: String, at: int) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	at = clampi(at, 0, bytes.size() - 1)
	bytes[at] = bytes[at] ^ 0xFF
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _copy(src: String, dst: String) -> void:
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(src))
	f.close()

# ------------------------------------------------------------------ tests ----

func t01_create_valid() -> void:
	var r := SaveSystem.create_profile("  Juan  Dela  ")
	check(r["ok"], "create_profile ok")
	check(SaveSystem.active_profile_name() == "Juan Dela", "name trimmed to 'Juan Dela'")
	check(FileAccess.file_exists(SaveSystem._save_path(r["id"])), "save file created")
	check(SaveSystem.money == 0 and SaveSystem.equipped["top"] == "basic_polo", "starts with default data")
	note("created id=%s name='%s'" % [r["id"], SaveSystem.active_profile_name()])

func t02_invalid_names() -> void:
	SaveSystem.create_profile("Maria")
	var cases := ["", " ", "A", "ThisNameIsWayTooLong", "<script>", "../../x", "1234", "maria", "Juan;DROP"]
	for c in cases:
		var r := SaveSystem.create_profile(c)
		check(not r["ok"], "'%s' rejected" % c)
		note("'%s' -> %s" % [c, r["error"]])
	check(SaveSystem.profiles.size() == 1, "still only 1 profile")

func t03_profile_limit() -> void:
	for n in ["Ana", "Ben", "Cara", "Dado"]:
		check(SaveSystem.create_profile(n)["ok"], "%s created" % n)
	var r := SaveSystem.create_profile("Ely")
	check(not r["ok"], "5th profile rejected")
	note("5th -> " + r["error"])

func t04_persistence() -> void:
	SaveSystem.create_profile("Lito")
	SaveSystem.add_money(150)
	SaveSystem.unlock_clothing("barong")
	SaveSystem.equip("top", "barong")
	_restart()
	check(SaveSystem.active_profile_name() == "Lito", "last profile re-selected")
	check(SaveSystem.money == 150, "money 150 (got %d)" % SaveSystem.money)
	check(SaveSystem.is_unlocked("barong") and SaveSystem.equipped["top"] == "barong", "barong unlocked + equipped")

func t05_not_plaintext() -> void:
	var r := SaveSystem.create_profile("Nena")
	SaveSystem.add_money(777)
	var raw := FileAccess.get_file_as_bytes(SaveSystem._save_path(r["id"])).get_string_from_ascii()
	check(not raw.contains("money") and not raw.contains("777") and not raw.contains("Nena"), "no readable field names/values in file")
	note("first bytes: " + FileAccess.get_file_as_bytes(SaveSystem._save_path(r["id"])).slice(0, 12).hex_encode())

func t06_tamper_main() -> void:
	var r := SaveSystem.create_profile("Tess")
	SaveSystem.add_money(100)   # this save becomes the .bak
	SaveSystem.add_money(50)    # main = 150, bak = 100
	_flip_byte(SaveSystem._save_path(r["id"]), 60)
	_restart()
	check(SaveSystem.money == 100, "backup value 100 restored (got %d)" % SaveSystem.money)
	check(FileAccess.file_exists(SaveSystem._corrupt_path(r["id"])), "edited file kept as .corrupt")
	note("notice: " + SaveSystem.take_notice())

func t07_tamper_both() -> void:
	var r := SaveSystem.create_profile("Udo")
	SaveSystem.add_money(100)
	SaveSystem.add_money(50)
	_flip_byte(SaveSystem._save_path(r["id"]), 60)
	_flip_byte(SaveSystem._bak_path(r["id"]), 60)
	_restart()
	check(SaveSystem.money == 0, "fresh default data (got %d)" % SaveSystem.money)
	check(SaveSystem.active_profile_name() == "Udo", "profile itself kept")
	note("notice: " + SaveSystem.take_notice())

func t08_ownership() -> void:
	var a := SaveSystem.create_profile("Rich")
	SaveSystem.add_money(5000)
	var b := SaveSystem.create_profile("Poor")
	SaveSystem.add_money(10)
	_copy(SaveSystem._save_path(a["id"]), SaveSystem._save_path(b["id"]))
	SaveSystem._remove_if_exists(SaveSystem._bak_path(b["id"]))
	check(SaveSystem.select_profile(b["id"]), "select Poor")
	check(SaveSystem.money != 5000, "Poor did NOT receive Rich's 5000 (got %d)" % SaveSystem.money)
	check(SaveSystem.select_profile(a["id"]) and SaveSystem.money == 5000, "Rich's own save still loads 5000")

func t09_bad_id() -> void:
	SaveSystem.create_profile("Vic")
	for bad in ["../../encanto_save", "0123456789abcdef", "", "C:/Windows/x"]:
		check(not SaveSystem.select_profile(bad), "'%s' refused" % bad)
	check(SaveSystem.active_profile_name() == "Vic", "active profile unchanged")
	note("error: " + SaveSystem.last_error)

func t10_sanitize() -> void:
	var r := SaveSystem.create_profile("Wena")
	var id: String = r["id"]
	var evil := {"version": 2, "profile_id": id, "profile_name": "Wena", "money": 99999999,
		"unlocked_clothing": ["basic_polo", "hacker_suit", 42], "equipped": {"top": "hacker_suit", "bottom": "basic_pants", "accessory": "none"},
		"game_completed": true, "completed_enemies": ["kapre"], "bayong_rewards_obtained": []}
	var f := FileAccess.open_encrypted_with_pass(SaveSystem._save_path(id), FileAccess.WRITE, SaveSystem._key_for(id))
	f.store_string(JSON.stringify(evil))
	f.close()
	SaveSystem.select_profile(id)
	check(SaveSystem.money == SaveSystem.MAX_MONEY, "money clamped to %d (got %d)" % [SaveSystem.MAX_MONEY, SaveSystem.money])
	check(not SaveSystem.is_unlocked("hacker_suit") and not SaveSystem.is_unlocked("42"), "unknown items dropped")
	check(SaveSystem.equipped["top"] == "basic_polo", "equipped falls back to basic_polo")
	evil["money"] = -500
	f = FileAccess.open_encrypted_with_pass(SaveSystem._save_path(id), FileAccess.WRITE, SaveSystem._key_for(id))
	f.store_string(JSON.stringify(evil))
	f.close()
	SaveSystem.select_profile(id)
	check(SaveSystem.money == 0, "negative money clamped to 0 (got %d)" % SaveSystem.money)

func t11_reset() -> void:
	SaveSystem.create_profile("Xia")
	SaveSystem.add_money(300)
	SaveSystem.unlock_clothing("barong")
	SaveSystem.mark_game_completed()
	check(SaveSystem.reset_profile(), "reset ok")
	_restart()
	check(SaveSystem.active_profile_name() == "Xia", "name kept")
	check(SaveSystem.money == 0 and not SaveSystem.is_unlocked("barong") and not SaveSystem.game_completed, "progress cleared")

func t12_delete() -> void:
	var a := SaveSystem.create_profile("Yna")
	SaveSystem.add_money(1)
	SaveSystem.create_profile("Zed")
	check(SaveSystem.delete_profile(a["id"]), "delete ok")
	check(SaveSystem.profiles.size() == 1, "1 profile left")
	for p in [SaveSystem._save_path(a["id"]), SaveSystem._bak_path(a["id"])]:
		check(not FileAccess.file_exists(p), "%s removed" % p.get_file())
	_restart()
	check(SaveSystem.profiles.size() == 1 and SaveSystem.profiles[0]["name"] == "Zed", "deletion persisted")

func t13_index_rebuild() -> void:
	SaveSystem.create_profile("Abby")
	SaveSystem.create_profile("Bong")
	var f := FileAccess.open(SaveSystem._index_path(), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	_restart()
	var names := []
	for p in SaveSystem.profiles:
		names.append(p["name"])
	names.sort()
	check(names == ["Abby", "Bong"], "both profiles recovered with names (got %s)" % str(names))
	note("notice: " + SaveSystem.take_notice())

func t14_signed_out() -> void:
	SaveSystem.create_profile("Cely")
	SaveSystem.add_money(20)
	SaveSystem.sign_out()
	check(not SaveSystem.has_active_profile(), "no active profile")
	check(not SaveSystem.save_game(), "save_game returns false")
	note("message: " + SaveSystem.last_error)
	_restart()
	check(not SaveSystem.has_active_profile(), "stays signed out after restart")

func t15_spend() -> void:
	SaveSystem.create_profile("Dino")
	SaveSystem.add_money(50)
	check(not SaveSystem.spend_money(-100), "negative spend refused")
	check(not SaveSystem.spend_money(51), "overspend refused")
	check(SaveSystem.spend_money(50) and SaveSystem.money == 0, "exact spend ok")

func t16_write_failure() -> void:
	# Point the profile folder at a path whose parent is a FILE - writes must fail.
	var blocker := "user://test_blocker"
	var f := FileAccess.open(blocker, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	SaveSystem.profile_dir = blocker.path_join("profiles")
	SaveSystem.init_storage()
	var got_signal := [false]
	var cb := func(_m: String) -> void: got_signal[0] = true
	SaveSystem.save_failed.connect(cb)
	var r := SaveSystem.create_profile("Edna")
	SaveSystem.save_failed.disconnect(cb)
	check(not r["ok"], "create_profile reports failure")
	check(got_signal[0], "save_failed signal emitted (UI can show it)")
	check(not SaveSystem.has_active_profile(), "no half-created profile left active")
	note("error: " + str(r["error"]))
	DirAccess.remove_absolute(blocker)

func t17_legacy() -> void:
	var f := FileAccess.open(TEST_LEGACY, FileAccess.WRITE)
	f.store_string(JSON.stringify({"money": 420, "unlocked_clothing": ["basic_polo", "basic_pants", "none", "barong"], "equipped": {"top": "barong", "bottom": "basic_pants", "accessory": "none"}}))
	f.close()
	_restart()
	check(SaveSystem.active_profile_name() == "Player 1", "migrated into 'Player 1'")
	check(SaveSystem.money == 420 and SaveSystem.equipped["top"] == "barong", "old progress kept")
	check(not FileAccess.file_exists(TEST_LEGACY), "plain-text file deleted")

func t18_interrupted() -> void:
	var r := SaveSystem.create_profile("Fely")
	SaveSystem.add_money(80)
	# Simulate a crash in the middle of writing: half-written temp file left behind.
	var f := FileAccess.open(SaveSystem._tmp_path(r["id"]), FileAccess.WRITE)
	f.store_string("partial")
	f.close()
	_restart()
	check(SaveSystem.money == 80, "last complete save (80) used (got %d)" % SaveSystem.money)
	SaveSystem.add_money(1)
	check(SaveSystem.money == 81, "next save succeeds over leftover .tmp")
