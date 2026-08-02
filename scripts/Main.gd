extends Node2D

const PuzzleGenerator := preload("res://scripts/PuzzleGenerator.gd")
const CardHandScript := preload("res://scripts/CardHand.gd")
const SoundManagerScript := preload("res://scripts/SoundManager.gd")

const GRID_SIZE := Vector2i(4, 4)
const RUN_LENGTH := 6
const SCRAMBLE_COUNT_BASE := 4
const SCRAMBLE_COUNT_CAP := 9
const STARTING_DECK := ["invert", "invert", "swap"]

const TARGET_PATTERNS := [
	[
		[1, 0, 0, 1],
		[0, 1, 1, 0],
		[0, 1, 1, 0],
		[1, 0, 0, 1],
	],
	[
		[1, 0, 1, 0],
		[0, 1, 0, 1],
		[1, 0, 1, 0],
		[0, 1, 0, 1],
	],
	[
		[1, 1, 1, 1],
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 1, 1, 1],
	],
	[
		[1, 1, 0, 0],
		[1, 1, 0, 0],
		[1, 1, 0, 0],
		[1, 1, 0, 0],
	],
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

var sound: Node

var pending_card_index: int = -1
var pending_card: Dictionary = {}
var pending_clicks: Array = []

var run_deck: Array = []
var puzzle_index: int = 0

var original_initial: Array = []
var solution_ops: Array = []
var puzzle_token: int = 0
var replaying_solution: bool = false

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

	sound = Node.new()
	sound.set_script(SoundManagerScript)
	add_child(sound)

	grid = Node2D.new()
	grid.set_script(load("res://scripts/GridManager.gd"))
	grid.position = Vector2(220, 120)
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

	_start_new_run()

func _start_new_run() -> void:
	run_deck = STARTING_DECK.duplicate()
	puzzle_index = 0
	draft_label.visible = false
	draft_hand.visible = false
	_start_new_puzzle()

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
	grid.clear_preview()

	var target: Array = TARGET_PATTERNS[puzzle_index % TARGET_PATTERNS.size()]
	var scramble_count: int = min(SCRAMBLE_COUNT_BASE + puzzle_index, SCRAMBLE_COUNT_CAP)
	var result: Dictionary = PuzzleGenerator.generate(GRID_SIZE, target, scramble_count, rng, run_deck)

	original_initial = []
	for row in result.initial:
		original_initial.append(row.duplicate(true))
	solution_ops = result.hand.duplicate(true)

	grid.setup(GRID_SIZE, result.initial, target)
	card_hand.set_hand(result.hand)
	status_label.text = ""
	progress_label.text = "Puzzle %d / %d" % [puzzle_index + 1, RUN_LENGTH]
	_update_labels()

func _on_card_selected(index: int) -> void:
	if index < 0 or index >= card_hand.cards.size():
		return
	pending_card_index = index
	pending_card = card_hand.cards[index]
	pending_clicks = []
	var needed: int = _targets_needed(pending_card.type)
	if needed == 0:
		grid.apply_card({"type": pending_card.type, "params": {}})
		sound.play_tone(440.0, 0.08)
		_consume_pending_card()
	else:
		grid.set_preview(pending_card.type)

func _on_tile_clicked(x: int, y: int) -> void:
	if pending_card.is_empty():
		return
	pending_clicks.append(Vector2i(x, y))
	var needed: int = _targets_needed(pending_card.type)
	if pending_clicks.size() < needed:
		if pending_card.type == "swap":
			grid.set_preview("swap", pending_clicks[0])
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

	grid.apply_card({"type": pending_card.type, "params": params})
	grid.clear_preview()
	sound.play_tone(440.0, 0.08)
	_consume_pending_card()

func _consume_pending_card() -> void:
	card_hand.remove_card(pending_card_index)
	pending_card_index = -1
	pending_card = {}
	pending_clicks = []
	_update_labels()

	if grid.is_solved():
		if puzzle_index + 1 >= RUN_LENGTH:
			status_label.text = "RUN COMPLETE!"
			sound.play_chime([523.25, 659.25, 783.99, 1046.5], 0.14)
		else:
			status_label.text = "Solved!"
			sound.play_chime([523.25, 659.25, 783.99], 0.12)
			_show_draft()
	elif card_hand.cards.is_empty():
		status_label.text = "Out of cards — run failed"
		sound.play_chime([392.0, 293.66], 0.2)
		solve_button.visible = true

func _show_draft() -> void:
	grid.visible = false
	card_hand.visible = false

	var offered: Array = _pick_random_distinct(PuzzleGenerator.CARD_TYPES, 3)
	for child in draft_hand.get_children():
		child.queue_free()
	for card_type in offered:
		var btn := Button.new()
		btn.text = CardHandScript.label_for({"type": card_type})
		btn.custom_minimum_size = Vector2(120, 60)
		btn.pressed.connect(_on_draft_picked.bind(card_type))
		draft_hand.add_child(btn)

	draft_label.visible = true
	draft_hand.visible = true

func _on_draft_picked(card_type: String) -> void:
	sound.play_tone(600.0, 0.06)
	run_deck.append(card_type)
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
	var target: Array = TARGET_PATTERNS[puzzle_index % TARGET_PATTERNS.size()]
	var replay_state: Array = []
	for row in original_initial:
		replay_state.append(row.duplicate(true))
	grid.setup(GRID_SIZE, replay_state, target)
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
		_:
			return 0

func _update_labels() -> void:
	moves_label.text = "Cards left: %d" % card_hand.cards.size()
