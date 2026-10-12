extends GutTest
# The frame-rate work replaced slow loops with faster ones that must give exactly the
# same answers: the AI's distance fields, frontier_distance, hex_distance, the sliced
# ai_move, and the map view's per-unit cache (buffs, shields, flanking, damage).
# Each is checked here against the plain version on crowded random boards.

var _map_before := ""

func before_each() -> void:
	_map_before = WorldMap.MAP_ID

func after_each() -> void:
	if _map_before != "":
		WorldMap.use_map(_map_before)

# A war on `map_id` with about `fill` of every nation's land covered in random
# cards, some hurt, and some nations too poor to pay for Interceptor cover.
func _crowded_war(map_id: String, seed_i: int, fill: float = 0.45) -> MapWar:
	WorldMap.use_map(map_id)
	seed(seed_i)
	var first := str(WorldMap.nations()[0]["name"])
	var c := MapCampaign.new(first)
	var w := MapWar.new()
	w.setup(c, func(_nm): return CardFactory.make_state_troops_player(), CardFactory.make_state_troops_player(true))
	for k in w.units.keys().duplicate(): # setup's starting cards are random: start empty
		w._remove(k)
	w.rng.seed = seed_i
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	var n_types := CardFactory.all_card_types().size()
	for nm in w.players.keys():
		for t in c.tiles_of(str(nm)):
			if r.randf() > fill or w.units.has(MapCampaign.key_of(t.x, t.y)):
				continue
			var card: Card = CardFactory.all_card_types()[r.randi() % n_types]
			w._put(str(nm), card, t)
			if r.randf() < 0.3: # hurt
				if card is Unit:
					(card as Unit).HitPoints = maxi(1, (card as Unit).HitPoints - r.randi_range(1, 5))
				elif card is Building:
					(card as Building).HitPoints = maxi(1, (card as Building).HitPoints - r.randi_range(1, 5))
		(w.players[nm] as Player).MoneySupply = 3 if r.randf() < 0.3 else 100
	return w

# The hex_distance before it was rewritten without the per-call shift array.
static func _ref_hex_distance(a: Vector2i, b: Vector2i) -> int:
	var best: int = 1 << 30
	var shifts: Array = [-WorldMap.GRID_W, 0, WorldMap.GRID_W] if WorldMap.WRAPS else [0]
	for shift in shifts:
		var bx: int = b.x + int(shift)
		var aq: int = a.x - (a.y - (a.y & 1)) / 2
		var bq: int = bx - (b.y - (b.y & 1)) / 2
		var dq: int = aq - bq
		var dr: int = a.y - b.y
		best = mini(best, (absi(dq) + absi(dr) + absi(dq + dr)) / 2)
	return best

func test_hex_distance_unchanged():
	for map_id in ["world", "europe"]:
		WorldMap.use_map(map_id)
		var r := RandomNumberGenerator.new()
		r.seed = 7
		var bad := 0
		for i in range(4000):
			var a := Vector2i(r.randi_range(0, WorldMap.GRID_W - 1), r.randi_range(0, WorldMap.GRID_H - 1))
			var b := Vector2i(r.randi_range(0, WorldMap.GRID_W - 1), r.randi_range(0, WorldMap.GRID_H - 1))
			if MapCampaign.hex_distance(a, b) != _ref_hex_distance(a, b):
				bad += 1
		assert_eq(bad, 0, "hex_distance matches the old formula on %s" % map_id)

func test_distance_field_is_the_nearest_source_by_hex_distance():
	for map_id in ["world", "europe"]:
		WorldMap.use_map(map_id)
		var r := RandomNumberGenerator.new()
		r.seed = 11
		var sources: Array = []
		for i in range(25):
			sources.append(Vector2i(r.randi_range(0, WorldMap.GRID_W - 1), r.randi_range(0, WorldMap.GRID_H - 1)))
		sources.append(sources[3]) # a duplicate: the earlier copy wins
		var field := MapCampaign.distance_field(sources)
		var dist: PackedInt32Array = field[0]
		var src: PackedInt32Array = field[1]
		var bad := 0
		for y in range(WorldMap.GRID_H):
			for x in range(WorldMap.GRID_W):
				var best := 1 << 30
				var best_i := -1
				for i in range(sources.size()):
					var d := MapCampaign.hex_distance(Vector2i(x, y), sources[i])
					if d < best:
						best = d
						best_i = i
				var c := y * WorldMap.GRID_W + x
				if dist[c] != best or src[c] != best_i:
					bad += 1
		assert_eq(bad, 0, "every hex of %s: nearest source and its distance, first source on ties" % map_id)
	var empty := MapCampaign.distance_field([])
	assert_eq((empty[1] as PackedInt32Array)[0], -1, "no sources: nothing is near")

