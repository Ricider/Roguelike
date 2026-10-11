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
	assert_eq((w.players[A] as Player).Influence, inf_before + roundi(3 * MapWar.INFLUENCE_PER_HEX), "winner earns 2.5 Influence per hex taken (rounded)")
	assert_eq(int(events[0]["influence"]), roundi(3 * MapWar.INFLUENCE_PER_HEX), "event reports the Influence")
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
	assert_true(int(st.get("blocked_interceptor", 0)) >= 0, "the Interceptor's cut (it blocks 7%, so often nothing on a small hit) is counted")
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
	# (10, 10) may be open sea on the world map: then the gun sits in a boat and reaches 2 less
	var r := w.attack_range(A, w.units[arty]["card"], Vector2i(10, 10))
	assert_eq(r, MapWar.RANGED_RANGE - (MapWar.SEA_RANGE_PENALTY if not WorldMap.is_land(10, 10) else 0), "8, or 6 from a boat")
	var near := Wall.new()
	near.HitPoints = 999
	_drop(w, B, near, 10 + r) # right at the edge of its reach
	_drop(w, B, Wall.new(), 10 + r + 4) # out of reach
	for i in range(12):
		var log := w.fire(arty)
		assert_eq(log.size(), 1, "fires")
		assert_eq(log[0]["to"], Vector2i(10 + r, 10), "only ever at the target within reach")
	w._remove(MapCampaign.key_of(10 + r, 10))
	assert_true(w.fire(arty).is_empty(), "nothing within reach: no shot")

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
	assert_eq(MapWar.deploy_anchors(Infantry.new()), ["Housing", "Barracks"], "people: near Housing or Barracks")
	assert_eq(MapWar.deploy_anchors(SpecialOps.new()), ["Housing", "Barracks"], "Special Ops are people too")
	assert_eq(MapWar.deploy_anchors(Tank.new()), ["Factory"], "ground machines: Factory")
	assert_eq(MapWar.deploy_anchors(Artilery.new()), ["Factory"], "guns too")
	assert_eq(MapWar.deploy_anchors(Drone.new()), ["Corporation", "Factory", "Airport"], "Drones: Corporation, Factory or Airport")
	assert_eq(MapWar.deploy_anchors(FighterJet.new()), ["Airport"], "Fighter Jets: Airports only")
	assert_eq(MapWar.deploy_anchors(BomberJet.new()), ["Airport"], "Bomber Jets: Airports only")
	assert_eq(MapWar.deploy_anchors(Wall.new()), [], "buildings go anywhere")

func test_units_deploy_only_near_the_flag_or_their_buildings():
	var w := _zone_war()
	var p: Player = w.players[A]
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_eq(w.can_place(A, inf, Vector2i(2, 10)), "", "2 hexes from the flag: fine")
	assert_string_contains(w.can_place(A, inf, Vector2i(3, 10)), "within 2 hexes of your flag, a Housing or a Barracks", "3 is too far")
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
	assert_string_contains(w.can_place(A, jet, Vector2i(11, 10)), "within 2 hexes of one of your Airports", "no Airport yet: no jets, even beside the Factory")
	assert_ne(w.can_place(A, jet, Vector2i(1, 10)), "", "nor beside the flag")
	w._put(A, Airport.new(), Vector2i(8, 10))
	assert_ne(w.can_place(A, jet, Vector2i(11, 10)), "", "3 hexes from the Airport: too far")
	assert_eq(w.can_place(A, jet, Vector2i(10, 10)), "", "2 hexes from the Airport: built there")
	w._put(A, Barracks.new(), Vector2i(24, 10))
	assert_ne(w.can_place(A, jet, Vector2i(22, 10)), "", "but not near a Barracks")
	p.Hand = [tank]
	assert_ne(w.can_place(A, tank, Vector2i(22, 10)), "", "nor a Tank: Barracks train people")
	p.Hand = [inf]
	assert_eq(w.can_place(A, inf, Vector2i(22, 10)), "", "Infantry muster at the Barracks")
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

