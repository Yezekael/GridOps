extends Node2D

const CombatManagerScript := preload("res://scripts/CombatManager.gd")
const CardHandScript := preload("res://scripts/CardHand.gd")
const SoundManagerScript := preload("res://scripts/SoundManager.gd")
const SaveManagerScript := preload("res://scripts/SaveManager.gd")

const RUN_LENGTH := 6
const STARTING_DECK := ["strike", "strike", "strike", "block", "block"]

const UPGRADES := [
	{"id": "extra_strike", "label": "Extra Strike", "cost": 5, "card_type": "strike"},
	{"id": "extra_block", "label": "Extra Block", "cost": 5, "card_type": "block"},
	{"id": "unlock_heal", "label": "Unlock Heal", "cost": 10, "card_type": "heal"},
	{"id": "unlock_double_strike", "label": "Unlock Double Strike", "cost": 10, "card_type": "double_strike"},
	{"id": "unlock_big_strike", "label": "Unlock Big Strike", "cost": 12, "card_type": "big_strike"},
	{"id": "unlock_heavy_block", "label": "Unlock Heavy Block", "cost": 12, "card_type": "heavy_block"},
	{"id": "unlock_vampiric_strike", "label": "Unlock Vampiric Strike", "cost": 12, "card_type": "vampiric_strike"},
	{"id": "unlock_energy_potion", "label": "Unlock Energy Potion", "cost": 15, "card_type": "energy_potion"},
]

const ACHIEVEMENTS := [
	{"id": "first_win", "label": "First Win", "desc": "Complete a full run"},
	{"id": "flawless_victory", "label": "Flawless Victory", "desc": "Win a fight without taking any damage"},
	{"id": "full_deck", "label": "Full Deck", "desc": "Have all 8 card types in your deck at once"},
	{"id": "big_spender", "label": "Big Spender", "desc": "Spend 20+ currency in the shop (lifetime)"},
	{"id": "veteran", "label": "Veteran", "desc": "Play 10 runs"},
	{"id": "collector", "label": "Collector", "desc": "Permanently unlock all 8 card types via the shop"},
]

var combat: Node
var combat_view: Control
var card_hand: HBoxContainer
var end_turn_button: Button

var player_label: Label
var player_hp_bar: ProgressBar
var enemy_label: Label
var enemy_hp_bar: ProgressBar
var intent_label: Label

var status_label: Label
var energy_label: Label
var progress_label: Label
var new_run_button: Button

var draft_view: CenterContainer
var draft_label: Label
var draft_hand: HBoxContainer

var shop_view: CenterContainer
var shop_label: Label
var shop_hand: GridContainer
var shop_button: Button

var achievements_view: CenterContainer
var achievements_label: Label
var achievements_hand: GridContainer
var achievements_button: Button

var main_menu: CenterContainer
var menu_title_label: Label
var start_run_button: Button
var quit_button: Button

var view_before_overlay: String = "menu"

var run_deck: Array = []
var encounter_index: int = 0

var rng := RandomNumberGenerator.new()
var sound: Node
var save_mgr: Node
var stats_label: Label

