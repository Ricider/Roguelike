extends GutTest
# GUT suite for MapWar: cards placed on world-map hexes fighting across nations.
# Synthetic territory on row 10 (x = column): A owns 10-14, B owns 15-25, C owns 26-30,
# so hex distance along the row is just |dx|.

const A := "Horde"
const B := "Coalition Army"
const C := "Insurgents"

func _plain_player(_nm: String) -> Player:
	return Player.new(100, 200, 200)

func _war() -> MapWar:
	var c := MapCampaign.new(A)
	var w := MapWar.new()
	w.setup(c, _plain_player, Player.new(100, 200, 200))
	for k in w.units.keys().duplicate():
		w._remove(k)
	var owner := {}
	for x in range(10, 15):
		owner[MapCampaign.key_of(x, 10)] = A
	for x in range(15, 26):
		owner[MapCampaign.key_of(x, 10)] = B
	for x in range(26, 31):
		owner[MapCampaign.key_of(x, 10)] = C
	c.owner = owner
	w.rng.seed = 1234
	return w

func _drop(w: MapWar, nation: String, card: Card, x: int) -> String:
	w._put(nation, card, Vector2i(x, 10))
	return MapCampaign.key_of(x, 10)

func test_hex_distance():
	assert_eq(MapWar.hex_distance(Vector2i(10, 4), Vector2i(10, 4)), 0, "same hex")
	for i in range(6):
		assert_eq(MapWar.hex_distance(Vector2i(10, 5), MapCampaign.hex_neighbor(Vector2i(10, 5), i)), 1, "neighbor %d is 1 away" % i)
	assert_eq(MapWar.hex_distance(Vector2i(0, 4), Vector2i(WorldMap.GRID_W - 1, 4)), 1, "wraps east-west")
	assert_eq(MapWar.hex_distance(Vector2i(10, 10), Vector2i(17, 10)), 7, "along a row")

func test_setup_places_starting_cards_on_own_land():
	var c := MapCampaign.new("State Troops")
	var w := MapWar.new()
	w.setup(c, func(nm): return CardFactory.make_state_troops_player(), CardFactory.make_state_troops_player(true))
	assert_eq(w.players.size(), 8, "a Player per nation")
	for k in w.units.keys():
		var info: Dictionary = w.units[k]
		var t := MapWar.key_to_hex(k)
		assert_eq(c.owner_of(t.x, t.y), str(info["owner"]), "starting card %s sits on its own land" % k)
		assert_true((w.players[info["owner"]] as Player).MapCards.has(info["card"]), "tracked in MapCards")
	assert_true(w.units.size() >= 8, "every nation starts with cards on the map")

func test_place_rules_and_cost():
	var w := _war()
	var p: Player = w.players[A]
	var tank := Tank.new()
	p.Hand = [tank]
	p.MoneySupply = 100
	p.BioSupply = 100
	assert_ne(w.can_place(A, tank, Vector2i(20, 10)), "", "cannot build on enemy land")
	# A's flag sits at the centre of its land (x=12), so build next to it
	assert_eq(w.can_place(A, tank, Vector2i(11, 10)), "", "own empty hex ok")
	assert_true(w.place(A, tank, Vector2i(11, 10)), "placed")
	assert_eq(p.MoneySupply, 100 - tank.MoneyCost, "money paid")
	assert_eq(p.BioSupply, 100 - tank.BioCost, "bio paid")
	assert_false(p.Hand.has(tank), "left the hand")
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_ne(w.can_place(A, inf, Vector2i(11, 10)), "", "occupied hex rejected")
	p.MoneySupply = 0
	assert_true(w.can_place(A, inf, Vector2i(13, 10)).contains("Money"), "shortfall explained")

func test_melee_hits_closest_enemy_card():
	var w := _war()
	var shooter := _drop(w, A, Tank.new(), 14)
	var near := _drop(w, B, Wall.new(), 16)
	var far := _drop(w, C, Wall.new(), 27)
	var log := w.fire(shooter)
	assert_eq(log.size(), 1, "one shot")
	assert_eq(log[0]["to"], MapWar.key_to_hex(near), "closest card hit")
	assert_eq(log[0]["victim"], B, "closest nation")
	assert_true(w.units.has(far), "far card untouched")

func test_ranged_hits_random_target_of_closest_nation():
	var hit_hexes := {}
	var flag_hits := 0
	for trial in range(60):
		var t := _war()
		t.rng.seed = trial
		var shooter := _drop(t, A, Artilery.new(), 14)
		_drop(t, B, Wall.new(), 16) # B is the closest nation (its flag stands at x=25)
		_drop(t, C, Wall.new(), 26) # C's card is closer than B's flag but C is not the closest nation
		var log := t.fire(shooter)
		assert_eq(log[0]["victim"], B, "ranged unit targets the closest nation")
		hit_hexes[log[0]["to"]] = true
		if log[0]["direct"]:
			flag_hits += 1
	var b_flag: Vector2i = _war().flag_sites()[B]
	assert_true(hit_hexes.has(Vector2i(16, 10)), "sometimes the card")
	assert_true(hit_hexes.has(b_flag) and flag_hits > 0, "sometimes the flag")
	assert_false(hit_hexes.has(Vector2i(26, 10)), "never another nation")

func test_kill_costs_biocost_and_is_credited():
	var w := _war()
	var shooter := _drop(w, A, Tank.new(), 14)
	var victim := Infantry.new()
	victim.HitPoints = 1
	_drop(w, B, victim, 15)
	var hp_before: int = (w.players[B] as Player).HitPoints
	var log := w.fire(shooter)
	assert_eq(log[0]["destroyed"].size(), 1, "target destroyed")
	assert_false(w.units.has(MapCampaign.key_of(15, 10)), "removed from map")
	assert_eq((w.players[B] as Player).HitPoints, hp_before - victim.BioCost, "owner pays BioCost HP")
	assert_eq(int(w.ledger[B][A]), victim.BioCost, "damage credited to attacker")
	assert_true((w.players[B] as Player).Graveyard.has(victim), "card goes to graveyard")

func test_flag_is_a_target_and_hurts_nation_hp():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(16, 10) # within a Tank's reach
	var shooter := _drop(w, A, Tank.new(), 14)
	var b_flag: Vector2i = w.flag_sites()[B]
	var log := w.fire(shooter)
	assert_true(log[0]["direct"], "flag hit")
	assert_eq(log[0]["to"], b_flag, "shot lands on B's flag hex")
	assert_eq(log[0]["victim"], B, "closest enemy flag")
	var shot: int = Tank.new().Damage + MapWar.HOME_BONUS # fired from A's own land
	assert_eq((w.players[B] as Player).HitPoints, 100 - shot, "flag damage comes off B's HP")
	assert_eq(int(w.ledger[B][A]), shot, "credited to the attacker")

func test_melee_prefers_closer_flag_over_farther_card():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(15, 10)
	var shooter := _drop(w, A, Tank.new(), 14)
	var b_flag: Vector2i = w.flag_sites()[B]
	_drop(w, C, Wall.new(), b_flag.x + 3) # a card, but farther than B's flag (still in reach)
	var log := w.fire(shooter)
	assert_eq(log[0]["to"], b_flag, "closest target is the flag")
	assert_true(log[0]["direct"], "flag, not the wall")

func test_rocket_launcher_fires_four_times():
	var w := _war()
	var shooter := _drop(w, A, RocketLauncher.new(), 14)
	var wall := Wall.new()
	wall.HitPoints = 999
	_drop(w, B, wall, 15)
	assert_eq(w.fire(shooter).size(), 4, "4 shots")