# --- fighting from boats ------------------------------------------------------------
func test_units_in_boats_have_less_range():
	var w := _war()
	var c := _coast(w)
	var inf := Infantry.new()
	var arty := Artilery.new()
	assert_eq(w.attack_range(A, inf, c[0]), MapWar.MELEE_RANGE, "on land: 4")
	assert_eq(w.attack_range(A, inf, c[1]), MapWar.MELEE_RANGE - MapWar.SEA_RANGE_PENALTY, "in a boat: 2")
	assert_eq(w.attack_range(A, arty, c[1]), MapWar.RANGED_RANGE - MapWar.SEA_RANGE_PENALTY, "a gun in a boat: 6")
	assert_eq(w.attack_range(A, Drone.new(), c[1]), MapWar.MELEE_RANGE, "flying units don't sit in boats")
	assert_eq(w.attack_range(A, inf), MapWar.MELEE_RANGE, "no position given: the plain range")

func test_a_boat_fires_only_within_its_shorter_reach():
	var w := _war()
	var c := _coast(w)
	for nm in [B, C]:
		w.campaign.flag_sites[nm] = Vector2i(-50, -50) # flags well out of the way
	# an enemy Wall 3 hexes from the boat: in reach from land (4), not from the boat (2)
	var target := Vector2i(-1, -1)
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var t := Vector2i(x, y)
			if target.x < 0 and MapCampaign.hex_distance(t, c[1]) == 3 and not w.units.has(MapCampaign.key_of(x, y)) and not WorldMap.is_void(x, y):
				target = t
	var wall := Wall.new()
	wall.HitPoints = 999
	w._put(B, wall, target)
	w._put(A, Infantry.new(), c[1])
	var k := MapCampaign.key_of(c[1].x, c[1].y)
	assert_true(w.predict_target(k).is_empty(), "3 hexes is out of a boat's reach")
	assert_true(w.fire(k).is_empty(), "so it holds its fire")

func test_units_in_boats_take_more_per_hit():
	var w := _war()
	var c := _coast(w)
	for nm in [B, C]:
		w.campaign.flag_sites[nm] = Vector2i(-50, -50)
	var boat := Infantry.new()
	boat.HitPoints = 999
	w._put(B, boat, c[1]) # B's Infantry in a boat, A's Tank on the coast beside it
	var tk := MapCampaign.key_of(c[0].x, c[0].y)
	w._put(A, Tank.new(), c[0])
	w.reset_round_stats()
	var hp0 := boat.HitPoints
	var log := w.fire(tk)
	assert_eq(log[0]["to"], c[1], "the Tank hits the boat")
	var plain: int = w.effective_damage(A, Tank.new(), c[0])
	assert_eq(hp0 - boat.HitPoints, plain + MapWar.SEA_DAMAGE_PENALTY, "+1 for being caught at sea")
	assert_eq(int(w.round_stats[A + "|" + B].get("boat", 0)), MapWar.SEA_DAMAGE_PENALTY, "the report counts it")
	assert_true(w.in_boat(boat, c[1]) and not w.in_boat(Drone.new(), c[1]), "only ground units sit in boats")

# --- upkeep -------------------------------------------------------------------------
func test_upkeep_is_five_percent_of_the_units_on_the_map():
	var w := _war()
	assert_eq(w.upkeep(A), {"money": 0, "bio": 0}, "no units, no upkeep")
	for x in range(10, 14):
		_drop(w, A, Infantry.new(), x) # 4 x (5 Money, 15 Bio)
	_drop(w, A, Tank.new(), 14) # 25 Money, 10 Bio
	var money: int = 4 * Infantry.new().MoneyCost + Tank.new().MoneyCost # 45
	var bio: int = 4 * Infantry.new().BioCost + Tank.new().BioCost # 70
	# progressive: brackets 10, 11, 12, 13, 14%; the dearest units in the cheapest brackets
	# Money: Tank 25 at 10%, then the Infantry's 5s at 11-14%: 2.5 + 0.55 + 0.6 + 0.65 + 0.7 = 5
	# Bio: the Infantry's 15s at 10-13%, the Tank's 10 at 14%: 1.5 + 1.65 + 1.8 + 1.95 + 1.4 = 8.3
	assert_eq(w.upkeep(A), {"money": 5, "bio": 8}, "progressive, rounded on the totals")
	assert_almost_eq(w.upkeep_rate(A), 0.15, 0.0001, "the 6th unit would pay 15%")
	w.campaign.owner[MapCampaign.key_of(9, 10)] = A
	w._put(A, Factory.new(), Vector2i(9, 10))
	assert_eq(w.upkeep(A), {"money": 5, "bio": 8}, "buildings cost nothing to keep (nor take a bracket)")
	assert_eq(w.upkeep(B), {"money": 0, "bio": 0}, "each nation pays for its own")