func _ready() -> void:
	rng.randomize()

	sound = Node.new()
	sound.set_script(SoundManagerScript)
	add_child(sound)

	save_mgr = Node.new()
	save_mgr.set_script(SaveManagerScript)
	add_child(save_mgr)

	combat = Node.new()
	combat.set_script(CombatManagerScript)
	add_child(combat)
	combat.setup(rng)

	var ui := CanvasLayer.new()
	add_child(ui)

	progress_label = Label.new()
	progress_label.position = Vector2(20, 20)
	progress_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(progress_label)

	energy_label = Label.new()
	energy_label.position = Vector2(20, 55)
	energy_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(energy_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 90)
	status_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(status_label)

	combat_view = Control.new()
	combat_view.position = Vector2.ZERO
	ui.add_child(combat_view)

	player_label = Label.new()
	player_label.position = Vector2(240, 150)
	player_label.add_theme_font_size_override("font_size", 20)
	combat_view.add_child(player_label)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.position = Vector2(240, 180)
	player_hp_bar.custom_minimum_size = Vector2(320, 20)
	player_hp_bar.show_percentage = false
	combat_view.add_child(player_hp_bar)

	enemy_label = Label.new()
	enemy_label.position = Vector2(240, 230)
	enemy_label.add_theme_font_size_override("font_size", 20)
	combat_view.add_child(enemy_label)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.position = Vector2(240, 260)
	enemy_hp_bar.custom_minimum_size = Vector2(320, 20)
	enemy_hp_bar.show_percentage = false
	combat_view.add_child(enemy_hp_bar)

	intent_label = Label.new()
	intent_label.position = Vector2(240, 300)
	intent_label.add_theme_font_size_override("font_size", 18)
	intent_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	combat_view.add_child(intent_label)

	card_hand = HBoxContainer.new()
	card_hand.set_script(CardHandScript)
	card_hand.position = Vector2(20, 540)
	card_hand.add_theme_constant_override("separation", 10)
	combat_view.add_child(card_hand)
	card_hand.card_selected.connect(_on_card_selected)

	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.position = Vector2(780, 70)
	end_turn_button.custom_minimum_size = Vector2(140, 40)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	combat_view.add_child(end_turn_button)

	draft_view = CenterContainer.new()
	draft_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	draft_view.visible = false
	ui.add_child(draft_view)

	var draft_vbox := VBoxContainer.new()
	draft_vbox.add_theme_constant_override("separation", 16)
	draft_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	draft_view.add_child(draft_vbox)

	draft_label = Label.new()
	draft_label.add_theme_font_size_override("font_size", 24)
	draft_label.text = "Choose a card to add to your deck:"
	draft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	draft_vbox.add_child(draft_label)

	draft_hand = HBoxContainer.new()
	draft_hand.add_theme_constant_override("separation", 10)
	draft_hand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	draft_vbox.add_child(draft_hand)

	new_run_button = Button.new()
	new_run_button.text = "New Run"
	new_run_button.position = Vector2(780, 20)
	new_run_button.custom_minimum_size = Vector2(140, 40)
	new_run_button.pressed.connect(_start_new_run)
	ui.add_child(new_run_button)

	shop_button = Button.new()
	shop_button.text = "Shop"
	shop_button.position = Vector2(780, 120)
	shop_button.custom_minimum_size = Vector2(140, 40)
	shop_button.pressed.connect(_open_shop)
	ui.add_child(shop_button)

	achievements_button = Button.new()
	achievements_button.text = "Achievements"
	achievements_button.position = Vector2(780, 170)
	achievements_button.custom_minimum_size = Vector2(140, 40)
	achievements_button.pressed.connect(_open_achievements)
	ui.add_child(achievements_button)

	stats_label = Label.new()
	stats_label.position = Vector2(780, 220)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	ui.add_child(stats_label)
	_update_stats_label()

	shop_view = CenterContainer.new()
	shop_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_view.visible = false
	ui.add_child(shop_view)

	var shop_vbox := VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 16)
	shop_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_view.add_child(shop_vbox)

	shop_label = Label.new()
	shop_label.add_theme_font_size_override("font_size", 20)
	shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shop_vbox.add_child(shop_label)

	shop_hand = GridContainer.new()
	shop_hand.columns = 3
	shop_hand.add_theme_constant_override("h_separation", 10)
	shop_hand.add_theme_constant_override("v_separation", 10)
	shop_hand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shop_vbox.add_child(shop_hand)

	achievements_view = CenterContainer.new()
	achievements_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	achievements_view.visible = false
	ui.add_child(achievements_view)

	var achievements_vbox := VBoxContainer.new()
	achievements_vbox.add_theme_constant_override("separation", 16)
	achievements_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	achievements_view.add_child(achievements_vbox)

	achievements_label = Label.new()
	achievements_label.add_theme_font_size_override("font_size", 20)
	achievements_label.text = "Achievements"
	achievements_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievements_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	achievements_vbox.add_child(achievements_label)

	achievements_hand = GridContainer.new()
	achievements_hand.columns = 2
	achievements_hand.add_theme_constant_override("h_separation", 10)
	achievements_hand.add_theme_constant_override("v_separation", 10)
	achievements_hand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	achievements_vbox.add_child(achievements_hand)

	main_menu = CenterContainer.new()
	main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(main_menu)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 16)
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_menu.add_child(menu_vbox)

	menu_title_label = Label.new()
	menu_title_label.add_theme_font_size_override("font_size", 40)
	menu_title_label.text = "GridOps"
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_vbox.add_child(menu_title_label)

	start_run_button = Button.new()
	start_run_button.text = "Start Run"
	start_run_button.custom_minimum_size = Vector2(160, 50)
	start_run_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_run_button.pressed.connect(_start_new_run)
	menu_vbox.add_child(start_run_button)

	quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(160, 50)
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_button.pressed.connect(_on_quit_pressed)
	menu_vbox.add_child(quit_button)

	_show_main_menu()

func _hide_all_views() -> void:
	main_menu.visible = false
	combat_view.visible = false
	draft_view.visible = false
	shop_view.visible = false
	achievements_view.visible = false