func test_frontier_distance_matches_the_old_search():
	var w := _crowded_war("world", 3)
	for nm in ["Horde", "Insurgents"]:
		var ref: Dictionary = {}
		var queue: Array = []
		for k in w.campaign.owner.keys():
			if str(w.campaign.owner[k]) != nm:
				ref[k] = 0
				queue.append(MapWar.key_to_hex(str(k)))
		var head := 0
		while head < queue.size():
			var cur: Vector2i = queue[head]
			head += 1
			var d: int = int(ref[MapCampaign.key_of(cur.x, cur.y)])
			for nb in MapCampaign.wrapped_neighbors(cur):
				var nk := MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y)
				if not ref.has(nk):
					ref[nk] = d + 1
					queue.append(nb)
		var got := w.frontier_distance(nm)
		assert_eq(got.size(), ref.size(), "%s: the same hexes" % nm)
		var bad := 0
		for k in ref.keys():
			if int(got.get(k, -1)) != int(ref[k]):
				bad += 1
		assert_eq(bad, 0, "%s: the same distances" % nm)

func test_ai_scores_with_distance_fields_match_the_full_scan():
	for map_id in ["world", "europe"]:
		var w := _crowded_war(map_id, 5)
		var checked := 0
		var bad := 0
		for nm in w.players.keys():
			var ctx := w._ai_move_setup(str(nm))
			if ctx.is_empty():
				continue
			var plain := w._move_weights(str(nm)) # no precomputed fields: scans every foe
			var n_units := 0
			for k in w.cards_of(str(nm)):
				if not (w.units[k]["card"] is Unit):
					continue
				n_units += 1
				if n_units > 6:
					break
				var u := w.units[k]["card"] as Unit
				var cands: Array = w.reachable(k).keys()
				cands.append(MapWar.key_to_hex(k))
				for t in cands:
					var r := w.attack_range(str(nm), u, t)
					var fast := w._position_score(str(nm), k, t, ctx["foes"], ctx["flags"], r, ctx["wts"])
					var slow := w._position_score(str(nm), k, t, ctx["foes"], ctx["flags"], r, plain)
					checked += 1
					if fast != slow:
						bad += 1
		assert_gt(checked, 100, "enough candidate hexes compared on %s" % map_id)
		assert_eq(bad, 0, "the AI scores every hex exactly as before on %s" % map_id)

func test_sliced_ai_move_makes_the_same_moves():
	var w1 := _crowded_war("world", 9, 0.25)
	var w2 := _crowded_war("world", 9, 0.25)
	for nm in ["Horde", "Coalition Army", "Insurgents"]:
		var seen: Array = []
		var a := w1.ai_move(nm)
		var b: Array = await w2.ai_move_sliced(nm, 0, func(mv): seen.append(mv[0]))
		assert_eq(b.size(), a.size(), "%s: as many moves" % nm)
		for i in range(mini(a.size(), b.size())):
			assert_eq(b[i][0], a[i][0], "%s move %d: the same unit" % [nm, i])
			assert_eq(b[i][1], a[i][1], "%s move %d: to the same hex" % [nm, i])
		assert_eq(seen.size(), b.size(), "%s: each move reported as it is made" % nm)

