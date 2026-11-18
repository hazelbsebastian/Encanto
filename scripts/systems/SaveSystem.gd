extends Node
## SaveSystem (autoload) - local player profiles + protected save files.
##
## Week 13 (PT5): the game is offline and single-device, so the identity model
## is a LOCAL PROFILE (no online account). Each profile has:
##   * a random id (16 hex chars) - never derived from the player's name,
##   * a nickname chosen by the player (validated, 2-12 characters),
##   * its own save file  user://profiles/<id>.sav  encrypted with a key that is
##     derived from this device + that profile id (nothing secret is stored in
##     the source code).
##
## Protection in place:
##   * Integrity: Godot's encrypted file stores a checksum of the content, so an
##     edited or damaged file fails to open instead of loading bad values.
##   * Ownership: the save also records which profile it belongs to; a file
##     copied over another profile's file is rejected.
##   * Recovery: every save keeps the previous good copy as <id>.bak and writes
##     through a temporary file, so a crash mid-save never loses progress.
##     A damaged save is moved aside as <id>.corrupt and the backup is used.
##   * Sanitising: loaded values are clamped/checked (money range, real
##     clothing ids) before the game uses them.
##
## The public API used by the rest of the game (money, equipped, add_money,
## unlock_clothing, ...) is unchanged from the original single-file save.

signal profile_changed(profile_name: String)
signal save_failed(message: String)

## Old single-file save from before Week 13 (tests point this elsewhere).
var legacy_save_path: String = "user://encanto_save.json"
const SAVE_VERSION := 2
const MAX_PROFILES := 4
const NAME_MIN := 2
const NAME_MAX := 12
const MAX_MONEY := 999999
## Public, non-secret label mixed into the key derivation (domain separation).
const KEY_CONTEXT := "encanto-profile-save-v1"

const DEFAULT_UNLOCKED := ["basic_polo", "basic_pants", "none"]
const DEFAULT_EQUIPPED := {"top": "basic_polo", "bottom": "basic_pants", "accessory": "none"}

## Folder that holds index.json, device.key and the per-profile saves.
## Tests point this at a separate folder so they never touch real saves.
var profile_dir: String = "user://profiles"

# ---- run-time profile state -------------------------------------------------
var profiles: Array = []          # [{ "id": String, "name": String, "created": int }]
var active_id: String = ""
var last_error: String = ""       # last message suitable for showing the player
var last_notice: String = ""      # e.g. "Backup restored" - shown once by the UI

# ---- the active profile's game data (same fields as before Week 13) -----------
var money: int = 0
var unlocked_clothing: Array = DEFAULT_UNLOCKED.duplicate()
var equipped: Dictionary = DEFAULT_EQUIPPED.duplicate()
var game_completed: bool = false
var completed_enemies: Array = []
var bayong_rewards_obtained: Array = []

var _device_secret: String = ""

func _ready() -> void:
	# The automated tests (tests/TestRunner.tscn) use their own folder and must
	# never read or change a player's real saves.
	if OS.get_cmdline_user_args().has("--run-tests"):
		return
	init_storage()

## (Re)initialise from disk. Safe to call again after changing profile_dir.
func init_storage() -> void:
	profiles = []
	active_id = ""
	last_error = ""
	last_notice = ""
	_apply(default_data())
	DirAccess.make_dir_recursive_absolute(profile_dir)
	_device_secret = _load_or_create_device_secret()
	var last_active := _load_index()
	_migrate_legacy_save()
	if last_active != "" and _find(last_active) >= 0:
		select_profile(last_active)

# =============================================================================
# Profiles
# =============================================================================

func has_profiles() -> bool:
	return not profiles.is_empty()

func has_active_profile() -> bool:
	return active_id != ""

func active_profile_name() -> String:
	var i := _find(active_id)
	return str(profiles[i]["name"]) if i >= 0 else ""

## Returns "" when the nickname is acceptable, otherwise a message for the player.
func validate_name(raw: String) -> String:
	var nick := _clean_name(raw)
	if nick.length() < NAME_MIN:
		return "Name is too short (at least %d characters)." % NAME_MIN
	if nick.length() > NAME_MAX:
		return "Name is too long (at most %d characters)." % NAME_MAX
	var allowed := RegEx.create_from_string("^[A-Za-z0-9Ññ _-]+$")
	if allowed.search(nick) == null:
		return "Use letters, numbers, spaces, - or _ only."
	if RegEx.create_from_string("[A-Za-zÑñ]").search(nick) == null:
		return "Name must contain at least one letter."
	for p in profiles:
		if str(p["name"]).to_lower() == nick.to_lower():
			return "That name is already used on this device."
	return ""

