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
	assert_true(c.is_neighbor("State Troops", "Horde"), "chapter 3: the State Troops and the Horde meet on land (the Caucasus)")
	var tbilisi := WorldMap.hex_for_latlon(41.72, 44.79)
	assert_eq(c.owner_of(tbilisi.x, tbilisi.y), "State Troops", "the Transcaucasus is theirs")
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

# --- chapter set pieces (extras on top of the default starting cards) -------------
func _war_for(n: int, with_extras: bool) -> MapWar:
	WorldMap.use_map("story_%d" % n)
	var saved: Array = WorldMap.EXTRAS
	if not with_extras:
		WorldMap.EXTRAS = []
	var gs = load("res://GodotHelpers/GameState.gd").new()
	var c := MapCampaign.new("State Troops")
	var w := MapWar.new()
	w.setup(c, func(nm): return gs.make_player_by_name(nm), gs.make_player_by_name("State Troops", true))
	WorldMap.EXTRAS = saved
	gs.free()
	return w

func _counts(w: MapWar) -> Dictionary:
	var out := {}
	for k in w.units.keys():
		var key := "%s|%s" % [w.units[k]["owner"], (w.units[k]["card"] as Card).card_name]
		out[key] = int(out.get(key, 0)) + 1
	return out

func _cards(w: MapWar, nation: String, card_name: String) -> Array:
	var out: Array = []
	for k in w.units.keys():
		if str(w.units[k]["owner"]) == nation and (w.units[k]["card"] as Card).card_name == card_name:
			out.append(k)
	return out

func _touches(w: MapWar, k: String, pred: Callable) -> bool:
	for nb in MapCampaign.wrapped_neighbors(MapWar.key_to_hex(k)):
		if pred.call(nb as Vector2i):
			return true
	return false

func test_chapter_extras_come_on_top_of_the_defaults():
	var expect := {
		1: {"Insurgents|Infantry": 8, "State Troops|Housing": 4},
		2: {"Fundamentalists|Barracks": 4, "State Troops|Infantry": 2},
		3: {"Horde|Tank": 2, "Horde|Special Ops": 2, "Mercenaries|Artilery": 2, "Mercenaries|Barracks": 1,
			"State Troops|Housing": 3, "State Troops|Factory": 2},
		4: {"Coalition Army|Corporation": 3, "Coalition Army|Interceptor": 3, "Coalition Army|Fighter Jet": 3,
			"State Troops|Tank": 2, "State Troops|Artilery": 2, "State Troops|Housing": 2},
		5: {},
	}
	for n in expect.keys():
		var a := _counts(_war_for(n, true))
		var b := _counts(_war_for(n, false))
		var diff := {}
		for key in a.keys():
			var d: int = int(a[key]) - int(b.get(key, 0))
			if d != 0:
				diff[key] = d
		assert_eq(diff, expect[n], "chapter %d adds exactly its extras" % n)

func test_chapter_one_set_pieces():
	var w := _war_for(1, true)
	var c: MapCampaign = w.campaign
	var damaged: Array = _cards(w, "State Troops", "Housing").filter(func(k): return w.card_hp(w.units[k]["card"]) == 10)
	assert_eq(damaged.size(), 2, "two housings start at 10 HP")
	for k in damaged:
		assert_gt(int((w.units[k]["card"] as Card).get_meta("map_max_hp")), 10, "shown against their full HP")
		assert_true(_touches(w, k, func(t): return c.owner_of(t.x, t.y) == "Insurgents"), "on the Insurgent border")
	var inf: Array = _cards(w, "Insurgents", "Infantry")
	assert_eq(inf.size(), 8, "eight Insurgent Infantry")
	for k in inf:
		var t := MapWar.key_to_hex(k)
		assert_eq(WorldMap.terrain_at(t.x, t.y), WorldMap.MOUNTAIN, "every one dug in on a mountain")
	assert_false(StoryText.chapter(1).get("briefing", {}).is_empty(), "chapter 1 briefs the player at the start")
	assert_false(StoryText.chapter(1).get("combat_briefing", {}).is_empty(), "and after the first End Turn")
	var istanbul := WorldMap.hex_for_latlon(41.01, 28.98)
	var near: Array = _cards(w, "State Troops", "Housing").filter(func(k): return MapCampaign.hex_distance(MapWar.key_to_hex(k), istanbul) <= 3)
	assert_true(near.size() >= 2, "two housings at Istanbul")

func test_chapter_three_set_pieces():
	var w := _war_for(3, true)
	var c: MapCampaign = w.campaign
	var barracks: Array = _cards(w, "Mercenaries", "Barracks")
	var frontline: Array = barracks.filter(func(k): return _touches(w, k, func(t): return c.owner_of(t.x, t.y) == "State Troops"))
	assert_false(frontline.is_empty(), "a Mercenary Barracks on Libya's eastern border")
	# (their default cards include Barracks too: find the one flanked by the two Artilery)
	var flanked: Array = frontline.filter(func(bk):
		return _cards(w, "Mercenaries", "Artilery").filter(func(k): return MapCampaign.hex_distance(MapWar.key_to_hex(k), MapWar.key_to_hex(bk)) == 1).size() >= 2)
	assert_eq(flanked.size(), 1, "an Artilery either side of it")
	for card in ["Tank", "Special Ops"]:
		var in_caucasus: Array = _cards(w, "Horde", card).filter(func(k):
			var ll := WorldMap.hex_latlon(MapWar.key_to_hex(k).x, MapWar.key_to_hex(k).y)
			return ll.x >= 43.3 and ll.x <= 46.5 and ll.y >= 36.6 and ll.y <= 49.0)
		assert_true(in_caucasus.size() >= 2, "two Horde %s in the Caucasus" % card)

func test_chapter_four_set_pieces():
	var w := _war_for(4, true)
	var corps: Array = _cards(w, "Coalition Army", "Corporation")
	assert_eq(corps.size(), 3, "three Corporations")
	for ck in corps:
		var icp: Array = _cards(w, "Coalition Army", "Interceptor").filter(func(k): return MapCampaign.hex_distance(MapWar.key_to_hex(k), MapWar.key_to_hex(ck)) == 1)
		assert_eq(icp.size(), 1, "an Interceptor beside each Corporation")
		var jets: Array = _cards(w, "Coalition Army", "Fighter Jet").filter(func(k): return MapCampaign.hex_distance(MapWar.key_to_hex(k), MapWar.key_to_hex(icp[0])) == 1)
		assert_true(jets.size() >= 1, "and a Fighter Jet beside that Interceptor")
