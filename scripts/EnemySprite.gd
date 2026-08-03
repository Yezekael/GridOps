extends Node2D

var archetype: String = "grunt"
var act_index: int = 0
var bob_time: float = 0.0
var base_y: float = 0.0

func set_archetype(new_archetype: String, new_act_index: int) -> void:
	archetype = new_archetype
	act_index = new_act_index
	queue_redraw()

func _ready() -> void:
	base_y = position.y

func _process(delta: float) -> void:
	bob_time += delta
	position.y = base_y + sin(bob_time * 2.0) * 4.0

func _rank_color(base: Color) -> Color:
	return base.lightened(act_index * 0.15)

func _draw() -> void:
	match archetype:
		"grunt":
			_draw_grunt()
		"skirmisher":
			_draw_skirmisher()
		"guardian":
			_draw_guardian()
		"regenerator":
			_draw_regenerator()
		"berserker":
			_draw_berserker()
		"boss":
			_draw_boss()
		_:
			draw_circle(Vector2.ZERO, 40, Color(0.5, 0.5, 0.5))

func _draw_grunt() -> void:
	var color := _rank_color(Color(0.55, 0.45, 0.35))
	draw_rect(Rect2(-35, -35, 70, 70), color, true)
	draw_rect(Rect2(-35, -35, 70, 70), Color(0, 0, 0, 0.4), false, 3.0)

func _draw_skirmisher() -> void:
	var color := _rank_color(Color(0.85, 0.6, 0.2))
	var points := PackedVector2Array([Vector2(0, -45), Vector2(38, 30), Vector2(-38, 30)])
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.4), 3.0)

func _draw_guardian() -> void:
	var color := _rank_color(Color(0.3, 0.5, 0.8))
	var points := PackedVector2Array([
		Vector2(0, -45), Vector2(35, -25), Vector2(35, 20),
		Vector2(0, 45), Vector2(-35, 20), Vector2(-35, -25),
	])
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.4), 3.0)

func _draw_regenerator() -> void:
	var color := _rank_color(Color(0.3, 0.75, 0.4))
	draw_circle(Vector2.ZERO, 40, color)
	draw_circle(Vector2.ZERO, 40, Color(0, 0, 0, 0.4), false, 3.0)
	draw_rect(Rect2(-6, -20, 12, 40), Color(1, 1, 1, 0.85), true)
	draw_rect(Rect2(-20, -6, 40, 12), Color(1, 1, 1, 0.85), true)

func _draw_berserker() -> void:
	var color := _rank_color(Color(0.8, 0.2, 0.2))
	var points := PackedVector2Array()
	var spikes := 8
	for i in spikes * 2:
		var angle: float = i * PI / spikes
		var radius: float = 45.0 if i % 2 == 0 else 22.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func _draw_boss() -> void:
	var boss_colors := [Color(0.55, 0.15, 0.15), Color(0.4, 0.15, 0.55), Color(0.15, 0.1, 0.25)]
	var color: Color = boss_colors[clamp(act_index, 0, boss_colors.size() - 1)]
	var points := PackedVector2Array()
	var spikes := 10
	for i in spikes * 2:
		var angle: float = i * PI / spikes
		var radius: float = 60.0 if i % 2 == 0 else 30.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
	draw_circle(Vector2.ZERO, 15, Color(1, 0.85, 0.3, 0.9))