func test_collapse_cedes_border_to_top_damager():
	var w := _war()
	var bcard := _drop(w, B, Wall.new(), 15)
	for x in [20, 21, 22]:
		_drop(w, B, Infantry.new(), x) # 3 units: not weak, normal speed
	(w.players[B] as Player).HitPoints = 0
	w.ledger[B] = {A: 40, C: 10}
	(w.players[A] as Player).HitPoints = 35
	var before_a := w.campaign.tile_count(A)
	var inf_before: int = (w.players[A] as Player).Influence
	var events := w.resolve_collapses()
	assert_eq((w.players[A] as Player).Influence, inf_before + 3 * MapWar.INFLUENCE_PER_HEX, "winner earns Influence per hex taken")
	assert_eq(int(events[0]["influence"]), 3 * MapWar.INFLUENCE_PER_HEX, "event reports the Influence")
	assert_eq(events.size(), 1, "one collapse")
	assert_eq(events[0]["winner"], A, "top damager wins land")
	assert_eq(events[0]["tiles"], 3, "1 tile per 10 HP the victor has left")
	assert_false(events[0]["doubled"], "3 units: normal speed")
	assert_eq(w.campaign.tile_count(A), before_a + 3, "A grew")
	assert_eq(w.campaign.owner_of(15, 10), A, "border hex taken")
	assert_false(w.units.has(bcard), "loser's card on the lost hex is gone")
	assert_eq((w.players[B] as Player).HitPoints, (w.players[B] as Player).MaxHitPoints, "loser rebuilds")

func test_weak_nation_loses_territory_twice_as_fast():
	var w := _war()
	_drop(w, B, Infantry.new(), 20)
	_drop(w, B, Infantry.new(), 21) # only 2 units (walls/buildings don't count)
	_drop(w, B, Wall.new(), 22)
	assert_true(w.is_weak(B), "fewer than 3 units is weak")
	(w.players[B] as Player).HitPoints = 0
	w.ledger[B] = {A: 40}
	(w.players[A] as Player).HitPoints = 35
	var events := w.resolve_collapses()
	assert_true(events[0]["doubled"], "doubled")
	assert_eq(events[0]["tiles"], 6, "3 hexes x2")

func test_nation_without_units_loses_territory_four_times_as_fast():
	var w := _war()
	_drop(w, B, Wall.new(), 20) # walls and buildings are not units
	_drop(w, B, Housing.new(), 21)
	assert_eq(w.unit_count(B), 0, "no units on the map")
	assert_eq(w.loss_multiplier(B), 4, "4x")
	(w.players[B] as Player).HitPoints = 0
	w.ledger[B] = {A: 40}
	(w.players[A] as Player).HitPoints = 25 # 2 hexes normally
	var events := w.resolve_collapses()
	assert_eq(int(events[0]["multiplier"]), 4, "event reports 4x")
	assert_eq(events[0]["tiles"], 8, "2 hexes x4")

func test_loss_multiplier_steps():
	var w := _war()
	assert_eq(w.loss_multiplier(B), 4, "0 units -> 4x")
	_drop(w, B, Infantry.new(), 20)
	assert_eq(w.loss_multiplier(B), 2, "1 unit -> 2x")
	_drop(w, B, Infantry.new(), 21)
	assert_eq(w.loss_multiplier(B), 2, "2 units -> 2x")
	_drop(w, B, Tank.new(), 22)
	assert_eq(w.loss_multiplier(B), 1, "3 units -> 1x")

func test_flag_needs_its_own_hex():
	var w := _war()
	var p: Player = w.players[A]
	var flag: Vector2i = w.campaign.capital_site(A)
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_ne(w.can_place(A, inf, flag), "", "cannot build on the flag hex")
	p.Hand = [Infantry.new(), Infantry.new(), Infantry.new(), Infantry.new(), Infantry.new()]
	var placed := w.ai_build(A)
	for pl in placed:
		assert_ne(pl[1], flag, "AI never builds on its flag")

func test_fallen_flag_moves_to_free_centre():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(15, 10) # B's flag on the border hex
	for x in [22, 24, 25]:
		_drop(w, B, Infantry.new(), x)
	(w.players[B] as Player).HitPoints = 0
	w.ledger[B] = {A: 40}
	(w.players[A] as Player).HitPoints = 35 # takes 15, 16, 17
	var events := w.resolve_collapses()
	assert_true(events[0]["flag_moved"], "flag relocated")
	var site: Vector2i = w.campaign.capital_site(B)
	assert_eq(w.campaign.owner_of(site.x, site.y), B, "inside B's land")
	assert_false(w.units.has(MapCampaign.key_of(site.x, site.y)), "on a free hex")
	# B keeps 18..25: centre 21.5 -> 21 (22 holds a card)
	assert_eq(site, Vector2i(21, 10), "nearest free hex to the centre")

func test_world_starting_territories():
	var c := MapCampaign.new("Horde")
	var at := func(lat: float, lon: float) -> String:
		var h := WorldMap.hex_for_latlon(lat, lon)
		return c.owner_of(h.x, h.y)
	# (inland points: at 4 degrees per hex, coastal cities can fall on sea hexes)
	# North America (+Greenland) is Corporate Troops, South America + Australia Peace Keepers
	for spot in [Vector2(41.0, -82.0), Vector2(64.0, -150.0), Vector2(45.0, -100.0), Vector2(19.4, -99.1)]:
		assert_eq(at.call(spot.x, spot.y), "Corporate Troops", "North America at %s" % spot)
	for spot in [Vector2(-15.8, -47.9), Vector2(-34.6, -58.4), Vector2(-25.0, 134.0), Vector2(-31.0, 145.0)]:
		assert_eq(at.call(spot.x, spot.y), "Peace Keepers", "South America / Australia at %s" % spot)
	# Horde: Russia and eastern China
	for spot in [Vector2(55.8, 37.6), Vector2(55.0, 83.0), Vector2(62.0, 130.0), Vector2(39.9, 116.4), Vector2(33.0, 116.0)]:
		assert_eq(at.call(spot.x, spot.y), "Horde", "Russia / east China at %s" % spot)
	# Coalition Army: all of Europe, London included
	for spot in [Vector2(51.5, -0.1), Vector2(48.9, 2.35), Vector2(52.5, 13.4), Vector2(40.4, -3.7), Vector2(52.2, 21.0), Vector2(50.45, 30.5), Vector2(62.0, 15.0)]:
		assert_eq(at.call(spot.x, spot.y), "Coalition Army", "Europe at %s" % spot)
	# Fundamentalists: West Africa
	for spot in [Vector2(15.0, -12.0), Vector2(16.8, -3.0), Vector2(12.6, -8.0), Vector2(31.6, -7.99)]:
		assert_eq(at.call(spot.x, spot.y), "Fundamentalists", "West Africa at %s" % spot)
	# nobody starts with land on a continent that isn't theirs through the Bering bridge
	for k in c.owner.keys():
		var t := MapWar.key_to_hex(k)
		if WorldMap.region_of(t.x, t.y) == 1:
			assert_true(str(c.owner[k]) in ["Corporate Troops", "Peace Keepers"], "Americas hex %s is American" % k)

