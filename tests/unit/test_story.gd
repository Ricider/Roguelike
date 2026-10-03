extends GutTest
# GUT suite for the State Troops story campaign: chapter maps, starting
# territories, greyed-out areas and the chapter text.

const CHAPTER_NATIONS := {
	1: ["State Troops", "Insurgents"],
	2: ["State Troops", "Fundamentalists"],
	3: ["State Troops", "Horde", "Mercenaries"],
	4: ["State Troops", "Coalition Army"],
	5: ["State Troops", "Horde", "Corporate Troops", "Peace Keepers", "Insurgents"],
}

func after_each():
	WorldMap.use_map("world")

func test_every_chapter_map_sets_up_its_war():
	for n in CHAPTER_NATIONS.keys():
		assert_true(WorldMap.use_map("story_%d" % n), "chapter %d map loads" % n)
		assert_eq(WorldMap.STORY_CHAPTER, n, "knows its chapter")
		var names: Array = WorldMap.nations().map(func(d): return str(d["name"]))
		names.sort()
		var want: Array = CHAPTER_NATIONS[n].duplicate()
		want.sort()
		assert_eq(names, want, "chapter %d has exactly its nations" % n)
		var c := MapCampaign.new("State Troops")
		for nm in CHAPTER_NATIONS[n]:
			assert_true(c.is_alive(nm), "chapter %d: %s starts with land" % [n, nm])
			var cap := c.capital_site(nm)
			assert_eq(c.owner_of(cap.x, cap.y), nm, "chapter %d: %s's flag on its own land" % [n, nm])
		for k in c.owner.keys():
			var t := MapWar.key_to_hex(str(k))
			assert_false(WorldMap.is_void(t.x, t.y), "chapter %d: nothing owned out of play" % n)
		assert_false(c.has_won(), "chapter %d is not won at the start" % n)

func test_greyed_out_areas():
	WorldMap.use_map("story_1")
	var rome := WorldMap.hex_for_latlon(41.9, 12.5)
	var ankara := WorldMap.hex_for_latlon(39.93, 32.85)
	assert_true(WorldMap.is_void(rome.x, rome.y), "Italy is out of chapter 1")
	assert_false(WorldMap.is_void(ankara.x, ankara.y), "Anatolia is in it")
	WorldMap.use_map("story_4")
	var london := WorldMap.hex_for_latlon(51.5, -0.5)
	assert_true(WorldMap.is_void(london.x, london.y), "Britain is outside the EU war")
	WorldMap.use_map("story_5")
	var c := MapCampaign.new("State Troops")
	var sp := WorldMap.hex_for_latlon(-15.8, -47.9) # Brasilia
	assert_eq(c.owner_of(sp.x, sp.y), "Peace Keepers", "the rest of the world is Peace Keepers")

func test_chapter_one_insurgents_hold_south_east_anatolia():
	WorldMap.use_map("story_1")
	var c := MapCampaign.new("State Troops")
	var diyarbakir := WorldMap.hex_for_latlon(37.91, 40.23)
	var istanbul := WorldMap.hex_for_latlon(41.01, 28.98)
	assert_eq(c.owner_of(diyarbakir.x, diyarbakir.y), "Insurgents", "the south-east is theirs")
	assert_eq(c.owner_of(istanbul.x, istanbul.y), "State Troops", "Constantinople is yours")

func test_territory_carries_over():
	# what chapter 2 is fought over is the State Troops' land in chapter 3
	WorldMap.use_map("story_3")
	var c := MapCampaign.new("State Troops")
	for ll in [[30.04, 31.24], [33.51, 36.29], [39.93, 32.85], [44.8, 20.46]]: # Cairo, Damascus, Ankara, Belgrade
		var t := WorldMap.hex_for_latlon(ll[0], ll[1])
		assert_eq(c.owner_of(t.x, t.y), "State Troops", "chapter 3: %s held" % str(ll))
	var sabha := WorldMap.hex_for_latlon(27.04, 14.43) # inland Libya (coastal cities can fall on sea hexes)
	assert_eq(c.owner_of(sabha.x, sabha.y), "Mercenaries", "Libya is the Mercenaries'")
	WorldMap.use_map("story_4")
	var c4 := MapCampaign.new("State Troops")
	var benghazi := WorldMap.hex_for_latlon(32.1, 20.1)
	assert_eq(c4.owner_of(benghazi.x, benghazi.y), "State Troops", "chapter 4 keeps Libya")
	var paris := WorldMap.hex_for_latlon(48.86, 2.35)
	assert_eq(c4.owner_of(paris.x, paris.y), "Coalition Army", "the Coalition holds the EU")

func test_story_text_covers_every_chapter():
	assert_eq(StoryText.count(), 5, "five chapters")
	for n in range(1, 6):
		var ch: Dictionary = StoryText.chapter(n)
		assert_false((ch["intro"] as Array).is_empty(), "chapter %d has an intro" % n)
		assert_ne(str(ch["objective"]), "", "chapter %d has an objective" % n)
		assert_not_null(StoryText.image(str(ch["image"])), "chapter %d has its picture" % n)
	assert_not_null(StoryText.image("epilogue"), "epilogue picture")
	assert_not_null(StoryText.image("defeat"), "defeat picture")
