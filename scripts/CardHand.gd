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

func set_disabled(index: int, disabled: bool) -> void:
	if index >= 0 and index < get_child_count():
		get_child(index).disabled = disabled

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var count: int = cards.size()
	var width: float = MAX_CARD_WIDTH
	if count > 0:
		width = min(MAX_CARD_WIDTH, (WIDTH_BUDGET - float(count - 1) * SEPARATION) / float(count))
	for i in cards.size():
		var btn := Button.new()
		btn.text = label_for(cards[i])
		btn.custom_minimum_size = Vector2(width, 60)
		btn.pressed.connect(_on_pressed.bind(i))
		add_child(btn)

func _on_pressed(index: int) -> void:
	card_selected.emit(index)

static func label_for(card_type: String) -> String:
	match card_type:
		"strike":
			return "Strike\n(1) 6 dmg"
		"block":
			return "Block\n(1) 5 blk"
		"heal":
			return "Heal\n(2) +8 hp"
		"double_strike":
			return "Double Strike\n(2) 4x2 dmg"
		"big_strike":
			return "Big Strike\n(2) 12 dmg"
		"heavy_block":
			return "Heavy Block\n(2) 10 blk"
		"vampiric_strike":
			return "Vampiric\n(2) 5 dmg +3hp"
		"energy_potion":
			return "Energy Potion\n(0) +1 energy"
		_:
			return card_type