func test_conquest_erodes_border_evenly():
	# Horde (Chukotka) invades Corporate Troops' Alaska over the Bering bridge: the
	# gains must stay near the old front instead of a thin wedge into Canada.
	var c := MapCampaign.new("Horde")
	var winner := "Horde" # Siberia
	var loser := "Corporate Troops" # Alaska
	assert_true(c.neighbors_of(loser).has(winner), "they meet at the Bering bridge")
	# rings of the loser's land by distance from the pre-war front
	var ring: Dictionary = c._depth_from_front(winner, loser)
	var per_ring: Dictionary = {}
	for k in ring.keys():
		per_ring[ring[k]] = int(per_ring.get(ring[k], 0)) + 1
	var need := 0
	var minimal := 0
	while need < 15:
		minimal += 1
		need += int(per_ring.get(minimal, 0))
	var before: Array = c.tiles_of(winner)
	var moved := c.conquer(winner, loser, 150) # 15 hexes
	assert_eq(moved, 15, "15 hexes taken")
	var deepest := 0
	for t in c.tiles_of(winner):
		if not before.has(t):
			deepest = maxi(deepest, int(ring[MapCampaign.key_of(t.x, t.y)]))
	assert_eq(deepest, minimal, "front advances ring by ring: no deeper than the geography forces (%d)" % minimal)

func test_map_buildings_pay_income():
	var w := _war()
	var p: Player = w.players[A]
	var base := p.total_money_income()
	_drop(w, A, Factory.new(), 11)
	assert_eq(p.total_money_income(), base + Factory.new().Income, "factory on the map pays")
	_drop(w, A, Housing.new(), 12)
	assert_eq(Housing.count_housing(p), 1, "housing on the map counts")

func test_ai_build_places_on_own_land():
	var w := _war()
	var p: Player = w.players[B]
	p.Hand = [Infantry.new(), Housing.new(), Wall.new()]
	p.MoneySupply = 200
	p.BioSupply = 200
	var placed := w.ai_build(B)
	assert_eq(placed.size(), 3, "all affordable cards placed")
	for pl in placed:
		var t: Vector2i = pl[1]
		assert_eq(w.campaign.owner_of(t.x, t.y), B, "on own land")
	# fighters go to the front (B borders both A and C), housing to the rear
	var by_name := {}
	for pl in placed:
		by_name[(pl[0] as Card).card_name] = pl[1]
	var fd := w.frontier_distance(B)
	var inf_hex: Vector2i = by_name["Infantry"]
	var house_hex: Vector2i = by_name["Housing"]
	# infantry as close to the front as its deploy zone (2 hexes of the flag or a Housing) allows
	var best_fd := int(fd[MapCampaign.key_of(inf_hex.x, inf_hex.y)])
	for t in w.deploy_hexes(B, Infantry.new()):
		best_fd = mini(best_fd, int(fd[MapCampaign.key_of(t.x, t.y)]))
	assert_eq(int(fd[MapCampaign.key_of(inf_hex.x, inf_hex.y)]), best_fd, "infantry as near the border as it may go")
	assert_true(int(fd[MapCampaign.key_of(house_hex.x, house_hex.y)]) > 3, "housing deep in the rear")

func test_save_roundtrip():
	var w := _war()
	var t := Tank.new()
	t.HitPoints = 7
	_drop(w, A, t, 12)
	_drop(w, B, Wall.new(), 18)
	(w.players[B] as Player).HitPoints = 42
	w.turn = 5
	var d := w.to_data()
	var w2 := MapWar.from_data(d, w.campaign, _plain_player, Player.new(100, 200, 200))
	assert_eq(w2.turn, 5, "turn survives")
	assert_eq(w2.units.size(), 2, "units survive")
	assert_eq((w2.units[MapCampaign.key_of(12, 10)]["card"] as Unit).HitPoints, 7, "damage survives")
	assert_eq((w2.players[B] as Player).HitPoints, 42, "nation HP survives")

func test_gamestate_save_resume_restores_war():
	# save_game() writes the real user:// save; keep the player's own save safe
	var save_path := "user://savegame.json"
	var backup: String = FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	var had_save: bool = FileAccess.file_exists(save_path)
	var gs = load("res://GodotHelpers/GameState.gd").new()
	gs.start_map_campaign("Horde")
	var w: MapWar = gs.ensure_map_war()
	assert_eq(gs.ensure_map_war(), w, "same war while the campaign lives")
	var before: int = w.units.size()
	assert_true(before > 0, "starting cards on the map")
	(w.players["Horde"] as Player).HitPoints = 77
	w.turn = 3
	assert_true(gs.save_game(), "saved")
	var gs2 = load("res://GodotHelpers/GameState.gd").new()
	assert_true(gs2.load_game(), "loaded")
	var w2: MapWar = gs2.ensure_map_war()
	assert_eq(w2.units.size(), before, "cards restored")
	assert_eq(w2.turn, 3, "turn restored")
	assert_eq((w2.players["Horde"] as Player).HitPoints, 77, "nation HP restored")
	gs.free()
	gs2.free()
	if had_save:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func test_shop_odds_follow_starting_deck():
	var w := _war()
	w.deck_weights[A] = {"Infantry": 10, "Tank": 5}
	var n := 3000
	var inf := 0
	for i in range(n):
		var c := w.roll_shop_card(A)
		assert_true(c.card_name in ["Infantry", "Tank"], "only cards from the starting deck")
		if c.card_name == "Infantry":
			inf += 1
	var frac := float(inf) / n
	assert_almost_eq(frac, 2.0 / 3.0, 0.04, "Infantry about 2/3 of slots (got %.3f)" % frac)

func test_real_nation_shop_uses_its_own_deck():
	var c := MapCampaign.new("State Troops")
	var w := MapWar.new()
	var gs = load("res://GodotHelpers/GameState.gd").new()
	w.setup(c, func(nm): return gs.make_player_by_name(nm), gs.make_player_by_name("State Troops", true))
	var weights: Dictionary = w.deck_weights["Insurgents"]
	# odds = copies in the Insurgents' whole starting deck (piles + starting board)
	var fresh: Player = gs.make_player_by_name("Insurgents")
	var expect: Dictionary = {}
	for pile in [fresh.DrawPile, fresh.get_all_board_cards()]:
		for card in pile:
			expect[(card as Card).card_name] = int(expect.get((card as Card).card_name, 0)) + 1
	assert_eq(weights, expect, "shop odds match the starting deck")
	assert_true(int(weights.get("Drone", 0)) >= 8, "the deck's 8 Drones are counted")
	assert_false(weights.has("Fighter Jet"), "Insurgents never start with jets")
	for trial in range(20):
		w.restock_shop("Insurgents")
		for card in w.shop_of("Insurgents")["cards"]:
			assert_true(weights.has((card as Card).card_name), "%s is in the Insurgents deck" % (card as Card).card_name)
	assert_eq(w.shop_of("Insurgents")["cards"].size(), MapWar.SHOP_CARD_SLOTS, "5 card slots")
	gs.free()

func test_ai_shop_spends_without_overspending():
	var w := _war()
	var p: Player = w.players[B]
	w.deck_weights[B] = {"Infantry": 1, "Tank": 1, "Artilery": 1}
	p.Influence = 100
	w.restock_shop(B)
	var draw_before := p.DrawPile.size()
	var bought := w.ai_shop(B)
	assert_false(bought.is_empty(), "AI buys something with 100 Influence")
	assert_true(p.Influence >= 0, "never overspends")
	var cards_bought := 0
	for nm in bought:
		if not p.has_modifier(str(nm)):
			cards_bought += 1
	assert_eq(p.DrawPile.size(), draw_before + cards_bought, "bought cards join the draw pile")
	for c in w.shop_of(B)["cards"]:
		assert_true((c as Card).InfluenceCost > p.Influence, "stops only when nothing left is affordable")

