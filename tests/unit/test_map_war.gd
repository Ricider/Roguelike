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
	assert_eq(MapWar.hex_distance(Vector2i(0, 4), Vector2i(59, 4)), 1, "wraps east-west")
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
	assert_eq(w.can_place(A, tank, Vector2i(12, 10)), "", "own empty hex ok")
	assert_true(w.place(A, tank, Vector2i(12, 10)), "placed")
	assert_eq(p.MoneySupply, 100 - tank.MoneyCost, "money paid")
	assert_eq(p.BioSupply, 100 - tank.BioCost, "bio paid")
	assert_false(p.Hand.has(tank), "left the hand")
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_ne(w.can_place(A, inf, Vector2i(12, 10)), "", "occupied hex rejected")
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

func test_ranged_hits_random_card_of_closest_nation():
	var w := _war()
	var hit_hexes := {}
	for trial in range(40):
		var t := _war()
		t.rng.seed = trial
		var shooter := _drop(t, A, Artilery.new(), 14)
		_drop(t, B, Wall.new(), 16) # B is the closest nation...
		_drop(t, B, Wall.new(), 25) # ...and also owns this far card
		_drop(t, C, Wall.new(), 26) # C's card is closer than B's far one but C is not the closest nation
		var log := t.fire(shooter)
		assert_eq(log[0]["victim"], B, "ranged unit targets the closest nation")
		hit_hexes[log[0]["to"]] = true
	assert_true(hit_hexes.has(Vector2i(16, 10)) and hit_hexes.has(Vector2i(25, 10)), "random card of that nation, near or far")
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

func test_direct_hit_when_no_enemy_cards():
	var w := _war()
	var shooter := _drop(w, A, Tank.new(), 14)
	var log := w.fire(shooter)
	assert_true(log[0]["direct"], "direct HP hit")
	assert_eq(log[0]["victim"], B, "closest enemy nation")
	assert_eq((w.players[B] as Player).HitPoints, 100 - Tank.new().Damage, "HP reduced")

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
	(w.players[B] as Player).HitPoints = 0
	w.ledger[B] = {A: 40, C: 10}
	(w.players[A] as Player).HitPoints = 35
	var before_a := w.campaign.tile_count(A)
	var events := w.resolve_collapses()
	assert_eq(events.size(), 1, "one collapse")
	assert_eq(events[0]["winner"], A, "top damager wins land")
	assert_eq(events[0]["tiles"], 3, "1 tile per 10 HP the victor has left")
	assert_eq(w.campaign.tile_count(A), before_a + 3, "A grew")
	assert_eq(w.campaign.owner_of(15, 10), A, "border hex taken")
	assert_false(w.units.has(bcard), "loser's card on the lost hex is gone")
	assert_eq((w.players[B] as Player).HitPoints, (w.players[B] as Player).MaxHitPoints, "loser rebuilds")

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
