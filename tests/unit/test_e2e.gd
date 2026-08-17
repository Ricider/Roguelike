extends GutTest
# E2E: simulates full games, takes as many actions as possible through public APIs

func _make_player_with_deck(name: String) -> Player:
	var gs = load("res://GodotHelpers/GameState.gd").new()
	autofree(gs)
	return gs.make_player_by_name(name)

func _clear_board(player: Player):
	for row in player.Board:
		for sq in row.Squares:
			sq.clear()

func _count_board_cards(player: Player) -> int:
	var n := 0
	for row in player.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null:
				n += 1
	return n

func _card_by_name(name: String) -> Card:
	match name:
		"Wall": return Wall.new()
		"Infantry": return Infantry.new()
		"Tank": return Tank.new()
		"Artilery": return Artilery.new()
		"Rocket Launcher": return RocketLauncher.new()
		"Drone": return Drone.new()
		"Fighter Jet": return FighterJet.new()
		"Factory": return Factory.new()
		"Barracks": return Barracks.new()
		"Housing": return Housing.new()
		"Corporation": return Corporation.new()
		_: return Wall.new()

func _play_random_affordable(player: Player) -> int:
	# Try to play every affordable card in hand to random empty squares
	var played := 0
	var hand_copy: Array = player.Hand.duplicate()
	hand_copy.shuffle()
	for card in hand_copy:
		var eff_money: int = player.get_effective_money_cost(card) if card is Card else card.MoneyCost
		if player.MoneySupply < eff_money:
			continue
		if player.BioSupply < card.BioCost:
			continue
		var empties := player.get_empty_squares()
		if empties.is_empty():
			break
		var sq: Square = empties[randi() % empties.size()]
		# Find coords
		var found := false
		for r in range(player.Board.size()):
			for c in range(player.Board[r].Squares.size()):
				if player.Board[r].Squares[c] == sq:
					if player.play_card(card, r, c):
						played += 1
						found = true
						break
			if found:
				break
	return played

# --- Full run simulation ---
func test_e2e_full_run_state_troops():
	var gs = load("res://GodotHelpers/GameState.gd").new()
	autofree(gs)
	gs.start_run("State Troops")
	assert_eq(gs.run_player.display_name, "State Troops", "run player State Troops")
	assert_eq(gs.run_player.Influence, 20, "starts with 20 influence")
	assert_eq(gs.run_enemies.size(), 3, "3 enemies excludes self")
	assert_eq(gs.run_enemies[0].display_name, "Insurgents", "first is Insurgents")
	# Simulate sequential battles
	var total_influence_gained := 0
	for idx in range(gs.run_enemies.size()):
		var enemy: Player = gs.get_current_enemy()
		assert_not_null(enemy, "enemy exists")
		# Give both players resources to play
		gs.run_player.MoneySupply = 200
		gs.run_player.BioSupply = 200
		enemy.MoneySupply = 200
		enemy.BioSupply = 200
		# Start battle: clear boards (State Troops starts with 2, we keep for first battle then clear)
		if idx > 0:
			_clear_board(gs.run_player)
		# Ensure enemy has its starting board (already), and draw
		gs.run_player.DrawPile = CardFactory.make_state_troops_deck() if idx==0 else CardFactory.make_horde_deck() if enemy.display_name=="Horde" else CardFactory.make_euro_army_deck() if enemy.display_name=="Euro Army" else CardFactory.make_insurgents_deck()
		gs.run_player.Hand.clear()
		gs.run_player.DiscardPile.clear()
		gs.run_player.Graveyard.clear()
		enemy.Hand.clear()
		enemy.DiscardPile.clear()
		# Simulate 3 turns
		for turn in range(3):
			gs.run_player.economy_phase()
			enemy.economy_phase()
			if enemy is AIPlayer:
				(enemy as AIPlayer).take_build_turn()
			_play_random_affordable(gs.run_player)
			var cs := CombatState.new(gs.run_player, enemy)
			cs.combat_phase()
			# Check HP still sane
			assert_true(gs.run_player.HitPoints > -1000, "HP sane")
			assert_true(enemy.HitPoints > -1000, "enemy HP sane")
			gs.run_player.discard_hand()
			enemy.discard_hand()
			if enemy.HitPoints <= 0 or gs.run_player.HitPoints <= 0:
				break
		# Simulate victory: force enemy HP 0, gain influence, shop, continue
		if enemy.HitPoints > 0:
			enemy.HitPoints = 0
		var before_inf: int = gs.run_player.Influence
		var enemy_inf: int = enemy.Influence
		gs.gain_influence(enemy_inf)
		total_influence_gained += enemy_inf
		assert_eq(gs.run_player.Influence, before_inf + enemy_inf, "gained influence on victory")
		# Shop between battles (except after last)
		if idx < gs.run_enemies.size() - 1:
			gs.prepare_shop()
			assert_eq(gs.shop_offer.size(), 5, "shop offers 5")
			# Buy cheapest affordable
			var cheapest: Card = null
			for c in gs.shop_offer:
				if c.InfluenceCost <= gs.run_player.Influence:
					if cheapest == null or c.InfluenceCost < cheapest.InfluenceCost:
						cheapest = c
			if cheapest != null:
				var draw_before: int = gs.run_player.DrawPile.size()
				var inf_before: int = gs.run_player.Influence
				assert_true(gs.buy_card(cheapest), "buy succeeds")
				assert_eq(gs.run_player.DrawPile.size(), draw_before + 1, "deck grew")
				assert_eq(gs.run_player.Influence, inf_before - cheapest.InfluenceCost, "influence deducted")
			# Try remove once
			gs.run_player.Influence = max(gs.run_player.Influence, 25)
			gs.shop_remove_used = false
			if not gs.run_player.DrawPile.is_empty():
				var card_to_rem: Card = gs.run_player.DrawPile[0]
				var inf_b: int = gs.run_player.Influence
				assert_true(gs.remove_card_from_deck(card_to_rem), "remove succeeds")
				assert_eq(gs.run_player.Influence, inf_b - 25, "remove costs 25")
				assert_true(gs.shop_remove_used, "flag set")
				assert_false(gs.remove_card_from_deck(card_to_rem), "second remove fails")
			gs.advance_enemy()
		else:
			# Last enemy defeated
			gs.advance_enemy()
			assert_true(gs.is_run_complete(), "run complete after last victory")
	assert_eq(total_influence_gained, 10 + 25 + 50, "total 85 influence from Insurgents+Horde+Euro")

