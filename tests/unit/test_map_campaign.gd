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
		assert_true(_every_piece_has_a_city(c, nm), "%s: every piece of territory holds one of its cities" % nm)
	for k in c.owner.keys():
		var parts := str(k).split(",")
		assert_true(WorldMap.is_land(int(parts[0]), int(parts[1])), "owned tile %s is land" % k)

func test_wilderness_and_bering_bridge():
	var c := MapCampaign.new("Horde")
	var last := WorldMap.GRID_W - 1
	assert_true(WorldMap.is_land(30, WorldMap.GRID_H - 1), "Antarctic shelf is land")
	assert_eq(c.owner_of(30, WorldMap.GRID_H - 1), "", "Antarctica is unclaimed wilderness")
	var nz := WorldMap.hex_for_latlon(-42.0, 172.5)
	assert_true(WorldMap.is_land(nz.x, nz.y), "New Zealand is land")
	assert_eq(c.owner_of(nz.x, nz.y), "", "New Zealand is unclaimed wilderness")
	# the Bering land bridge: a row where both map edges are land
	var by := -1
	for y in range(WorldMap.GRID_H):
		if WorldMap.is_land(0, y) and WorldMap.is_land(last, y):
			by = y
			break
	assert_true(by >= 0, "Bering bridge exists at the wrap seam")
	assert_true(c.owner_of(0, by) != "", "Bering bridge west owned")
	assert_true(c.owner_of(last, by) != "", "Bering bridge east owned")
	assert_true(MapCampaign.wrapped_neighbors(Vector2i(0, by)).has(Vector2i(last, by)), "wrap adjacency")

func test_neighbors_symmetric_and_sane():
	var c := MapCampaign.new("State Troops")
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		assert_false(c.neighbors_of(nm).is_empty(), "%s has a neighbor" % nm)
		for m in c.neighbors_of(nm):
			assert_true(c.neighbors_of(m).has(nm), "symmetric %s/%s" % [nm, m])
	# North America (Corporate Troops) meets Asia only at the Bering bridge, where Horde holds Siberia
	var ct: Array = c.neighbors_of("Corporate Troops")
	assert_true(ct.has("Horde"), "Alaska borders Russia over the Bering bridge")
	assert_true(ct.has("Peace Keepers"), "North America meets South America at Panama")
	assert_eq(ct.size(), 2, "no Atlantic border: Corporate Troops don't touch Europe or Africa")
	assert_true(c.neighbors_of("Peace Keepers").has("Insurgents"), "Australia is reachable through New Guinea")
	# Japan's main islands (east of Korea) are owned, so they can be fought over
	# (a lone far-north islet can stay wilderness, like New Zealand)
	var japan_owned := 0
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var ll := WorldMap.hex_latlon(x, y)
			if WorldMap.is_land(x, y) and ll.x > 31.0 and ll.x < 41.0 and ll.y > 131.0 and ll.y < 146.0 and c.owner_of(x, y) != "":
				japan_owned += 1
	assert_true(japan_owned > 0, "Japan is owned and reachable")

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
	# Hex map: a lone hex has 6 edges; a 3-hex row shares 2 internal edges (3*6 - 2*2)
	assert_eq(c.border_edges("Horde").size(), 6, "lone hex borders all 6 sides")
	assert_eq(c.border_edges("Coalition Army").size(), 14, "3-hex row has 14 edges")
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
	var hs := c.capital_site("Horde")
	assert_eq(c.capital_holder_at(hs.x, hs.y), "Horde", "living flag reported")
	for t in [Vector2i(30, 7), Vector2i(31, 7)]:
		assert_ne(c.capital_holder_at(t.x, t.y), "Coalition Army", "dead nation flies no flag")

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

func test_old_grid_save_restarts_campaign():
	var old := {"player_nation": "Horde", "owner": {"36,6": "Horde"}} # 60x30-era save, no grid info
	var c := MapCampaign.from_data(old)
	assert_eq(c.player_nation, "Horde", "same nation")
	assert_true(c.has_meta("restarted"), "flagged as restarted")
	assert_eq(c.alive_nations().size(), 8, "fresh world, not the stale layout")


# Every connected piece of a nation's starting land contains its capital or a seed city
# (Peace Keepers start on two continents: South America and Australia).
func _every_piece_has_a_city(c: MapCampaign, nm: String) -> bool:
	var seeds: Array = WorldMap.nation_seeds(nm)
	var seen := {}
	for t in c.tiles_of(nm):
		if seen.has(t):
			continue
		var piece: Array = [t]
		seen[t] = true
		var i := 0
		while i < piece.size():
			for nb in MapCampaign.wrapped_neighbors(piece[i]):
				if not seen.has(nb) and c.owner_of(nb.x, nb.y) == nm:
					seen[nb] = true
					piece.append(nb)
			i += 1
		var has_city := false
		for sd in seeds:
			if piece.has(sd):
				has_city = true
		if not has_city:
			return false
	return true
