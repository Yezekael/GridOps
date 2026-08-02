extends Node2D

signal tile_clicked(x: int, y: int)

const TILE_SIZE := 64
const TILE_GAP := 4

var grid_size: Vector2i = Vector2i(4, 4)
var tile_states: Array = []
var target_states: Array = []
var visual_values: Array = []

var hover_cell: Vector2i = Vector2i(-1, -1)
var preview_card_type: String = ""
var preview_first_click: Vector2i = Vector2i(-1, -1)

func setup(size: Vector2i, initial: Array, target: Array) -> void:
	grid_size = size
	tile_states = initial.duplicate(true)
	target_states = target.duplicate(true)
	visual_values = []
	for y in grid_size.y:
		var row := []
		for x in grid_size.x:
			row.append(float(tile_states[y][x]))
		visual_values.append(row)
	queue_redraw()

func set_preview(card_type: String, first_click: Vector2i = Vector2i(-1, -1)) -> void:
	preview_card_type = card_type
	preview_first_click = first_click
	queue_redraw()

func clear_preview() -> void:
	preview_card_type = ""
	preview_first_click = Vector2i(-1, -1)
	queue_redraw()

func invert(x: int, y: int) -> void:
	tile_states[y][x] = 1 - tile_states[y][x]

func swap(x1: int, y1: int, x2: int, y2: int) -> void:
	var tmp = tile_states[y1][x1]
	tile_states[y1][x1] = tile_states[y2][x2]
	tile_states[y2][x2] = tmp

func mirror_row(row: int) -> void:
	tile_states[row].reverse()

func mirror_col(col: int) -> void:
	var top := 0
	var bottom := grid_size.y - 1
	while top < bottom:
		var tmp = tile_states[top][col]
		tile_states[top][col] = tile_states[bottom][col]
		tile_states[bottom][col] = tmp
		top += 1
		bottom -= 1

func rotate180() -> void:
	var new_states := []
	for y in grid_size.y:
		var row := []
		for x in grid_size.x:
			row.append(tile_states[grid_size.y - 1 - y][grid_size.x - 1 - x])
		new_states.append(row)
	tile_states = new_states

func apply_card(card: Dictionary) -> void:
	var before: Array = []
	for row in tile_states:
		before.append(row.duplicate(true))

	match card.type:
		"invert":
			invert(card.params.x, card.params.y)
		"swap":
			swap(card.params.x1, card.params.y1, card.params.x2, card.params.y2)
		"mirror_row":
			mirror_row(card.params.row)
		"mirror_col":
			mirror_col(card.params.col)
		"rotate180":
			rotate180()

	_animate_changes(before)

func _animate_changes(before: Array) -> void:
	for y in grid_size.y:
		for x in grid_size.x:
			if before[y][x] != tile_states[y][x]:
				_animate_cell(x, y, float(tile_states[y][x]))

func _animate_cell(x: int, y: int, target_value: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_visual_value.bind(x, y), visual_values[y][x], target_value, 0.25)

func _set_visual_value(x: int, y: int, value: float) -> void:
	visual_values[y][x] = value
	queue_redraw()

func is_solved() -> bool:
	for y in grid_size.y:
		for x in grid_size.x:
			if tile_states[y][x] != target_states[y][x]:
				return false
	return true

func _is_cell_highlighted(x: int, y: int) -> bool:
	match preview_card_type:
		"invert":
			return hover_cell == Vector2i(x, y)
		"swap":
			return hover_cell == Vector2i(x, y) or preview_first_click == Vector2i(x, y)
		"mirror_row":
			return hover_cell.x >= 0 and hover_cell.y == y
		"mirror_col":
			return hover_cell.y >= 0 and hover_cell.x == x
		_:
			return false

func _draw() -> void:
	if tile_states.is_empty():
		return
	for y in grid_size.y:
		for x in grid_size.x:
			var rect := Rect2(
				x * (TILE_SIZE + TILE_GAP),
				y * (TILE_SIZE + TILE_GAP),
				TILE_SIZE,
				TILE_SIZE
			)
			var t: float = visual_values[y][x]
			var fill_color: Color = Color(0.15, 0.15, 0.18).lerp(Color(0.85, 0.85, 0.9), t)
			draw_rect(rect, fill_color, true)

			if _is_cell_highlighted(x, y):
				draw_rect(rect, Color(1.0, 0.85, 0.2, 0.35), true)

			var matches_target: bool = tile_states[y][x] == target_states[y][x]
			var border_color: Color = Color(0.3, 0.9, 0.4) if matches_target else Color(0.6, 0.15, 0.15)
			draw_rect(rect, border_color, false, 2.0)

func _cell_at_local(local_pos: Vector2) -> Vector2i:
	var step := float(TILE_SIZE + TILE_GAP)
	var cell := Vector2i(int(local_pos.x / step), int(local_pos.y / step))
	if cell.x < 0 or cell.x >= grid_size.x or cell.y < 0 or cell.y >= grid_size.y:
		return Vector2i(-1, -1)
	var offset_x: float = fmod(local_pos.x, step)
	var offset_y: float = fmod(local_pos.y, step)
	if offset_x > TILE_SIZE or offset_y > TILE_SIZE:
		return Vector2i(-1, -1)
	return cell

func _unhandled_input(event: InputEvent) -> void:
	if tile_states.is_empty():
		return
	if event is InputEventMouseMotion:
		var cell := _cell_at_local(to_local(event.position))
		if cell != hover_cell:
			hover_cell = cell
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_at_local(to_local(event.position))
		if cell.x >= 0:
			tile_clicked.emit(cell.x, cell.y)