# Cache entries that disagree with MapWar (empty = all agree), and the drawing order.
func _cache_errors(view: WorldMapView, w: MapWar) -> Array:
	var cache: Array = view.unit_cache()
	var bad: Array = []
	if cache.size() != w.units.size():
		bad.append("%d entries for %d cards" % [cache.size(), w.units.size()])
	var last_row := -1
	for e in cache:
		var k: String = e["k"]
		var card: Card = e["card"]
		var t: Vector2i = e["t"]
		if t.y < last_row:
			bad.append("%s out of order" % k)
		last_row = t.y
		if not w.units.has(k) or w.units[k]["card"] != card:
			bad.append("%s stale" % k)
			continue
		if bool(e["buffed"]) != w.is_buffed(k):
			bad.append("%s buffed" % k)
		if bool(e["shielded"]) != (w.is_shielded(k) and not (card is Interceptor)):
			bad.append("%s shielded" % k)
		if int(e["flank"]) != w.flank_bonus(k):
			bad.append("%s flank" % k)
		if card is Unit:
			var want := str(w.effective_damage(str(e["owner"]), card as Unit, t)) + ("x4" if (card is RocketLauncher or card is Howitzer) else "")
			if str(e["atk"]) != want:
				bad.append("%s atk %s != %s" % [k, e["atk"], want])
	return bad

func test_view_unit_cache_follows_moves_arrivals_and_losses():
	var w := _crowded_war("world", 21)
	var view := WorldMapView.new()
	view.war = w
	assert_eq(_cache_errors(view, w), [], "built from scratch")
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var types := CardFactory.all_card_types().size()
	for step in range(60):
		var keys: Array = w.units.keys()
		var k: String = keys[r.randi() % keys.size()]
		var t := MapWar.key_to_hex(k)
		var free: Array = []
		for nb in MapCampaign.wrapped_neighbors(t):
			if not w.units.has(MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y)):
				free.append(nb)
		match r.randi() % 3:
			0: # a card falls
				w._remove(k)
			1: # one steps to a free neighbour (several at once every so often)
				for i in range(1 + (3 if step % 10 == 0 else 0)):
					if free.is_empty():
						break
					var to: Vector2i = free.pop_back()
					var info: Dictionary = w.units[k] if w.units.has(k) else {}
					if info.is_empty():
						break
					w.units.erase(k)
					w.units[MapCampaign.key_of(to.x, to.y)] = info
					k = MapCampaign.key_of(to.x, to.y)
			2: # a new card next to it
				if not free.is_empty():
					var owner := str(w.players.keys()[r.randi() % w.players.size()])
					w._put(owner, CardFactory.all_card_types()[r.randi() % types], free[0])
		assert_eq(_cache_errors(view, w), [], "after change %d" % step)
	# a lot at once falls back to a full rebuild
	for k in w.units.keys().slice(0, 60):
		w._remove(k)
	assert_eq(_cache_errors(view, w), [], "after many changes at once")
	view.free()

func test_view_unit_cache_matches_the_war_rules():
	var w := _crowded_war("world", 13)
	var view := WorldMapView.new()
	view.war = w
	var cache: Array = view.unit_cache()
	assert_eq(cache.size(), w.units.size(), "an entry per card")
	var bad: Array = []
	var last_row := -1
	for e in cache:
		var k: String = e["k"]
		var card: Card = e["card"]
		var t: Vector2i = e["t"]
		assert_true(t.y >= last_row, "north to south")
		last_row = t.y
		if bool(e["buffed"]) != w.is_buffed(k):
			bad.append("%s buffed" % k)
		if bool(e["shielded"]) != (w.is_shielded(k) and not (card is Interceptor)):
			bad.append("%s shielded" % k)
		if int(e["flank"]) != w.flank_bonus(k):
			bad.append("%s flank" % k)
		if card is Unit:
			var want := str(w.effective_damage(str(e["owner"]), card as Unit, t)) + ("x4" if (card is RocketLauncher or card is Howitzer) else "")
			if str(e["atk"]) != want:
				bad.append("%s atk %s != %s" % [k, e["atk"], want])
	assert_eq(bad, [], "buffs, shields, flanking and damage as MapWar works them out")
	# changing the war rebuilds it
	var some_key: String = cache[0]["k"]
	w._remove(some_key)
	assert_eq(view.unit_cache().size(), w.units.size(), "a removed card leaves the cache")
	view.free()

