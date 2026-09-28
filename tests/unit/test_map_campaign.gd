extends GutTest
# GUT suite for MapCampaign: starting territory, neighbor-only war, and
# border-gore-free conquest (1 tile per 10 HP from the shared border).

func test_starting_territory_valid():
	var c := MapCampaign.new("State Troops")
	assert_eq(c.player_nation, "State Troops", "player nation set")
	assert_eq(c.alive_nations().size(), 8, "all 8 nations start alive")
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		assert_true(c.is_alive(nm), "%s alive" % nm)
		assert_eq(c.owner_of(int(d["x"]), int(d["y"])), nm, "%s owns its capital" % nm)
		assert_true(c.is_territory_connected(nm), "%s starts connected" % nm)
	for k in c.owner.keys():
		var parts := str(k).split(",")
		assert_true(WorldMap.is_land(int(parts[0]), int(parts[1])), "owned tile %s is land" % k)

func test_wilderness_and_bering_bridge():
	var c := MapCampaign.new("Horde")
	assert_eq(c.owner_of(30, 29), "", "Antarctica is unclaimed wilderness")
	assert_eq(c.owner_of(58, 21), "", "New Zealand is unclaimed wilderness")
	assert_true(c.owner_of(0, 4) != "", "Bering bridge west owned")
	assert_eq(c.owner_of(0, 4), c.owner_of(59, 4), "Bering wraps east-west")
	assert_true(MapCampaign.wrapped_neighbors(Vector2i(0, 4)).has(Vector2i(59, 4)), "wrap adjacency")

func test_neighbors_symmetric_and_sane():
	var c := MapCampaign.new("State Troops")
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		assert_false(c.neighbors_of(nm).is_empty(), "%s has a neighbor" % nm)
		for m in c.neighbors_of(nm):
			assert_true(c.neighbors_of(m).has(nm), "symmetric %s/%s" % [nm, m])
	assert_eq(c.neighbors_of("Peace Keepers"), ["Corporate Troops"], "Americas link Asia only")
	assert_true(c.neighbors_of("Corporate Troops").has("Insurgents"), "Japan borders mainland")
	assert_false(c.neighbors_of("Peace Keepers").has("Horde"), "no NYC-Moscow border")

func test_can_attack_rules():
	var c := MapCampaign.new("State Troops")
	assert_true(c.can_attack("Insurgents"), "neighbor attackable")
	assert_false(c.can_attack("State Troops"), "cannot attack self")
	assert_false(c.can_attack("Peace Keepers"), "non-neighbor not attackable")
	assert_false(c.can_attack(""), "wilderness not attackable")
	assert_false(c.can_attack("No Such Nation"), "unknown not attackable")
	# Dead nations cannot be attacked (synthetic 1-tile remnant, real land).
	var skirmish := MapCampaign.new("Horde")
	skirmish.owner = {"30,7": "Horde", "31,7": "Coalition Army"}
	assert_true(skirmish.can_attack("Coalition Army"), "remnant attackable first")
	assert_eq(skirmish.conquer("Horde", "Coalition Army", 50), 1, "last tile taken")
	assert_false(skirmish.is_alive("Coalition Army"), "remnant eliminated")
	assert_false(skirmish.can_attack("Coalition Army"), "dead nation not attackable")

func test_border_edges_valid():
	var c := MapCampaign.new("State Troops")
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		var edges: Array = c.border_edges(nm)
		assert_false(edges.is_empty(), "%s has border edges" % nm)
		for e in edges:
			var entry := e as Array
			var t := entry[0] as Vector2i
			var d := entry[1] as Vector2i
			assert_eq(c.owner_of(t.x, t.y), nm, "edge tile owned by %s" % nm)
			var nx: int = (t.x + d.x + WorldMap.GRID_W) % WorldMap.GRID_W
			var ny: int = t.y + d.y
			var o := ""
			if ny >= 0 and ny < WorldMap.GRID_H:
				o = c.owner_of(nx, ny)
			assert_true(o != nm, "edge %s faces non-%s land" % [t, nm])

func test_border_edges_synthetic_pocket():
	var c := MapCampaign.new("Horde")
	c.owner = {
		"32,6": "Horde",
		"31,7": "Coalition Army", "32,7": "Coalition Army", "33,7": "Coalition Army",
	}
	assert_eq(c.border_edges("Horde").size(), 4, "lone tile borders all 4 sides")
	assert_eq(c.border_edges("Coalition Army").size(), 8, "3-tile row has 8 edges")
	assert_true(c.border_edges("Insurgents").is_empty(), "landless nation has no edges")

func test_tiles_for_hp():
	assert_eq(MapCampaign.tiles_for_hp(0), 1, "min 1 tile")
	assert_eq(MapCampaign.tiles_for_hp(9), 1, "9 HP -> 1")
	assert_eq(MapCampaign.tiles_for_hp(10), 1, "10 HP -> 1")
	assert_eq(MapCampaign.tiles_for_hp(35), 3, "35 HP -> 3")
	assert_eq(MapCampaign.tiles_for_hp(100), 10, "100 HP -> 10")

