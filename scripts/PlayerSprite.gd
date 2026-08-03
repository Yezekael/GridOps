extends Node2D

var bob_time: float = 0.0
var base_y: float = 0.0
var base_x: float = 0.0
var block_amount: int = 0

func _ready() -> void:
	base_y = position.y
	base_x = position.x

func _process(delta: float) -> void:
	bob_time += delta
	position.y = base_y + sin(bob_time * 2.0) * 4.0

func set_block(amount: int) -> void:
	block_amount = amount
	queue_redraw()

func _draw() -> void:
	var color := Color(0.3, 0.8, 0.85)

	if block_amount > 0:
		draw_circle(Vector2(0, 0), 55, Color(0.5, 0.85, 1.0, 0.25))
		draw_arc(Vector2(0, 0), 55, 0, TAU, 32, Color(0.6, 0.9, 1.0, 0.7), 3.0)

	draw_circle(Vector2(0, -50), 18, color)
	draw_arc(Vector2(0, -50), 18, 0, TAU, 24, Color(0, 0, 0, 0.4), 3.0)

	var torso := PackedVector2Array([
		Vector2(-22, -30), Vector2(22, -30), Vector2(28, 35), Vector2(-28, 35),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), Color(0, 0, 0, 0.4), 3.0)

func hit_flash() -> void:
	modulate = Color(1.6, 0.6, 0.6)
	var mod_tween := create_tween()
	mod_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.25)

	var shake_tween := create_tween()
	shake_tween.tween_property(self, "position:x", base_x - 8, 0.04)
	shake_tween.tween_property(self, "position:x", base_x + 8, 0.04)
	shake_tween.tween_property(self, "position:x", base_x, 0.04)

func heal_flash() -> void:
	modulate = Color(0.6, 1.6, 0.7)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
