extends GutTest
# Missiles, Nukes, Interceptor reach, ruins and nuclear wasteland (MapWar).
# Synthetic territory on row 10 as in test_map_war.gd: A owns 10-14, B 15-25,
# C 26-30; flags stand at 12, 20 and 28.

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
	for nm in w.players.keys():
		(w.players[nm] as Player).MoneySupply = 100
		(w.players[nm] as Player).Hand.clear()
	return w

func _drop(w: MapWar, nation: String, card: Card, x: int, y: int = 10) -> String:
	w._put(nation, card, Vector2i(x, y))
	return MapCampaign.key_of(x, y)

func _hp(w: MapWar, k: String) -> int:
	return w.card_hp(w.units[k]["card"]) if w.units.has(k) else 0

# ------------------------------------------------------------- Interceptors
func test_interceptor_covers_three_hexes():
	var w := _war()
	var k := _drop(w, B, Tank.new(), 17)
	_drop(w, B, Interceptor.new(), 23, 10) # 6 away: no cover
	assert_false(w.is_shielded(k), "an Interceptor 6 hexes away covers nothing here")
	_drop(w, B, Interceptor.new(), 13) # 4 hexes west along the row
	assert_false(w.is_shielded(k), "4 hexes is out of reach")
	_drop(w, B, Interceptor.new(), 14) # 3 hexes
	assert_true(w.is_shielded(k), "3 hexes is in reach")
	assert_eq(w.covering_interceptor(B, Vector2i(17, 10)), Vector2i(14, 10), "the nearest one covers it")
	(w.players[B] as Player).MoneySupply = 5
	assert_false(w.is_shielded(k), "not while its owner can't pay 6 Money")

func test_interceptor_blocks_ranged_hits_three_hexes_away():
	var w := _war()
	var art := Artilery.new() # ranged
	_drop(w, A, art, 13)
	var tk := _drop(w, B, Tank.new(), 16)
	_drop(w, B, Interceptor.new(), 19)
	var icp: Card = w.units[MapCampaign.key_of(19, 10)]["card"]
	var blocked_any := false
	for i in range(10):
		var before := _hp(w, tk)
		var log := w.fire(MapCampaign.key_of(13, 10))
		for e in log:
			if bool(e.get("intercepted", false)):
				blocked_any = true
				assert_eq(e["intercept_from"], Vector2i(19, 10), "the shot is stopped from 3 hexes away")
		if blocked_any or not w.units.has(tk):
			break
		assert_true(before >= _hp(w, tk))
	assert_true(blocked_any, "an Interceptor 3 hexes from the target blocks ranged hits")
	assert_lt(w.card_hp(icp), 20, "and pays 2 HP for it")

# ---------------------------------------------------------------- ruins
func test_destroyed_building_leaves_ruins():
	var w := _war()
	var wall := Wall.new()
	wall.HitPoints = 1
	var wk := _drop(w, B, wall, 15)
	_drop(w, A, Infantry.new(), 14)
	w.fire(MapCampaign.key_of(14, 10))
	assert_false(w.units.has(wk), "the wall is destroyed")
	assert_eq(w.scar_at(Vector2i(15, 10)), "ruins", "and leaves ruins")

func test_dead_unit_leaves_no_ruins():
	var w := _war()
	var inf := Infantry.new()
	inf.HitPoints = 1
	var k := _drop(w, B, inf, 15)
	_drop(w, A, Tank.new(), 14)
	w.fire(MapCampaign.key_of(14, 10))
	assert_false(w.units.has(k))
	assert_eq(w.scar_at(Vector2i(15, 10)), "", "only buildings leave ruins")

func test_ruins_cover_ground_units_only():
	var w := _war()
	var t := Vector2i(16, 10)
	w.scars[MapCampaign.key_of(t.x, t.y)] = "ruins"
	assert_eq(w.ruins_adjusted(Infantry.new(), t, 5), 5 - MapWar.RUINS_COVER, "ground units take 2 less")
	assert_eq(w.ruins_adjusted(Infantry.new(), t, 2), 1, "never below 1")
	assert_eq(w.ruins_adjusted(FighterJet.new(), t, 5), 5, "flying units get no cover")
	assert_eq(w.ruins_adjusted(Wall.new(), t, 5), 5, "buildings get no cover")
	assert_eq(w.ruins_adjusted(Infantry.new(), Vector2i(17, 10), 5), 5, "only on the ruins hex")

