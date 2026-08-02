extends Node2D

const PuzzleGenerator := preload("res://scripts/PuzzleGenerator.gd")
const CardHandScript := preload("res://scripts/CardHand.gd")
const SoundManagerScript := preload("res://scripts/SoundManager.gd")
const SaveManagerScript := preload("res://scripts/SaveManager.gd")

const RUN_LENGTH := 6
const SCRAMBLE_COUNT_BASE := 4
const SCRAMBLE_COUNT_CAP := 9
const BOSS_SCRAMBLE_BONUS := 2
const STARTING_DECK := ["invert", "invert", "swap"]

const PATTERN_NAMES := [
	"x", "checkerboard", "frame", "half_left",
	"half_top", "corners", "diamond", "diagonal",
]

const UPGRADES := [
	{"id": "extra_invert", "label": "Extra Invert", "cost": 5, "card_type": "invert"},
	{"id": "extra_swap", "label": "Extra Swap", "cost": 5, "card_type": "swap"},
	{"id": "unlock_mirror_row", "label": "Unlock Mirror Row", "cost": 10, "card_type": "mirror_row"},
	{"id": "unlock_mirror_col", "label": "Unlock Mirror Col", "cost": 10, "card_type": "mirror_col"},
	{"id": "unlock_rotate180", "label": "Unlock Rotate 180", "cost": 12, "card_type": "rotate180"},
	{"id": "unlock_invert_row", "label": "Unlock Invert Row", "cost": 12, "card_type": "invert_row"},
	{"id": "unlock_invert_col", "label": "Unlock Invert Col", "cost": 12, "card_type": "invert_col"},
	{"id": "unlock_transpose", "label": "Unlock Transpose", "cost": 15, "card_type": "transpose"},
]

const ACHIEVEMENTS := [
	{"id": "first_win", "label": "First Win", "desc": "Complete a full run"},
	{"id": "efficient", "label": "Efficient", "desc": "Solve a puzzle with 2+ cards left in hand"},
	{"id": "full_deck", "label": "Full Deck", "desc": "Have all 8 card types in your deck at once"},
	{"id": "big_spender", "label": "Big Spender", "desc": "Spend 20+ currency in the shop (lifetime)"},
	{"id": "veteran", "label": "Veteran", "desc": "Play 10 runs"},
	{"id": "collector", "label": "Collector", "desc": "Permanently unlock all 8 card types via the shop"},
]

var grid: Node2D
var card_hand: HBoxContainer
var status_label: Label
var moves_label: Label
var progress_label: Label
var solve_button: Button
var new_run_button: Button

var draft_label: Label
var draft_hand: HBoxContainer

var shop_label: Label
var shop_hand: GridContainer
var shop_button: Button
var shop_was_showing_draft: bool = false

var achievements_label: Label
var achievements_hand: GridContainer
var achievements_button: Button
var achievements_was_showing_draft: bool = false

var pending_card_index: int = -1
var pending_card: Dictionary = {}
var pending_clicks: Array = []

var run_deck: Array = []
var puzzle_index: int = 0
var current_target: Array = []
var current_grid_size: Vector2i = Vector2i(4, 4)
var last_pattern_name: String = ""

var original_initial: Array = []
var solution_ops: Array = []
var puzzle_token: int = 0
var replaying_solution: bool = false

var rng := RandomNumberGenerator.new()
var sound: Node
var save_mgr: Node
var stats_label: Label

