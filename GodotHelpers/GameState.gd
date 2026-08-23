extends Node

# Roguelike run state per new spec: player chooser, enemy sequence, shop, influence
var selected_player_name: String = "State Troops" # chosen Player to play as
var selected_enemy: String = "Euro Army" # legacy debug enemy (now part of sequence)

var run_player: Player = null # persistent player across battles (deck+influence+HP)
var run_enemies: Array = [] # Player[] remaining enemies sorted
var run_enemy_index: int = 0
var run_started: bool = false
var is_tutorial: bool = false
var shop_offer: Array = [] # Card[] 5 cards
var shop_modifier_offer: Array = [] # Modifier[] 3 modifiers
var shop_remove_used: bool = false

func set_player(name: String):
	if name in ["Insurgents", "State Troops", "Fundamentalists", "Mercenaries", "Peace Keepers", "Horde", "Euro Army", "Coalition Army", "Corporate Troops"]:
		selected_player_name = name

func set_enemy(name: String):
	if name in ["Euro Army", "Coalition Army", "Corporate Troops", "Insurgents", "Horde", "State Troops", "Fundamentalists", "Mercenaries", "Peace Keepers"]:
		selected_enemy = name

func make_player_by_name(name: String, for_human: bool = false) -> Player:
	match name:
		"Insurgents":
			return CardFactory.make_insurgents_player()
		"State Troops":
			return CardFactory.make_state_troops_player(for_human)
		"Fundamentalists":
			return CardFactory.make_fundamentalists_player(for_human)
		"Mercenaries":
			return CardFactory.make_mercenaries_player(for_human)
		"Peace Keepers":
			return CardFactory.make_peace_keepers_player(for_human)
		"Horde":
			return CardFactory.make_horde_player(for_human)
		"Coalition Army":
			return CardFactory.make_coalition_army_player(for_human)
		"Corporate Troops":
			return CardFactory.make_corporate_troops_player(for_human)
		"Euro Army":
			return CardFactory.make_euro_army_player(for_human)
		_:
			return CardFactory.make_state_troops_player(for_human)

func make_selected_enemy() -> AIPlayer:
	if selected_enemy == "Insurgents":
		return CardFactory.make_insurgents_player()
	if selected_enemy == "State Troops":
		return CardFactory.make_state_troops_player() as AIPlayer
	if selected_enemy == "Fundamentalists":
		return CardFactory.make_fundamentalists_player()
	if selected_enemy == "Mercenaries":
		return CardFactory.make_mercenaries_player()
	if selected_enemy == "Peace Keepers":
		return CardFactory.make_peace_keepers_player()
	if selected_enemy == "Horde":
		return CardFactory.make_horde_player()
	if selected_enemy == "Coalition Army":
		return CardFactory.make_coalition_army_player()
	if selected_enemy == "Corporate Troops":
		return CardFactory.make_corporate_troops_player()
	return CardFactory.make_euro_army_player()

func background_path_for(player_name: String) -> String:
	if player_name == "Insurgents":
		return "res://Assets/Players/Insurgents/background.png"
	if player_name == "State Troops":
		return "res://Assets/Players/State Troops/background.png"
	if player_name == "Fundamentalists":
		return "res://Assets/Players/Fundamentalists/background.png"
	if player_name == "Mercenaries":
		return "res://Assets/Players/Mercenaries/background.png"
	if player_name == "Peace Keepers":
		return "res://Assets/Players/Peace Keepers/background.png"
	if player_name == "Horde":
		return "res://Assets/Players/Horde/background.png"
	if player_name == "Coalition Army":
		return "res://Assets/Players/Coalition Army/background.png"
	if player_name == "Corporate Troops":
		return "res://Assets/Players/Corporate Troops/background.png"
	if player_name == "Euro Army":
		return "res://Assets/Players/Euro Army/background.png"
	return ""

func start_run(chosen_name: String):
	is_tutorial = false
	selected_player_name = chosen_name
	run_player = make_player_by_name(chosen_name, true)
	# deep copy? Keep reference as run_player
	run_enemies = CardFactory.enemy_sequence_for_player(chosen_name)
	run_enemy_index = 0
	run_started = true
	shop_offer.clear()
	shop_modifier_offer.clear()
	shop_remove_used = false

