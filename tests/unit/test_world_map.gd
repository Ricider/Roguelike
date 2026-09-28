extends GutTest
# GUT suite for the Civ-style world map: Earth grid data + nation starts.
# Map-only scope: verifies grid shape, terrain coverage, and that every
# sample nation sits on a distinct land tile matching its region.

func test_world_map_dimensions():
	assert_eq(WorldMap.GRID_W, 60, "grid width 60")
	assert_eq(WorldMap.GRID_H, 30, "grid height 30")
	assert_eq(WorldMap.ROWS.size(), 30, "30 rows")
	for i in range(WorldMap.ROWS.size()):
		assert_eq((WorldMap.ROWS[i] as String).length(), 60, "row %d is 60 chars" % i)

func test_world_map_valid_terrain_chars():
	var valid := [".", "g", "d", "m", "s", "j"]
	for y in range(WorldMap.GRID_H):
		var row: String = WorldMap.ROWS[y]
		for x in range(WorldMap.GRID_W):
			assert_true(valid.has(row.substr(x, 1)), "tile (%d,%d) valid" % [x, y])

func test_world_map_terrain_coverage():
	var seen := {}
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			seen[WorldMap.terrain_at(x, y)] = true
	for t in ["ocean", "grassland", "desert", "mountain", "snow", "jungle"]:
		assert_true(seen.has(t), "terrain present: %s" % t)

func test_world_map_nation_count_and_starts():
	var nations: Array = WorldMap.nations()
	assert_eq(nations.size(), 8, "8 sample nations")
	var spots := {}
	for n in nations:
		var d := n as Dictionary
		var x := int(d["x"])
		var y := int(d["y"])
		assert_true(WorldMap.in_bounds(x, y), "%s in bounds" % d["name"])
		assert_true(WorldMap.is_land(x, y), "%s capital on land" % d["name"])
		var key := "%d,%d" % [x, y]
		assert_false(spots.has(key), "%s start is distinct" % d["name"])
		spots[key] = true
		assert_eq(WorldMap.nation_start(str(d["name"])), Vector2i(x, y), "%s lookup" % d["name"])

func test_world_map_expected_capitals():
	assert_eq(WorldMap.nation_start("Insurgents"), Vector2i(41, 9), "Kabul")
	assert_eq(WorldMap.nation_start("State Troops"), Vector2i(37, 9), "Baghdad")
	assert_eq(WorldMap.nation_start("Fundamentalists"), Vector2i(29, 6), "London")
	assert_eq(WorldMap.nation_start("Mercenaries"), Vector2i(33, 14), "Kinshasa")
	assert_eq(WorldMap.nation_start("Peace Keepers"), Vector2i(18, 8), "New York")
	assert_eq(WorldMap.nation_start("Horde"), Vector2i(36, 6), "Moscow")
	assert_eq(WorldMap.nation_start("Coalition Army"), Vector2i(30, 7), "Paris")
	assert_eq(WorldMap.nation_start("Corporate Troops"), Vector2i(53, 9), "Tokyo")

func test_world_map_continents_and_oceans():
	# Spot-check the Earth likeness: land where continents are, water in oceans.
	for spot in [Vector2i(10, 7), Vector2i(30, 7), Vector2i(45, 6), Vector2i(50, 20), Vector2i(32, 17)]:
		assert_true(WorldMap.is_land(spot.x, spot.y), "land at (%d,%d)" % [spot.x, spot.y])
	for spot in [Vector2i(24, 10), Vector2i(56, 15), Vector2i(5, 20)]:
		assert_false(WorldMap.is_land(spot.x, spot.y), "ocean at (%d,%d)" % [spot.x, spot.y])

func test_world_map_nation_at_and_unknown():
	var n := WorldMap.nation_at(37, 9)
	assert_eq(str(n.get("name")), "State Troops", "nation_at Baghdad")
	assert_true(WorldMap.nation_at(24, 10).is_empty(), "no nation mid-Atlantic")
	assert_true(WorldMap.nation_by_name("Nope").is_empty(), "unknown nation empty")
	assert_eq(WorldMap.nation_start("Nope"), Vector2i(-1, -1), "unknown start sentinel")
	assert_eq(WorldMap.terrain_at(-1, 0), "ocean", "out of bounds is ocean")