func _ready() -> void:
	rng.randomize()

	sound = Node.new()
	sound.set_script(SoundManagerScript)
	add_child(sound)

	save_mgr = Node.new()
	save_mgr.set_script(SaveManagerScript)
	add_child(save_mgr)

	grid = Node2D.new()
	grid.set_script(load("res://scripts/GridManager.gd"))
	grid.position = Vector2(240, 150)
	add_child(grid)
	grid.tile_clicked.connect(_on_tile_clicked)

	var ui := CanvasLayer.new()
	add_child(ui)

	progress_label = Label.new()
	progress_label.position = Vector2(20, 20)
	progress_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(progress_label)

	moves_label = Label.new()
	moves_label.position = Vector2(20, 55)
	moves_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(moves_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 90)
	status_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(status_label)

	card_hand = HBoxContainer.new()
	card_hand.set_script(CardHandScript)
	card_hand.position = Vector2(20, 540)
	card_hand.add_theme_constant_override("separation", 10)
	ui.add_child(card_hand)
	card_hand.card_selected.connect(_on_card_selected)

	draft_label = Label.new()
	draft_label.position = Vector2(300, 220)
	draft_label.add_theme_font_size_override("font_size", 24)
	draft_label.text = "Choose a card to add to your deck:"
	draft_label.visible = false
	ui.add_child(draft_label)

	draft_hand = HBoxContainer.new()
	draft_hand.position = Vector2(300, 270)
	draft_hand.add_theme_constant_override("separation", 10)
	draft_hand.visible = false
	ui.add_child(draft_hand)

	new_run_button = Button.new()
	new_run_button.text = "New Run"
	new_run_button.position = Vector2(780, 20)
	new_run_button.custom_minimum_size = Vector2(140, 40)
	new_run_button.pressed.connect(_start_new_run)
	ui.add_child(new_run_button)

	solve_button = Button.new()
	solve_button.text = "Show Solution"
	solve_button.position = Vector2(780, 70)
	solve_button.custom_minimum_size = Vector2(140, 40)
	solve_button.visible = false
	solve_button.pressed.connect(_on_solve_pressed)
	ui.add_child(solve_button)

	shop_button = Button.new()
	shop_button.text = "Shop"
	shop_button.position = Vector2(780, 120)
	shop_button.custom_minimum_size = Vector2(140, 40)
	shop_button.pressed.connect(_open_shop)
	ui.add_child(shop_button)

	achievements_button = Button.new()
	achievements_button.text = "Achievements"
	achievements_button.position = Vector2(780, 170)
	achievements_button.custom_minimum_size = Vector2(140, 40)
	achievements_button.pressed.connect(_open_achievements)
	ui.add_child(achievements_button)

	stats_label = Label.new()
	stats_label.position = Vector2(780, 220)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	ui.add_child(stats_label)
	_update_stats_label()

	shop_label = Label.new()
	shop_label.position = Vector2(300, 150)
	shop_label.add_theme_font_size_override("font_size", 20)
	shop_label.visible = false
	ui.add_child(shop_label)

	shop_hand = GridContainer.new()
	shop_hand.position = Vector2(300, 210)
	shop_hand.columns = 3
	shop_hand.add_theme_constant_override("h_separation", 10)
	shop_hand.add_theme_constant_override("v_separation", 10)
	shop_hand.visible = false
	ui.add_child(shop_hand)

	achievements_label = Label.new()
	achievements_label.position = Vector2(300, 150)
	achievements_label.add_theme_font_size_override("font_size", 20)
	achievements_label.text = "Achievements"
	achievements_label.visible = false
	ui.add_child(achievements_label)

	achievements_hand = GridContainer.new()
	achievements_hand.position = Vector2(300, 190)
	achievements_hand.columns = 2
	achievements_hand.add_theme_constant_override("h_separation", 10)
	achievements_hand.add_theme_constant_override("v_separation", 10)
	achievements_hand.visible = false
	ui.add_child(achievements_hand)

	_start_new_run()

func _start_new_run() -> void:
	run_deck = STARTING_DECK.duplicate()
	for card_type in save_mgr.data.unlocked_starting_cards:
		run_deck.append(card_type)
	puzzle_index = 0
	last_pattern_name = ""
	draft_label.visible = false
	draft_hand.visible = false

	save_mgr.data.total_runs += 1
	save_mgr.save_data()
	_update_stats_label()
	if int(save_mgr.data.total_runs) >= 10:
		_unlock_achievement("veteran")
	_check_full_deck_achievement()

	_start_new_puzzle()

func _check_full_deck_achievement() -> void:
	var distinct := {}
	for card_type in run_deck:
		distinct[card_type] = true
	if distinct.size() >= PuzzleGenerator.CARD_TYPES.size():
		_unlock_achievement("full_deck")

func _update_stats_label() -> void:
	var d: Dictionary = save_mgr.data
	stats_label.text = "Best: Puzzle %d/%d\nRuns: %d  Wins: %d\nCurrency: %d" % [
		d.best_puzzle_reached, RUN_LENGTH, d.total_runs, d.runs_completed, int(d.currency)
	]

func _record_best_puzzle_reached() -> void:
	if puzzle_index + 1 > save_mgr.data.best_puzzle_reached:
		save_mgr.data.best_puzzle_reached = puzzle_index + 1
		save_mgr.save_data()
		_update_stats_label()