func test_hits_on_units_in_ruins_are_cut():
	var w := _war()
	var tank := Tank.new()
	var tk := _drop(w, B, tank, 15)
	w.scars[tk] = "ruins"
	_drop(w, A, Tank.new(), 14) # melee, not ranged
	var before := tank.HitPoints
	var log := w.fire(MapCampaign.key_of(14, 10))
	assert_eq(log.size(), 1)
	var raw: int = w.effective_damage(A, w.units[MapCampaign.key_of(14, 10)]["card"], Vector2i(14, 10))
	var want: int = w.ruins_adjusted(tank, Vector2i(15, 10), MapWar.terrain_adjusted(tank, Vector2i(15, 10), raw))
	assert_eq(before - tank.HitPoints, want, "the hit is cut by the ruins")
	var st: Dictionary = w.round_stats.get(A + "|" + B, {})
	assert_eq(int(st.get("blocked_ruins", 0)), MapWar.terrain_adjusted(tank, Vector2i(15, 10), raw) - want, "counted for the round report")

func test_building_over_ruins_clears_them():
	var w := _war()
	var flag := w.campaign.capital_site(B)
	var t := flag + Vector2i(1, 0)
	w.scars[MapCampaign.key_of(t.x, t.y)] = "ruins"
	var house := Housing.new()
	(w.players[B] as Player).Hand = [house]
	(w.players[B] as Player).BioSupply = 200
	assert_eq(w.can_place(B, house, t), "", "buildings can go on ruins")
	assert_true(w.place(B, house, t))
	assert_eq(w.scar_at(t), "", "rebuilt: the ruins are gone")

# --------------------------------------------------------------- missiles
func test_missile_ranges_from_each_launch_site():
	var w := _war()
	var m := Missile.new()
	(w.players[A] as Player).Hand = [m]
	assert_ne(w.can_fire_item(A, m, Vector2i(16, 10)), "", "no launch site: can't fire")
	_drop(w, A, Barracks.new(), 11)
	assert_eq(w.can_fire_item(A, m, Vector2i(17, 10)), "", "a Barracks fires 6 hexes")
	assert_ne(w.can_fire_item(A, m, Vector2i(18, 10)), "", "but not 7")
	_drop(w, A, Interceptor.new(), 10)
	assert_eq(w.can_fire_item(A, m, Vector2i(18, 10)), "", "an Interceptor fires 8 hexes")
	assert_ne(w.can_fire_item(A, m, Vector2i(19, 10)), "", "but not 9")
	_drop(w, A, Airport.new(), 13)
	assert_eq(w.can_fire_item(A, m, Vector2i(25, 10)), "", "an Airport fires 12 hexes")
	assert_ne(w.can_fire_item(A, m, Vector2i(26, 10)), "", "but not 13")
	assert_eq(w.item_launcher_for(A, m, Vector2i(17, 10)), Vector2i(13, 10), "the nearest site in range fires it")
	assert_ne(w.can_place(A, m, Vector2i(13, 10)), "", "items are never placed on the map")

func test_missile_blast_hits_enemies_within_one_hex():
	var w := _war()
	var m := Missile.new()
	var p: Player = w.players[A]
	p.Hand = [m]
	_drop(w, A, Barracks.new(), 11)
	var hit: Array = []
	for x in [16, 17, 18]:
		hit.append(_drop(w, B, Tank.new(), x))
	var below := _drop(w, B, Tank.new(), 17, 11) # a neighbour on the next row
	var far := _drop(w, B, Tank.new(), 19) # 2 away: outside
	var mine := _drop(w, A, Tank.new(), 17, 9) # its own side is spared
	var hp0 := {}
	for k in w.units.keys():
		hp0[k] = _hp(w, k)
	var ev := w.fire_item(A, m, Vector2i(17, 10))
	assert_false(ev.is_empty(), "fired")
	for k in hit + [below]:
		var t := MapWar.key_to_hex(k)
		assert_eq(int(hp0[k]) - _hp(w, k), MapWar.terrain_adjusted(w.units[k]["card"], t, 6), "%s takes 6 (less mountain cover)" % k)
	assert_eq(_hp(w, far), int(hp0[far]), "2 hexes away: untouched")
	assert_eq(_hp(w, mine), int(hp0[mine]), "own cards are spared")
	assert_eq(p.MoneySupply, 100 - 30, "costs 30 Money")
	assert_false(p.Hand.has(m), "used up")
	assert_true(p.Graveyard.has(m), "to the graveyard")
	assert_eq(ev["entries"].size(), 4, "a log entry per card hit")
	assert_eq(ev["from"], Vector2i(11, 10))

