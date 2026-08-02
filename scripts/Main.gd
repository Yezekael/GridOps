extends Node2D

const PuzzleGenerator := preload("res://scripts/PuzzleGenerator.gd")
const CardHandScript := preload("res://scripts/CardHand.gd")

const GRID_SIZE := Vector2i(4, 4)
const SCRAMBLE_COUNT := 6
const TARGET_PATTERN := [
	[1, 0, 0, 1],
	[0, 1, 1, 0],
	[0, 1, 1, 0],
	[1, 0, 0, 1],
]

var grid: Node2D
var card_hand: HBoxContainer
var status_label: Label
var moves_label: Label
var solve_button: Button

var pending_card_index: int = -1
var pending_card: Dictionary = {}
var pending_clicks: Array = []

var original_initial: Array = []
var solution_ops: Array = []
var puzzle_token: int = 0
var replaying_solution: bool = false

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

	grid = Node2D.new()
	grid.set_script(load("res://scripts/GridManager.gd"))
	grid.position = Vector2(220, 120)
	add_child(grid)
	grid.tile_clicked.connect(_on_tile_clicked)

	var ui := CanvasLayer.new()
	add_child(ui)

	moves_label = Label.new()
	moves_label.position = Vector2(20, 20)
	moves_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(moves_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 60)
	status_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(status_label)

	card_hand = HBoxContainer.new()
	card_hand.set_script(CardHandScript)
	card_hand.position = Vector2(20, 540)
	card_hand.add_theme_constant_override("separation", 10)
	ui.add_child(card_hand)
	card_hand.card_selected.connect(_on_card_selected)

	var new_puzzle_button := Button.new()
	new_puzzle_button.text = "New Puzzle"
	new_puzzle_button.position = Vector2(780, 20)
	new_puzzle_button.custom_minimum_size = Vector2(140, 40)
	new_puzzle_button.pressed.connect(_start_new_puzzle)
	ui.add_child(new_puzzle_button)

	solve_button = Button.new()
	solve_button.text = "Show Solution"
	solve_button.position = Vector2(780, 70)
	solve_button.custom_minimum_size = Vector2(140, 40)
	solve_button.visible = false
	solve_button.pressed.connect(_on_solve_pressed)
	ui.add_child(solve_button)

	_start_new_puzzle()

func _start_new_puzzle() -> void:
	puzzle_token += 1
	replaying_solution = false
	pending_card_index = -1
	pending_card = {}
	pending_clicks = []
	solve_button.visible = false
	solve_button.disabled = false

	var result: Dictionary = PuzzleGenerator.generate(GRID_SIZE, TARGET_PATTERN, SCRAMBLE_COUNT, rng)
	original_initial = []
	for row in result.initial:
		original_initial.append(row.duplicate(true))
	solution_ops = result.hand.duplicate(true)

	grid.setup(GRID_SIZE, result.initial, TARGET_PATTERN)
	card_hand.set_hand(result.hand)
	status_label.text = ""
	_update_labels()

func _on_card_selected(index: int) -> void:
	if index < 0 or index >= card_hand.cards.size():
		return
	pending_card_index = index
	pending_card = card_hand.cards[index]
	pending_clicks = []
	if _targets_needed(pending_card.type) == 0:
		grid.apply_card({"type": pending_card.type, "params": {}})
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

	grid.apply_card({"type": pending_card.type, "params": params})
	_consume_pending_card()

func _consume_pending_card() -> void:
	card_hand.remove_card(pending_card_index)
	pending_card_index = -1
	pending_card = {}
	pending_clicks = []
	_update_labels()

	if grid.is_solved():
		status_label.text = "SOLVED!"
	elif card_hand.cards.is_empty():
		status_label.text = "Out of cards — failed"
		solve_button.visible = true

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
	grid.setup(GRID_SIZE, replay_state, TARGET_PATTERN)
	status_label.text = "Replaying solution..."

	for op in solution_ops:
		await get_tree().create_timer(0.6).timeout
		if token != puzzle_token:
			return
		grid.apply_card(op)

	if token != puzzle_token:
		return
	status_label.text = "Solution replayed — tap New Puzzle to try another"

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