func test_player_shop_buy_and_remove_rules():
	var w := _war()
	var p: Player = w.players[A]
	w.deck_weights[A] = {"Tank": 1}
	w.restock_shop(A)
	var tank: Card = w.shop_of(A)["cards"][0]
	p.Influence = tank.InfluenceCost - 1
	assert_false(w.buy_card(A, tank), "can't buy without enough Influence")
	p.Influence = 100
	assert_true(w.buy_card(A, tank), "bought")
	assert_eq(p.Influence, 100 - tank.InfluenceCost, "paid")
	assert_false(w.buy_card(A, tank), "sold item leaves the shop")
	var junk := Wall.new()
	p.DrawPile.append(junk)
	assert_true(w.remove_card(A, junk), "remove a card")
	assert_false(p.DrawPile.has(junk), "gone from the deck")
	var junk2 := Wall.new()
	p.DrawPile.append(junk2)
	assert_false(w.remove_card(A, junk2), "only one removal per turn")
	w.begin_turn(A)
	assert_true(w.remove_card(A, junk2), "restock resets the removal")

func test_shops_survive_save():
	var w := _war()
	w.deck_weights[B] = {"Drone": 3}
	w.restock_shop(B)
	(w.players[B] as Player).Influence = 77
	var d := w.to_data()
	var w2 := MapWar.from_data(d, w.campaign, _plain_player, Player.new(100, 200, 200))
	assert_eq(int(w2.deck_weights[B]["Drone"]), 3, "odds survive")
	assert_eq(w2.shop_of(B)["cards"].size(), MapWar.SHOP_CARD_SLOTS, "stock survives")
	assert_eq((w2.shop_of(B)["cards"][0] as Card).card_name, "Drone", "same stock")
	assert_eq((w2.players[B] as Player).Influence, 77, "Influence survives")

func test_predict_target_matches_what_fires():
	var w := _war()
	var shooter := _drop(w, A, Tank.new(), 14)
	_drop(w, B, Wall.new(), 16)
	_drop(w, C, Wall.new(), 27)
	var aim := w.predict_target(shooter)
	assert_eq(aim["hex"], Vector2i(16, 10), "predicts the closest target")
	assert_eq(aim["owner"], B, "of the closest nation")
	assert_eq(int(aim["distance"]), 2, "2 hexes away")
	assert_false(aim["ranged"], "Tank has no Range")
	var log := w.fire(shooter)
	assert_eq(log[0]["to"], aim["hex"], "the shot lands where the hover said")
	var arty := _drop(w, A, Artilery.new(), 13)
	assert_true(w.predict_target(arty)["ranged"], "Artillery reports ranged targeting")
	assert_true(w.predict_target(MapCampaign.key_of(16, 10)).is_empty(), "buildings don't shoot")


func test_modifiers_apply_to_cards_already_on_the_map():
	var w := _war()
	var p: Player = w.players[A]
	var inf := Infantry.new()
	var inf_k := _drop(w, A, inf, 11) # 12 HP
	inf.HitPoints = 5 # damaged: 7 HP lost
	var house := Housing.new()
	var house_k := _drop(w, A, house, 12) # 50 HP
	house.HitPoints = 3
	var dd := Modifier.new("Defensive Doctrine", "+10 HP", 0)
	w.shops[A] = {"cards": [], "mods": [dd], "remove_used": false}
	p.Influence = 100
	assert_true(w.buy_modifier(A, dd), "bought")
	assert_eq(inf.HitPoints, 15, "+10 HP right away, damage kept (5 -> 15)")
	assert_eq(int(inf.get_meta("map_max_hp")), 22, "max HP 12 -> 22")
	assert_eq(house.HitPoints, 13, "buildings too")
	var fan := Modifier.new("Fanaticism", "buildings -50% HP, units +40%", 0)
	w.shops[A] = {"cards": [], "mods": [fan], "remove_used": false}
	assert_true(w.buy_modifier(A, fan), "bought")
	assert_eq(house.HitPoints, 1, "a card pushed to 0 or below is pinned at 1")
	assert_true(w.units.has(house_k) and w.units.has(inf_k), "nobody dies from a modifier")
	assert_eq(w.last_modifier_changes.size(), 2, "both cards changed")

func test_shop_odds_stay_on_the_starting_deck():
	var c := MapCampaign.new("State Troops")
	var w := MapWar.new()
	var gs = load("res://GodotHelpers/GameState.gd").new()
	var human: Player = gs.make_player_by_name("State Troops", true)
	w.setup(c, func(nm): return gs.make_player_by_name(nm), human)
	var start: Dictionary = w.deck_weights["State Troops"].duplicate(true)
	# buying and trimming the deck leaves the odds alone
	human.Influence = 999
	for card in (w.shop_of("State Troops")["cards"] as Array).duplicate():
		w.buy_card("State Troops", card)
	for i in range(10):
		human.DrawPile.append(Drone.new())
	human.DrawPile.pop_front()
	w.restock_shop("State Troops")
	assert_eq(w.deck_weights["State Troops"], start, "odds unchanged by purchases")
	assert_false(w.deck_weights["State Troops"].has("Drone"), "no Drone odds from bought Drones")
	# an old save without stored odds rebuilds them from a fresh starting deck
	var data := w.to_data()
	data.erase("weights")
	var w2 := MapWar.from_data(data, c, func(nm): return gs.make_player_by_name(nm), human)
	assert_eq(w2.deck_weights["State Troops"], start, "old saves get starting-deck odds")
	gs.free()

func test_flag_reforms_the_moment_its_nation_falls():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(15, 10) # B's flag right on the border
	for x in [18, 24, 25]:
		_drop(w, B, Infantry.new(), x)
	(w.players[B] as Player).HitPoints = 1
	(w.players[A] as Player).HitPoints = 35
	var first := _drop(w, A, Tank.new(), 14)
	var second := _drop(w, A, Artilery.new(), 12) # reaches 8 hexes: the Infantry at 18 after the collapse
	var log := w.fire(first)
	assert_true(log[0]["direct"], "the first tank hits B's flag")
	assert_true(log[0].has("collapses"), "B collapses on that very shot")
	var ev: Dictionary = log[0]["collapses"][0]
	assert_eq(ev["loser"], B, "B fell")
	assert_eq(ev["winner"], A, "to A")
	assert_eq((w.players[B] as Player).HitPoints, (w.players[B] as Player).MaxHitPoints, "B's flag re-forms at full HP")
	var site: Vector2i = w.campaign.capital_site(B)
	assert_ne(site, Vector2i(15, 10), "on a new hex")
	assert_eq(ev["flag"], site, "the event says where")
	# the next attacker shoots at the new state, not a dead flag
	var log2 := w.fire(second)
	assert_false(log2.is_empty(), "the second gun still has a target")
	if log2[0]["direct"]:
		assert_eq(log2[0]["to"], site, "a flag shot goes to the re-formed flag")
	assert_false(log2[0].has("collapses"), "B is back at full HP: no second collapse")
	# the collapse is still reported once afterwards (log lines, Influence)
	var events := w.resolve_collapses()
	assert_eq(events.size(), 1, "reported once")
	assert_eq(w.resolve_collapses().size(), 0, "and not again")

func test_modifiers_cost_four_times_their_base_price():
	for m in Modifier.all_modifiers():
		var base: int = -1
		for b in Modifier._base_modifiers():
			if (b as Modifier).modifier_name == (m as Modifier).modifier_name:
				base = (b as Modifier).InfluenceCost
		assert_eq((m as Modifier).InfluenceCost, base * 4, "%s costs 4x" % (m as Modifier).modifier_name)
	assert_eq(Modifier.all_modifiers()[0].InfluenceCost, 140, "Conscription 35 -> 140")

