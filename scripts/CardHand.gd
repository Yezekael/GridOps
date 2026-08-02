extends HBoxContainer

signal card_selected(index: int)

const MAX_CARD_WIDTH := 110.0
const SEPARATION := 10.0
const WIDTH_BUDGET := 900.0

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
	var count: int = cards.size()
	var width: float = MAX_CARD_WIDTH
	if count > 0:
		# Later puzzles can deal up to 9 cards, which at full width would
		# overflow the window. Shrink cards to fit a fixed budget instead.
		width = min(MAX_CARD_WIDTH, (WIDTH_BUDGET - float(count - 1) * SEPARATION) / float(count))
	for i in cards.size():
		var btn := Button.new()
		btn.text = label_for(cards[i])
		btn.custom_minimum_size = Vector2(width, 60)
		btn.pressed.connect(_on_pressed.bind(i))
		add_child(btn)

func _on_pressed(index: int) -> void:
	card_selected.emit(index)

static func label_for(card: Dictionary) -> String:
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
