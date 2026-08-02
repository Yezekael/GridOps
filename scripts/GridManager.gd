extends Node2D

signal tile_clicked(x: int, y: int)

const TILE_GAP := 4.0
const GRID_PIXEL_BUDGET := 268.0
const DEFAULT_TILE_SIZE := 64.0

var grid_size: Vector2i = Vector2i(4, 4)
var tile_states: Array = []
var target_states: Array = []
var tile_size: float = DEFAULT_TILE_SIZE

func setup(size: Vector2i, initial: Array, target: Array) -> void:
	grid_size = size
	# Keep the grid's total footprint roughly constant regardless of size,
	# so a 6x6 puzzle doesn't overlap the card hand below it: tiles shrink
	# as the grid grows instead of the whole grid getting physically bigger.
	tile_size = (GRID_PIXEL_BUDGET - float(grid_size.x - 1) * TILE_GAP) / float(grid_size.x)
	tile_states = initial.duplicate(true)
	target_states = target.duplicate(true)
	queue_redraw()

func invert(x: int, y: int) -> void:
	tile_states[y][x] = 1 - tile_states[y][x]
	queue_redraw()

func swap(x1: int, y1: int, x2: int, y2: int) -> void:
	var tmp = tile_states[y1][x1]
	tile_states[y1][x1] = tile_states[y2][x2]
	tile_states[y2][x2] = tmp
	queue_redraw()

func mirror_row(row: int) -> void:
	tile_states[row].reverse()
	queue_redraw()

func mirror_col(col: int) -> void:
	var top := 0
	var bottom := grid_size.y - 1
	while top < bottom:
		var tmp = tile_states[top][col]
		tile_states[top][col] = tile_states[bottom][col]
		tile_states[bottom][col] = tmp
		top += 1
		bottom -= 1
	queue_redraw()

func rotate180() -> void:
	var new_states := []
	for y in grid_size.y:
		var row := []
		for x in grid_size.x:
			row.append(tile_states[grid_size.y - 1 - y][grid_size.x - 1 - x])
		new_states.append(row)
	tile_states = new_states
	queue_redraw()

func apply_card(card: Dictionary) -> void:
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

func is_solved() -> bool:
	for y in grid_size.y:
		for x in grid_size.x:
			if tile_states[y][x] != target_states[y][x]:
				return false
	return true

func _draw() -> void:
	if tile_states.is_empty():
		return

	var font := ThemeDB.fallback_font
	var font_size := 16
	var step := tile_size + TILE_GAP

	for x in grid_size.x:
		var col_label_pos := Vector2(x * step + tile_size / 2.0 - 4, -12)
		draw_string(font, col_label_pos, str(x + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.6, 0.6, 0.65))
	for y in grid_size.y:
		var row_label_pos := Vector2(-24, y * step + tile_size / 2.0 + 5)
		draw_string(font, row_label_pos, str(y + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.6, 0.6, 0.65))

	var marker_radius: float = clamp(tile_size * 0.08, 3.0, 5.0)
	var marker_inset: float = marker_radius + 5.0

	for y in grid_size.y:
		for x in grid_size.x:
			var rect := Rect2(
				x * step,
				y * step,
				tile_size,
				tile_size
			)
			var on: bool = tile_states[y][x] == 1
			var matches_target: bool = tile_states[y][x] == target_states[y][x]
			var fill_color: Color = Color(0.85, 0.85, 0.9) if on else Color(0.15, 0.15, 0.18)
			draw_rect(rect, fill_color, true)
			var border_color: Color = Color(0.3, 0.9, 0.4) if matches_target else Color(0.6, 0.15, 0.15)
			draw_rect(rect, border_color, false, 2.0)

			# Match/mismatch is also shown as a shape (not just border color)
			# so it reads correctly for colorblind players.
			var marker_center := rect.position + Vector2(tile_size - marker_inset, marker_inset)
			var marker_color := Color(1.0, 1.0, 1.0, 0.85) if on else Color(0.0, 0.0, 0.0, 0.85)
			if matches_target:
				draw_circle(marker_center, marker_radius, marker_color)
			else:
				draw_line(marker_center + Vector2(-marker_radius, -marker_radius), marker_center + Vector2(marker_radius, marker_radius), marker_color, 2.0)
				draw_line(marker_center + Vector2(-marker_radius, marker_radius), marker_center + Vector2(marker_radius, -marker_radius), marker_color, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if tile_states.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = to_local(event.position)
		var step := tile_size + TILE_GAP
		var cell := Vector2i(int(local_pos.x / step), int(local_pos.y / step))
		if cell.x < 0 or cell.x >= grid_size.x or cell.y < 0 or cell.y >= grid_size.y:
			return
		var offset_x: float = fmod(local_pos.x, step)
		var offset_y: float = fmod(local_pos.y, step)
		if offset_x <= tile_size and offset_y <= tile_size:
			tile_clicked.emit(cell.x, cell.y)