# The full scan _closest_targets did before it learnt to look only within reach.
static func _ref_closest(w: MapWar, nation: String, from: Vector2i, flags: Dictionary, reach: int) -> Array:
	var best: int = 1 << 30
	var closest: Array = []
	for k in w.units.keys():
		var info: Dictionary = w.units[k]
		var o := str(info["owner"])
		if o == nation or w.card_hp(info["card"]) <= 0:
			continue
		var d := MapCampaign.hex_distance(from, MapWar.key_to_hex(str(k)))
		if d > reach:
			continue
		if d < best:
			best = d
			closest = [{"key": k, "owner": o}]
		elif d == best:
			closest.append({"key": k, "owner": o})
	for fnation in flags.keys():
		if str(fnation) == nation:
			continue
		var site: Vector2i = flags[fnation]
		var d2 := MapCampaign.hex_distance(from, site)
		if d2 > reach:
			continue
		var cand := {"flag": str(fnation), "hex": site, "owner": str(fnation)}
		if d2 < best:
			best = d2
			closest = [cand]
		elif d2 == best:
			closest.append(cand)
	return closest

func test_closest_targets_match_the_full_scan():
	for map_id in ["world", "europe"]:
		var w := _crowded_war(map_id, 17, 0.6)
		# some dead cards still on the map, as mid-attack
		var n := 0
		for k in w.units.keys():
			n += 1
			if n % 17 == 0:
				var c: Card = w.units[k]["card"]
				if c is Unit:
					(c as Unit).HitPoints = 0
		var flags := w.flag_sites()
		var r := RandomNumberGenerator.new()
		r.seed = 17
		var names: Array = w.players.keys()
		var bad := 0
		var ties := 0
		for i in range(400):
			var nm := str(names[r.randi() % names.size()])
			var from := Vector2i(r.randi_range(0, WorldMap.GRID_W - 1), r.randi_range(0, WorldMap.GRID_H - 1))
			var reach := r.randi_range(1, 10)
			var got := w._closest_targets(nm, from, flags, reach)
			var want := _ref_closest(w, nm, from, flags, reach)
			if got != want:
				bad += 1
			if want.size() > 1:
				ties += 1
		assert_gt(w.units.size(), (2 * 10 + 3) * 21, "crowded enough for the in-reach search on %s" % map_id)
		assert_gt(ties, 20, "ties exercised on %s" % map_id)
		assert_eq(bad, 0, "the same targets in the same order on %s" % map_id)

func test_enemy_unit_field_matches_nearest_enemy_unit():
	for map_id in ["world", "europe"]:
		var w := _crowded_war(map_id, 23, 0.3)
		var bad := 0
		for nm in ["Horde", "Insurgents"]:
			if not w.players.has(nm):
				continue
			for flags_too in [false, true]:
				var field := w._enemy_unit_field(nm, flags_too)
				for y in range(0, WorldMap.GRID_H, 2):
					for x in range(0, WorldMap.GRID_W, 2):
						if mini(99, field[y * WorldMap.GRID_W + x]) != w._nearest_enemy_unit(nm, Vector2i(x, y), flags_too):
							bad += 1
		assert_eq(bad, 0, "the same nearest-enemy distance everywhere on %s" % map_id)

func test_sliced_ai_build_places_the_same_cards():
	var boards: Array = []
	for i in range(2):
		var w := _crowded_war("world", 29, 0.15)
		for nm in ["Horde", "Insurgents"]:
			var p: Player = w.players[nm]
			p.MoneySupply = 400
			p.BioSupply = 400
			p.Hand = [Infantry.new(), Tank.new(), Barracks.new(), Wall.new(), Housing.new(), Artilery.new()]
		boards.append(w)
	for nm in ["Horde", "Insurgents"]:
		seed(31) # the hand is shuffled with the global generator
		var a: Array = boards[0].ai_build(nm)
		seed(31)
		var b: Array = await boards[1].ai_build_sliced(nm, 0)
		assert_eq(b.size(), a.size(), "%s: as many cards placed" % nm)
		for i in range(mini(a.size(), b.size())):
			assert_eq((b[i][0] as Card).card_name, (a[i][0] as Card).card_name, "%s card %d" % [nm, i])
			assert_eq(b[i][1], a[i][1], "%s card %d: the same hex" % [nm, i])