func _show_main_menu() -> void:
	_hide_all_views()
	main_menu.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _start_new_run() -> void:
	main_menu.visible = false
	run_deck = STARTING_DECK.duplicate()
	for card_type in save_mgr.data.unlocked_starting_cards:
		run_deck.append(card_type)
	encounter_index = 0
	combat.player_hp = combat.player_max_hp
	draft_view.visible = false

	save_mgr.data.total_runs += 1
	save_mgr.save_data()
	_update_stats_label()
	if int(save_mgr.data.total_runs) >= 10:
		_unlock_achievement("veteran")
	_check_full_deck_achievement()

	_start_new_encounter()

func _check_full_deck_achievement() -> void:
	var distinct := {}
	for card_type in run_deck:
		distinct[card_type] = true
	if distinct.size() >= CombatManagerScript.CARD_TYPES.size():
		_unlock_achievement("full_deck")

func _update_stats_label() -> void:
	var d: Dictionary = save_mgr.data
	stats_label.text = "Best: Encounter %d/%d\nRuns: %d  Wins: %d\nCurrency: %d" % [
		d.best_encounter_reached, RUN_LENGTH, d.total_runs, d.runs_completed, int(d.currency)
	]

func _record_best_encounter_reached() -> void:
	if encounter_index + 1 > save_mgr.data.best_encounter_reached:
		save_mgr.data.best_encounter_reached = encounter_index + 1
		save_mgr.save_data()
		_update_stats_label()

func _is_boss_encounter(index: int) -> bool:
	return index == RUN_LENGTH - 1

func _enemy_config_for_encounter(index: int) -> Dictionary:
	if _is_boss_encounter(index):
		return {
			"name": "Warlord",
			"hp": 70,
			"intents": [
				{"type": "attack", "damage": 8},
				{"type": "attack", "damage": 14},
				{"type": "defend", "block": 6},
			],
			"rage_per_turn": 1,
		}

	var base_hp: int = 20 + index * 8
	var base_dmg: int = 5 + index * 2

	match index:
		0:
			return {
				"name": "Grunt",
				"hp": base_hp,
				"intents": [{"type": "attack", "damage": base_dmg}],
			}
		1:
			return {
				"name": "Skirmisher",
				"hp": base_hp,
				"intents": [
					{"type": "attack", "damage": base_dmg - 2},
					{"type": "attack", "damage": base_dmg + 6},
				],
			}
		2:
			return {
				"name": "Guardian",
				"hp": base_hp + 6,
				"intents": [
					{"type": "attack", "damage": base_dmg},
					{"type": "defend", "block": 8},
				],
			}
		3:
			return {
				"name": "Regenerator",
				"hp": base_hp,
				"intents": [
					{"type": "attack", "damage": base_dmg},
					{"type": "heal", "heal": 8},
				],
			}
		_:
			return {
				"name": "Berserker",
				"hp": base_hp,
				"intents": [{"type": "attack", "damage": base_dmg}],
				"rage_per_turn": 3,
			}

func _start_new_encounter() -> void:
	end_turn_button.disabled = false
	_hide_all_views()
	combat_view.visible = true

	var enemy_config: Dictionary = _enemy_config_for_encounter(encounter_index)
	combat.start_combat(run_deck, enemy_config)
	status_label.text = ""
	if _is_boss_encounter(encounter_index):
		progress_label.text = "Encounter %d / %d — BOSS FIGHT" % [encounter_index + 1, RUN_LENGTH]
		progress_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		progress_label.text = "Encounter %d / %d" % [encounter_index + 1, RUN_LENGTH]
		progress_label.remove_theme_color_override("font_color")
	_refresh_combat_ui()

func _refresh_combat_ui() -> void:
	player_hp_bar.max_value = combat.player_max_hp
	player_hp_bar.value = combat.player_hp
	player_label.text = "You: %d/%d HP  (Block: %d)" % [combat.player_hp, combat.player_max_hp, combat.player_block]

	enemy_hp_bar.max_value = combat.enemy_max_hp
	enemy_hp_bar.value = combat.enemy_hp
	enemy_label.text = "%s: %d/%d HP  (Block: %d)" % [combat.enemy_name, combat.enemy_hp, combat.enemy_max_hp, combat.enemy_block]

	intent_label.text = "Enemy intends: %s" % combat.intent_description()
	energy_label.text = "Energy: %d/%d" % [combat.energy, CombatManagerScript.ENERGY_PER_TURN]

	card_hand.set_hand(combat.hand)
	for i in card_hand.get_child_count():
		card_hand.set_disabled(i, not combat.can_play(i))