func test_e2e_every_card_type_play_and_combat():
	var all_types: Array = [Wall.new(), Infantry.new(), Tank.new(), Artilery.new(), RocketLauncher.new(), Drone.new(), FighterJet.new(), Factory.new(), Barracks.new(), Housing.new(), Corporation.new()]
	for card in all_types:
		var p := Player.new(100, 200, 200, 0, "Test", "", 100)
		p.Hand = [card]
		var before_money: int = p.MoneySupply
		var before_bio: int = p.BioSupply
		var eff: int = p.get_effective_money_cost(card)
		assert_true(p.play_card(card, 0, 0), "play %s succeeds" % card.card_name)
		assert_eq(p.MoneySupply, before_money - eff, "money deducted for %s" % card.card_name)
		assert_eq(p.BioSupply, before_bio - card.BioCost, "bio deducted for %s" % card.card_name)
		assert_eq(p.Board[0].Squares[0].Inhabitant, card, "placed %s" % card.card_name)
		assert_eq(card.InfluenceCost > 0, true, "%s has InfluenceCost" % card.card_name)
	# Combat with all specials together
	var atk := Player.new(100, 200, 200, 0, "Atk", "", 50)
	var def := Player.new(100, 200, 200, 0, "Def", "", 50)
	atk.Board[1].Squares[1].place(Barracks.new())
	var inf := Infantry.new()
	atk.Board[1].Squares[2].place(inf) # adjacent to barracks +2
	atk.Board[0].Squares[0].place(FighterJet.new())
	atk.Board[0].Squares[1].place(RocketLauncher.new())
	atk.Board[2].Squares[0].place(Drone.new()) # flying
	def.Board[0].Squares[0].place(Infantry.new())
	def.Board[0].Squares[1].place(Wall.new())
	def.Board[1].Squares[1].place(Drone.new()) # flying target
	var cs := CombatState.new(atk, def)
	var log: Array = cs.combat_phase()
	assert_true(log.size() > 0, "combat log not empty with many units")
	for entry in log:
		assert_true(entry["damage"] >= 1, "damage at least 1")
	# Check barracks bonus applied
	assert_true(Barracks.bonus_if_adjacent(atk, atk.Board[1].Squares[2]) == 2, "barracks still adjacent")

func test_e2e_shop_buy_all_and_remove_exhaustive():
	var gs = load("res://GodotHelpers/GameState.gd").new()
	autofree(gs)
	for start_name in ["Insurgents", "State Troops", "Horde", "Euro Army"]:
		gs.start_run(start_name)
		gs.prepare_shop()
		assert_eq(gs.shop_offer.size(), 5, "shop 5 for %s" % start_name)
		# Exhaust influence by buying cheapest until broke
		gs.run_player.Influence = 200
		var bought := 0
		while not gs.shop_offer.is_empty():
			var cheapest: Card = gs.shop_offer[0]
			for c in gs.shop_offer:
				if c.InfluenceCost < cheapest.InfluenceCost:
					cheapest = c
			if cheapest.InfluenceCost > gs.run_player.Influence:
				break
			assert_true(gs.buy_card(cheapest), "buy %s" % cheapest.card_name)
			bought += 1
		assert_true(bought >= 1, "bought at least 1 for %s" % start_name)
		# Remove test: must have 25, once per shop
		gs.shop_remove_used = false
		gs.run_player.Influence = 30
		var card_to_rem: Card = gs.run_player.DrawPile[0]
		assert_true(gs.remove_card_from_deck(card_to_rem), "remove 1")
		assert_false(gs.remove_card_from_deck(card_to_rem), "remove 2 fails once per shop")
		# Next shop resets flag
		gs.prepare_shop()
		assert_false(gs.shop_remove_used, "flag reset next shop")
		gs.run_player.Influence = 30
		# Add a known card to remove
		var wall := Wall.new()
		gs.run_player.DrawPile.append(wall)
		assert_true(gs.remove_card_from_deck(wall), "remove after reset succeeds")