## Creates a profile, makes it active, and saves its default data.
## Returns { "ok": bool, "error": String, "id": String }.
func create_profile(raw_name: String) -> Dictionary:
	if profiles.size() >= MAX_PROFILES:
		return {"ok": false, "error": "Only %d profiles fit on this device. Delete one first." % MAX_PROFILES, "id": ""}
	var problem := validate_name(raw_name)
	if problem != "":
		return {"ok": false, "error": problem, "id": ""}
	var id := _new_id()
	profiles.append({"id": id, "name": _clean_name(raw_name), "created": int(Time.get_unix_time_from_system())})
	active_id = id
	_apply(default_data())
	if not save_game():
		profiles.remove_at(_find(id))
		active_id = ""
		return {"ok": false, "error": last_error, "id": ""}
	_save_index()
	profile_changed.emit(active_profile_name())
	return {"ok": true, "error": "", "id": id}

## Loads a profile's own save. Only ids that exist in this device's index are
## accepted, so a crafted id can never point at another file.
func select_profile(id: String) -> bool:
	if not _valid_id(id) or _find(id) < 0:
		last_error = "That profile does not exist."
		return false
	active_id = id
	_load_active()
	_save_index()
	profile_changed.emit(active_profile_name())
	return true

## Saves and leaves the current profile (back to the profile picker).
func sign_out() -> void:
	if active_id != "":
		save_game()
	active_id = ""
	_apply(default_data())
	_save_index()
	profile_changed.emit("")

## Wipes the active profile's progress (money, outfits, completion) but keeps
## the profile and its name.
func reset_profile() -> bool:
	if active_id == "":
		return false
	_apply(default_data())
	var ok := save_game()
	_remove_if_exists(_bak_path(active_id))
	return ok

## Deletes a profile and every file that belongs to it.
func delete_profile(id: String) -> bool:
	var i := _find(id)
	if not _valid_id(id) or i < 0:
		last_error = "That profile does not exist."
		return false
	for path in [_save_path(id), _bak_path(id), _tmp_path(id), _corrupt_path(id)]:
		_remove_if_exists(path)
	profiles.remove_at(i)
	if active_id == id:
		active_id = ""
		_apply(default_data())
		profile_changed.emit("")
	_save_index()
	return true

func take_notice() -> String:
	var n := last_notice
	last_notice = ""
	return n

# =============================================================================
# Game data (unchanged public API)
# =============================================================================

func default_data() -> Dictionary:
	return {
		"money": 0,
		"unlocked_clothing": DEFAULT_UNLOCKED.duplicate(),
		"equipped": DEFAULT_EQUIPPED.duplicate(),
		"game_completed": false,
		"completed_enemies": [],
		"bayong_rewards_obtained": [],
	}

## Kept for compatibility: reloads the active profile from disk.
func load_game() -> void:
	if active_id != "":
		_load_active()

## Writes the active profile safely: tmp file -> keep old copy as .bak -> rename.
func save_game() -> bool:
	if active_id == "":
		last_error = "No profile selected - progress is not being saved."
		return false
	var data := {
		"version": SAVE_VERSION,
		"profile_id": active_id,
		"profile_name": active_profile_name(),
		"money": money,
		"unlocked_clothing": unlocked_clothing,
		"equipped": equipped,
		"game_completed": game_completed,
		"completed_enemies": completed_enemies,
		"bayong_rewards_obtained": bayong_rewards_obtained,
	}
	var tmp := _tmp_path(active_id)
	var f := FileAccess.open_encrypted_with_pass(tmp, FileAccess.WRITE, _key_for(active_id))
	if f == null:
		return _fail("Could not save (error %d). Check free storage space." % FileAccess.get_open_error())
	f.store_string(JSON.stringify(data))
	f.close()
	var main := _save_path(active_id)
	if FileAccess.file_exists(main):
		_remove_if_exists(_bak_path(active_id))
		DirAccess.rename_absolute(main, _bak_path(active_id))
	var err := DirAccess.rename_absolute(tmp, main)
	if err != OK:
		return _fail("Could not finish saving (error %d)." % err)
	return true