func test_round_stats_split_damage_by_source():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(24, 10) # keep B's flag out of reach
	_drop(w, A, Barracks.new(), 13)
	var drone := _drop(w, A, Drone.new(), 14)
	var target := Infantry.new()
	target.HitPoints = 1
	_drop(w, B, target, 15)
	_drop(w, B, Interceptor.new(), 16)
	w.reset_round_stats()
	var log := w.fire(drone)
	assert_eq(log[0]["to"], Vector2i(15, 10), "the drone hits the infantry")
	var st: Dictionary = w.round_stats[A + "|" + B]
	var dmg: int = Drone.new().Damage + 2 + MapWar.HOME_BONUS
	assert_eq(int(st.get("barracks", 0)), 2, "Barracks +2 is credited")
	assert_eq(int(st.get("home", 0)), MapWar.HOME_BONUS, "so is the home-ground +1")
	assert_true(int(st.get("blocked_interceptor", 0)) > 0, "the Interceptor's cut is counted")
	assert_eq(int(st.get("dealt", 0)) + int(st.get("blocked_interceptor", 0)) + int(st.get("blocked_mountain", 0)) + int(st.get("blocked_forest", 0)), dmg,
		"what landed plus what was stopped adds up to the shot")
	assert_eq(int(st.get("kills", 0)), 1, "the kill is counted")
	assert_eq(int(st.get("kill_hp", 0)), Infantry.new().BioCost, "with the HP it cost B")
	assert_false(w.round_stats.has(B + "|" + A), "nothing the other way")
	w.reset_round_stats()
	assert_true(w.round_stats.is_empty(), "reset clears the round")

# --- moving units -----------------------------------------------------------------
func test_move_allowances():
	var w := _war()
	assert_eq(w.move_allowance(A, Drone.new()), MapWar.MOVE_FLYING, "flying: 6")
	assert_eq(MapWar.MOVE_FLYING, 6, "flying units: 6 hexes a turn")
	assert_eq(w.move_allowance(A, Artilery.new()), MapWar.MOVE_RANGED, "ranged: 3")
	assert_eq(MapWar.MOVE_RANGED, 3, "ranged units: 3")
	var tank := Tank.new()
	assert_true(tank.BioCost < tank.MoneyCost, "a Tank costs more money than bio")
	assert_eq(w.move_allowance(A, tank), MapWar.MOVE_CHEAP, "BioCost < MoneyCost: 4")
	assert_eq(MapWar.MOVE_CHEAP, 4, "machines: 4")
	var inf := Infantry.new()
	assert_true(inf.BioCost >= inf.MoneyCost, "Infantry costs more bio than money")
	assert_eq(w.move_allowance(A, inf), MapWar.MOVE_DEFAULT, "everything else: 5")
	assert_eq(MapWar.MOVE_DEFAULT, 5, "everything else: 5")
	assert_eq(w.move_allowance(A, Wall.new()), 0, "buildings never move")
	assert_eq(w.move_allowance(A, Barracks.new()), 0, "buildings never move")

func test_ground_units_cross_borders_within_their_moves():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	w.campaign.flag_sites[B] = Vector2i(20, 10)
	var k := _drop(w, A, Infantry.new(), 12)
	var reach := w.reachable(k)
	for x in [11, 13, 14, 15, 16, 17]:
		assert_true(reach.has(Vector2i(x, 10)), "can reach %d" % x)
	assert_eq(w.campaign.owner_of(15, 10), B, "15 is enemy land...")
	assert_false(reach.has(Vector2i(10, 10)), "not onto its own flag")
	assert_false(reach.has(Vector2i(18, 10)), "no further than its moves")
	for t in reach.keys():
		assert_true(MapCampaign.hex_distance(t, Vector2i(12, 10)) <= MapWar.MOVE_DEFAULT, "all within 5 hexes")
	var path := w.move(A, k, Vector2i(16, 10))
	assert_eq(path.size(), 5, "walked four hexes")
	var nk := MapCampaign.key_of(16, 10)
	assert_true(w.units.has(nk) and not w.units.has(k), "the card is on its new hex")
	assert_eq(w.moves_left(nk), 1, "one move left this turn")
	assert_true(w.reachable(nk).has(Vector2i(17, 10)), "one more step")
	for t in w.reachable(nk).keys():
		assert_eq(MapCampaign.hex_distance(t, Vector2i(16, 10)), 1, "only one hex more")
	assert_true(w.move(A, nk, Vector2i(14, 10)).is_empty(), "can't go further than its moves")
	assert_false(w.move(A, nk, Vector2i(17, 10)).is_empty(), "steps on into enemy land")
	assert_eq(w.campaign.owner_of(17, 10), B, "...which stays the enemy's")
	w.begin_turn(A)
	assert_eq(w.moves_left(MapCampaign.key_of(17, 10)), MapWar.MOVE_DEFAULT, "a new turn refills its moves")

func test_ground_units_cant_push_through_enemy_cards_or_onto_flags():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	w.campaign.flag_sites[B] = Vector2i(16, 10)
	var k := _drop(w, A, Infantry.new(), 14)
	_drop(w, B, Wall.new(), 15)
	var reach := w.reachable(k)
	assert_false(reach.has(Vector2i(15, 10)), "not onto an enemy card")
	assert_false(reach.has(Vector2i(16, 10)), "nor onto an enemy flag")
	for t in reach.keys():
		for step in reach[t]:
			assert_ne(step, Vector2i(15, 10), "and never through the enemy card")

func test_ground_units_sail():
	# a coastal hex of A's with open sea next to it
	var w := _war()
	var coast := Vector2i(-1, -1)
	var sea := Vector2i(-1, -1)
	for y in range(2, WorldMap.GRID_H - 2):
		for x in range(WorldMap.GRID_W):
			if not WorldMap.is_land(x, y) or WorldMap.is_void(x, y):
				continue
			for nb in MapCampaign.wrapped_neighbors(Vector2i(x, y)):
				if not WorldMap.is_land(nb.x, nb.y) and not WorldMap.is_void(nb.x, nb.y):
					coast = Vector2i(x, y)
					sea = nb
					break
			if coast.x >= 0:
				break
		if coast.x >= 0:
			break
	assert_true(coast.x >= 0, "found a coast")
	w.campaign.owner[MapCampaign.key_of(coast.x, coast.y)] = A
	w._put(A, Infantry.new(), coast)
	var k := MapCampaign.key_of(coast.x, coast.y)
	assert_true(w.reachable(k).has(sea), "a ground unit can put out to sea")
	assert_false(w.move(A, k, sea).is_empty(), "and stop there, by boat")

func test_flying_units_cross_anything_and_land_anywhere_free():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(16, 10)
	var dk := _drop(w, A, Drone.new(), 14)
	_drop(w, B, Wall.new(), 15)
	var reach := w.reachable(dk)
	assert_true(reach.has(Vector2i(18, 10)), "flies over the enemy card, onto enemy land 4 hexes away")
	assert_false(reach.has(Vector2i(16, 10)), "but not onto a flag")
	assert_false(reach.has(Vector2i(15, 10)), "nor onto a card")

# --- attack ranges ----------------------------------------------------------
func test_melee_units_reach_four_hexes():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	var tank := _drop(w, A, Tank.new(), 10)
	_drop(w, B, Wall.new(), 15) # 5 hexes away
	assert_eq(w.attack_range(A, w.units[tank]["card"]), MapWar.MELEE_RANGE, "melee range")
	assert_true(w.fire(tank).is_empty(), "nothing within 4 hexes: no shot")
	assert_true(w.predict_target(tank).is_empty(), "and the hover says so")
	w.move(A, tank, Vector2i(11, 10))
	var k := MapCampaign.key_of(11, 10)
	var log := w.fire(k)
	assert_eq(log.size(), 1, "one step closer it fires")
	assert_eq(log[0]["to"], Vector2i(15, 10), "at the Wall 4 hexes away")