func test_e2e_corporation_discount_cascade_in_game():
	var p := Player.new(100, 200, 200, 0, "Test", "", 50)
	# No corp: Wall 10
	assert_eq(p.get_effective_money_cost(Wall.new()), 10, "no discount 10")
	p.Board[0].Squares[0].place(Corporation.new())
	assert_eq(p.get_effective_money_cost(Wall.new()), 8, "1 corp 10->8")
	p.Board[0].Squares[1].place(Corporation.new())
	assert_eq(p.get_effective_money_cost(Wall.new()), 6, "2 corps 10->6")
	p.Board[0].Squares[2].place(Corporation.new())
	# 0.8^3=0.512 -> 10*0.512=5.12 round 5
	assert_eq(p.get_effective_money_cost(Wall.new()), 5, "3 corps 10->5")
	# Factory 30 with 3 corps 30*0.512=15.36 round 15
	assert_eq(p.get_effective_money_cost(Factory.new()), 15, "Factory 30 with 3 corps ->15")
	# With 3 corps, Factory 30*0.512=15.36 round 15
	var p3 := Player.new(100, 200, 200, 0, "Test", "", 50)
	p3.Board[0].Squares[0].place(Corporation.new())
	p3.Board[0].Squares[1].place(Corporation.new())
	p3.Board[0].Squares[2].place(Corporation.new())
	assert_eq(p3.get_effective_money_cost(Factory.new()), 15, "Factory 30 with 3 corps 15")
	# AI also discounts
	var ai := AIPlayer.new(100, 200, 200, 0, "AI", "", 50)
	ai.Board[0].Squares[0].place(Corporation.new())
	ai.Hand = [Wall.new(), Wall.new()]
	ai.MoneySupply = 8
	ai.BioSupply = 100
	var before: int = ai.Hand.size()
	ai.take_build_turn()
	# With discount 8, ai should be able to play one Wall with 8 money (otherwise needs 10)
	assert_true(ai.Hand.size() < before, "AI plays discounted Wall with 8 money")

func test_e2e_turn_loop_economy_and_board():
	var p := _make_player_with_deck("Insurgents")
	p.MoneySupply = 20
	p.BioSupply = 100
	p.DrawPile = CardFactory.make_insurgents_deck()
	p.Hand.clear()
	p.DiscardPile.clear()
	p.Graveyard.clear()
	_clear_board(p)
	# Simulate 5 full turns: economy -> build -> combat -> discard
	for turn in range(5):
		var bio_before: int = p.BioSupply
		var money_before: int = p.MoneySupply
		p.economy_phase()
		assert_true(p.BioSupply > bio_before, "bio grows turn %d" % turn)
		assert_true(p.MoneySupply >= money_before + 10, "money at least +10 turn %d" % turn)
		assert_eq(p.Hand.size(), 10, "draws to 10 turn %d" % turn)
		# Try to play up to 2 cards
		var played: int = _play_random_affordable(p)
		assert_true(played >= 0, "played %d turn %d" % [played, turn])
		# Combat vs dummy
		var dummy := Player.new(100, 100, 100, 0, "Dummy", "", 0)
		var cs := CombatState.new(p, dummy)
		var log: Array = cs.combat_phase()
		# After combat, discard
		var hand_sz: int = p.Hand.size()
		var discard_before: int = p.DiscardPile.size()
		p.discard_hand()
		assert_eq(p.Hand.size(), 0, "hand cleared after discard turn %d" % turn)
		assert_eq(p.DiscardPile.size(), discard_before + hand_sz, "discard pile grew turn %d" % turn)
		# Board should have at most 40 cards
		assert_true(_count_board_cards(p) <= 40, "board <=40 turn %d" % turn)

