extends GutTest
# GUT suite for the Civ-style world map: Earth grid data + nation starts.
# Map-only scope: verifies grid shape, terrain coverage, and that every
# sample nation sits on a distinct land tile matching its region.

func test_world_map_dimensions():
	assert_eq(WorldMap.GRID_W, 90, "grid width 90")
	assert_eq(WorldMap.GRID_H, 40, "grid height 40")
	assert_eq(WorldMap.ROWS.size(), WorldMap.GRID_H, "one row per grid line")
	for i in range(WorldMap.ROWS.size()):
		assert_eq((WorldMap.ROWS[i] as String).length(), WorldMap.GRID_W, "row %d spans the grid" % i)

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

# Real coordinates of each capital; the generator puts it on (or right next to)
# the hex containing that point.
const CAPITAL_LATLON := {
	"Insurgents": Vector2(34.53, 69.17), "State Troops": Vector2(33.31, 44.36),
	"Fundamentalists": Vector2(51.51, -0.13), "Mercenaries": Vector2(-4.32, 15.31),
	"Peace Keepers": Vector2(40.71, -74.01), "Horde": Vector2(55.76, 37.62),
	"Coalition Army": Vector2(48.86, 2.35), "Corporate Troops": Vector2(35.68, 139.69),
}

func test_world_map_expected_capitals():
	for nm in CAPITAL_LATLON.keys():
		var ll: Vector2 = CAPITAL_LATLON[nm]
		var want := WorldMap.hex_for_latlon(ll.x, ll.y)
		var got := WorldMap.nation_start(nm)
		assert_true(MapWar.hex_distance(want, got) <= 1, "%s capital at its real location (%s vs %s)" % [nm, got, want])

func test_world_map_continents_and_oceans():
	# Spot-check the Earth likeness with real coordinates.
	var land := {"Brazil": Vector2(-10, -55), "Congo": Vector2(0, 22), "Siberia": Vector2(62, 100),
		"Australia": Vector2(-25, 134), "US Midwest": Vector2(40, -95), "India": Vector2(22, 79), "Sahara": Vector2(23, 10)}
	for nm in land.keys():
		var h := WorldMap.hex_for_latlon(land[nm].x, land[nm].y)
		assert_true(WorldMap.is_land(h.x, h.y), "land in %s %s" % [nm, h])
	var sea := {"mid-Atlantic": Vector2(30, -40), "mid-Pacific": Vector2(0, -140), "Indian Ocean": Vector2(-20, 80), "South Atlantic": Vector2(-30, -15)}
	for nm in sea.keys():
		var h2 := WorldMap.hex_for_latlon(sea[nm].x, sea[nm].y)
		assert_false(WorldMap.is_land(h2.x, h2.y), "ocean in %s %s" % [nm, h2])
	assert_eq(WorldMap.terrain_at(WorldMap.hex_for_latlon(23, 10).x, WorldMap.hex_for_latlon(23, 10).y), "desert", "Sahara is desert")

func test_world_map_nation_at_and_unknown():
	var baghdad := WorldMap.nation_start("State Troops")
	var n := WorldMap.nation_at(baghdad.x, baghdad.y)
	assert_eq(str(n.get("name")), "State Troops", "nation_at Baghdad")
	var atl := WorldMap.hex_for_latlon(30, -40)
	assert_true(WorldMap.nation_at(atl.x, atl.y).is_empty(), "no nation mid-Atlantic")
	assert_true(WorldMap.nation_by_name("Nope").is_empty(), "unknown nation empty")
	assert_eq(WorldMap.nation_start("Nope"), Vector2i(-1, -1), "unknown start sentinel")
	assert_eq(WorldMap.terrain_at(-1, 0), "ocean", "out of bounds is ocean")