func test_upkeep_comes_out_of_the_turns_income():
	var w := _war()
	for x in range(10, 15):
		_drop(w, A, SpecialOps.new(), x) # 5 x (15 Money, 20 Bio) at 10+11+12+13+14% = 60%
	var up := w.upkeep(A)
	assert_eq(up, {"money": 9, "bio": 12}, "15 x 0.6 = 9 Money, 20 x 0.6 = 12 Bio")
	var p: Player = w.players[A]
	p.MoneySupply = 50
	p.BioSupply = 50
	var money_gain := p.predicted_money_gain()
	var bio_gain := p.predicted_bio_gain()
	w.begin_turn(A)
	assert_eq(p.MoneySupply, 50 + money_gain - int(up["money"]), "income minus upkeep")
	assert_eq(p.BioSupply, 50 + bio_gain - int(up["bio"]), "for Bio too")
	assert_eq(w.last_upkeep, up, "and the map screen is told what was paid")
	# a broke nation just hits 0
	p.MoneySupply = 0
	p.BioSupply = 0
	w.pay_upkeep(A)
	assert_eq(p.MoneySupply, 0, "never below 0")
	assert_eq(p.BioSupply, 0, "never below 0")

# --- where buildings may go -----------------------------------------------------------
func test_buildings_go_near_the_flag_buildings_or_infantry():
	var w := _zone_war() # A owns row 10 from 0 to 24, flag at 0
	var p: Player = w.players[A]
	var wall := Wall.new()
	p.Hand = [wall]
	assert_eq(w.can_place(A, wall, Vector2i(5, 10)), "", "5 hexes from the flag: fine")
	assert_string_contains(w.can_place(A, wall, Vector2i(6, 10)), "must be built within 5 hexes of your flag or one of your buildings", "6 is too far")
	# a building extends the zone 5 more hexes
	w._put(A, Housing.new(), Vector2i(5, 10))
	assert_eq(w.can_place(A, wall, Vector2i(10, 10)), "", "5 from the Housing")
	assert_ne(w.can_place(A, wall, Vector2i(11, 10)), "", "but no further")
	# an Infantry lets you build 2 hexes around it, however far from home
	var inf := Infantry.new()
	w._put(A, inf, Vector2i(20, 10))
	assert_eq(w.can_place(A, wall, Vector2i(18, 10)), "", "2 hexes from your Infantry")
	assert_eq(w.can_place(A, wall, Vector2i(22, 10)), "", "either side")
	assert_ne(w.can_place(A, wall, Vector2i(17, 10)), "", "3 is too far from it")
	# other units don't count, nor do dead ones or other nations' cards
	w._remove(MapCampaign.key_of(20, 10))
	w._put(A, Tank.new(), Vector2i(20, 10))
	assert_ne(w.can_place(A, wall, Vector2i(21, 10)), "", "a Tank is no builder")
	w._put(B, Infantry.new(), Vector2i(23, 10)) # standing on A's land
	assert_ne(w.can_place(A, wall, Vector2i(22, 10)), "", "an enemy Infantry doesn't help you build")
	var dead := Housing.new()
	w._put(A, dead, Vector2i(15, 10))
	assert_eq(w.can_place(A, wall, Vector2i(17, 10)), "", "a standing Housing does")
	dead.HitPoints = 0
	assert_ne(w.can_place(A, wall, Vector2i(17, 10)), "", "a fallen one doesn't")
	# still only on your own land
	w._put(A, Infantry.new(), Vector2i(24, 9))
	assert_ne(w.can_place(A, wall, Vector2i(25, 10)), "", "never outside your borders")