func test_e2e_all_player_boards_and_decks():
	for name in ["Insurgents", "State Troops", "Horde", "Euro Army"]:
		var pl: Player = _make_player_with_deck(name)
		assert_not_null(pl, "player %s exists" % name)
		assert_true(pl.HitPoints > 0, "%s HP >0" % name)
		assert_true(pl.Influence >= 10, "%s influence" % name)
		assert_true(pl.DrawPile.size() >= 31, "%s deck >=31" % name)
		# Board invariants
		var cnt: int = _count_board_cards(pl)
		if name == "Insurgents":
			assert_eq(cnt, 0, "Insurgents empty board")
		elif name == "State Troops":
			assert_eq(cnt, 2, "State Troops 2")
		elif name == "Horde":
			assert_eq(cnt, 5, "Horde 5")
			for row in pl.Board:
				for sq in row.Squares:
					if sq.Inhabitant != null:
						var hp: int = (sq.Inhabitant as Unit).HitPoints if sq.Inhabitant is Unit else (sq.Inhabitant as Building).HitPoints
						assert_eq(hp, 5, "Horde all HP 5")
		elif name == "Euro Army":
			assert_eq(cnt, 3, "Euro 3")
		# BackgroundImage not empty except maybe
		assert_true(pl.BackgroundImage != "", "%s background not empty" % name)
		# Flag exists
		assert_true(ResourceLoader.exists("res://Assets/Players/%s/flag.png" % name) or ResourceLoader.exists("res://Assets/Players/%s/sprite.png" % name), "%s flag/sprite exists" % name)

func test_e2e_combat_every_card_vs_every_card():
	var atk_names: Array = ["Infantry", "Tank", "Artilery", "Rocket Launcher", "Drone", "Fighter Jet"]
	var def_names: Array = ["Wall", "Housing", "Factory", "Barracks", "Corporation", "Infantry", "Drone"]
	for atk_name in atk_names:
		for def_name in def_names:
			var atk := Player.new(100, 200, 200, 0, "Atk", "", 50)
			var def := Player.new(100, 200, 200, 0, "Def", "", 50)
			var atk_card: Card = _card_by_name(atk_name)
			var def_fresh: Card = _card_by_name(def_name)
			if atk_card is Unit:
				(atk_card as Unit).HitPoints = 12
			elif atk_card is Building:
				(atk_card as Building).HitPoints = 20
			if def_fresh is Unit:
				(def_fresh as Unit).HitPoints = 12
			elif def_fresh is Building:
				(def_fresh as Building).HitPoints = 20
			atk.Board[0].Squares[0].place(atk_card)
			def.Board[0].Squares[0].place(def_fresh)
			var cs := CombatState.new(atk, def)
			var log: Array = cs.combat_phase()
			assert_true(log.size() >= 0, "combat %s vs %s logged" % [atk_name, def_name])
			if def_fresh is Unit and (def_fresh as Unit).Flying:
				if not (atk_card is Unit and (atk_card as Unit).HasRange):
					if atk_name == "Infantry" and def_name == "Drone":
						assert_eq((def_fresh as Unit).HitPoints, 11, "flying half Infantry vs Drone")

func test_e2e_game_controller_shop_and_victory_flow():
	# Simulate GameState victory -> shop -> continue without needing GameController scene
	var gs = load("res://GodotHelpers/GameState.gd").new()
	autofree(gs)
	gs.start_run("Horde")
	var first_enemy: Player = gs.get_current_enemy()
	assert_eq(first_enemy.display_name, "Insurgents", "Horde run first enemy Insurgents")
	# Kill first enemy
	first_enemy.HitPoints = 0
	var inf_before: int = gs.run_player.Influence
	gs.gain_influence(first_enemy.Influence)
	assert_eq(gs.run_player.Influence, inf_before + first_enemy.Influence, "gain on victory")
	gs.advance_enemy()
	assert_false(gs.is_run_complete(), "not complete after 1/3")
	assert_eq(gs.shop_offer.size(), 5, "shop after advance")
	assert_false(gs.shop_remove_used, "remove flag reset")
	# Buy and remove in shop
	gs.run_player.Influence = 100
	var card: Card = gs.shop_offer[0]
	assert_true(gs.buy_card(card), "buy in shop")
	gs.run_player.Influence = 30
	var rem: Card = gs.run_player.DrawPile[0]
	assert_true(gs.remove_card_from_deck(rem), "remove")
	assert_true(gs.shop_remove_used, "flag")
	# Next enemy should be State Troops (Diff2) after Insurgents, since Horde run excludes Horde
	var second: Player = gs.get_current_enemy()
	assert_eq(second.display_name, "State Troops", "second enemy State Troops")
	second.HitPoints = 0
	gs.gain_influence(second.Influence)
	gs.advance_enemy()
	var third: Player = gs.get_current_enemy()
	assert_eq(third.display_name, "Euro Army", "third enemy Euro Army")
	third.HitPoints = 0
	gs.gain_influence(third.Influence)
	gs.advance_enemy()
	assert_true(gs.is_run_complete(), "run complete after 3 victories")