func test_missile_hits_flags_and_destroys_cards():
	var w := _war()
	var m := Missile.new()
	(w.players[A] as Player).Hand = [m]
	_drop(w, A, Airport.new(), 13)
	var weak := Infantry.new()
	weak.HitPoints = 2
	var wk := _drop(w, B, weak, 21)
	var hp_b: int = (w.players[B] as Player).HitPoints
	var ev := w.fire_item(A, m, w.campaign.capital_site(B))
	assert_false(w.units.has(wk), "the Infantry next to the flag dies")
	var destroyed := 0
	var direct := 0
	for e in ev["entries"]:
		destroyed += (e["destroyed"] as Array).size()
		if bool(e["direct"]):
			direct += 1
	assert_eq(destroyed, 1, "reported as destroyed")
	assert_eq(direct, 1, "the flag is hit")
	assert_eq((w.players[B] as Player).HitPoints, hp_b - 6 - weak.BioCost, "6 to the flag, and the lost card's BioCost")

func test_items_are_halved_by_an_enemy_interceptor():
	var w := _war()
	var m := Missile.new()
	(w.players[A] as Player).Hand = [m]
	_drop(w, A, Barracks.new(), 11)
	var tk := _drop(w, B, Tank.new(), 16)
	var icp := Interceptor.new()
	_drop(w, B, icp, 19) # 3 from the target
	var b: Player = w.players[B]
	var hp0 := _hp(w, tk)
	var ev := w.fire_item(A, m, Vector2i(16, 10))
	assert_eq(ev["intercept_from"], Vector2i(19, 10), "shot down by the Interceptor")
	assert_eq(int(ev["damage"]), 3, "half damage")
	assert_eq(hp0 - _hp(w, tk), MapWar.terrain_adjusted(w.units[tk]["card"], Vector2i(16, 10), 3))
	assert_eq(icp.HitPoints, 20 - 2, "the Interceptor pays 2 HP")
	assert_eq(b.MoneySupply, 100 - 6, "its owner 6 Money")

func test_a_broke_interceptor_does_not_stop_items():
	var w := _war()
	var m := Missile.new()
	(w.players[A] as Player).Hand = [m]
	_drop(w, A, Barracks.new(), 11)
	_drop(w, B, Interceptor.new(), 17)
	(w.players[B] as Player).MoneySupply = 3
	var ev := w.fire_item(A, m, Vector2i(16, 10))
	assert_eq(ev["intercept_from"], Vector2i(-1, -1), "under 6 Money: no interception")
	assert_eq(int(ev["damage"]), 6)

# ------------------------------------------------------------------ nukes
func test_nuke_fires_from_bomber_jets_eight_hexes():
	var w := _war()
	var n := Nuke.new()
	(w.players[A] as Player).Hand = [n]
	(w.players[A] as Player).MoneySupply = 200
	_drop(w, A, Airport.new(), 11)
	assert_ne(w.can_fire_item(A, n, Vector2i(15, 10)), "", "Nukes need a Bomber Jet, not an Airport")
	_drop(w, A, BomberJet.new(), 13)
	assert_eq(w.can_fire_item(A, n, Vector2i(21, 10)), "", "8 hexes from the Bomber Jet")
	assert_ne(w.can_fire_item(A, n, Vector2i(22, 10)), "", "not 9")
	(w.players[A] as Player).MoneySupply = 119
	assert_ne(w.can_fire_item(A, n, Vector2i(21, 10)), "", "it costs 120 Money")