func test_conquer_exact_border_transfer():
	var c := MapCampaign.new("State Troops")
	var before_w := c.tile_count("State Troops")
	var before_l := c.tile_count("Insurgents")
	var loser_before := {}
	for t in c.tiles_of("Insurgents"):
		loser_before[t] = true
	var winner_before := {}
	for t in c.tiles_of("State Troops"):
		winner_before[t] = true
	var moved: int = c.conquer("State Troops", "Insurgents", 35)
	assert_eq(moved, 3, "35 HP takes exactly 3")
	assert_eq(c.tile_count("State Troops"), before_w + 3, "winner gains 3")
	assert_eq(c.tile_count("Insurgents"), before_l - 3, "loser loses 3")
	for t in c.tiles_of("State Troops"):
		if not winner_before.has(t):
			assert_true(loser_before.has(t), "gained %s was loser land" % t)
	assert_true(c.is_territory_connected("State Troops"), "winner stays connected")
	assert_true(c.is_territory_connected("Insurgents"), "loser stays connected")

func test_conquer_caps_at_elimination():
	# Synthetic pocket: winner borders only the middle of a 3-tile loser
	# row, so the first take must split it (last-resort rule) and the war
	# still wipes the loser instead of stalling at zero progress.
	var c := MapCampaign.new("Horde")
	c.owner = {
		"32,6": "Horde",
		"31,7": "Coalition Army", "32,7": "Coalition Army", "33,7": "Coalition Army",
	}
	assert_true(c.can_attack("Coalition Army"), "pocket attackable")
	var moved: int = c.conquer("Horde", "Coalition Army", 9999)
	assert_eq(moved, 3, "takes all 3 despite the split")
	assert_false(c.is_alive("Coalition Army"), "loser eliminated")
	assert_true(c.is_territory_connected("Horde"), "winner connected after wipe")

func test_conquer_real_map_makes_progress():
	var c := MapCampaign.new("Horde")
	var before := c.tile_count("Coalition Army")
	var moved: int = c.conquer("Horde", "Coalition Army", 9999)
	assert_true(moved > 0, "war vs neighbor always takes at least 1")
	assert_true(moved <= before, "cannot take more than loser holds")
	assert_eq(c.tile_count("Coalition Army"), before - moved, "counts balance")

func test_capital_site_fresh():
	var c := MapCampaign.new("Horde")
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		var home := Vector2i(int(d["x"]), int(d["y"]))
		assert_eq(c.capital_site(nm), home, "%s flag starts home" % nm)
		assert_eq(c.capital_holder_at(home.x, home.y), nm, "%s holds home" % nm)

func test_capital_site_follows_borders():
	# Horde loses its home tile (36,6) but keeps (35,6): flag must move there.
	var c := MapCampaign.new("Horde")
	c.owner = {"36,6": "Horde", "35,6": "Horde", "37,6": "Insurgents"}
	assert_eq(c.conquer("Insurgents", "Horde", 10), 1, "home tile falls")
	assert_eq(c.capital_site("Horde"), Vector2i(35, 6), "flag retreats to (35,6)")
	assert_eq(c.owner_of(35, 6), "Horde", "flag inside friendly borders")
	assert_eq(c.capital_holder_at(35, 6), "Horde", "holder follows flag")
	assert_eq(c.capital_holder_at(36, 6), "", "no flag on lost home")

func test_capital_site_dead_nation():
	var c := MapCampaign.new("Horde")
	c.owner = {"30,7": "Horde", "31,7": "Coalition Army"}
	c.conquer("Horde", "Coalition Army", 50)
	assert_eq(c.capital_site("Coalition Army"), WorldMap.nation_start("Coalition Army"), "dead flag stays home")
	assert_eq(c.capital_holder_at(30, 7), "", "dead nation flies no flag at Paris")
	assert_eq(c.capital_holder_at(31, 7), "Horde", "living flag reported")

func test_map_battle_active_flag():
	var gs = load("res://GodotHelpers/GameState.gd").new()
	gs.start_map_campaign("Horde")
	assert_true(gs.map_mode, "campaign is map mode")
	assert_false(gs.map_battle_active(), "no battle on fresh map")
	assert_true(gs.map_campaign is MapCampaign, "campaign exists")
	gs.start_map_battle("Insurgents")
	assert_true(gs.map_battle_active(), "war marks battle active")
	assert_eq(gs.run_enemies.size(), 1, "one war target")
	gs.end_map_battle()
	assert_false(gs.map_battle_active(), "back on map clears battle")
	assert_true(gs.run_enemies.is_empty(), "no stale war target")
	assert_true(gs.map_mode, "still map mode after battle")
	gs.free()

func test_has_won_and_lost():
	var c := MapCampaign.new("Horde")
	assert_false(c.has_won(), "fresh campaign not won")
	assert_false(c.has_lost(), "fresh campaign not lost")
	for k in c.owner.keys():
		c.owner[k] = "Horde"
	assert_true(c.has_won(), "all tiles -> won")
	for k in c.owner.keys():
		c.owner[k] = "Insurgents"
	assert_true(c.has_lost(), "no tiles -> lost")
	assert_false(c.has_won(), "lost means not won")

func test_serialize_roundtrip():
	var c := MapCampaign.new("Mercenaries")
	c.conquer("Mercenaries", "State Troops", 40)
	var d := c.to_data()
	var c2 := MapCampaign.from_data(d)
	assert_eq(c2.player_nation, "Mercenaries", "nation survives")
	assert_eq(c2.owner, c.owner, "ownership survives")
	assert_eq(c2.tile_count("Mercenaries"), c.tile_count("Mercenaries"), "counts survive")
