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
	# Tutorial: Insurgents have 20 HP total only in tutorial (normal 120)
	if run_enemies.size() > 0 and run_enemies[0] != null:
		run_enemies[0].HitPoints = 20
		run_enemies[0].MaxHitPoints = 20
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
	var _owned2: Array = []
	if run_player != null:
		for mm in run_player.Modifiers:
			if mm is Modifier:
				_owned2.append((mm as Modifier).modifier_name)
	shop_modifier_offer = CardFactory.random_modifier_offer_excluding(_owned2)

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
	var owned: Array = []
	if run_player != null:
		for m in run_player.Modifiers:
			if m is Modifier:
				owned.append((m as Modifier).modifier_name)
	shop_modifier_offer = CardFactory.random_modifier_offer_excluding(owned)
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
const SAVE_PATH := "user://savegame.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir != null:
			dir.remove("savegame.json")

func save_game() -> bool:
	if run_player == null:
		return false
	var data: Dictionary = {}
	data["selected_player_name"] = selected_player_name
	data["selected_enemy"] = selected_enemy
	data["run_enemy_index"] = run_enemy_index
	data["run_started"] = run_started
	data["is_tutorial"] = is_tutorial
	data["shop_remove_used"] = shop_remove_used
	# Serialize run_player
	data["run_player"] = _serialize_player(run_player)
	# Serialize enemies
	var enemies_data: Array = []
	for e in run_enemies:
		if e is Player:
			enemies_data.append(_serialize_player(e as Player))
	data["run_enemies"] = enemies_data
	# Serialize shop offers by name
	var shop_cards: Array = []
	for c in shop_offer:
		if c is Card:
			shop_cards.append((c as Card).card_name)
	data["shop_offer"] = shop_cards
	var shop_mods: Array = []
	for m in shop_modifier_offer:
		if m is Modifier:
			shop_mods.append((m as Modifier).modifier_name)
	data["shop_modifier_offer"] = shop_mods
	var json_str: String = JSON.stringify(data)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(json_str)
	f.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var json_str: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return false
	var data: Dictionary = json.data as Dictionary
	if data == null:
		return false
	selected_player_name = data.get("selected_player_name", selected_player_name)
	selected_enemy = data.get("selected_enemy", selected_enemy)
	run_enemy_index = int(data.get("run_enemy_index", 0))
	run_started = bool(data.get("run_started", false))
	is_tutorial = bool(data.get("is_tutorial", false))
	shop_remove_used = bool(data.get("shop_remove_used", false))
	# Deserialize player
	var pd = data.get("run_player", null)
	if pd is Dictionary:
		run_player = _deserialize_player(pd as Dictionary)
	else:
		run_player = null
	# Deserialize enemies
	run_enemies.clear()
	var ed = data.get("run_enemies", [])
	if ed is Array:
		for e in ed as Array:
			if e is Dictionary:
				var pl = _deserialize_player(e as Dictionary)
				if pl != null:
					run_enemies.append(pl)
	# Deserialize shop
	shop_offer.clear()
	var sc = data.get("shop_offer", [])
	if sc is Array:
		for n in sc as Array:
			var c = _card_by_name(str(n))
			if c != null:
				shop_offer.append(c)
	shop_modifier_offer.clear()
	var sm = data.get("shop_modifier_offer", [])
	if sm is Array:
		for n in sm as Array:
			var m = Modifier.by_name(str(n))
			if m != null:
				shop_modifier_offer.append(m)
	return run_player != null

func _serialize_player(p: Player) -> Dictionary:
	var d: Dictionary = {}
	d["display_name"] = p.display_name
	d["HitPoints"] = p.HitPoints
	d["MaxHitPoints"] = p.MaxHitPoints
	d["BioSupply"] = p.BioSupply
	d["MoneySupply"] = p.MoneySupply
	d["Influence"] = p.Influence
	d["Difficulty"] = p.Difficulty
	d["BackgroundImage"] = p.BackgroundImage
	d["is_ai"] = p is AIPlayer
	# Modifiers
	var mods: Array = []
	for m in p.Modifiers:
		if m is Modifier:
			mods.append((m as Modifier).modifier_name)
	d["Modifiers"] = mods
	# Piles as card names with HP persistence
	d["DrawPile"] = _pile_to_names(p.DrawPile)
	d["DiscardPile"] = _pile_to_names(p.DiscardPile)
	d["Hand"] = _pile_to_names(p.Hand)
	d["Graveyard"] = _pile_to_names(p.Graveyard)
	# Board 4x10 stored as dicts to preserve HP
	var board: Array = []
	for r in range(p.Board.size()):
		var row: Array = []
		var row_obj = p.Board[r] as Row
		for c in range(row_obj.Squares.size()):
			var sq = row_obj.Squares[c] as Square
			if sq.Inhabitant != null and sq.Inhabitant is Card:
				var card = sq.Inhabitant as Card
				var cd: Dictionary = {"name": card.card_name}
				if card is Unit:
					cd["hp"] = (card as Unit).HitPoints
				elif card is Building:
					cd["hp"] = (card as Building).HitPoints
				row.append(cd)
			else:
				row.append(null)
		board.append(row)
	d["Board"] = board
	return d

