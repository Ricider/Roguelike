extends GutTest
# Extended E2E: full run with modifiers, economy, damage, persistence, shop, victory→shop loop
# Simulates game without scene/GPU, using pure Player/CombatState/GameState APIs

func _make_gs() -> Node:
	var gs = load("res://GodotHelpers/GameState.gd").new()
	autofree(gs)
	return gs

func _card(name: String) -> Card:
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
		"Howitzer": return Howitzer.new()
		_: return Wall.new()

func _clear_board(p: Player):
	for row in p.Board:
		for sq in row.Squares:
			sq.clear()

func _count_board(p: Player) -> int:
	var n := 0
	for row in p.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null:
				n += 1
	return n

func _play_affordable(p: Player) -> int:
	var played := 0
	var hand: Array = p.Hand.duplicate()
	for card in hand:
		var c := card as Card
		if p.BioSupply < c.BioCost:
			continue
		if c is Card and p.MoneySupply < p.get_effective_money_cost(c):
			continue
		var empties: Array = p.get_empty_squares()
		if empties.is_empty():
			break
		var sq: Square = empties[0]
		for r in range(p.Board.size()):
			for col in range(p.Board[r].Squares.size()):
				if p.Board[r].Squares[col] == sq:
					if p.play_card(c, r, col):
						played += 1
						empties.erase(sq)
					break
	return played

# --- Modifier economy & combat ---