func test_nuke_blast_and_wasteland():
	var w := _war()
	var n := Nuke.new()
	var p: Player = w.players[A]
	p.Hand = [n]
	p.MoneySupply = 200
	_drop(w, A, BomberJet.new(), 13)
	var t := Vector2i(17, 10)
	var edge := _drop(w, B, Tank.new(), 21) # 4 away
	var out := _drop(w, C, Tank.new(), 26) # 9 away
	var hp_edge := _hp(w, edge)
	var hp_b: int = (w.players[B] as Player).HitPoints
	var ev := w.fire_item(A, n, t)
	assert_true(bool(ev["nuke"]))
	assert_eq(p.MoneySupply, 80, "costs 120 Money")
	var lost := 0
	if not w.units.has(edge):
		lost = Tank.new().BioCost
	else:
		assert_eq(hp_edge - _hp(w, edge), MapWar.terrain_adjusted(w.units[edge]["card"], Vector2i(21, 10), 8), "4 hexes out: 20 - 4 x 3 = 8")
	assert_eq(_hp(w, out), Tank.new().HitPoints, "beyond 4 hexes: untouched")
	assert_eq((w.players[B] as Player).HitPoints, hp_b - 11 - lost, "B's flag (3 hexes away) takes 20 - 3 x 3 = 11")
	var waste := 0
	for k in w.scars.keys():
		if str(w.scars[k]) == "wasteland":
			waste += 1
			assert_lte(MapCampaign.hex_distance(MapWar.key_to_hex(str(k)), t), 1)
	assert_eq(waste, 7, "the 7 hexes at its heart become wasteland")
	assert_eq((ev["wasteland"] as Array).size(), 7)

func test_nuke_damage_falls_off_with_distance():
	var n := Nuke.new()
	assert_eq([n.damage_at(0), n.damage_at(1), n.damage_at(2), n.damage_at(3), n.damage_at(4)], [20, 17, 14, 11, 8], "3 less per hex")
	assert_eq([n.damage_at(0, true), n.damage_at(4, true)], [10, 4], "an interception halves what reaches each hex")
	assert_eq(Missile.new().damage_at(1), 6, "Missiles don't fall off")
	var w := _war()
	(w.players[A] as Player).Hand = [n]
	(w.players[A] as Player).MoneySupply = 200
	_drop(w, A, BomberJet.new(), 13)
	var t := Vector2i(17, 10)
	var hp0 := {}
	for x in [17, 18, 19]:
		var k := _drop(w, B, Tank.new(), x)
		hp0[k] = _hp(w, k)
	var ev := w.fire_item(A, n, t)
	for e in ev["entries"]:
		if bool(e["direct"]):
			continue
		var to: Vector2i = e["to"]
		var want: int = MapWar.terrain_adjusted(Tank.new(), to, 20 - 3 * MapCampaign.hex_distance(to, t))
		assert_eq(int(e["damage"]), want, "%s: %d hexes out" % [str(to), MapCampaign.hex_distance(to, t)])

func test_wasteland_burns_units_that_start_their_turn_there():
	var w := _war()
	var t := Vector2i(17, 10)
	w.scars[MapCampaign.key_of(t.x, t.y)] = "wasteland"
	var tank := Tank.new()
	var k := _drop(w, B, tank, 17)
	var wall := Wall.new()
	_drop(w, B, wall, 18)
	w.scars[MapCampaign.key_of(18, 10)] = "wasteland"
	var weak := Infantry.new()
	weak.HitPoints = 2
	var wk := _drop(w, B, weak, 16)
	w.scars[wk] = "wasteland"
	var hp0 := tank.HitPoints
	var wall0 := wall.HitPoints
	var b_hp: int = (w.players[B] as Player).HitPoints
	var res := w.fallout(B)
	assert_eq(tank.HitPoints, hp0 - MapWar.FALLOUT_DAMAGE, "units there lose 3")
	assert_eq(wall.HitPoints, wall0, "buildings don't")
	assert_false(w.units.has(wk), "a unit at 2 HP is lost")
	assert_eq((w.players[B] as Player).HitPoints, b_hp, "costing its nation no HP")
	assert_eq(res.size(), 2)
	assert_true(w.units.has(k))
	w.fallout(A)
	assert_eq(tank.HitPoints, hp0 - MapWar.FALLOUT_DAMAGE, "only on its own nation's turn")
	w.begin_turn(B)
	assert_eq(tank.HitPoints, hp0 - 2 * MapWar.FALLOUT_DAMAGE, "begin_turn applies it")
	assert_eq(w.last_fallout.size(), 1)

