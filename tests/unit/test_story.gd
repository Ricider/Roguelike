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
	assert_eq(StoryText.count("state"), 5, "five chapters")
	for n in range(1, 6):
		var ch: Dictionary = StoryText.chapter("state", n)
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
		2: {"Fundamentalists|Barracks": 4, "Fundamentalists|Infantry": 6,
			"State Troops|Infantry": 2, "State Troops|Wall": 3, "State Troops|Artilery": 2},
		3: {"Horde|Tank": 2, "Horde|Special Ops": 2, "Mercenaries|Artilery": 2, "Mercenaries|Barracks": 1,
			"State Troops|Housing": 3, "State Troops|Factory": 2, "State Troops|Wall": 2},
		4: {"Coalition Army|Corporation": 3, "Coalition Army|Interceptor": 3, "Coalition Army|Fighter Jet": 3,
			"State Troops|Tank": 2, "State Troops|Artilery": 2, "State Troops|Housing": 2, "State Troops|Special Ops": 2},
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
	assert_false(StoryText.chapter("state", 1).get("briefing", {}).is_empty(), "chapter 1 briefs the player at the start")
	assert_false(StoryText.chapter("state", 1).get("combat_briefing", {}).is_empty(), "and after the first End Turn")
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
	assert_true(flanked.size() >= 1, "an Artilery either side of it") # (a default Barracks can land between them too)
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

# --- all eight campaigns ------------------------------------------------------
func test_every_campaign_chapter_is_playable():
	for cid in StoryText.ORDER:
		var faction := str(StoryText.campaign(cid)["faction"])
		assert_true(StoryText.count(cid) >= 3, "%s has chapters" % cid)
		for n in range(1, StoryText.count(cid) + 1):
			var map_id := StoryText.map_id(cid, n)
			assert_true(WorldMap.use_map(map_id), "%s loads" % map_id)
			assert_eq(WorldMap.STORY_CAMPAIGN, cid, "%s knows its campaign" % map_id)
			assert_eq(WorldMap.STORY_CHAPTER, n, "%s knows its chapter" % map_id)
			var c := MapCampaign.new(faction)
			assert_true(c.is_alive(faction), "%s: the player's %s start with land" % [map_id, faction])
			assert_true(c.alive_nations().size() >= 2, "%s: there is somebody to fight" % map_id)
			for nm in c.alive_nations():
				var cap := c.capital_site(str(nm))
				assert_eq(c.owner_of(cap.x, cap.y), str(nm), "%s: %s's flag on its own land" % [map_id, nm])
			for k in c.owner.keys():
				var t := MapWar.key_to_hex(str(k))
				assert_false(WorldMap.is_void(t.x, t.y), "%s: nothing owned out of play" % map_id)
			assert_false(c.has_won(), "%s is not won at the start" % map_id)

func test_every_campaign_has_its_words_and_pictures():
	for cid in StoryText.ORDER:
		var camp: Dictionary = StoryText.campaign(cid)
		for key in ["faction", "title", "subtitle", "era"]:
			assert_ne(str(camp.get(key, "")), "", "%s has a %s" % [cid, key])
		for n in range(1, StoryText.count(cid) + 1):
			var ch: Dictionary = StoryText.chapter(cid, n)
			assert_false((ch["intro"] as Array).is_empty(), "%s %d has an intro" % [cid, n])
			assert_ne(str(ch["objective"]), "", "%s %d has an objective" % [cid, n])
			assert_not_null(StoryText.image(str(ch["image"])), "%s %d has its picture" % [cid, n])
		var ep: Dictionary = StoryText.epilogue(cid)
		assert_false((ep.get("lines", []) as Array).is_empty(), "%s has a finale" % cid)
		assert_not_null(StoryText.image(str(ep["image"])), "%s finale picture" % cid)
		assert_not_null(StoryText.image(str(StoryText.defeat(cid)["image"])), "%s defeat picture" % cid)

