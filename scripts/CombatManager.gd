extends Node

signal card_played(card_type: String)
signal turn_ended
signal combat_won
signal combat_lost

const CARD_DEFS := {
	"strike": {"cost": 1, "damage": 6},
	"block": {"cost": 1, "block": 5},
	"heal": {"cost": 2, "heal": 8},
	"double_strike": {"cost": 2, "damage": 4, "hits": 2},
	"big_strike": {"cost": 2, "damage": 12},
	"heavy_block": {"cost": 2, "block": 10},
	"vampiric_strike": {"cost": 2, "damage": 5, "heal": 3},
	"energy_potion": {"cost": 0, "energy_gain": 1},
}

const CARD_TYPES := [
	"strike", "block", "heal", "double_strike",
	"big_strike", "heavy_block", "vampiric_strike", "energy_potion",
]

const HAND_SIZE := 5
const ENERGY_PER_TURN := 3

var player_max_hp: int = 50
var player_hp: int = 50
var player_block: int = 0
var energy: int = 0

var enemy_max_hp: int = 0
var enemy_hp: int = 0
var enemy_name: String = "Enemy"
var enemy_intents: Array = []
var current_intent: Dictionary = {}

var draw_pile: Array = []
var discard_pile: Array = []
var hand: Array = []
var damage_taken_this_combat: int = 0

var rng: RandomNumberGenerator

func setup(shared_rng: RandomNumberGenerator) -> void:
	rng = shared_rng

func start_combat(deck: Array, enemy_config: Dictionary) -> void:
	draw_pile = deck.duplicate()
	_shuffle(draw_pile)
	discard_pile = []
	hand = []
	player_block = 0
	damage_taken_this_combat = 0

	enemy_max_hp = enemy_config.hp
	enemy_hp = enemy_max_hp
	enemy_name = enemy_config.get("name", "Enemy")
	enemy_intents = enemy_config.intents
	_pick_new_intent()

	start_turn()

func start_turn() -> void:
	player_block = 0
	energy = ENERGY_PER_TURN
	_draw_hand()

func _draw_hand() -> void:
	hand = []
	for i in HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			_shuffle(draw_pile)
			discard_pile = []
		hand.append(draw_pile.pop_back())

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func can_play(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	return energy >= CARD_DEFS[hand[index]].get("cost", 0)

func play_card(index: int) -> bool:
	if not can_play(index):
		return false
	var card_type: String = hand[index]
	var def: Dictionary = CARD_DEFS[card_type]
	energy -= int(def.get("cost", 0))

	for i in int(def.get("hits", 1)):
		if def.has("damage"):
			enemy_hp = max(0, enemy_hp - int(def.damage))
	if def.has("block"):
		player_block += int(def.block)
	if def.has("heal"):
		player_hp = min(player_max_hp, player_hp + int(def.heal))
	if def.has("energy_gain"):
		energy += int(def.energy_gain)

	discard_pile.append(card_type)
	hand.remove_at(index)
	card_played.emit(card_type)

	if enemy_hp <= 0:
		combat_won.emit()
	return true

func end_turn() -> void:
	discard_pile.append_array(hand)
	hand = []

	var dmg: int = int(current_intent.get("damage", 0))
	var absorbed: int = min(player_block, dmg)
	var taken: int = dmg - absorbed
	player_block -= absorbed
	player_hp = max(0, player_hp - taken)
	damage_taken_this_combat += taken

	turn_ended.emit()

	if player_hp <= 0:
		combat_lost.emit()
		return

	_pick_new_intent()
	start_turn()

func _pick_new_intent() -> void:
	current_intent = enemy_intents[rng.randi_range(0, enemy_intents.size() - 1)]

func intent_description() -> String:
	var dmg: int = int(current_intent.get("damage", 0))
	return "Attack for %d" % dmg