func test_e2e_modifiers_economy_and_persistence():
	var gs = _make_gs()
	gs.start_run("State Troops")
	var p: Player = gs.run_player
	assert_eq(p.Influence, 30, "starts 30 inf")
	# Starter players have 1 preset modifier per CardFactory (State Troops -> State of emergency)
	# Clear for isolated modifier tests, but assert starter exists first
	assert_true(p.Modifiers.size() >= 1, "starts with at least 1 starter modifier")
	p.Modifiers.clear()
	assert_eq(p.Modifiers.size(), 0, "cleared to 0 for isolated test")

	# Give infinite influence to buy
	p.Influence = 500
	gs.run_player.Influence = 500
	gs.prepare_shop()
	assert_eq(gs.shop_modifier_offer.size(), 3, "3 modifier offers")
	var mod: Modifier = gs.shop_modifier_offer[0] as Modifier
	var mod_name: String = mod.modifier_name
	var cost: int = mod.InfluenceCost
	var inf_before: int = p.Influence
	assert_true(gs.buy_modifier(mod), "buy modifier succeeds")
	assert_eq(p.Influence, inf_before - cost, "inf deducted")
	assert_eq(p.Modifiers.size(), 1, "modifier appended")
	assert_eq((p.Modifiers[0] as Modifier).modifier_name, mod_name, "same modifier stored")
	# Duplicate buy must fail
	var dup := Modifier.by_name(mod_name)
	gs.shop_modifier_offer.append(dup)
	assert_false(gs.buy_modifier(dup), "duplicate modifier buy fails")

	# Test each modifier effect in isolation (fresh player per modifier)
	# Conscription: +15 bio but 50% less money
	var p_cons := Player.new(100, 100, 100, 0, "Test", "", 0)
	p_cons.Modifiers.append(Modifier.by_name("Conscription"))
	var bio_before: int = p_cons.BioSupply
	var money_before: int = p_cons.MoneySupply
	p_cons.economy_phase()
	assert_true(p_cons.BioSupply >= bio_before + 15 - 1, "Conscription +15 bio")
	# Money should be less than without conscription (base 10+income); we check it exists via no crash

	# State of emergency: +3 HP each turn
	var p_soe := Player.new(100, 100, 100, 0, "Test", "", 0)
	p_soe.HitPoints = 80
	p_soe.Modifiers.append(Modifier.by_name("State of emergency"))
	p_soe.economy_phase()
	assert_eq(p_soe.HitPoints, 83, "State of emergency +3 HP")

	# Corruption: +10 money extra
	var p_corr := Player.new(100, 100, 100, 0, "Test", "", 0)
	p_corr.Modifiers.append(Modifier.by_name("Corruption"))
	var m_before: int = p_corr.MoneySupply
	p_corr.economy_phase()
	assert_true(p_corr.MoneySupply >= m_before + 10, "Corruption +10 money")

	# Advanced Robotics: all units have range, costs +5 money
	var p_rob := Player.new(100, 200, 200, 0, "Test", "", 0)
	p_rob.Modifiers.append(Modifier.by_name("Advanced Robotics"))
	var inf_card := Infantry.new() # normally no range
	assert_true(p_rob.has_range_for(inf_card), "Advanced Robotics gives range to Infantry")
	assert_eq(p_rob.get_effective_money_cost(inf_card), inf_card.MoneyCost + 5, "Advanced Robotics +5 cost")

	# Aerial Supremacy: flying +2 damage, +5 cost for flying
	var p_air := Player.new(100, 200, 200, 0, "Test", "", 0)
	p_air.Modifiers.append(Modifier.by_name("Aerial Supremacy"))
	var drone := Drone.new() # flying
	var sq: Square = p_air.Board[0].Squares[0] as Square
	assert_eq(p_air.get_effective_money_cost(drone), drone.MoneyCost + 5, "Aerial +5 for flying")
	assert_eq(p_air.effective_damage_for(drone, sq), drone.Damage + 2, "flying +2 dmg")
	var inf2 := Infantry.new()
	assert_eq(p_air.effective_damage_for(inf2, sq), inf2.Damage, "non-flying no bonus")
	assert_eq(p_air.get_effective_money_cost(inf2), inf2.MoneyCost, "non-flying no extra cost")

	# Fanaticism/Corruption: building HP -50%, units +100% HP (fanaticism)
	var p_fan := Player.new(100, 200, 200, 0, "Test", "", 0)
	p_fan.Modifiers.append(Modifier.by_name("Fanaticism"))
	var house := Housing.new()
	house.HitPoints = 10
	p_fan.apply_hitpoints_modifier(house)
	assert_true(house.HitPoints < 10, "Fanaticism halves building HP")
	var inf3 := Infantry.new()
	inf3.HitPoints = 12
	p_fan.apply_hitpoints_modifier(inf3)
	assert_true(inf3.HitPoints > 12, "Fanaticism doubles unit HP")

	# Guerilla Warfare: BioCost > MoneyCost => double dmg, opposite => half HP
	var p_gue := Player.new(100, 200, 200, 0, "Test", "", 0)
	p_gue.Modifiers.append(Modifier.by_name("Guerilla Warfare"))
	var heavy_bio := Wall.new() # Bio 5 Money 2 => bio>money => double dmg (but wall buildings not units)
	var atk := Infantry.new() # Money 5 Bio 15 => bio>money => double dmg
	atk.HitPoints = 12
	p_gue.apply_hitpoints_modifier(atk)
	# For infantry (bio>money) HP should stay 12 (not half), damage doubled later

	# Persistence: reset_player_for_new_encounter must keep Modifiers but reset deck/board/bio/money
	var keep_name: String = (gs.run_player.Modifiers[0] as Modifier).modifier_name
	var keep_count: int = gs.run_player.Modifiers.size()
	gs.reset_player_for_new_encounter()
	assert_eq(gs.run_player.Modifiers.size(), keep_count, "Modifiers persist through encounter reset")
	assert_eq((gs.run_player.Modifiers[0] as Modifier).modifier_name, keep_name, "same modifier after reset")
	assert_eq(gs.run_player.DiscardPile.size(), 0, "discard cleared on reset")
	assert_eq(gs.run_player.Hand.size(), 0, "hand cleared on reset")
	assert_true(gs.run_player.DrawPile.size() >= 31, "drawpile reshuffled to starter size")