func test_the_chronicle_holds_every_chapter_once():
	var seen := {}
	for act in StoryText.acts():
		for pair in act["chapters"]:
			var key := "%s_%d" % [pair[0], pair[1]]
			assert_false(seen.has(key), "%s appears once" % key)
			seen[key] = true
	var total := 0
	for cid in StoryText.ORDER:
		total += StoryText.count(cid)
		for n in range(1, StoryText.count(cid) + 1):
			assert_true(seen.has("%s_%d" % [cid, n]), "%s %d is in the chronicle" % [cid, n])
	assert_eq(seen.size(), total, "and nothing else")
	# each campaign's chapters come in its own order
	var pos := {}
	var i := 0
	for act in StoryText.acts():
		for pair in act["chapters"]:
			pos["%s_%d" % [pair[0], pair[1]]] = i
			i += 1
	for cid in StoryText.ORDER:
		for n in range(2, StoryText.count(cid) + 1):
			assert_lt(int(pos["%s_%d" % [cid, n - 1]]), int(pos["%s_%d" % [cid, n]]), "%s chapter %d comes after %d" % [cid, n, n - 1])

func test_campaign_handoffs_line_up():
	# the Insurgents' first chapter ends where the State Troops' first begins
	WorldMap.use_map("story_1")
	var st := MapCampaign.new("State Troops")
	var diyarbakir := WorldMap.hex_for_latlon(37.91, 40.23)
	assert_eq(st.owner_of(diyarbakir.x, diyarbakir.y), "Insurgents", "State chapter 1: Diyarbakir is the Insurgents'")
	var held: Array = st.tiles_of("Insurgents")
	WorldMap.use_map("story_insurgents_1")
	var ins := MapCampaign.new("Insurgents")
	assert_eq(WorldMap.nation_by_name("State Troops")["capital"], "Diyarbakir", "the State Troops defend Diyarbakir")
	var flag := ins.capital_site("State Troops")
	assert_eq(ins.owner_of(flag.x, flag.y), "State Troops", "...which they hold at the start of the Insurgents' chapter 1")
	var fought: Array = ins.tiles_of("Insurgents") + ins.tiles_of("State Troops")
	fought.sort()
	held.sort()
	assert_eq(fought, held, "the Insurgents' first war is fought over exactly the land they hold when the State Troops' story begins")
	# and the Insurgents' last chapter is fought over the corner they hold in State chapter 5
	WorldMap.use_map("story_insurgents_3")
	var ins3 := MapCampaign.new("Insurgents")
	var paris := WorldMap.hex_for_latlon(48.86, 2.35)
	assert_eq(ins3.owner_of(paris.x, paris.y), "State Troops", "Insurgents chapter 3: northern France is the State Troops' to lose")

# --- chapter forces: asymmetric extras, reinforcements, setup, briefing -----------
func _faction_war(map_id: String, with_extras: bool = true) -> MapWar:
	WorldMap.use_map(map_id)
	var faction := str(StoryText.campaign(WorldMap.STORY_CAMPAIGN).get("faction", "State Troops"))
	var saved: Array = WorldMap.EXTRAS
	if not with_extras:
		WorldMap.EXTRAS = []
	var gs = load("res://GodotHelpers/GameState.gd").new()
	var w := MapWar.new()
	w.setup(MapCampaign.new(faction), func(nm): return gs.make_player_by_name(nm), gs.make_player_by_name(faction, true))
	WorldMap.EXTRAS = saved
	gs.free()
	return w

func test_every_chapter_has_forces_for_both_sides():
	for cid in StoryText.ORDER:
		var faction := str(StoryText.campaign(cid)["faction"])
		for n in range(1, StoryText.count(cid) + 1):
			var map_id := StoryText.map_id(cid, n)
			WorldMap.use_map(map_id)
			var mine := 0
			var theirs := 0
			for r in WorldMap.EXTRAS:
				if str(r["nation"]) == faction:
					mine += int(r["count"])
				else:
					theirs += int(r["count"])
			assert_gt(mine, 0, "%s: the player gets extra forces" % map_id)
			assert_gt(theirs, 0, "%s: so does the enemy" % map_id)
			if map_id == "story_1":
				continue # the tutorial briefs the player itself
			assert_ne(str(WorldMap.FORCES.get("title", "")), "", "%s: has a forces briefing" % map_id)
			assert_gt((WorldMap.FORCES.get("lines", []) as Array).size(), 1, "%s: that explains the asymmetry" % map_id)

