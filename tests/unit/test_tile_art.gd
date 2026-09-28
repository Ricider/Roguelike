extends GutTest
# GUT suite for TileArt: the procedural per-terrain tile texture set.

func test_tile_set_complete():
	var set := TileArt.make_tile_set()
	assert_eq(set.size(), 6, "6 terrains")
	for terrain in TileArt.TERRAINS:
		assert_true(set.has(terrain), "has %s" % terrain)
		var variants: Array = set[terrain]
		assert_eq(variants.size(), TileArt.VARIANTS, "%s has 4 variants" % terrain)
		for tex in variants:
			assert_true(tex is ImageTexture, "%s variant is ImageTexture" % terrain)
			var t := tex as ImageTexture
			assert_eq(t.get_width(), TileArt.SIZE, "width 48")
			assert_eq(t.get_height(), TileArt.SIZE, "height 48")
			assert_eq(t.get_image().get_pixel(24, 24).a, 1.0, "tile opaque")

func test_tile_variants_differ_but_stable():
	var set := TileArt.make_tile_set()
	for terrain in TileArt.TERRAINS:
		var variants: Array = set[terrain]
		var first: PackedByteArray = (variants[0] as ImageTexture).get_image().get_data()
		for i in range(1, variants.size()):
			var other: PackedByteArray = (variants[i] as ImageTexture).get_image().get_data()
			assert_ne(other, first, "%s variant %d differs" % [terrain, i])
	var again := TileArt.make_tile_set()
	for terrain in TileArt.TERRAINS:
		var a: PackedByteArray = ((set[terrain] as Array)[0] as ImageTexture).get_image().get_data()
		var b: PackedByteArray = ((again[terrain] as Array)[0] as ImageTexture).get_image().get_data()
		assert_eq(a, b, "%s art deterministic" % terrain)