func test_ai_builds_only_inside_the_zone():
	var w := _zone_war()
	var p: Player = w.players[A]
	p.Hand = [Factory.new(), Housing.new(), Wall.new()]
	var placed := w.ai_build(A)
	assert_eq(placed.size(), 3, "all three built")
	for pl in placed:
		assert_true(MapCampaign.hex_distance(pl[1], Vector2i(0, 10)) <= MapWar.BUILD_RADIUS * 3, "chained out from the flag at most")
		var ok := false
		for z in w.deploy_zone(A, pl[0]):
			if MapCampaign.hex_distance(pl[1], z[0]) <= int(z[1]) and z[0] != pl[1]:
				ok = true
		assert_true(ok, "%s sits within reach of the flag or another building" % (pl[0] as Card).card_name)

# --- Interceptors: 75% ------------------------------------------------------------------
func test_interceptors_block_three_quarters_on_average():
	var w := _war()
	w.rng.seed = 42
	var total := 0
	var n := 4000
	for i in range(n):
		var b := w.intercept_block(10)
		assert_true(b == 7 or b == 8, "a 10-damage hit loses 7 or 8")
		total += b
	assert_almost_eq(float(total) / (n * 10), MapWar.INTERCEPT_SHARE, 0.01, "75% of the damage on average")
	assert_eq(w.intercept_block(1), 0, "a 1-damage hit is never cut to 0")
	assert_eq(w.intercept_block(2), 1, "a 2-damage hit keeps at least 1")
	var big := 0
	for i in range(1000):
		big += w.intercept_block(100)
	assert_eq(big, 75000, "a 100-damage hit loses exactly 75")

func test_an_interceptor_only_pays_when_it_blocks():
	var w := _war()
	var p: Player = w.players[B]
	p.MoneySupply = 100
	var icp := Interceptor.new()
	w._put(B, icp, Vector2i(16, 10))
	w._put(B, Wall.new(), Vector2i(15, 10))
	var drone := Drone.new() # flying: interceptable
	var hp0 := icp.HitPoints
	var paid := 0
	var blocks := 0
	for i in range(200):
		var money0 := p.MoneySupply
		var out := w._intercept(B, Vector2i(15, 10), drone, A, 5)
		if out < 5:
			blocks += 1
			assert_true(out == 1 or out == 2, "a 5-damage hit loses 3 or 4")
			assert_eq(p.MoneySupply, money0 - 6, "a block costs 6 Money")
		else:
			assert_eq(p.MoneySupply, money0, "no block, no cost")
		p.MoneySupply = 100
		icp.HitPoints = hp0
	assert_eq(blocks, 200, "every 5-damage hit is blocked")
	# a 1-damage hit can't be cut, so it costs nothing
	var m1 := p.MoneySupply
	assert_eq(w._intercept(B, Vector2i(15, 10), drone, A, 1), 1, "1 damage stays 1")
	assert_eq(p.MoneySupply, m1, "and the Interceptor doesn't pay for nothing")

# --- Influence for destroyed buildings --------------------------------------------------
func test_destroying_an_enemy_building_pays_a_third_of_its_influence_price():
	assert_eq(MapWar.building_bounty(Barracks.new()), 10, "Barracks: 30 / 3")
	assert_eq(MapWar.building_bounty(Wall.new()), 2, "Wall: 5 / 3, rounded")
	assert_eq(MapWar.building_bounty(Factory.new()), 7, "Factory: 20 / 3, rounded")
	assert_eq(MapWar.building_bounty(Infantry.new()), 0, "units pay nothing")
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	var target := Barracks.new()
	target.HitPoints = 1
	w._put(B, target, Vector2i(15, 10))
	var shooter := _drop(w, A, Tank.new(), 14)
	var inf0 := (w.players[A] as Player).Influence
	var log := w.fire(shooter)
	assert_eq(log[0]["destroyed"].size(), 1, "the Barracks falls")
	assert_eq(int(log[0]["destroyed"][0]["bounty"]), 10, "the shot says what it earned")
	assert_eq((w.players[A] as Player).Influence, inf0 + 10, "the attacker gains 10 Influence")
	assert_eq(w.take_bounty(A), 10, "the map screen can collect it for the log")
	assert_eq(w.take_bounty(A), 0, "once")
	# a destroyed unit pays nothing
	var inf := Infantry.new()
	inf.HitPoints = 1
	w._put(B, inf, Vector2i(15, 10))
	var inf1 := (w.players[A] as Player).Influence
	w.fire(shooter)
	assert_eq((w.players[A] as Player).Influence, inf1, "no Influence for units")

