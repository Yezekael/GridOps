extends Node

const SAVE_PATH := "user://gridops_save.json"

var data: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	data = _default_data()
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text := file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			for key in parsed.keys():
				data[key] = parsed[key]

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _default_data() -> Dictionary:
	return {
		"total_runs": 0,
		"runs_completed": 0,
		"best_puzzle_reached": 0,
		"currency": 0,
		"lifetime_currency_spent": 0,
		"unlocked_starting_cards": [],
		"achievements": [],
	}