func start_tutorial():
	is_tutorial = true
	selected_player_name = "State Troops"
	selected_enemy = "Insurgents"
	run_player = make_player_by_name("State Troops", true)
	run_enemies = [make_player_by_name("Insurgents") as AIPlayer]
	run_enemy_index = 0
	run_started = true
	shop_offer.clear()
	shop_modifier_offer.clear()
	shop_remove_used = false
	# Tutorial deck will be set by TutorialController, keep minimal

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
	shop_modifier_offer = CardFactory.random_modifier_offer()

func reset_player_for_new_encounter():
	if run_player == null:
		return
	var template: Player = make_player_by_name(selected_player_name, true)
	# Preserve HitPoints, Influence, display_name, Difficulty, BackgroundImage, Modifiers (permanent)
	# Reset Bio/Mmoney to starting spec
	run_player.BioSupply = template.BioSupply
	run_player.MoneySupply = template.MoneySupply
	# Apply starting board HP with modifiers (Fanaticism etc.) before placing
	for r in range(template.Board.size()):
		for c in range(template.Board[r].Squares.size()):
			var card: Card = template.Board[r].Squares[c].Inhabitant
			if card != null:
				run_player.apply_hitpoints_modifier(card)
	# Reset Board: clear current and copy starting placements (Horde damaged 5, etc.)
	for row in run_player.Board:
		for sq in row.Squares:
			sq.clear()
	for r in range(template.Board.size()):
		for c in range(template.Board[r].Squares.size()):
			var card: Card = template.Board[r].Squares[c].Inhabitant
			if card != null:
				# Move the card instance from template (template will be freed, so no duplication needed)
				# Need to ensure same card type and same HP (e.g., Horde 5 HP). Directly place the instance.
				run_player.Board[r].Squares[c].place(card)
				# Clear template square so it doesn't double-free (not needed but keep clean)
				template.Board[r].Squares[c].clear()
	# Reset deck piles to starting deck (fresh shuffled) but preserve shop-bought cards so they appear next turn.
	# Duplicate array to avoid sharing reference with template
	# Count starter cards by name to detect purchased extras (e.g. extra Wall beyond starter 10)
	var starter_counts: Dictionary = {}
	for sc in template.DrawPile:
		var sn: String = (sc as Card).card_name if sc is Card else str(sc)
		starter_counts[sn] = (starter_counts.get(sn, 0) as int) + 1
	var preserved: Array = []
	var seen_extra: Dictionary = {}
	# Scan all piles that may contain shop cards bought in previous shop (Draw/Discard/Hand/Graveyard)
	for pile in [run_player.DrawPile, run_player.DiscardPile, run_player.Hand, run_player.Graveyard]:
		for c in pile:
			if c is Card:
				var cn: String = (c as Card).card_name
				var already: int = seen_extra.get(cn, 0) as int
				var allowed: int = starter_counts.get(cn, 0) as int
				# Keep only copies beyond starter counts -> those are shop purchases
				if already >= allowed:
					preserved.append(c)
				seen_extra[cn] = already + 1
	run_player.DrawPile = template.DrawPile.duplicate()
	for c in preserved:
		run_player.DrawPile.append(c)
	run_player.DrawPile.shuffle()
	run_player.DiscardPile.clear()
	run_player.Hand.clear()
	run_player.Graveyard.clear()
	# Do NOT clear Modifiers - they are permanent until game reset

func is_run_complete() -> bool:
	return run_enemy_index >= run_enemies.size()

func gain_influence(amount: int):
	if run_player != null:
		run_player.Influence += amount

func prepare_shop():
	shop_offer = CardFactory.random_shop_offer()
	shop_modifier_offer = CardFactory.random_modifier_offer()
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

func buy_modifier(mod: Modifier) -> bool:
	if run_player == null or mod == null:
		return false
	if run_player.Influence < mod.InfluenceCost:
		return false
	if not shop_modifier_offer.has(mod):
		return false
	# Prevent buying same modifier twice
	for m in run_player.Modifiers:
		if m is Modifier and (m as Modifier).modifier_name == mod.modifier_name:
			return false
	run_player.Influence -= mod.InfluenceCost
	run_player.Modifiers.append(mod)
	shop_modifier_offer.erase(mod)
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