func test_buildings_destroyed_by_a_nuke_heart_leave_wasteland_not_ruins():
	var w := _war()
	var n := Nuke.new()
	(w.players[A] as Player).Hand = [n]
	(w.players[A] as Player).MoneySupply = 200
	_drop(w, A, BomberJet.new(), 13)
	var wall := Wall.new()
	wall.HitPoints = 5
	_drop(w, B, wall, 17)
	var wall2 := Wall.new()
	wall2.HitPoints = 5
	_drop(w, B, wall2, 19) # 2 from the heart
	w.fire_item(A, n, Vector2i(17, 10))
	assert_eq(w.scar_at(Vector2i(17, 10)), "wasteland")
	assert_eq(w.scar_at(Vector2i(19, 10)), "ruins", "further out a building leaves ruins")

# ------------------------------------------------------------ setup, AI, saves
func test_nations_start_with_their_items():
	var c := MapCampaign.new("State Troops")
	var w := MapWar.new()
	var gs = load("res://GodotHelpers/GameState.gd").new()
	w.setup(c, func(nm): return gs.make_player_by_name(nm), gs.make_player_by_name("State Troops", true))
	var want := {"Coalition Army": [1, 3], "Corporate Troops": [2, 5], "Horde": [3, 2], "State Troops": [0, 2], "Insurgents": [0, 0]}
	for nm in want.keys():
		var p: Player = w.players[nm]
		var nukes := 0
		var missiles := 0
		for card in p.DrawPile + p.DiscardPile + p.Hand:
			if card is Nuke:
				nukes += 1
			elif card is Missile:
				missiles += 1
		assert_eq([nukes, missiles], want[nm], "%s: Nukes and Missiles" % nm)
	assert_eq(int((w.deck_weights["Horde"] as Dictionary).get("Nuke", 0)), 3, "and their shops offer them")
	gs.free()

func test_ai_fires_a_missile_at_a_cluster():
	var w := _war()
	var m := Missile.new()
	(w.players[A] as Player).Hand = [m]
	_drop(w, A, Barracks.new(), 11)
	for x in [15, 16, 17]:
		_drop(w, B, Tank.new(), x)
	_drop(w, B, Tank.new(), 16, 11)
	var pick := w.ai_pick_item(A)
	assert_false(pick.is_empty(), "worth firing")
	assert_lte(MapCampaign.hex_distance(pick["target"], Vector2i(16, 10)), 1, "aimed at the cluster")
	var fired := w.ai_use_items(A)
	assert_eq(fired.size(), 1, "fired once (it had one)")
	assert_eq(w.ai_pick_item(A), {}, "nothing left to fire")

func test_ai_keeps_items_without_a_worthwhile_target():
	var w := _war()
	var m := Missile.new()
	(w.players[A] as Player).Hand = [m]
	_drop(w, A, Barracks.new(), 11)
	var inf := Infantry.new()
	inf.HitPoints = 3
	_drop(w, B, inf, 24) # out of reach
	assert_eq(w.ai_pick_item(A), {}, "nothing in reach worth it")
	var placed := w.ai_build(A)
	for pl in placed:
		assert_false(pl[0] is Item, "ai_build never places items")
	assert_true((w.players[A] as Player).Hand.has(m), "still in hand")

func test_scars_survive_a_save():
	var w := _war()
	w.scars[MapCampaign.key_of(16, 10)] = "ruins"
	w.scars[MapCampaign.key_of(17, 10)] = "wasteland"
	var w2 := MapWar.from_data(w.to_data(), w.campaign, _plain_player, Player.new(100, 200, 200))
	assert_eq(w2.scar_at(Vector2i(16, 10)), "ruins")
	assert_eq(w2.scar_at(Vector2i(17, 10)), "wasteland")