# --- the round report's economy ----------------------------------------------------------
func test_last_economy_explains_the_turns_income():
	var w := _war()
	var p: Player = w.players[A]
	p.MoneySupply = 50
	p.BioSupply = 50
	w.campaign.owner[MapCampaign.key_of(9, 10)] = A
	w._put(A, Factory.new(), Vector2i(9, 10))
	w._put(A, Factory.new(), Vector2i(10, 10))
	w._put(A, Housing.new(), Vector2i(11, 10))
	for x in [12, 13, 14]:
		_drop(w, A, SpecialOps.new(), x) # 3 x (15 Money, 20 Bio): 2 Money, 3 Bio upkeep
	w.begin_turn(A)
	var e: Dictionary = w.last_economy[A]
	var money := {}
	for l in e["money"]:
		money[str(l[0])] = int(l[1])
	assert_eq(money["Base income"], 10, "base income")
	assert_eq(money["Factory x2"], 30, "two Factories, 15 each")
	assert_eq(money["Housing x1"], 2, "a Housing's 2 Money")
	var upkeep_line := 0
	for key in money.keys():
		if str(key).begins_with("Upkeep (3 units, progressive"):
			upkeep_line = money[key]
	assert_eq(upkeep_line, -roundi(15 * (0.10 + 0.11 + 0.12)), "3 Special Ops: 15 Money each at 10, 11 and 12%")
	var sum := 0
	for l in e["money"]:
		sum += int(l[1])
	assert_eq(int(e["money_to"]) - int(e["money_from"]), sum, "the lines add up to the change")
	assert_eq(int(e["money_to"]), p.MoneySupply, "and end where the treasury is")
	var bsum := 0
	for l in e["bio"]:
		bsum += int(l[1])
	assert_eq(int(e["bio_to"]) - int(e["bio_from"]), bsum, "Bio lines add up too")
	# the 200 cap shows as a loss
	p.MoneySupply = 195
	w.begin_turn(A)
	var capped := 0
	for l in w.last_economy[A]["money"]:
		if str(l[0]) == "Over the 200 cap":
			capped = int(l[1])
	assert_lt(capped, 0, "income lost to the cap is listed")

func test_influence_log_splits_hexes_and_buildings():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	var target := Barracks.new()
	target.HitPoints = 1
	w._put(B, target, Vector2i(15, 10))
	w.fire(_drop(w, A, Tank.new(), 14))
	assert_eq(int(w.influence_log[A]["buildings"]), 10, "a destroyed Barracks: 10")
	w.reset_round_stats()
	assert_true(w.influence_log.is_empty(), "cleared with the round")

# --- minimum Influence ------------------------------------------------------------------
func test_every_nation_gets_at_least_five_influence_a_turn():
	var w := _war()
	var p: Player = w.players[A]
	var i0 := p.Influence
	w.begin_turn(A)
	assert_eq(p.Influence, i0 + MapWar.MIN_INFLUENCE_PER_TURN, "earned nothing: topped up to 5")
	assert_eq(int(w.last_economy[A]["influence_topup"]), 5, "the report is told")
	# earned 2 since: topped up by 3
	w._log_influence(A, "buildings", 2)
	p.Influence += 2
	var i1 := p.Influence
	w.begin_turn(A)
	assert_eq(p.Influence, i1 + 3, "2 earned + 3 top-up = 5")
	# earned 10: no top-up
	w._log_influence(A, "hexes", 10)
	p.Influence += 10
	var i2 := p.Influence
	w.begin_turn(A)
	assert_eq(p.Influence, i2, "earned more than 5: nothing added")
	assert_eq(int(w.last_economy[A]["influence_topup"]), 0, "and no top-up reported")
	# every nation, not just yours
	var q: Player = w.players[B]
	var j0 := q.Influence
	w.begin_turn(B)
	assert_eq(q.Influence, j0 + 5, "AI nations get it too")