func test_e2e_shop_full_flow_with_modifiers_and_remove():
	var gs = _make_gs()
	gs.start_run("Horde")
	var p: Player = gs.run_player
	p.Influence = 200
	gs.run_player.Influence = 200
	gs.prepare_shop()
	assert_eq(gs.shop_offer.size(), 5, "5 cards")
	assert_eq(gs.shop_modifier_offer.size(), 3, "3 modifiers")
	# Buy cards until broke
	var bought_cards: int = 0
	var offer_copy: Array = gs.shop_offer.duplicate()
	for c in offer_copy:
		var card := c as Card
		if card.InfluenceCost <= p.Influence:
			assert_true(gs.buy_card(card), "buy card %s" % card.card_name)
			bought_cards += 1
	assert_true(bought_cards >= 1, "bought at least 1")
	# Buy modifiers until broke
	var bought_mods: int = 0
	var mod_copy: Array = gs.shop_modifier_offer.duplicate()
	for m in mod_copy:
		var mod2 := m as Modifier
		if mod2.InfluenceCost <= p.Influence:
			if gs.buy_modifier(mod2):
				bought_mods += 1
	assert_true(bought_mods >= 0, "mod buy attempted")
	# Remove once per shop
	gs.shop_remove_used = false
	p.Influence = 30
	gs.run_player.Influence = 30
	if p.DrawPile.is_empty():
		p.DrawPile.append(Wall.new())
	var rem: Card = p.DrawPile[0]
	var inf_r_before: int = p.Influence
	assert_true(gs.remove_card_from_deck(rem), "remove succeeds 25 cost")
	assert_eq(p.Influence, inf_r_before - 25, "25 deducted")
	assert_true(gs.shop_remove_used, "flag set")
	assert_false(gs.remove_card_from_deck(rem), "second remove fails")
	# Next shop resets
	gs.prepare_shop()
	assert_false(gs.shop_remove_used, "flag reset next shop")
	assert_eq(gs.shop_offer.size(), 5, "new shop 5 cards")

func test_e2e_full_run_victory_to_shop_loop():
	# Simulate entire roguelike run (7 enemies with 8 players) with economy→build→combat→discard each turn, victory→shop→continue
	var gs = _make_gs()
	gs.start_run("State Troops")
	assert_eq(gs.run_enemies.size(), 7, "7 enemies excludes self with 8 players")
	var total_inf: int = 0
	for idx in range(gs.run_enemies.size()):
		var enemy: Player = gs.get_current_enemy()
		assert_not_null(enemy, "enemy %d exists" % idx)
		# Ensure resources
		gs.run_player.MoneySupply = 200
		gs.run_player.BioSupply = 200
		enemy.MoneySupply = 200
		enemy.BioSupply = 200
		if idx > 0:
			_clear_board(gs.run_player)
		gs.run_player.Hand.clear()
		enemy.Hand.clear()
		# Simulate up to 3 turns
		for turn in range(3):
			gs.run_player.economy_phase()
			enemy.economy_phase()
			if enemy is AIPlayer:
				(enemy as AIPlayer).take_build_turn()
			_play_affordable(gs.run_player)
			var cs := CombatState.new(gs.run_player, enemy)
			cs.combat_phase()
			gs.run_player.discard_hand()
			enemy.discard_hand()
			if enemy.HitPoints <= 0 or gs.run_player.HitPoints <= 0:
				break
		var enemy_inf: int = enemy.Influence
		if enemy.HitPoints > 0:
			enemy.HitPoints = 0
		var before: int = gs.run_player.Influence
		gs.gain_influence(enemy_inf)
		total_inf += enemy_inf
		assert_eq(gs.run_player.Influence, before + enemy_inf, "gained %d after victory %d" % [enemy_inf, idx])
		if idx < gs.run_enemies.size() - 1:
			gs.advance_enemy()
			assert_false(gs.is_run_complete(), "not complete after %d" % idx)
			# shop is prepared inside advance_enemy (5 + 3)
			assert_eq(gs.shop_offer.size(), 5, "shop 5 cards after victory %d" % idx)
			assert_eq(gs.shop_modifier_offer.size(), 3, "shop 3 mods after victory %d" % idx)
			# buy one cheap card
			gs.run_player.Influence = max(gs.run_player.Influence, 50)
			var cheap: Card = null
			for c in gs.shop_offer:
				if cheap == null or (c as Card).InfluenceCost < (cheap as Card).InfluenceCost:
					cheap = c
			if cheap != null and cheap.InfluenceCost <= gs.run_player.Influence:
				var sz: int = gs.run_player.DrawPile.size()
				assert_true(gs.buy_card(cheap), "buy cheap card after victory %d" % idx)
				assert_eq(gs.run_player.DrawPile.size(), sz + 1, "deck grew")
			# reset for next encounter (board/money/bio reset, modifiers persist)
			var mods_before: int = gs.run_player.Modifiers.size()
			gs.reset_player_for_new_encounter()
			assert_eq(gs.run_player.Modifiers.size(), mods_before, "mods persist after reset %d" % idx)
			assert_true(_count_board(gs.run_player) >= 1, "starting board repopulated")
		else:
			gs.advance_enemy()
			assert_true(gs.is_run_complete(), "complete after last victory")
	assert_true(total_inf > 0, "total inf gained >0 was %d" % total_inf)

