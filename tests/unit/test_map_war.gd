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
	var shooter := _drop(w, A, Tank.new(), 14)
	var b_flag: Vector2i = w.flag_sites()[B]
	var log := w.fire(shooter)
	assert_true(log[0]["direct"], "flag hit")
	assert_eq(log[0]["to"], b_flag, "shot lands on B's flag hex")
	assert_eq(log[0]["victim"], B, "closest enemy flag")
	assert_eq((w.players[B] as Player).HitPoints, 100 - Tank.new().Damage, "flag damage comes off B's HP")
	assert_eq(int(w.ledger[B][A]), Tank.new().Damage, "credited to the attacker")

func test_melee_prefers_closer_flag_over_farther_card():
	var w := _war()
	var shooter := _drop(w, A, Tank.new(), 14)
	var b_flag: Vector2i = w.flag_sites()[B]
	_drop(w, C, Wall.new(), b_flag.x + 3) # a card, but farther than B's flag
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
	assert_eq(int(fd[MapCampaign.key_of(inf_hex.x, inf_hex.y)]), 1, "infantry on a border hex")
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