# --- Airports, Fighter Jets and Bomber Jets ---------------------------------------------
func test_new_air_cards():
	var ap := Airport.new()
	assert_eq([ap.HitPoints, ap.MoneyCost, ap.BioCost, ap.InfluenceCost], [25, 25, 15, 50], "Airport: 25 HP, 25 Money, 15 Bio, 50 Influence")
	var bj := BomberJet.new()
	assert_eq([bj.HitPoints, bj.Damage, bj.MoneyCost, bj.BioCost, bj.InfluenceCost], [8, 4, 50, 15, 60], "Bomber Jet: 8 HP, 4 damage, 50/15/60")
	assert_true(bj.Flying and bj.HasRange, "flying, with Range")
	var fj := FighterJet.new()
	assert_eq([fj.Damage, fj.MoneyCost], [3, 45], "Fighter Jet: 3 damage, 45 Money")
	assert_false(fj.HasRange, "no Range any more")
	var ad := Player.new(100, 200, 200)
	ad.Modifiers.append(Modifier.by_name("Advanced Robotics"))
	assert_true(ad.has_range_for(fj), "Advanced Robotics: flying units get Range")

func test_fighter_jets_stay_within_twelve_hexes_of_an_airport():
	var w := _zone_war() # A owns row 10, 0..24, flag at 0
	w.campaign.flag_sites[B] = Vector2i(40, 10)
	w.campaign.flag_sites[C] = Vector2i(45, 10)
	var p: Player = w.players[A]
	w._put(A, Factory.new(), Vector2i(3, 10))
	var jet := FighterJet.new()
	p.Hand = [jet]
	assert_true(w.deploy_hexes(A, jet).is_empty(), "no Airport: nowhere to deploy a Fighter Jet")
	w._put(A, Airport.new(), Vector2i(2, 10))
	assert_false(w.deploy_hexes(A, jet).is_empty(), "with one, near the Factory")
	# flying: only to hexes within 12 of the Airport
	w._put(A, FighterJet.new(), Vector2i(10, 10))
	var k := MapCampaign.key_of(10, 10)
	var reach := w.reachable(k)
	assert_true(reach.has(Vector2i(14, 10)), "12 hexes from the Airport: fine")
	assert_false(reach.has(Vector2i(15, 10)), "13 is out of range")
	for t in reach.keys():
		assert_true(MapCampaign.hex_distance(t, Vector2i(2, 10)) <= MapWar.AIRPORT_RANGE, "every destination within 12")

func test_stranded_fighter_jets_lose_hp_until_home_or_crashed():
	var w := _zone_war()
	var ap := Airport.new()
	w._put(A, ap, Vector2i(2, 10))
	var jet := FighterJet.new()
	w._put(A, jet, Vector2i(10, 10))
	var hp0 := jet.HitPoints
	w.begin_turn(A)
	assert_eq(jet.HitPoints, hp0, "in range: no loss")
	ap.HitPoints = 0 # the Airport is destroyed
	w._remove(MapCampaign.key_of(2, 10))
	w.begin_turn(A)
	assert_eq(jet.HitPoints, hp0 - MapWar.JET_ATTRITION, "out of range: -2 HP a turn")
	assert_eq(w.last_attrition.size(), 1, "the map screen is told")
	var k := MapCampaign.key_of(10, 10)
	assert_false(w.reachable(k).is_empty(), "a stranded jet can still fly, to find a new Airport")
	var hp_nation := (w.players[A] as Player).HitPoints
	jet.HitPoints = 2
	w.begin_turn(A)
	assert_false(w.units.has(k), "out of fuel: it crashes")
	assert_true(bool(w.last_attrition[0][1]), "reported as crashed")
	assert_eq((w.players[A] as Player).HitPoints >= hp_nation, true, "a crash costs the nation no HP")