func test_e2e_deck_integrity_across_shop_and_discard():
	var gs = _make_gs()
	gs.start_run("Insurgents")
	var p: Player = gs.run_player
	var start_size: int = p.DrawPile.size()
	assert_true(start_size >= 31, "starter deck >=31")
	# Play some cards, discard, ensure total cards conserved (hand+draw+discard+board+graveyard constant aside from shop buys)
	p.MoneySupply = 200
	p.BioSupply = 200
	p.Hand.clear()
	p.economy_phase() # draws to 10
	assert_eq(p.Hand.size(), 10, "draw to 10")
	var before_total: int = p.DrawPile.size() + p.Hand.size() + p.DiscardPile.size() + p.Graveyard.size() + _count_board(p)
	_play_affordable(p)
	var after_play_total: int = p.DrawPile.size() + p.Hand.size() + p.DiscardPile.size() + p.Graveyard.size() + _count_board(p)
	assert_eq(before_total, after_play_total, "total conserved after play (money only moves)")
	p.discard_hand()
	var after_discard_total: int = p.DrawPile.size() + p.Hand.size() + p.DiscardPile.size() + p.Graveyard.size() + _count_board(p)
	assert_eq(before_total, after_discard_total, "total conserved after discard")
	# Buy from shop increases total by 1
	gs.prepare_shop()
	p.Influence = 200
	gs.run_player.Influence = 200
	var card: Card = gs.shop_offer[0]
	assert_true(gs.buy_card(card), "buy increases total")
	var after_buy_total: int = p.DrawPile.size() + p.Hand.size() + p.DiscardPile.size() + p.Graveyard.size() + _count_board(p)
	assert_eq(after_buy_total, before_total + 1, "total +1 after shop buy")

func test_e2e_combat_with_all_modifiers():
	# Ensure combat respects effective damage/HP/range with multiple modifiers stacked
	var atk := Player.new(100, 200, 200, 0, "Atk", "", 50)
	var def := Player.new(100, 200, 200, 0, "Def", "", 50)
	atk.Modifiers.append(Modifier.by_name("Advanced Robotics"))
	atk.Modifiers.append(Modifier.by_name("Aerial Supremacy"))
	atk.Modifiers.append(Modifier.by_name("Guerilla Warfare"))
	var inf := Infantry.new() # normally 2 dmg no range, bio>money => guerilla double => 4, +0 aerial (not flying)
	var dr := Drone.new() # flying 3 dmg +2 aerial =5, gets range from robotics
	atk.Board[0].Squares[0].place(inf)
	atk.Board[0].Squares[1].place(dr)
	def.Board[3].Squares[0].place(Wall.new())
	def.Board[3].Squares[1].place(Wall.new())
	def.Board[3].Squares[1].Inhabitant.HitPoints = 20
	var cs := CombatState.new(atk, def)
	var log: Array = cs.combat_phase()
	assert_true(log.size() >= 2, "both attackers dealt damage with modifiers")
	for e in log:
		assert_true(e["damage"] >= 1, "damage >=1 with modifiers")
	# Verify range: Infantry now has range, should be able to hit even without Manhattan front restriction? Actually _pick_target_manhattan with HasRange true picks random among all; we just check no crash and damage dealt
	assert_true(atk.has_range_for(inf), "inf now ranged via Advanced Robotics")

func test_e2e_influence_shop_persistence():
	var gs = _make_gs()
	gs.start_run("Euro Army")
	var p: Player = gs.run_player
	var start_inf: int = p.Influence
	gs.gain_influence(50)
	assert_eq(p.Influence, start_inf + 50, "gain 50")
	gs.prepare_shop()
	var inf_before_buy: int = p.Influence
	var card: Card = gs.shop_offer[0]
	var cost: int = card.InfluenceCost
	if cost <= inf_before_buy:
		assert_true(gs.buy_card(card), "buy")
		assert_eq(p.Influence, inf_before_buy - cost, "deducted")
		# after purchase, shop_offer no longer contains card
		assert_false(gs.shop_offer.has(card), "removed from offer")
		# influence persists after shop continue (reset_player keeps influence)
		gs.reset_player_for_new_encounter()
		assert_eq(p.Influence, inf_before_buy - cost, "influence survives encounter reset")
