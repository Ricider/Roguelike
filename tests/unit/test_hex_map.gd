extends GutTest
# GUT suite for the hex world map: odd-r hex adjacency and pixel <-> hex picking.

func test_hex_neighbors_symmetric():
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var t := Vector2i(x, y)
			var nbs: Array = MapCampaign.wrapped_neighbors(t)
			assert_true(nbs.size() <= 6, "at most 6 neighbors")
			if y > 0 and y < WorldMap.GRID_H - 1:
				assert_eq(nbs.size(), 6, "interior hex has 6 neighbors")
			for n in nbs:
				assert_true(MapCampaign.wrapped_neighbors(n as Vector2i).has(t), "adjacency symmetric %s/%s" % [t, n])

func test_hex_edge_index_points_back():
	# Edge i of a hex and edge (i+3)%6 of its neighbor are the same shared edge.
	for t in [Vector2i(10, 4), Vector2i(10, 5), Vector2i(0, 7), Vector2i(59, 8)]:
		for i in range(6):
			var n := MapCampaign.hex_neighbor(t, i)
			assert_eq(MapCampaign.hex_neighbor(n, (i + 3) % 6), t, "edge %d of %s mirrors back" % [i, t])

func test_pixel_to_hex_roundtrip():
	var view := WorldMapView.new()
	view.size = Vector2(1500, 900)
	add_child_autofree(view)
	view.size = Vector2(1500, 900)
	var m: Array = view.metrics()
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var c: Vector2 = view.hex_center(x, y, m)
			assert_eq(view.tile_at_point(c), Vector2i(x, y), "centre of (%d,%d) picks itself" % [x, y])
	assert_eq(view.tile_at_point(Vector2(-50, -50)), Vector2i(-1, -1), "outside map picks nothing")
