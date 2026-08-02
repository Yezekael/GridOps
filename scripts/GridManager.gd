extends Node2D

signal tile_clicked(x: int, y: int)

const TILE_SIZE := 64
const TILE_GAP := 4

var grid_size: Vector2i = Vector2i(4, 4)
var tile_states: Array = []
var target_states: Array = []

func setup(size: Vector2i, initial: Array, target: Array) -> void:
	grid_size = size
	tile_states = initial.duplicate(true)
	target_states = target.duplicate(true)
	queue_redraw()

func invert(x: int, y: int) -> void:
	tile_states[y][x] = 1 - tile_states[y][x]
	queue_redraw()

func is_solved() -> bool:
	for y in grid_size.y:
		for x in grid_size.x:
			if tile_states[y][x] != target_states[y][x]:
				return false
	return true

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
			var on: bool = tile_states[y][x] == 1
			var matches_target: bool = tile_states[y][x] == target_states[y][x]
			var fill_color: Color = Color(0.85, 0.85, 0.9) if on else Color(0.15, 0.15, 0.18)
			draw_rect(rect, fill_color, true)
			var border_color: Color = Color(0.3, 0.9, 0.4) if matches_target else Color(0.6, 0.15, 0.15)
			draw_rect(rect, border_color, false, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if tile_states.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = to_local(event.position)
		var step := float(TILE_SIZE + TILE_GAP)
		var cell := Vector2i(int(local_pos.x / step), int(local_pos.y / step))
		if cell.x < 0 or cell.x >= grid_size.x or cell.y < 0 or cell.y >= grid_size.y:
			return
		var offset_x: float = fmod(local_pos.x, step)
		var offset_y: float = fmod(local_pos.y, step)
		if offset_x <= TILE_SIZE and offset_y <= TILE_SIZE:
			tile_clicked.emit(cell.x, cell.y)