func _on_card_selected(index: int) -> void:
	if not combat.can_play(index):
		return
	var enemy_hp_before: int = combat.enemy_hp
	var player_hp_before: int = combat.player_hp
	if not combat.play_card(index):
		return
	sound.play_tone(440.0, 0.08)

	var dmg_dealt: int = enemy_hp_before - combat.enemy_hp
	if dmg_dealt > 0:
		_spawn_floating_text(enemy_hp_bar.position + Vector2(150, 0), "-%d" % dmg_dealt, Color(1.0, 0.35, 0.35))
		_flash_bar(enemy_hp_bar, Color(1.0, 0.4, 0.4))
	var healed: int = combat.player_hp - player_hp_before
	if healed > 0:
		_spawn_floating_text(player_hp_bar.position + Vector2(150, 0), "+%d" % healed, Color(0.4, 1.0, 0.5))
		_flash_bar(player_hp_bar, Color(0.5, 1.0, 0.6))

	_refresh_combat_ui()
	if combat.enemy_hp <= 0:
		_on_combat_won()

func _on_end_turn_pressed() -> void:
	var player_hp_before: int = combat.player_hp
	combat.end_turn()
	sound.play_tone(300.0, 0.1)

	var taken: int = player_hp_before - combat.player_hp
	if taken > 0:
		_spawn_floating_text(player_hp_bar.position + Vector2(150, 0), "-%d" % taken, Color(1.0, 0.35, 0.35))
		_flash_bar(player_hp_bar, Color(1.0, 0.4, 0.4))

	if combat.player_hp <= 0:
		_on_combat_lost()
	else:
		_refresh_combat_ui()

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	combat_view.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 30, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _flash_bar(bar: ProgressBar, color: Color) -> void:
	bar.modulate = color
	var tween := create_tween()
	tween.tween_property(bar, "modulate", Color(1.0, 1.0, 1.0), 0.3)

func _on_combat_won() -> void:
	_record_best_encounter_reached()
	save_mgr.data.currency = int(save_mgr.data.currency) + 1
	if combat.damage_taken_this_combat == 0:
		_unlock_achievement("flawless_victory")

	if encounter_index + 1 >= RUN_LENGTH:
		status_label.text = "RUN COMPLETE!"
		sound.play_chime([523.25, 659.25, 783.99, 1046.5], 0.14)
		save_mgr.data.runs_completed += 1
		save_mgr.data.currency = int(save_mgr.data.currency) + 3
		save_mgr.save_data()
		_update_stats_label()
		_unlock_achievement("first_win")
		combat_view.visible = false
	else:
		save_mgr.save_data()
		_update_stats_label()
		status_label.text = "Victory!"
		sound.play_chime([523.25, 659.25, 783.99], 0.12)
		_show_draft()

func _on_combat_lost() -> void:
	_record_best_encounter_reached()
	status_label.text = "Defeated — run failed"
	sound.play_chime([392.0, 293.66], 0.2)
	_refresh_combat_ui()
	end_turn_button.disabled = true
	for i in card_hand.get_child_count():
		card_hand.set_disabled(i, true)

func _show_draft() -> void:
	_hide_all_views()

	draft_label.text = "Choose a card to add to your deck:"

	var offered: Array = _pick_random_distinct(CombatManagerScript.CARD_TYPES, 3)
	for child in draft_hand.get_children():
		child.queue_free()
	for card_type in offered:
		var btn := Button.new()
		btn.text = CardHandScript.label_for(card_type)
		btn.custom_minimum_size = Vector2(120, 60)
		btn.pressed.connect(_on_draft_picked.bind(card_type))
		draft_hand.add_child(btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(120, 60)
	skip_btn.pressed.connect(_on_draft_skipped)
	draft_hand.add_child(skip_btn)

	if run_deck.size() > 1:
		var remove_btn := Button.new()
		remove_btn.text = "Remove a Card"
		remove_btn.custom_minimum_size = Vector2(140, 60)
		remove_btn.pressed.connect(_show_draft_removal_options)
		draft_hand.add_child(remove_btn)

	draft_view.visible = true

func _show_draft_removal_options() -> void:
	draft_label.text = "Choose a card to remove from your deck:"
	for child in draft_hand.get_children():
		child.queue_free()

	var counts: Dictionary = {}
	for card_type in run_deck:
		counts[card_type] = counts.get(card_type, 0) + 1

	for card_type in counts.keys():
		var btn := Button.new()
		btn.text = "%s (x%d)" % [CardHandScript.label_for(card_type), counts[card_type]]
		btn.custom_minimum_size = Vector2(150, 60)
		btn.pressed.connect(_on_card_removed.bind(card_type))
		draft_hand.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 60)
	back_btn.pressed.connect(_show_draft)
	draft_hand.add_child(back_btn)