func test_ranged_units_reach_eight_hexes_and_pick_only_within_reach():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	var arty := _drop(w, A, Artilery.new(), 10)
	assert_eq(w.attack_range(A, w.units[arty]["card"]), MapWar.RANGED_RANGE, "ranged range")
	var near := Wall.new()
	near.HitPoints = 999
	_drop(w, B, near, 18) # 8 hexes away
	_drop(w, B, Wall.new(), 22) # 12: out of reach
	for i in range(12):
		var log := w.fire(arty)
		assert_eq(log.size(), 1, "fires")
		assert_eq(log[0]["to"], Vector2i(18, 10), "only ever at the target within 8 hexes")
	w._remove(MapCampaign.key_of(18, 10))
	assert_true(w.fire(arty).is_empty(), "nothing within 8 hexes: no shot")

func test_ai_marches_into_range():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(14, 10)
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	var k := _drop(w, A, Tank.new(), 10)
	_drop(w, B, Wall.new(), 17) # 7 hexes: out of a Tank's reach
	var moves := w.ai_move(A)
	assert_eq(moves.size(), 1, "the tank moves")
	assert_lt(MapCampaign.hex_distance(moves[0][1], Vector2i(17, 10)), 7, "towards the enemy")

func test_units_abroad_survive_their_nations_collapse():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(20, 10)
	var home := _drop(w, B, Infantry.new(), 15) # on the border hex B will cede
	var abroad := _drop(w, B, Infantry.new(), 12) # standing on A's land
	for x in [21, 22]:
		_drop(w, B, Infantry.new(), x)
	(w.players[A] as Player).HitPoints = 30 # cedes 3 hexes
	(w.players[B] as Player).HitPoints = 0
	w.ledger[B] = {A: 50}
	var events := w.resolve_collapses()
	assert_eq(events.size(), 1, "B collapses")
	assert_eq(w.campaign.owner_of(15, 10), A, "the border hex goes to A")
	assert_false(w.units.has(home), "the card on it is lost with the land")
	assert_true(w.units.has(abroad), "the unit away from home carries on")
	assert_eq(str(w.units[abroad]["owner"]), B, "still B's")

func test_buildings_and_new_cards_stay_put():
	var w := _war()
	var wk := _drop(w, A, Wall.new(), 12)
	assert_true(w.reachable(wk).is_empty(), "a Wall can't move")
	assert_true(w.move(A, wk, Vector2i(13, 10)).is_empty(), "nor be moved")
	var p: Player = w.players[A]
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_true(w.place(A, inf, Vector2i(11, 10)), "deployed")
	assert_eq(w.moves_left(MapCampaign.key_of(11, 10)), 0, "it moves from next turn")

func test_ai_hides_behind_its_wall():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	var k := _drop(w, A, Infantry.new(), 11)
	_drop(w, A, Wall.new(), 13)
	_drop(w, B, Infantry.new(), 16)
	var moves := w.ai_move(A)
	assert_eq(moves.size(), 1, "the infantry moves")
	assert_eq(moves[0][1], Vector2i(12, 10), "to the hex behind the wall")

func test_ai_closes_on_a_wounded_enemy():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	var k := _drop(w, A, Infantry.new(), 11)
	var hurt := Infantry.new()
	hurt.set_meta("map_max_hp", hurt.HitPoints)
	hurt.HitPoints = 2
	_drop(w, B, hurt, 16)
	var moves := w.ai_move(A)
	assert_eq(moves.size(), 1, "it moves")
	assert_eq(moves[0][1], Vector2i(15, 10), "right beside the wounded enemy")

func test_corporation_discount_works_on_the_map():
	var w := _war()
	var p: Player = w.players[A]
	var tank := Tank.new()
	var full := p.get_effective_money_cost(tank)
	_drop(w, A, Corporation.new(), 12)
	assert_eq(p.get_effective_money_cost(tank), int(round(full * 0.8)), "a Corporation on the map: 20% off")
	_drop(w, A, Corporation.new(), 13)
	assert_eq(p.get_effective_money_cost(tank), int(round(full * 0.64)), "two: 36% off")

func test_every_card_explains_itself():
	for c in [Infantry.new(), Tank.new(), SpecialOps.new(), AntiAircraft.new(), Drone.new(), Artilery.new(), Howitzer.new(),
			RocketLauncher.new(), FighterJet.new(), Wall.new(), Barracks.new(), Factory.new(), Housing.new(), Corporation.new(), Interceptor.new()]:
		assert_true((c as Card).SpecialEffect.length() > 30, "%s has a real description" % (c as Card).card_name)

# --- bulk moves and range helpers ----------------------------------------------
func test_group_marches_towards_a_hex_and_fans_out():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	var keys: Array = [_drop(w, A, Infantry.new(), 11), _drop(w, A, Infantry.new(), 12), _drop(w, A, Tank.new(), 13)]
	var goal := Vector2i(17, 10)
	var moves := w.move_group(A, keys, goal)
	assert_eq(moves.size(), 3, "all three move")
	var ends := {}
	for mv in moves:
		var to: Vector2i = mv[1]
		assert_false(ends.has(to), "no two end on the same hex")
		ends[to] = true
		assert_lt(MapCampaign.hex_distance(to, goal), MapCampaign.hex_distance(MapWar.key_to_hex(mv[0]), goal), "each got closer")
		assert_true(w.units.has(MapCampaign.key_of(to.x, to.y)), "and is really there")
	# the Tank (2 moves, nearest) takes the spot 2 hexes on; the Infantry fan out round it
	assert_true(w.units.has(MapCampaign.key_of(15, 10)), "the nearest unit leads")

func test_group_units_that_cant_get_closer_stay_put():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	var k := _drop(w, A, Infantry.new(), 12)
	var tired := _drop(w, A, Infantry.new(), 13)
	(w.units[tired]["card"] as Card).set_meta("moves_left", 0)
	var moves := w.move_group(A, [k, tired, "nope"], Vector2i(12, 10))
	assert_true(moves.is_empty(), "the one on the goal stays, the tired one can't move, the bad key is ignored")
	assert_true(w.units.has(k) and w.units.has(tired), "nobody moved")

func test_plan_group_previews_without_moving():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	var keys: Array = [_drop(w, A, Infantry.new(), 11), _drop(w, A, Tank.new(), 12)]
	var before := w.units.keys()
	before.sort()
	var plan := w.plan_group(A, keys, Vector2i(18, 10))
	assert_eq(plan.size(), 2, "both would move")
	var after := w.units.keys()
	after.sort()
	assert_eq(after, before, "nothing actually moved")
	for k in keys:
		assert_false((w.units[k]["card"] as Card).has_meta("moves_left"), "moves left untouched")
	var real := w.move_group(A, keys, Vector2i(18, 10))
	assert_eq(real.map(func(mv): return mv[1]), plan.map(func(mv): return mv[1]), "the preview matches the real move")