func _grid_size_for_puzzle(index: int) -> Vector2i:
	if index == RUN_LENGTH - 1:
		return Vector2i(7, 7)
	elif index < 2:
		return Vector2i(4, 4)
	elif index < 4:
		return Vector2i(5, 5)
	else:
		return Vector2i(6, 6)

func _scramble_count_for_puzzle(index: int) -> int:
	var count: int = min(SCRAMBLE_COUNT_BASE + index, SCRAMBLE_COUNT_CAP)
	if index == RUN_LENGTH - 1:
		count += BOSS_SCRAMBLE_BONUS
	return count

func _is_boss_puzzle(index: int) -> bool:
	return index == RUN_LENGTH - 1

func _generate_pattern(pattern_name: String, size: Vector2i) -> Array:
	var pattern: Array = []
	for y in size.y:
		var row: Array = []
		for x in size.x:
			row.append(1 if _pattern_cell(pattern_name, x, y, size) else 0)
		pattern.append(row)
	return pattern

func _pattern_cell(pattern_name: String, x: int, y: int, size: Vector2i) -> bool:
	match pattern_name:
		"x":
			return x == y or x == (size.x - 1 - y)
		"checkerboard":
			return (x + y) % 2 == 0
		"frame":
			return x == 0 or x == size.x - 1 or y == 0 or y == size.y - 1
		"half_left":
			return x < int(ceil(size.x / 2.0))
		"half_top":
			return y < int(ceil(size.y / 2.0))
		"corners":
			return (x == 0 or x == size.x - 1) and (y == 0 or y == size.y - 1)
		"diamond":
			var cx: float = (size.x - 1) / 2.0
			var cy: float = (size.y - 1) / 2.0
			return absf(x - cx) + absf(y - cy) <= size.x / 2.0
		"diagonal":
			return x == y
		_:
			return false

func _start_new_puzzle() -> void:
	puzzle_token += 1
	replaying_solution = false
	pending_card_index = -1
	pending_card = {}
	pending_clicks = []
	solve_button.visible = false
	solve_button.disabled = false
	grid.visible = true
	card_hand.visible = true

	current_grid_size = _grid_size_for_puzzle(puzzle_index)

	var pattern_name: String = PATTERN_NAMES[rng.randi_range(0, PATTERN_NAMES.size() - 1)]
	if PATTERN_NAMES.size() > 1:
		while pattern_name == last_pattern_name:
			pattern_name = PATTERN_NAMES[rng.randi_range(0, PATTERN_NAMES.size() - 1)]
	last_pattern_name = pattern_name
	current_target = _generate_pattern(pattern_name, current_grid_size)

	var scramble_count: int = _scramble_count_for_puzzle(puzzle_index)
	var result: Dictionary = PuzzleGenerator.generate(current_grid_size, current_target, scramble_count, rng, run_deck)

	original_initial = []
	for row in result.initial:
		original_initial.append(row.duplicate(true))
	solution_ops = result.hand.duplicate(true)

	grid.setup(current_grid_size, result.initial, current_target)
	card_hand.set_hand(result.hand)
	status_label.text = ""
	if _is_boss_puzzle(puzzle_index):
		progress_label.text = "Puzzle %d / %d — BOSS PUZZLE" % [puzzle_index + 1, RUN_LENGTH]
		progress_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		progress_label.text = "Puzzle %d / %d" % [puzzle_index + 1, RUN_LENGTH]
		progress_label.remove_theme_color_override("font_color")
	_update_labels()

func _on_card_selected(index: int) -> void:
	if index < 0 or index >= card_hand.cards.size():
		return
	pending_card_index = index
	pending_card = card_hand.cards[index]
	pending_clicks = []
	if _targets_needed(pending_card.type) == 0:
		grid.apply_card({"type": pending_card.type, "params": {}})
		sound.play_tone(440.0, 0.08)
		_consume_pending_card()

func _on_tile_clicked(x: int, y: int) -> void:
	if pending_card.is_empty():
		return
	pending_clicks.append(Vector2i(x, y))
	if pending_clicks.size() < _targets_needed(pending_card.type):
		return

	var params: Dictionary = {}
	match pending_card.type:
		"invert":
			params = {"x": pending_clicks[0].x, "y": pending_clicks[0].y}
		"swap":
			params = {
				"x1": pending_clicks[0].x, "y1": pending_clicks[0].y,
				"x2": pending_clicks[1].x, "y2": pending_clicks[1].y,
			}
		"mirror_row":
			params = {"row": pending_clicks[0].y}
		"mirror_col":
			params = {"col": pending_clicks[0].x}
		"invert_row":
			params = {"row": pending_clicks[0].y}
		"invert_col":
			params = {"col": pending_clicks[0].x}

	grid.apply_card({"type": pending_card.type, "params": params})
	sound.play_tone(440.0, 0.08)
	_consume_pending_card()