func _deserialize_player(d: Dictionary) -> Player:
	var is_ai: bool = bool(d.get("is_ai", false))
	var _p: Player = null
	if is_ai:
		_p = AIPlayer.new(int(d.get("HitPoints", 100)), int(d.get("BioSupply", 100)), int(d.get("MoneySupply", 20)), int(d.get("Difficulty", 0)), str(d.get("display_name", "")), str(d.get("BackgroundImage", "")), int(d.get("Influence", 0)))
	else:
		_p = Player.new(int(d.get("HitPoints", 100)), int(d.get("BioSupply", 100)), int(d.get("MoneySupply", 20)), int(d.get("Difficulty", 0)), str(d.get("display_name", "")), str(d.get("BackgroundImage", "")), int(d.get("Influence", 0)))
	var p := _p
	p.MaxHitPoints = int(d.get("MaxHitPoints", p.HitPoints))
	p.HitPoints = int(d.get("HitPoints", p.HitPoints))
	# Modifiers
	p.Modifiers.clear()
	var mods = d.get("Modifiers", [])
	if mods is Array:
		for n in mods as Array:
			var m = Modifier.by_name(str(n))
			if m != null:
				p.Modifiers.append(m)
	# Piles
	p.DrawPile = _names_to_pile(d.get("DrawPile", []) as Array)
	p.DiscardPile = _names_to_pile(d.get("DiscardPile", []) as Array)
	p.Hand = _names_to_pile(d.get("Hand", []) as Array)
	p.Graveyard = _names_to_pile(d.get("Graveyard", []) as Array)
	# Board - supports both old string format and new dict with hp
	var board = d.get("Board", [])
	if board is Array:
		for r in range(min(board.size(), p.Board.size())):
			var row_data = (board as Array)[r]
			if row_data is Array:
				for c in range(min((row_data as Array).size(), (p.Board[r] as Row).Squares.size())):
					var cell = (row_data as Array)[c]
					if cell == null:
						continue
					var name: String = ""
					var hp: int = -1
					if cell is Dictionary:
						name = str((cell as Dictionary).get("name", ""))
						hp = int((cell as Dictionary).get("hp", -1))
					elif cell is String:
						name = str(cell)
					if name == "":
						continue
					var card = _card_by_name(name)
					if card != null:
						if hp >= 0:
							if card is Unit:
								(card as Unit).HitPoints = hp
							elif card is Building:
								(card as Building).HitPoints = hp
						(p.Board[r] as Row).Squares[c].place(card)
	return p

func _pile_to_names(pile: Array) -> Array:
	var out: Array = []
	for c in pile:
		if c is Card:
			out.append((c as Card).card_name)
	return out

func _names_to_pile(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var c = _card_by_name(str(n))
		if c != null:
			out.append(c)
	return out

func _card_by_name(name: String) -> Card:
	match name:
		"Infantry": return Infantry.new()
		"Special Ops": return SpecialOps.new()
		"Anti Aircraft": return AntiAircraft.new()
		"Tank": return Tank.new()
		"Wall": return Wall.new()
		"Factory": return Factory.new()
		"Housing": return Housing.new()
		"Barracks": return Barracks.new()
		"Corporation": return Corporation.new()
		"Drone": return Drone.new()
		"Interceptor": return Interceptor.new()
		"Fighter Jet": return FighterJet.new()
		"Howitzer": return Howitzer.new()
		"Artilery": return Artilery.new()
		"Rocket Launcher": return RocketLauncher.new()
		"RocketLauncher": return RocketLauncher.new()
		_: return null