func add_money(amount: int) -> void:
	money = clampi(money + amount, 0, MAX_MONEY)
	save_game()

func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	save_game()
	return true

func is_unlocked(item_id: String) -> bool:
	return unlocked_clothing.has(item_id)

func unlock_clothing(item_id: String) -> void:
	if not unlocked_clothing.has(item_id):
		unlocked_clothing.append(item_id)
	save_game()

func equip(category: String, item_id: String) -> void:
	equipped[category] = item_id
	save_game()

func mark_enemy_completed(enemy_id: String) -> void:
	if not completed_enemies.has(enemy_id):
		completed_enemies.append(enemy_id)
	save_game()

func mark_game_completed() -> void:
	game_completed = true
	save_game()

func add_bayong_reward_record(reward_id: String) -> void:
	bayong_rewards_obtained.append(reward_id)
	save_game()

# =============================================================================
# Internals
# =============================================================================

func _save_path(id: String) -> String: return profile_dir.path_join(id + ".sav")
func _bak_path(id: String) -> String: return profile_dir.path_join(id + ".bak")
func _tmp_path(id: String) -> String: return profile_dir.path_join(id + ".tmp")
func _corrupt_path(id: String) -> String: return profile_dir.path_join(id + ".corrupt")
func _index_path() -> String: return profile_dir.path_join("index.json")
func _device_key_path() -> String: return profile_dir.path_join("device.key")

func _fail(msg: String) -> bool:
	last_error = msg
	push_warning("SaveSystem: " + msg)
	save_failed.emit(msg)
	return false

func _find(id: String) -> int:
	for i in profiles.size():
		if str(profiles[i]["id"]) == id:
			return i
	return -1

func _valid_id(id: String) -> bool:
	return RegEx.create_from_string("^[0-9a-f]{16}$").search(id) != null

func _new_id() -> String:
	var id := ""
	while id == "" or _find(id) >= 0:
		id = Crypto.new().generate_random_bytes(8).hex_encode()
	return id

func _clean_name(raw: String) -> String:
	var s := raw.strip_edges()
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s

## Per-device random value, created on first launch. Together with the OS
## device id it makes the save key unique to this install, so no key is ever
## written in the source code or committed to the repository.
func _load_or_create_device_secret() -> String:
	var path := _device_key_path()
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var s := f.get_as_text().strip_edges()
			f.close()
			if RegEx.create_from_string("^[0-9a-f]{64}$").search(s) != null:
				return s
	var secret := Crypto.new().generate_random_bytes(32).hex_encode()
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w:
		w.store_string(secret)
		w.close()
	return secret

func _key_for(id: String) -> String:
	return ("%s|%s|%s|%s" % [KEY_CONTEXT, OS.get_unique_id(), _device_secret, id]).sha256_text()

## Reads one encrypted save. Returns {} if missing, damaged, edited, or owned
## by a different profile.
func _read_save(path: String, id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, _key_for(id))
	if f == null:
		return {}   # wrong key, edited bytes or checksum mismatch
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if str(parsed.get("profile_id", "")) != id:
		return {}   # file belongs to someone else
	return parsed

func _load_active() -> void:
	var id := active_id
	var main := _save_path(id)
	var data := _read_save(main, id)
	if data.is_empty() and FileAccess.file_exists(main):
		# Damaged or tampered: keep it aside for inspection, then try the backup.
		_remove_if_exists(_corrupt_path(id))
		DirAccess.rename_absolute(main, _corrupt_path(id))
		data = _read_save(_bak_path(id), id)
		if data.is_empty():
			last_notice = "Your save could not be read, so this profile started fresh."
		else:
			last_notice = "Your save was damaged - the last backup was restored."
	elif data.is_empty():
		data = _read_save(_bak_path(id), id)
		if not data.is_empty():
			last_notice = "The last backup was restored."
	_apply(_sanitize(data))
	if not FileAccess.file_exists(main):
		save_game()