func _consume_pending_card() -> void:
	card_hand.remove_card(pending_card_index)
	pending_card_index = -1
	pending_card = {}
	pending_clicks = []
	_update_labels()

	if grid.is_solved():
		_record_best_puzzle_reached()
		save_mgr.data.currency = int(save_mgr.data.currency) + 1
		if card_hand.cards.size() >= 2:
			_unlock_achievement("efficient")
		if puzzle_index + 1 >= RUN_LENGTH:
			status_label.text = "RUN COMPLETE!"
			sound.play_chime([523.25, 659.25, 783.99, 1046.5], 0.14)
			save_mgr.data.runs_completed += 1
			save_mgr.data.currency = int(save_mgr.data.currency) + 3
			save_mgr.save_data()
			_update_stats_label()
			_unlock_achievement("first_win")
		else:
			save_mgr.save_data()
			_update_stats_label()
			status_label.text = "Solved!"
			sound.play_chime([523.25, 659.25, 783.99], 0.12)
			_show_draft()
	elif card_hand.cards.is_empty():
		status_label.text = "Out of cards — run failed"
		sound.play_chime([392.0, 293.66], 0.2)
		solve_button.visible = true
		_record_best_puzzle_reached()

func _show_draft() -> void:
	grid.visible = false
	card_hand.visible = false

	draft_label.text = "Choose a card to add to your deck:"

	var offered: Array = _pick_random_distinct(PuzzleGenerator.CARD_TYPES, 3)
	for child in draft_hand.get_children():
		child.queue_free()
	for card_type in offered:
		var btn := Button.new()
		btn.text = CardHandScript.label_for({"type": card_type})
		btn.custom_minimum_size = Vector2(120, 60)
		btn.pressed.connect(_on_draft_picked.bind(card_type))
		draft_hand.add_child(btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(120, 60)
	skip_btn.pressed.connect(_on_draft_skipped)
	draft_hand.add_child(skip_btn)

	if run_deck.size() > 1:
		var remove_btn := Button.new()
		remove_btn.text = "Remove a Card"
		remove_btn.custom_minimum_size = Vector2(140, 60)
		remove_btn.pressed.connect(_show_draft_removal_options)
		draft_hand.add_child(remove_btn)

	draft_label.visible = true
	draft_hand.visible = true

func _show_draft_removal_options() -> void:
	draft_label.text = "Choose a card to remove from your deck:"
	for child in draft_hand.get_children():
		child.queue_free()

	var counts: Dictionary = {}
	for card_type in run_deck:
		counts[card_type] = counts.get(card_type, 0) + 1

	for card_type in counts.keys():
		var btn := Button.new()
		btn.text = "%s (x%d)" % [CardHandScript.label_for({"type": card_type}), counts[card_type]]
		btn.custom_minimum_size = Vector2(150, 60)
		btn.pressed.connect(_on_card_removed.bind(card_type))
		draft_hand.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 60)
	back_btn.pressed.connect(_show_draft)
	draft_hand.add_child(back_btn)

func _on_card_removed(card_type: String) -> void:
	var idx: int = run_deck.find(card_type)
	if idx >= 0:
		run_deck.remove_at(idx)
	sound.play_tone(250.0, 0.1)
	_advance_after_draft()

func _open_shop() -> void:
	shop_was_showing_draft = draft_hand.visible
	grid.visible = false
	card_hand.visible = false
	draft_label.visible = false
	draft_hand.visible = false
	_rebuild_shop()
	shop_label.visible = true
	shop_hand.visible = true

func _close_shop() -> void:
	shop_label.visible = false
	shop_hand.visible = false
	if shop_was_showing_draft:
		_show_draft()
	else:
		grid.visible = true
		card_hand.visible = true

func _rebuild_shop() -> void:
	for child in shop_hand.get_children():
		child.queue_free()

	var currency: int = int(save_mgr.data.currency)
	shop_label.text = "Shop — Currency: %d (permanently added to your starting deck)" % currency

	for upgrade in UPGRADES:
		var btn := Button.new()
		btn.text = "%s (%d)" % [upgrade.label, upgrade.cost]
		btn.custom_minimum_size = Vector2(150, 50)
		btn.disabled = currency < upgrade.cost
		btn.pressed.connect(_on_upgrade_purchased.bind(upgrade))
		shop_hand.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(150, 50)
	close_btn.pressed.connect(_close_shop)
	shop_hand.add_child(close_btn)

