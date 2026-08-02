extends HBoxContainer

signal card_selected(index: int)

var cards: Array = []

func set_hand(new_cards: Array) -> void:
	cards = new_cards
	_rebuild()

func remove_card(index: int) -> void:
	cards.remove_at(index)
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	for i in cards.size():
		var btn := Button.new()
		btn.text = _label_for(cards[i])
		btn.custom_minimum_size = Vector2(110, 60)
		btn.pressed.connect(_on_pressed.bind(i))
		add_child(btn)

func _on_pressed(index: int) -> void:
	card_selected.emit(index)

func _label_for(card: Dictionary) -> String:
	match card.type:
		"invert":
			return "Invert"
		"swap":
			return "Swap"
		"mirror_row":
			return "Mirror Row"
		"mirror_col":
			return "Mirror Col"
		"rotate180":
			return "Rotate 180"
		_:
			return card.type
