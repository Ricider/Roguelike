extends GutTest
# GUT suite for the selectable campaign maps (world + regional) and terrain rules.

func after_each():
	WorldMap.use_map("world") # static map state: always hand the world map back

func test_every_map_loads_with_eight_capitals_on_land():
	for id in WorldMap.MAPS:
		assert_true(WorldMap.use_map(id), "%s loads" % id)
		assert_eq(WorldMap.ROWS.size(), WorldMap.GRID_H, "%s rows" % id)
		for r in WorldMap.ROWS:
			assert_eq((r as String).length(), WorldMap.GRID_W, "%s row width" % id)
		var seen := {}
		assert_eq(WorldMap.nations().size(), 8, "%s has all 8 factions" % id)
		for n in WorldMap.nations():
			var d := n as Dictionary
			var x := int(d["x"])
			var y := int(d["y"])
			assert_true(WorldMap.is_land(x, y), "%s: %s capital on land" % [id, d["capital"]])
			assert_false(seen.has(Vector2i(x, y)), "%s: %s capital has its own hex" % [id, d["capital"]])
			seen[Vector2i(x, y)] = true

func test_every_map_starts_a_playable_campaign():
	for id in WorldMap.MAPS:
		WorldMap.use_map(id)
		var c := MapCampaign.new("State Troops")
		assert_eq(c.alive_nations().size(), 8, "%s: all nations start with land" % id)
		for n in WorldMap.nations():
			var nm := str((n as Dictionary)["name"])
			assert_false(c.neighbors_of(nm).is_empty(), "%s: %s has a neighbour to fight" % [id, nm])
			assert_true(_pieces_hold_cities(c, nm), "%s: every piece of %s holds one of its cities" % [id, nm])

func test_regional_maps_do_not_wrap():
	WorldMap.use_map("europe")
	assert_false(WorldMap.WRAPS, "Europe has edges")
	var edge := Vector2i(0, 10)
	for nb in MapCampaign.wrapped_neighbors(edge):
		assert_true((nb as Vector2i).x <= 1, "no neighbour on the far side")
	assert_eq(MapCampaign.hex_distance(Vector2i(0, 10), Vector2i(WorldMap.GRID_W - 1, 10)), WorldMap.GRID_W - 1, "straight distance, no wrap")
	WorldMap.use_map("world")
	assert_true(WorldMap.WRAPS, "the world wraps")

func test_regional_capitals_at_real_cities():
	WorldMap.use_map("east_asia")
	var tokyo := WorldMap.nation_start("Corporate Troops")
	assert_true(MapCampaign.hex_distance(tokyo, WorldMap.hex_for_latlon(35.68, 139.69)) <= 1, "Tokyo where Tokyo is")
	WorldMap.use_map("europe")
	var paris := WorldMap.nation_start("Coalition Army")
	assert_true(MapCampaign.hex_distance(paris, WorldMap.hex_for_latlon(48.86, 2.35)) <= 1, "Paris where Paris is")
	var sea := WorldMap.hex_for_latlon(55.0, 3.0) # North Sea
	assert_false(WorldMap.is_land(sea.x, sea.y), "North Sea is water")

func test_picking_on_a_regional_map():
	WorldMap.use_map("byzantium")
	var view := WorldMapView.new()
	add_child_autofree(view)
	view.size = Vector2(1400, 800)
	view.center_on(Vector2i(10, 10), 2.0)
	view.pan_by(Vector2(5000, 5000)) # clamps at the map edge instead of wrapping
	var m: Array = view.metrics()
	var hits := 0
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var p: Vector2 = view.screen_pos(Vector2i(x, y), m)
			if p.x > 0 and p.x < view.size.x and p.y > 0 and p.y < view.size.y:
				assert_eq(view.tile_at_point(p), Vector2i(x, y), "hex %d,%d picks itself" % [x, y])
				hits += 1
	assert_true(hits > 50, "a good chunk of the map is on screen")
	assert_eq(view.tile_at_point(Vector2(-500, -500)), Vector2i(-1, -1), "off-map picks nothing")

func test_campaign_save_remembers_its_map():
	WorldMap.use_map("east_asia")
	var c := MapCampaign.new("Corporate Troops")
	var d := c.to_data()
	WorldMap.use_map("world")
	var c2 := MapCampaign.from_data(d)
	assert_eq(WorldMap.MAP_ID, "east_asia", "loading switches back to the saved map")
	assert_false(c2.has_meta("restarted"), "same grid: not restarted")
	assert_eq(c2.owner, c.owner, "territory restored")

# --- mountain cover -----------------------------------------------------------
func _mountain_and_plain() -> Array:
	var mountain := Vector2i(-1, -1)
	var plain := Vector2i(-1, -1)
	for y in range(2, WorldMap.GRID_H - 2):
		for x in range(2, WorldMap.GRID_W - 2):
			var t := WorldMap.terrain_at(x, y)
			if t == WorldMap.MOUNTAIN and mountain.x < 0:
				mountain = Vector2i(x, y)
			elif t == WorldMap.GRASSLAND and plain.x < 0:
				plain = Vector2i(x, y)
	return [mountain, plain]

func _hit(target_card: Card, at: Vector2i) -> int:
	var c := MapCampaign.new("Horde")
	var w := MapWar.new()
	w.setup(c, func(_nm): return Player.new(100, 200, 200), Player.new(100, 200, 200))
	for k in w.units.keys().duplicate():
		w._remove(k)
	w._put("Coalition Army", target_card, at)
	var shooter_hex := MapCampaign.wrapped_neighbors(at)[0] as Vector2i
	w._put("Horde", Tank.new(), shooter_hex)
	var log := w.fire(MapCampaign.key_of(shooter_hex.x, shooter_hex.y))
	return int(log[0]["damage"])

func test_ground_units_on_mountains_take_one_less_damage():
	var spots := _mountain_and_plain()
	assert_true(spots[0].x >= 0 and spots[1].x >= 0, "found a mountain and a plain hex")
	var tank_dmg := Tank.new().Damage
	assert_eq(_hit(Infantry.new(), spots[1]), tank_dmg, "full damage on grassland")
	assert_eq(_hit(Infantry.new(), spots[0]), tank_dmg - 1, "1 less on a mountain")
	# flying units get no cover (a non-ranged Tank still halves vs Flying)
	assert_eq(_hit(Drone.new(), spots[0]), tank_dmg / 2, "drones get no mountain cover")
	assert_eq(MapWar.terrain_adjusted(Infantry.new(), spots[0], 1), 1, "never below 1")
	assert_eq(MapWar.terrain_adjusted(Wall.new(), spots[0], 5), 5, "buildings/walls get no cover")

func _pieces_hold_cities(c: MapCampaign, nm: String) -> bool:
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
		var ok := false
		for sd in seeds:
			if piece.has(sd):
				ok = true
		if not ok:
			return false
	return true