func _on_upgrade_purchased(upgrade: Dictionary) -> void:
	var currency: int = int(save_mgr.data.currency)
	if currency < upgrade.cost:
		return
	save_mgr.data.currency = currency - upgrade.cost
	save_mgr.data.lifetime_currency_spent = int(save_mgr.data.lifetime_currency_spent) + int(upgrade.cost)
	save_mgr.data.unlocked_starting_cards.append(upgrade.card_type)
	save_mgr.save_data()
	_update_stats_label()
	sound.play_tone(700.0, 0.08)
	_rebuild_shop()

	if int(save_mgr.data.lifetime_currency_spent) >= 20:
		_unlock_achievement("big_spender")
	var unlocked_types := {}
	for card_type in save_mgr.data.unlocked_starting_cards:
		unlocked_types[card_type] = true
	if unlocked_types.size() >= PuzzleGenerator.CARD_TYPES.size():
		_unlock_achievement("collector")

func _open_achievements() -> void:
	achievements_was_showing_draft = draft_hand.visible
	grid.visible = false
	card_hand.visible = false
	draft_label.visible = false
	draft_hand.visible = false
	_rebuild_achievements()
	achievements_label.visible = true
	achievements_hand.visible = true

func _close_achievements() -> void:
	achievements_label.visible = false
	achievements_hand.visible = false
	if achievements_was_showing_draft:
		_show_draft()
	else:
		grid.visible = true
		card_hand.visible = true

func _rebuild_achievements() -> void:
	for child in achievements_hand.get_children():
		child.queue_free()

	var unlocked: Array = save_mgr.data.achievements
	for achievement in ACHIEVEMENTS:
		var label := Label.new()
		var mark: String = "[x]" if achievement.id in unlocked else "[ ]"
		label.text = "%s %s — %s" % [mark, achievement.label, achievement.desc]
		label.custom_minimum_size = Vector2(280, 30)
		achievements_hand.add_child(label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(150, 50)
	close_btn.pressed.connect(_close_achievements)
	achievements_hand.add_child(close_btn)

func _unlock_achievement(id: String) -> void:
	if id in save_mgr.data.achievements:
		return
	save_mgr.data.achievements.append(id)
	save_mgr.save_data()
	sound.play_chime([659.25, 880.0], 0.1)

func _on_draft_picked(card_type: String) -> void:
	sound.play_tone(600.0, 0.06)
	run_deck.append(card_type)
	_check_full_deck_achievement()
	_advance_after_draft()

func _on_draft_skipped() -> void:
	sound.play_tone(300.0, 0.06)
	_advance_after_draft()

func _advance_after_draft() -> void:
	puzzle_index += 1
	draft_label.visible = false
	draft_hand.visible = false
	_start_new_puzzle()

func _pick_random_distinct(pool: Array, count: int) -> Array:
	var remaining: Array = pool.duplicate()
	var picked: Array = []
	for i in range(min(count, remaining.size())):
		var idx: int = rng.randi_range(0, remaining.size() - 1)
		picked.append(remaining[idx])
		remaining.remove_at(idx)
	return picked

func _on_solve_pressed() -> void:
	if replaying_solution:
		return
	replaying_solution = true
	solve_button.disabled = true
	pending_card_index = -1
	pending_card = {}
	pending_clicks = []

	var token := puzzle_token
	var replay_state: Array = []
	for row in original_initial:
		replay_state.append(row.duplicate(true))
	grid.setup(current_grid_size, replay_state, current_target)
	status_label.text = "Replaying solution..."

	for op in solution_ops:
		await get_tree().create_timer(0.6).timeout
		if token != puzzle_token:
			return
		grid.apply_card(op)

	if token != puzzle_token:
		return
	status_label.text = "Solution replayed — tap New Run to try again"

func _targets_needed(card_type: String) -> int:
	match card_type:
		"invert":
			return 1
		"swap":
			return 2
		"mirror_row":
			return 1
		"mirror_col":
			return 1
		"rotate180":
			return 0
		"invert_row":
			return 1
		"invert_col":
			return 1
		"transpose":
			return 0
		_:
			return 0

func _update_labels() -> void:
	moves_label.text = "Cards left: %d" % card_hand.cards.size()