func _on_card_removed(card_type: String) -> void:
	var idx: int = run_deck.find(card_type)
	if idx >= 0:
		run_deck.remove_at(idx)
	sound.play_tone(250.0, 0.1)
	_advance_after_draft()

func _on_draft_picked(card_type: String) -> void:
	sound.play_tone(600.0, 0.06)
	run_deck.append(card_type)
	_check_full_deck_achievement()
	_advance_after_draft()

func _on_draft_skipped() -> void:
	sound.play_tone(300.0, 0.06)
	_advance_after_draft()

func _advance_after_draft() -> void:
	encounter_index += 1
	draft_view.visible = false
	_start_new_encounter()

func _pick_random_distinct(pool: Array, count: int) -> Array:
	var remaining: Array = pool.duplicate()
	var picked: Array = []
	for i in range(min(count, remaining.size())):
		var idx: int = rng.randi_range(0, remaining.size() - 1)
		picked.append(remaining[idx])
		remaining.remove_at(idx)
	return picked

func _capture_view_before_overlay() -> void:
	if not shop_view.visible and not achievements_view.visible:
		view_before_overlay = "menu" if main_menu.visible else "combat"

func _open_shop() -> void:
	_capture_view_before_overlay()
	_hide_all_views()
	_rebuild_shop()
	shop_view.visible = true

func _close_shop() -> void:
	_hide_all_views()
	_restore_previous_view()

func _rebuild_shop() -> void:
	for child in shop_hand.get_children():
		child.queue_free()

	var currency: int = int(save_mgr.data.currency)
	shop_label.text = "Shop — Currency: %d (permanently added to your starting deck)" % currency

	for upgrade in UPGRADES:
		var btn := Button.new()
		btn.text = "%s (%d)" % [upgrade.label, upgrade.cost]
		btn.custom_minimum_size = Vector2(150, 50)
		btn.disabled = currency < upgrade.cost
		btn.pressed.connect(_on_upgrade_purchased.bind(upgrade))
		shop_hand.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(150, 50)
	close_btn.pressed.connect(_close_shop)
	shop_hand.add_child(close_btn)

func _on_upgrade_purchased(upgrade: Dictionary) -> void:
	var currency: int = int(save_mgr.data.currency)
	if currency < upgrade.cost:
		return
	save_mgr.data.currency = currency - upgrade.cost
	save_mgr.data.lifetime_currency_spent = int(save_mgr.data.lifetime_currency_spent) + int(upgrade.cost)
	save_mgr.data.unlocked_starting_cards.append(upgrade.card_type)
	save_mgr.save_data()
	_update_stats_label()
	sound.play_tone(700.0, 0.08)
	_rebuild_shop()

	if int(save_mgr.data.lifetime_currency_spent) >= 20:
		_unlock_achievement("big_spender")
	var unlocked_types := {}
	for card_type in save_mgr.data.unlocked_starting_cards:
		unlocked_types[card_type] = true
	if unlocked_types.size() >= CombatManagerScript.CARD_TYPES.size():
		_unlock_achievement("collector")

func _open_achievements() -> void:
	_capture_view_before_overlay()
	_hide_all_views()
	_rebuild_achievements()
	achievements_view.visible = true

func _close_achievements() -> void:
	_hide_all_views()
	_restore_previous_view()

func _restore_previous_view() -> void:
	if view_before_overlay == "menu":
		main_menu.visible = true
	else:
		combat_view.visible = true

func _rebuild_achievements() -> void:
	for child in achievements_hand.get_children():
		child.queue_free()

	var unlocked: Array = save_mgr.data.achievements
	for achievement in ACHIEVEMENTS:
		var label := Label.new()
		var mark: String = "[x]" if achievement.id in unlocked else "[ ]"
		label.text = "%s %s — %s" % [mark, achievement.label, achievement.desc]
		label.custom_minimum_size = Vector2(280, 30)
		achievements_hand.add_child(label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(150, 50)
	close_btn.pressed.connect(_close_achievements)
	achievements_hand.add_child(close_btn)

func _unlock_achievement(id: String) -> void:
	if id in save_mgr.data.achievements:
		return
	save_mgr.data.achievements.append(id)
	save_mgr.save_data()
	sound.play_chime([659.25, 880.0], 0.1)
