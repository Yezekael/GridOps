extends Node2D

var grid: Node2D
var moves_left: int = 5
var card_selected: bool = false

var status_label: Label
var moves_label: Label
var card_button: Button

func _ready() -> void:
	grid = Node2D.new()
	grid.set_script(load("res://scripts/GridManager.gd"))
	grid.position = Vector2(220, 160)
	add_child(grid)
	grid.tile_clicked.connect(_on_tile_clicked)

	var initial: Array = [
		[0, 1, 0, 1],
		[1, 1, 0, 0],
		[0, 0, 1, 1],
		[1, 0, 1, 0],
	]
	var target: Array = [
		[1, 1, 1, 1],
		[1, 1, 1, 1],
		[1, 1, 1, 1],
		[1, 1, 1, 1],
	]
	grid.setup(Vector2i(4, 4), initial, target)

	_build_ui()

func _build_ui() -> void:
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

	card_button = Button.new()
	card_button.text = "Invert"
	card_button.position = Vector2(20, 540)
	card_button.custom_minimum_size = Vector2(140, 50)
	card_button.pressed.connect(_on_card_pressed)
	ui.add_child(card_button)

	_update_labels()

func _on_card_pressed() -> void:
	if moves_left <= 0:
		return
	card_selected = true
	status_label.text = "Select a tile to invert"

func _on_tile_clicked(x: int, y: int) -> void:
	if not card_selected or moves_left <= 0:
		return
	grid.invert(x, y)
	moves_left -= 1
	card_selected = false
	_update_labels()
	if grid.is_solved():
		status_label.text = "SOLVED!"
	elif moves_left <= 0:
		status_label.text = "Out of moves — failed"

func _update_labels() -> void:
	moves_label.text = "Moves left: %d" % moves_left
	if moves_left > 0 and not grid.is_solved():
		status_label.text = ""
