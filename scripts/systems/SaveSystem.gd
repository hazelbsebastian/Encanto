extends Node
## SaveSystem (autoload)
## Persists money, unlocked/equipped clothing and overall progress to
## user://encanto_save.json so it survives closing and reopening the game.

const SAVE_PATH := "user://encanto_save.json"

var money: int = 0
var unlocked_clothing: Array = ["basic_polo", "basic_pants", "none"]
var equipped: Dictionary = {"top": "basic_polo", "bottom": "basic_pants", "accessory": "none"}
var game_completed: bool = false
var completed_enemies: Array = []
var bayong_rewards_obtained: Array = []

func _ready() -> void:
	load_game()

func default_data() -> Dictionary:
	return {
		"money": 0,
		"unlocked_clothing": ["basic_polo", "basic_pants", "none"],
		"equipped": {"top": "basic_polo", "bottom": "basic_pants", "accessory": "none"},
		"game_completed": false,
		"completed_enemies": [],
		"bayong_rewards_obtained": [],
	}

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply(default_data())
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_apply(default_data())
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_apply(default_data())
		return
	var data: Dictionary = default_data()
	for key in data.keys():
		if parsed.has(key):
			data[key] = parsed[key]
	_apply(data)

func _apply(data: Dictionary) -> void:
	money = int(data.get("money", 0))
	unlocked_clothing = data.get("unlocked_clothing", ["basic_polo", "basic_pants", "none"])
	equipped = data.get("equipped", {"top": "basic_polo", "bottom": "basic_pants", "accessory": "none"})
	game_completed = bool(data.get("game_completed", false))
	completed_enemies = data.get("completed_enemies", [])
	bayong_rewards_obtained = data.get("bayong_rewards_obtained", [])

func save_game() -> void:
	var data := {
		"money": money,
		"unlocked_clothing": unlocked_clothing,
		"equipped": equipped,
		"game_completed": game_completed,
		"completed_enemies": completed_enemies,
		"bayong_rewards_obtained": bayong_rewards_obtained,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()

func add_money(amount: int) -> void:
	money += amount
	save_game()

func spend_money(amount: int) -> bool:
	if money < amount:
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