func test_bombers_are_covered_by_airports_and_jets_splash():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	w.campaign.flag_sites[C] = Vector2i(30, 10)
	var bomber := BomberJet.new()
	bomber.HitPoints = 99
	w._put(B, bomber, Vector2i(16, 10))
	var tank := _drop(w, A, Tank.new(), 14) # melee: half damage against flyers
	var hp0 := bomber.HitPoints
	w.fire(tank)
	var plain := hp0 - bomber.HitPoints
	w._put(B, Airport.new(), Vector2i(20, 10))
	var hp1 := bomber.HitPoints
	w.reset_round_stats()
	w.fire(tank)
	assert_eq(hp1 - bomber.HitPoints, maxi(1, plain - MapWar.BOMBER_AIRPORT_COVER), "within 12 of its Airport: 1 less damage")
	assert_eq(int(w.round_stats[A + "|" + B].get("blocked_airport", 0)), mini(1, plain - 1), "the report counts it")
	# a Bomber splashes the target's neighbours
	var w2 := _war()
	w2.campaign.flag_sites[B] = Vector2i(25, 10)
	w2.campaign.flag_sites[C] = Vector2i(30, 10)
	var t1 := Wall.new()
	t1.HitPoints = 99
	var t2 := Wall.new()
	t2.HitPoints = 99
	w2._put(B, t1, Vector2i(18, 10))
	w2._put(B, t2, Vector2i(19, 10))
	var bk := _drop(w2, A, BomberJet.new(), 14)
	var log := w2.fire(bk)
	assert_false((log[0]["splash"] as Array).is_empty(), "Bomber Jets splash")

# --- AI policy (tuned by self-play: tools/dev/ai_tournament.gd) ---------------------------
func test_ai_policy_defaults_and_overrides():
	var w := _war()
	assert_eq(w.ai_param(A, "w_cohesion"), MapWar.AI_DEFAULT["w_cohesion"], "defaults apply")
	w.ai_policy[A] = MapWar.AI_CLASSIC
	assert_eq(w.ai_param(A, "w_cohesion"), 0.0, "the classic AI can be switched back on per nation")
	assert_eq(w.ai_param(A, "w_inrange"), MapWar.AI_DEFAULT["w_inrange"], "unset keys fall back to the default")
	assert_eq(w.ai_param(B, "w_stay"), MapWar.AI_DEFAULT["w_stay"], "other nations keep the default")
	for k in MapWar.AI_CLASSIC.keys():
		assert_true(MapWar.AI_DEFAULT.has(k), "classic setting %s exists" % k)

func test_ai_values_firepower_per_influence():
	assert_gt(MapWar._card_value(Infantry.new()), MapWar._card_value(Wall.new()), "a fighting unit beats a Wall for the same Influence")
	assert_gt(MapWar._card_value(Factory.new()), 0.0, "buildings have some value")

func test_ai_keeps_units_together():
	var w := _war()
	w.campaign.flag_sites[B] = Vector2i(25, 10)
	_drop(w, A, Infantry.new(), 11) # a friend on 11
	var k := _drop(w, A, Infantry.new(), 14)
	var wts := w._move_weights(A)
	var foes: Array = []
	var next_to := w._position_score(A, k, Vector2i(12, 10), foes, [], 4, wts)
	var alone := w._position_score(A, k, Vector2i(13, 10), foes, [], 4, wts)
	assert_almost_eq(next_to - alone, float(MapWar.AI_DEFAULT["w_cohesion"]), 0.001, "a hex beside a friend scores w_cohesion more")

func test_focus_target_is_the_weakest_neighbour():
	var w := _war()
	(w.players[B] as Player).HitPoints = 10
	assert_eq(w.focus_target(A), B, "B (its only neighbour) is the one to gang up on")

# --- difficulty --------------------------------------------------------------------------
func test_difficulty_switches_the_ai_nations_between_classic_and_tuned():
	var gs = load("res://GodotHelpers/GameState.gd").new()
	gs.map_campaign = MapCampaign.new("State Troops")
	var w := MapWar.new()
	w.setup(gs.map_campaign, func(nm): return gs.make_player_by_name(nm), gs.make_player_by_name("State Troops", true))
	gs.apply_ai_difficulty(w, "normal")
	assert_eq(w.ai_param("Horde", "w_cohesion"), MapWar.AI_CLASSIC["w_cohesion"], "Normal: AI nations play the classic AI")
	assert_false(w.ai_policy.has("State Troops"), "your own nation is never given an AI policy")
	gs.apply_ai_difficulty(w, "hard")
	assert_true(w.ai_policy.is_empty(), "Hard: everyone on the tuned default")
	assert_eq(w.ai_param("Horde", "w_cohesion"), MapWar.AI_DEFAULT["w_cohesion"], "the tuned AI")
	gs.free()