func test_every_starting_extra_lands():
	for cid in StoryText.ORDER:
		for n in range(1, StoryText.count(cid) + 1):
			var map_id := StoryText.map_id(cid, n)
			var a := _counts(_faction_war(map_id, true))
			var b := _counts(_faction_war(map_id, false))
			var want := {}
			for r in WorldMap.EXTRAS:
				if int(r.get("turn", 1)) <= 1:
					var key := "%s|%s" % [r["nation"], r["card"]]
					want[key] = int(want.get(key, 0)) + int(r["count"])
			for key in want.keys():
				assert_eq(int(a.get(key, 0)) - int(b.get(key, 0)), int(want[key]), "%s: all of %s land" % [map_id, key])

func test_setup_tweaks_nations():
	var w := _faction_war("story_2")
	var fu: Player = w.players["Fundamentalists"]
	assert_eq(fu.MaxHitPoints, 80, "the zealots are brittle")
	assert_eq(fu.HitPoints, 80, "and start at that")
	var w3 := _faction_war("story_3")
	assert_eq((w3.players["Horde"] as Player).Influence, 100, "the Horde starts rich")

func test_reinforcements_land_on_their_turn():
	var w := _faction_war("story_2")
	var fu_inf := func() -> int: return _cards(w, "Fundamentalists", "Infantry").size()
	var st_tank := func() -> int: return _cards(w, "State Troops", "Tank").size()
	assert_eq(w.upcoming_reinforcements().size(), 2, "two reinforcements on the way")
	var inf0: int = fu_inf.call()
	var tank0: int = st_tank.call()
	for t in [1, 2]:
		w.turn = t
		w.begin_turn("Fundamentalists")
		w.begin_turn("State Troops")
		assert_true(w.last_arrivals.is_empty(), "nothing lands on turn %d" % t)
	assert_eq(fu_inf.call(), inf0, "the second wave is not here yet")
	w.turn = 3
	w.begin_turn("Fundamentalists")
	assert_eq(w.last_arrivals.size(), 4, "four Infantry land on turn 3")
	assert_eq(fu_inf.call(), inf0 + 4, "on the map")
	var cairo := WorldMap.hex_for_latlon(30.04, 31.24)
	for a in w.last_arrivals:
		assert_eq(str(a[0]), "Fundamentalists", "theirs")
		assert_lt(MapCampaign.hex_distance(a[2] as Vector2i, cairo), 6, "near Cairo")
	w.begin_turn("State Troops")
	assert_eq(st_tank.call(), tank0, "your Tanks are due on turn 4")
	w.turn = 4
	w.begin_turn("State Troops")
	assert_eq(st_tank.call(), tank0 + 2, "and arrive then")
	assert_true(w.pending.is_empty(), "nothing left on the way")

func test_reinforcements_wait_for_room_and_survive_a_save():
	var w := _faction_war("story_2")
	# fill every free Fundamentalist hex: the wave has nowhere to land
	var filler: Array = []
	for t in w.campaign.tiles_of("Fundamentalists"):
		if w._extra_free("Fundamentalists", t):
			w._put("Fundamentalists", Wall.new(), t)
			filler.append(t)
	w.turn = 3
	w.begin_turn("Fundamentalists")
	assert_true(w.last_arrivals.is_empty(), "no room, no landing")
	assert_eq(w.upcoming_reinforcements().filter(func(r): return r["nation"] == "Fundamentalists").size(), 1, "still waiting")
	# a save keeps what is still on its way
	var d := w.to_data()
	var gs = load("res://GodotHelpers/GameState.gd").new()
	var w2 := MapWar.from_data(d, w.campaign, func(nm): return gs.make_player_by_name(nm), gs.make_player_by_name("State Troops", true))
	gs.free()
	assert_eq(w2.pending.size(), w.pending.size(), "the save keeps the reinforcements on their way")
	for i in range(2):
		w2._remove(MapCampaign.key_of(filler[i].x, filler[i].y))
	w2.turn = 4
	w2.begin_turn("Fundamentalists")
	assert_eq(w2.last_arrivals.size(), 2, "as hexes free up, they land")
	assert_eq(int(w2.upcoming_reinforcements().filter(func(r): return r["nation"] == "Fundamentalists")[0]["count"]), 2, "the rest still wait")