func test_hexes_within_and_targets_in_range():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(16, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	var zone := w.hexes_within(Vector2i(12, 10), 4)
	assert_eq(zone.size(), 61, "a radius-4 hexagon: 61 hexes")
	for t in zone:
		assert_true(MapCampaign.hex_distance(t, Vector2i(12, 10)) <= 4, "all within 4")
	_drop(w, B, Wall.new(), 15)
	_drop(w, B, Wall.new(), 20)
	_drop(w, A, Wall.new(), 13)
	var tg := w.targets_in_range(A, Vector2i(12, 10), 4)
	assert_true(tg.has(Vector2i(15, 10)), "the enemy wall 3 hexes away")
	assert_true(tg.has(Vector2i(16, 10)), "and B's flag 4 away")
	assert_false(tg.has(Vector2i(20, 10)), "not the wall 8 away")
	assert_false(tg.has(Vector2i(13, 10)), "nor its own cards")

# --- deploy zones ----------------------------------------------------------------
func _zone_war() -> MapWar:
	# A owns the whole of row 10 from 0 to 24, flag at 0: far hexes need a building
	var w := _war()
	for x in range(0, 25):
		w.campaign.owner[MapCampaign.key_of(x, 10)] = A
	w.campaign.flag_sites[A] = Vector2i(0, 10)
	var p: Player = w.players[A]
	p.MoneySupply = 500
	p.BioSupply = 500
	return w

func test_deploy_anchors_by_cost_and_flight():
	assert_eq(MapWar.deploy_anchors(Infantry.new()), ["Housing"], "people: near Housing")
	assert_eq(MapWar.deploy_anchors(SpecialOps.new()), ["Housing"], "Special Ops are people too")
	assert_eq(MapWar.deploy_anchors(Tank.new()), ["Factory", "Barracks"], "ground machines: Factory or Barracks")
	assert_eq(MapWar.deploy_anchors(Artilery.new()), ["Factory", "Barracks"], "guns too")
	assert_eq(MapWar.deploy_anchors(Drone.new()), ["Corporation", "Factory"], "flying machines: Corporation or Factory")
	assert_eq(MapWar.deploy_anchors(FighterJet.new()), ["Corporation", "Factory"], "jets too")
	assert_eq(MapWar.deploy_anchors(Wall.new()), [], "buildings go anywhere")

func test_units_deploy_only_near_the_flag_or_their_buildings():
	var w := _zone_war()
	var p: Player = w.players[A]
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_eq(w.can_place(A, inf, Vector2i(2, 10)), "", "2 hexes from the flag: fine")
	assert_string_contains(w.can_place(A, inf, Vector2i(3, 10)), "within 2 hexes of your flag or a Housing", "3 is too far")
	w._put(A, Factory.new(), Vector2i(12, 10))
	assert_ne(w.can_place(A, inf, Vector2i(14, 10)), "", "a Factory doesn't raise Infantry")
	w._put(A, Housing.new(), Vector2i(18, 10))
	assert_eq(w.can_place(A, inf, Vector2i(20, 10)), "", "near a Housing it does")
	assert_ne(w.can_place(A, inf, Vector2i(21, 10)), "", "but only 2 hexes out")
	var tank := Tank.new()
	p.Hand = [tank]
	assert_eq(w.can_place(A, tank, Vector2i(14, 10)), "", "Tanks roll out near the Factory")
	assert_ne(w.can_place(A, tank, Vector2i(19, 10)), "", "not near Housing")
	var jet := FighterJet.new()
	p.Hand = [jet]
	assert_eq(w.can_place(A, jet, Vector2i(11, 10)), "", "a jet near the Factory")
	w._put(A, Barracks.new(), Vector2i(24, 10))
	assert_ne(w.can_place(A, jet, Vector2i(22, 10)), "", "but not near a Barracks")
	p.Hand = [tank]
	assert_eq(w.can_place(A, tank, Vector2i(22, 10)), "", "where a Tank may go")
	var wall := Wall.new()
	p.Hand = [wall]
	assert_eq(w.can_place(A, wall, Vector2i(9, 10)), "", "buildings: anywhere on your land")

func test_a_destroyed_building_no_longer_raises_units():
	var w := _zone_war()
	var p: Player = w.players[A]
	var h := Housing.new()
	w._put(A, h, Vector2i(15, 10))
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_eq(w.can_place(A, inf, Vector2i(17, 10)), "", "near the Housing")
	h.HitPoints = 0
	assert_ne(w.can_place(A, inf, Vector2i(17, 10)), "", "not once it has fallen")

func test_ai_and_deploy_hexes_respect_the_zones():
	var w := _zone_war()
	var hexes := w.deploy_hexes(A, Tank.new())
	assert_false(hexes.is_empty(), "somewhere near the flag")
	for t in hexes:
		assert_true(MapCampaign.hex_distance(t, Vector2i(0, 10)) <= MapWar.DEPLOY_RADIUS, "all within 2 of the flag")
	var p: Player = w.players[A]
	p.Hand = [Tank.new(), Infantry.new(), Wall.new()]
	var placed := w.ai_build(A)
	assert_eq(placed.size(), 3, "the AI deploys them all")
	for pl in placed:
		if pl[0] is Unit:
			assert_true(MapCampaign.hex_distance(pl[1], Vector2i(0, 10)) <= MapWar.DEPLOY_RADIUS, "%s in its zone" % (pl[0] as Card).card_name)

# --- home ground ------------------------------------------------------------------
func test_units_deal_one_more_damage_on_home_ground():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	var p: Player = w.players[A]
	var tank := Tank.new()
	assert_eq(w.effective_damage(A, tank, Vector2i(12, 10)), tank.Damage + 1, "on A's own land: +1")
	assert_eq(w.effective_damage(A, tank, Vector2i(17, 10)), tank.Damage, "on B's land: no bonus")
	assert_eq(w.effective_damage(A, tank, Vector2i(12, 2)), tank.Damage, "on land nobody holds (or sea): no bonus")
	# and it is what lands: a wall on B's side, shot from home and then from abroad
	var wall := Wall.new()
	wall.HitPoints = 999
	_drop(w, B, wall, 16)
	var home := _drop(w, A, Tank.new(), 14)
	var hp0 := wall.HitPoints
	w.fire(home)
	assert_eq(hp0 - wall.HitPoints, tank.Damage + 1, "from home: +1")
	w.move(A, home, Vector2i(15, 10)) # across the border
	var away := MapCampaign.key_of(15, 10)
	var hp1 := wall.HitPoints
	w.fire(away)
	assert_eq(hp1 - wall.HitPoints, tank.Damage, "from B's land: plain damage")

# --- flanking ---------------------------------------------------------------------
# B's unit on (20, 10), an even row: neighbours E (21,10) SE (20,11) SW (19,11) W (19,10) NW (19,9) NE (20,9)
const RING := [Vector2i(21, 10), Vector2i(20, 11), Vector2i(19, 11), Vector2i(19, 10), Vector2i(19, 9), Vector2i(20, 9)]

func _flank_war(enemy_at: Array, card_maker: Callable = func(): return Infantry.new()) -> MapWar:
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	var target := Infantry.new()
	target.HitPoints = 999
	w._put(B, target, Vector2i(20, 10))
	for i in enemy_at:
		w._put(A, card_maker.call(), RING[i])
	return w

func test_flank_tiers():
	var k := MapCampaign.key_of(20, 10)
	assert_eq(_flank_war([]).flank_bonus(k), 0, "alone: nothing")
	assert_eq(_flank_war([0]).flank_bonus(k), 0, "one enemy: nothing")
	assert_eq(_flank_war([0, 1]).flank_bonus(k), 0, "two side by side: not a flank")
	for pair in [[0, 3], [1, 4], [2, 5]]:
		assert_eq(_flank_war(pair).flank_bonus(k), MapWar.FLANK_FLANKED, "opposite sides %s: flanked +1" % str(pair))
	assert_eq(_flank_war([0, 1, 2]).flank_bonus(k), 0, "three on one side: still no pincer")
	assert_eq(_flank_war([0, 1, 3, 4]).flank_bonus(k), MapWar.FLANK_SURROUNDED, "four: surrounded +2")
	assert_eq(_flank_war([0, 1, 2, 3, 4]).flank_bonus(k), MapWar.FLANK_SURROUNDED, "five: still +2")
	assert_eq(_flank_war([0, 1, 2, 3, 4, 5]).flank_bonus(k), MapWar.FLANK_ENCIRCLED, "all six: encircled +4")

func test_only_living_enemy_units_flank():
	var k := MapCampaign.key_of(20, 10)
	assert_eq(_flank_war([0, 3], func(): return Wall.new()).flank_bonus(k), 0, "buildings don't flank")
	var w := _flank_war([0])
	w._put(B, Infantry.new(), RING[3])
	assert_eq(w.flank_bonus(k), 0, "a friend on the other side doesn't")
	var w2 := _flank_war([0, 3])
	(w2.units[MapCampaign.key_of(19, 10)]["card"] as Unit).HitPoints = 0
	assert_eq(w2.flank_bonus(k), 0, "nor does a dead one")
	var w3 := _flank_war([0])
	w3._put(C, Infantry.new(), RING[3])
	assert_eq(w3.flank_bonus(k), MapWar.FLANK_FLANKED, "two different enemy nations still pin it")
	var w4 := _flank_war([0, 1, 2, 3, 4, 5])
	w4._put(B, Wall.new(), Vector2i(22, 10))
	assert_eq(w4.flank_bonus(MapCampaign.key_of(22, 10)), 0, "buildings never take the penalty")

func test_flanked_units_take_more_per_hit():
	var w := _flank_war([0, 3]) # A's Infantry east and west of it, both on B's land (no home bonus)
	var target: Unit = w.units[MapCampaign.key_of(20, 10)]["card"]
	var hp0 := target.HitPoints
	w.reset_round_stats()
	var log := w.fire(MapCampaign.key_of(19, 10))
	assert_eq(log[0]["to"], Vector2i(20, 10), "the flanker shoots it")
	assert_eq(hp0 - target.HitPoints, Infantry.new().Damage + MapWar.FLANK_FLANKED, "+1 for the flank")
	assert_eq(int(log[0]["flank"]), MapWar.FLANK_FLANKED, "the shot says so")
	assert_eq(int(w.round_stats[A + "|" + B].get("flank", 0)), MapWar.FLANK_FLANKED, "and the round report counts it")
	var w6 := _flank_war([0, 1, 2, 3, 4, 5])
	var t6: Unit = w6.units[MapCampaign.key_of(20, 10)]["card"]
	var h6 := t6.HitPoints
	w6.fire(MapCampaign.key_of(19, 10))
	assert_eq(h6 - t6.HitPoints, Infantry.new().Damage + MapWar.FLANK_ENCIRCLED, "+4 encircled")

func test_ai_avoids_walking_into_a_pincer():
	var w := _war()
	w.campaign.flag_sites[A] = Vector2i(10, 10)
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	# B units at 16 and 18: hex 17 between them is a pincer; 15 is just as close to them
	_drop(w, B, Wall.new(), 16)
	_drop(w, B, Infantry.new(), 18)
	assert_eq(w.flank_at(A, Vector2i(17, 10)), 0, "a Wall doesn't make a pincer")
	w._remove(MapCampaign.key_of(16, 10))
	_drop(w, B, Infantry.new(), 16)
	assert_eq(w.flank_at(A, Vector2i(17, 10)), MapWar.FLANK_FLANKED, "two Infantry do")
	var k := _drop(w, A, Infantry.new(), 14)
	for mv in w.ai_move(A):
		assert_ne(mv[1], Vector2i(17, 10), "the AI doesn't step in between")

# --- boats ------------------------------------------------------------------------
# a coastal hex of A's (land) with a run of open sea next to it
func _coast(w: MapWar) -> Array:
	for y in range(2, WorldMap.GRID_H - 2):
		for x in range(WorldMap.GRID_W):
			if not WorldMap.is_land(x, y) or WorldMap.is_void(x, y):
				continue
			for nb in MapCampaign.wrapped_neighbors(Vector2i(x, y)):
				if WorldMap.is_land(nb.x, nb.y) or WorldMap.is_void(nb.x, nb.y):
					continue
				# and sea beyond it too
				for nb2 in MapCampaign.wrapped_neighbors(nb):
					if nb2 != Vector2i(x, y) and not WorldMap.is_land(nb2.x, nb2.y) and not WorldMap.is_void(nb2.x, nb2.y) \
							and MapCampaign.hex_distance(nb2, Vector2i(x, y)) == 2:
						w.campaign.owner[MapCampaign.key_of(x, y)] = A
						return [Vector2i(x, y), nb, nb2]
	return []

func test_boarding_costs_an_extra_move_and_sailing_is_slower():
	var w := _war()
	var c := _coast(w)
	assert_false(c.is_empty(), "found a coast")
	w._put(A, Infantry.new(), c[0])
	var k := MapCampaign.key_of(c[0].x, c[0].y)
	var reach := w.reachable(k)
	assert_true(reach.has(c[1]), "an Infantry boards (2 of its 5 moves)")
	assert_true(reach.has(c[2]), "and sails one hex more")
	assert_eq(w.path_cost(k, reach[c[2]]), 3, "board 2 + sail 1")
	w.move(A, k, c[1])
	var sk := MapCampaign.key_of(c[1].x, c[1].y)
	assert_eq(w.moves_left(sk), MapWar.MOVE_DEFAULT - 2, "boarding took 2 moves")
	w.begin_turn(A)
	assert_eq(w.moves_left(sk), MapWar.MOVE_DEFAULT - MapWar.SEA_PENALTY, "a turn at sea starts 1 move short")
	assert_eq(w.turn_allowance(sk), 4, "Infantry sails 4 hexes a turn (walks 5)")
	assert_true(w.reachable(sk).has(c[0]), "and can land again")

func test_every_ground_unit_can_sail_now_but_slower():
	var w := _war()
	var c := _coast(w)
	w._put(A, Artilery.new(), c[0])
	var k := MapCampaign.key_of(c[0].x, c[0].y)
	assert_true(w.can_sail(A, w.units[k]["card"]), "Artilery has 3 moves: enough to board")
	assert_true(w.reachable(k).has(c[1]), "so it can put out to sea")
	assert_true(w.can_sail(A, Tank.new()), "a Tank too")
	assert_true(w.can_sail(A, Drone.new()), "flying units don't need boats")
	# the rule still stands for a unit with a single move: no boarding
	assert_eq(w._step_cost(c[0], c[1], false, false), -1, "a non-sailor can't step onto the sea")
	assert_eq(w._step_cost(c[0], c[1], false, true), 1 + MapWar.SEA_PENALTY, "boarding costs extra")
	assert_eq(w._step_cost(c[1], c[2], false, true), 1, "sailing on costs 1")
	assert_eq(w._step_cost(c[0], c[1], true, false), 1, "flying over costs 1")
	# a gun that starts its turn at sea refills one move short
	w._remove(k)
	w._put(A, Artilery.new(), c[1])
	var sk := MapCampaign.key_of(c[1].x, c[1].y)
	w.refill_moves(A)
	assert_eq(w.moves_left(sk), MapWar.MOVE_RANGED - MapWar.SEA_PENALTY, "2 moves at sea")
	assert_true(w.reachable(sk).has(c[0]), "back to land")

func test_flying_units_ignore_the_sea():
	var w := _war()
	var c := _coast(w)
	w._put(A, Drone.new(), c[1])
	var k := MapCampaign.key_of(c[1].x, c[1].y)
	assert_eq(w.turn_allowance(k), MapWar.MOVE_FLYING, "a Drone over the sea keeps its 4 moves")