func test_upkeep_ramps_with_every_unit():
	var w := _zone_war()
	var paid: Array = [] # Bio upkeep for 1, 2, 3 ... Infantry
	for i in range(1, 25):
		_drop(w, A, Infantry.new(), i)
		paid.append(int(w.upkeep(A)["bio"]))
	assert_almost_eq(w.upkeep_rate(A), 0.10 + 0.01 * 24, 0.0001, "with 24 units the 25th would pay 34%")
	# the cost of each extra unit keeps growing: the last few cost more than the first few
	var first_steps: int = paid[4] - paid[0]
	var last_steps: int = paid[23] - paid[19]
	assert_gt(last_steps, first_steps, "the 21st-24th units add more upkeep than the 2nd-5th")
	assert_eq(paid[9], roundi(15 * 1.45), "10 Infantry: 15 Bio each at 10..19% = 22 a turn")
	# a new unit pays only its own bracket: the bill rises by exactly that much (before rounding)
	var nine := MapWar.progressive_upkeep([15, 15, 15, 15, 15, 15, 15, 15, 15])
	var ten := MapWar.progressive_upkeep([15, 15, 15, 15, 15, 15, 15, 15, 15, 15])
	assert_almost_eq(ten - nine, 15 * 0.19, 0.0001, "the 10th unit adds 19% of its own cost, nothing more")

func test_upkeep_caps_at_half():
	var w := _war()
	for y in range(0, 6):
		for x in range(10, 18):
			w._put(A, Infantry.new(), Vector2i(x, y)) # 48 units
	assert_eq(w.unit_count(A), 48, "48 units")
	assert_almost_eq(w.upkeep_rate(A), MapWar.UPKEEP_MAX, 0.0001, "never more than 50%")

func test_jets_are_built_only_at_airports():
	var w := _zone_war() # A owns row 10, 0..24, flag at 0
	w._put(A, Factory.new(), Vector2i(3, 10))
	w._put(A, Corporation.new(), Vector2i(5, 10))
	for card in [FighterJet.new(), BomberJet.new()]:
		assert_true(w.deploy_hexes(A, card).is_empty(), "%s: no Airport, nowhere to build it (flag, Factory and Corporation don't count)" % card.card_name)
	w._put(A, Airport.new(), Vector2i(15, 10))
	for card in [FighterJet.new(), BomberJet.new()]:
		var hexes := w.deploy_hexes(A, card)
		assert_false(hexes.is_empty(), "%s: now beside the Airport" % card.card_name)
		for t in hexes:
			assert_true(MapCampaign.hex_distance(t, Vector2i(15, 10)) <= MapWar.DEPLOY_RADIUS, "all within 2 hexes of it")
	assert_false(w.deploy_hexes(A, Drone.new()).is_empty(), "Drones still come from the Factory or Corporation")
	var drone_spots := w.deploy_hexes(A, Drone.new())
	assert_true(drone_spots.has(Vector2i(16, 10)), "and now from the Airport too")
	assert_true(drone_spots.has(Vector2i(4, 10)), "as well as beside the Factory")
	assert_eq(MapWar.deploy_rule_text(BomberJet.new()), "within 2 hexes of one of your Airports", "the rule in words")

func test_progressive_upkeep_is_the_cheapest_order():
	# every order of these costs over the brackets: ours must be the lowest
	var costs := [25, 5, 40, 10]
	var best := INF
	var perms: Array = [[]]
	for c in costs:
		var nxt: Array = []
		for pm in perms:
			for i in range(pm.size() + 1):
				var q: Array = (pm as Array).duplicate()
				q.insert(i, c)
				nxt.append(q)
		perms = nxt
	for pm in perms:
		var total := 0.0
		for i in range(pm.size()):
			total += float(pm[i]) * MapWar.upkeep_bracket(i + 1)
		best = minf(best, total)
	assert_almost_eq(MapWar.progressive_upkeep(costs), best, 0.0001, "the dearest units fill the cheapest brackets: the lowest bill")
	assert_almost_eq(MapWar.upkeep_bracket(1), 0.10, 0.0001, "1st unit 10%")
	assert_almost_eq(MapWar.upkeep_bracket(41), 0.50, 0.0001, "41st 50%")
	assert_almost_eq(MapWar.upkeep_bracket(60), 0.50, 0.0001, "and no more")