## Never trust what comes off the disk: clamp numbers and drop unknown ids.
func _sanitize(raw: Dictionary) -> Dictionary:
	var d := default_data()
	d["money"] = clampi(int(raw.get("money", 0)), 0, MAX_MONEY)
	var unlocked: Array = DEFAULT_UNLOCKED.duplicate()
	var src = raw.get("unlocked_clothing", [])
	if typeof(src) == TYPE_ARRAY:
		for item in src:
			var sid := str(item)
			if not unlocked.has(sid) and not ClothingData.get_item(sid).is_empty():
				unlocked.append(sid)
	d["unlocked_clothing"] = unlocked
	var eq: Dictionary = DEFAULT_EQUIPPED.duplicate()
	var src_eq = raw.get("equipped", {})
	if typeof(src_eq) == TYPE_DICTIONARY:
		for cat in DEFAULT_EQUIPPED.keys():
			var item_id := str(src_eq.get(cat, eq[cat]))
			if unlocked.has(item_id):
				eq[cat] = item_id
	d["equipped"] = eq
	d["game_completed"] = bool(raw.get("game_completed", false))
	for key in ["completed_enemies", "bayong_rewards_obtained"]:
		var arr = raw.get(key, [])
		var clean: Array = []
		if typeof(arr) == TYPE_ARRAY:
			for v in arr:
				clean.append(str(v).left(32))
		d[key] = clean
	return d

func _apply(data: Dictionary) -> void:
	money = int(data.get("money", 0))
	unlocked_clothing = data.get("unlocked_clothing", DEFAULT_UNLOCKED.duplicate())
	equipped = data.get("equipped", DEFAULT_EQUIPPED.duplicate())
	game_completed = bool(data.get("game_completed", false))
	completed_enemies = data.get("completed_enemies", [])
	bayong_rewards_obtained = data.get("bayong_rewards_obtained", [])

## index.json only lists ids, nicknames and creation time - no game data.
func _save_index() -> void:
	var f := FileAccess.open(_index_path(), FileAccess.WRITE)
	if f == null:
		_fail("Could not update the profile list.")
		return
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "last_active": active_id, "profiles": profiles}, "  "))
	f.close()

## Returns the last active id. Rebuilds the list from the save files if the
## index is missing or damaged (each save stores its own nickname).
func _load_index() -> String:
	var parsed = null
	if FileAccess.file_exists(_index_path()):
		var f := FileAccess.open(_index_path(), FileAccess.READ)
		if f:
			parsed = JSON.parse_string(f.get_as_text())
			f.close()
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("profiles")) == TYPE_ARRAY:
		for p in parsed["profiles"]:
			if typeof(p) == TYPE_DICTIONARY and _valid_id(str(p.get("id", ""))) and _find(str(p["id"])) < 0:
				profiles.append({"id": str(p["id"]), "name": _clean_name(str(p.get("name", "Player"))).left(NAME_MAX), "created": int(p.get("created", 0))})
		return str(parsed.get("last_active", ""))
	_rebuild_index()
	return ""

func _rebuild_index() -> void:
	var dir := DirAccess.open(profile_dir)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".sav"):
			continue
		var id := file.get_basename()
		if not _valid_id(id) or profiles.size() >= MAX_PROFILES:
			continue
		var data := _read_save(_save_path(id), id)
		if data.is_empty():
			continue
		var nick := _clean_name(str(data.get("profile_name", ""))).left(NAME_MAX)
		if nick.length() < NAME_MIN:
			nick = "Player %d" % (profiles.size() + 1)
		profiles.append({"id": id, "name": nick, "created": 0})
	if not profiles.is_empty():
		last_notice = "The profile list was rebuilt from your save files."
		_save_index()

## Pre-Week-13 builds kept one unprotected JSON file. Move its progress into a
## new protected profile once, then delete the plain-text file.
func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(legacy_save_path):
		return
	var f := FileAccess.open(legacy_save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	if f:
		f.close()
	var nick := "Player 1"
	var n := 1
	while validate_name(nick) != "" and n < 9:
		n += 1
		nick = "Player %d" % n
	var result := create_profile(nick)
	if result["ok"]:
		if typeof(parsed) == TYPE_DICTIONARY:
			_apply(_sanitize(parsed))
			save_game()
		DirAccess.remove_absolute(legacy_save_path)
		last_notice = "Your old progress was moved into the profile \"%s\"." % nick

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
