extends Node

# Roguelike run state per new spec: player chooser, enemy sequence, shop, influence
var selected_player_name: String = "State Troops" # chosen Player to play as
var selected_enemy: String = "Euro Army" # legacy debug enemy (now part of sequence)

var run_player: Player = null # persistent player across battles (deck+influence+HP)
var run_enemies: Array = [] # Player[] remaining enemies sorted
var run_enemy_index: int = 0
var run_started: bool = false
var shop_offer: Array = [] # Card[] 5 cards
var shop_remove_used: bool = false

func set_player(name: String):
	if name in ["Insurgents", "State Troops", "Horde", "Euro Army"]:
		selected_player_name = name

func set_enemy(name: String):
	if name in ["Euro Army", "Insurgents", "Horde", "State Troops"]:
		selected_enemy = name

func make_player_by_name(name: String, for_human: bool = false) -> Player:
	match name:
		"Insurgents":
			return CardFactory.make_insurgents_player()
		"State Troops":
			return CardFactory.make_state_troops_player(for_human)
		"Horde":
			return CardFactory.make_horde_player(for_human)
		"Euro Army":
			return CardFactory.make_euro_army_player(for_human)
		_:
			return CardFactory.make_state_troops_player(for_human)

func make_selected_enemy() -> AIPlayer:
	if selected_enemy == "Insurgents":
		return CardFactory.make_insurgents_player()
	if selected_enemy == "Horde":
		return CardFactory.make_horde_player()
	if selected_enemy == "State Troops":
		return CardFactory.make_state_troops_player() as AIPlayer
	return CardFactory.make_euro_army_player()

func background_path_for(player_name: String) -> String:
	if player_name == "Insurgents":
		return "res://Assets/Players/Insurgents/background.png"
	if player_name == "State Troops":
		return "res://Assets/Players/State Troops/background.png"
	if player_name == "Horde":
		return "res://Assets/Players/Horde/background.png"
	if player_name == "Euro Army":
		return "res://Assets/Players/Euro Army/background.png"
	return ""

func start_run(chosen_name: String):
	selected_player_name = chosen_name
	run_player = make_player_by_name(chosen_name, true)
	# deep copy? Keep reference as run_player
	run_enemies = CardFactory.enemy_sequence_for_player(chosen_name)
	run_enemy_index = 0
	run_started = true
	shop_offer.clear()
	shop_remove_used = false

func get_current_enemy() -> AIPlayer:
	if run_enemies.is_empty():
		return make_selected_enemy()
	if run_enemy_index < run_enemies.size():
		return run_enemies[run_enemy_index] as AIPlayer
	return null

func advance_enemy():
	run_enemy_index += 1
	shop_remove_used = false
	shop_offer = CardFactory.random_shop_offer()

func is_run_complete() -> bool:
	return run_enemy_index >= run_enemies.size()

func gain_influence(amount: int):
	if run_player != null:
		run_player.Influence += amount

func prepare_shop():
	shop_offer = CardFactory.random_shop_offer()
	shop_remove_used = false

func buy_card(card: Card) -> bool:
	if run_player == null or card == null:
		return false
	if run_player.Influence < card.InfluenceCost:
		return false
	if not shop_offer.has(card):
		return false
	run_player.Influence -= card.InfluenceCost
	run_player.DrawPile.append(card)
	shop_offer.erase(card)
	return true

func remove_card_from_deck(card: Card) -> bool:
	if run_player == null or card == null:
		return false
	if shop_remove_used:
		return false
	if run_player.Influence < 25:
		return false
	# Remove from any pile: DrawPile/DiscardPile/Graveyard/Hand
	var found: bool = false
	for pile in [run_player.DrawPile, run_player.DiscardPile, run_player.Graveyard, run_player.Hand]:
		if pile.has(card):
			pile.erase(card)
			found = true
			break
		# also by name if instance differs
	if not found:
		# try by card_name search first occurrence
		for pile in [run_player.DrawPile, run_player.DiscardPile, run_player.Graveyard]:
			for i in range(pile.size()):
				if pile[i].card_name == card.card_name:
					pile.remove_at(i)
					found = true
					break
			if found:
				break
	if not found:
		return false
	run_player.Influence -= 25
	shop_remove_used = true
	return true
