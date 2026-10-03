# MapCampaign: territory ownership + conquest rules for the world-map game.
# Same battles/shop as the sequential run, but wars are chosen on the map:
# attack neighboring nations only; winner takes 1 tile per 10 HP left,
# always from the shared border so no side gets border gore.
extends RefCounted
class_name MapCampaign

# Hex grid in "odd-r" offset layout: pointy-top hexes, odd rows sit half a hex
# to the right. Direction index i matches hex edge i as drawn by WorldMapView:
# 0=E, 1=SE, 2=SW, 3=W, 4=NW, 5=NE.
const HEX_DIRS_EVEN: Array = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)]
const HEX_DIRS_ODD: Array = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]

var player_nation: String = ""
var owner: Dictionary = {} # "x,y" -> nation name, land tiles only
var flag_sites: Dictionary = {} # nation -> Vector2i where its flag stands (default: capital)

func _init(nation: String = "") -> void:
	if nation != "":
		new_campaign(nation)

static func key_of(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func tiles_for_hp(hp_left: int) -> int:
	return maxi(1, hp_left / 10)

static func hex_dirs(row: int) -> Array:
	return HEX_DIRS_ODD if (row & 1) == 1 else HEX_DIRS_EVEN

# Neighbor across hex edge i with east-west wraparound; y may fall off the
# map (callers check 0 <= y < GRID_H).
static func hex_neighbor(t: Vector2i, i: int) -> Vector2i:
	var d := hex_dirs(t.y)[i] as Vector2i
	var nx: int = t.x + d.x
	if WorldMap.WRAPS:
		nx = posmod(nx, WorldMap.GRID_W)
	return Vector2i(nx, t.y + d.y) # regional maps: may be off the grid (callers check)

# The 6 hex neighbors with east-west wraparound (Civ-style cylinder map),
# so the Bering Strait land bridge links the Americas to Asia.
static func wrapped_neighbors(t: Vector2i) -> Array:
	var out: Array = []
	for i in range(6):
		var n := hex_neighbor(t, i)
		if WorldMap.in_bounds(n.x, n.y):
			out.append(n)
	return out

# Hex distance with east-west wrap (cube distance on the odd-r layout).
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
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

func new_campaign(nation: String) -> void:
	player_nation = nation
	owner.clear()
	flag_sites.clear()
	# Story chapters come with their starting territories drawn in.
	if not WorldMap.START_OWNER.is_empty():
		for y in range(WorldMap.GRID_H):
			for x in range(WorldMap.GRID_W):
				var o := WorldMap.start_owner_at(x, y)
				if o != "" and WorldMap.is_land(x, y):
					owner[key_of(x, y)] = o
		return
	# 1. Every nation's capital and extra seed cities.
	var seeds_of: Dictionary = {}
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		seeds_of[nm] = WorldMap.nation_seeds(nm)
		for sd in seeds_of[nm]:
			var sv := sd as Vector2i
			owner[key_of(sv.x, sv.y)] = nm
	# 2. Territory claims (maps that define them, e.g. the world map's continents).
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			if not WorldMap.is_land(x, y) or owner.has(key_of(x, y)):
				continue
			var claimant := WorldMap.claim_at(x, y)
			if claimant != "":
				owner[key_of(x, y)] = claimant
	# 3. Claimed land cut off from all of its nation's cities goes back to the pool,
	#    so no nation starts with stray enclaves (islands, slivers beyond a strait).
	for nm in seeds_of.keys():
		var keep: Dictionary = {}
		var queue: Array = []
		for sd in seeds_of[nm]:
			var sv := sd as Vector2i
			keep[key_of(sv.x, sv.y)] = true
			queue.append(sv)
		var h := 0
		while h < queue.size():
			var cur: Vector2i = queue[h]
			h += 1
			for nt in wrapped_neighbors(cur):
				var t := nt as Vector2i
				var k := key_of(t.x, t.y)
				if not keep.has(k) and str(owner.get(k, "")) == nm:
					keep[k] = true
					queue.append(t)
		for k in owner.keys().duplicate():
			if str(owner[k]) == nm and not keep.has(k):
				owner.erase(k)
	# 4. Remaining land: multi-source BFS outward from owned hexes. Nations with a
	#    claim keep to their claimed borders, so leftovers first grow from the
	#    nations without one; only land none of those can reach (e.g. Korea and Japan
	#    behind a claimed coast) then goes to a claimed neighbour. The BFS never
	#    crosses the Americas/Old World line (world map), so nobody starts with a
	#    foothold on another continent through the Bering land bridge.
	var claimed_nations: Dictionary = {}
	for c in WorldMap.CLAIMS:
		claimed_nations[str(c["nation"])] = true
	_grow_into_unowned(func(o: String) -> bool: return not claimed_nations.has(o))
	_grow_into_unowned(func(_o: String) -> bool: return true)
	# Land unreachable by land (Antarctica, New Zealand) stays unowned
	# wilderness: it has no borders, so it can never be fought over, and
	# the win check only covers owned tiles.

# Multi-source BFS from every hex owned by a nation accepted by `source_ok`,
# claiming unowned land within the same region.
func _grow_into_unowned(source_ok: Callable) -> void:
	var queue: Array = []
	for k in owner.keys():
		if source_ok.call(str(owner[k])):
			queue.append(MapWar.key_to_hex(str(k)))
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var from_nation := str(owner[key_of(cur.x, cur.y)])
		for nt in wrapped_neighbors(cur):
			var t := nt as Vector2i
			if not WorldMap.is_land(t.x, t.y):
				continue
			var nk := key_of(t.x, t.y)
			if owner.has(nk):
				continue
			if WorldMap.region_of(t.x, t.y) != WorldMap.region_of(cur.x, cur.y):
				continue
			owner[nk] = from_nation
			queue.append(t)

func owner_of(x: int, y: int) -> String:
	return str(owner.get(key_of(x, y), ""))

func tiles_of(nation: String) -> Array:
	var out: Array = []
	for k in owner.keys():
		if str(owner[k]) == nation:
			var parts := str(k).split(",")
			out.append(Vector2i(int(parts[0]), int(parts[1])))
	return out

func tile_count(nation: String) -> int:
	var c := 0
	for k in owner.keys():
		if str(owner[k]) == nation:
			c += 1
	return c

func is_alive(nation: String) -> bool:
	return tile_count(nation) > 0

func alive_nations() -> Array:
	var out: Array = []
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		if is_alive(nm):
			out.append(nm)
	return out

func neighbors_of(nation: String) -> Array:
	var found: Dictionary = {}
	for t in tiles_of(nation):
		for nt in wrapped_neighbors(t):
			var w := nt as Vector2i
			var o := owner_of(w.x, w.y)
			if o != "" and o != nation:
				found[o] = true
	var out: Array = []
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		if found.has(nm):
			out.append(nm)
	return out

func is_neighbor(a: String, b: String) -> bool:
	return neighbors_of(a).has(b)

# Border edges of a nation for map highlighting: Array of [tile, dir, edge]
# where dir is the (unwrapped) offset to a non-nation hex neighbor (rival
# land, wilderness, ocean, or map edge) and edge is the hex edge index 0-5.
func border_edges(nation: String) -> Array:
	var out: Array = []
	for t in tiles_of(nation):
		var tile := t as Vector2i
		var dirs := hex_dirs(tile.y)
		for i in range(6):
			var d := dirs[i] as Vector2i
			var nb := hex_neighbor(tile, i)
			var o := ""
			if WorldMap.in_bounds(nb.x, nb.y):
				o = owner_of(nb.x, nb.y)
			if o != nation:
				out.append([tile, d, i])
	return out

func can_attack(target: String) -> bool:
	if target == "" or target == player_nation:
		return false
	if not is_alive(player_nation) or not is_alive(target):
		return false
	return is_neighbor(player_nation, target)

func is_territory_connected(nation: String) -> bool:
	var tiles := tiles_of(nation)
	if tiles.size() <= 1:
		return true
	var start: Vector2i = tiles[0]
	var seen: Dictionary = {key_of(start.x, start.y): true}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for nt in wrapped_neighbors(cur):
			var w := nt as Vector2i
			if owner_of(w.x, w.y) != nation:
				continue
			var nk := key_of(w.x, w.y)
			if seen.has(nk):
				continue
			seen[nk] = true
			queue.append(nt)
	return seen.size() == tiles.size()

# Transfer up to tiles_for_hp(hp_left) tiles from loser to winner.
# Every tile is taken from the shared border, preferring takes that keep
# the loser connected (unless wiping them out), so neither side normally
# gets border gore. If every border take would split a tiny enclave, one
# is taken anyway so wars always make progress.
func conquer(winner: String, loser: String, hp_left: int, multiplier: int = 1) -> int:
	var want := tiles_for_hp(hp_left) * maxi(multiplier, 1)
	var moved := 0
	# hex distance from the winner's land to every hex (reaches overseas nations)
	var field := _distance_field(winner)
	var depth := _depth_from_front(winner, loser, field)
	while moved < want and tile_count(loser) > 0:
		var pick := _pick_border_tile(winner, loser, depth, field)
		if pick.x < 0:
			break
		owner[key_of(pick.x, pick.y)] = winner
		moved += 1
	return moved

func _adjacent_to(t: Vector2i, nation: String) -> bool:
	for nt in wrapped_neighbors(t):
		var w := nt as Vector2i
		if owner_of(w.x, w.y) == nation:
			return true
	return false

func _winner_neighbors(t: Vector2i, nation: String) -> int:
	var n := 0
	for nt in wrapped_neighbors(t):
		var w := nt as Vector2i
		if owner_of(w.x, w.y) == nation:
			n += 1
	return n

# Hexes (land or sea) from the winner's territory to every hex on the map:
# a multi-source breadth-first search, so it is the wrap-aware hex distance.
func _distance_field(winner: String) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array = []
	for t in tiles_of(winner):
		dist[key_of(t.x, t.y)] = 0
		queue.append(t)
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = int(dist[key_of(cur.x, cur.y)])
		for nt in wrapped_neighbors(cur):
			var v := nt as Vector2i
			var k := key_of(v.x, v.y)
			if not dist.has(k):
				dist[k] = d + 1
				queue.append(v)
	return dist

# The loser's hexes closest to the winner: those on the shared border, or, when
# the two don't touch (overseas), the ones nearest the winner's land across the sea.
func _front_tiles(winner: String, loser: String, field: Dictionary) -> Array:
	var best: int = 1 << 30
	var out: Array = []
	for t in tiles_of(loser):
		var d: int = 1 if _winner_neighbors(t, winner) > 0 else int(field.get(key_of(t.x, t.y), 1 << 20))
		if d < best:
			best = d
			out = [t]
		elif d == best:
			out.append(t)
	return out

# How many steps each loser hex lies from the winner's pre-war front
# (BFS through the loser's land). Conquest takes whole rings in order, so the
# front advances evenly instead of a thin wedge driving inland.
func _depth_from_front(winner: String, loser: String, field: Dictionary = {}) -> Dictionary:
	var depth: Dictionary = {}
	var queue: Array = []
	var seeds: Array = []
	if field.is_empty():
		for t in tiles_of(loser):
			if _winner_neighbors(t, winner) > 0:
				seeds.append(t)
	else:
		seeds = _front_tiles(winner, loser, field)
	for t in seeds:
		depth[key_of(t.x, t.y)] = 1
		queue.append(t)
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = int(depth[key_of(cur.x, cur.y)])
		for nt in wrapped_neighbors(cur):
			var v := nt as Vector2i
			var k := key_of(v.x, v.y)
			if owner_of(v.x, v.y) == loser and not depth.has(k):
				depth[k] = d + 1
				queue.append(v)
	return depth

# Next hex the winner takes: on the shared border when there is one, shallowest
# ring first (see _depth_from_front), then the hex most surrounded by the winner,
# then the one nearest the winner's flag (wrap-aware). With no shared border
# (an overseas nation, given `field`), the loser's hexes nearest the winner's land.
func _pick_border_tile(winner: String, loser: String, depth: Dictionary = {}, field: Dictionary = {}) -> Vector2i:
	var frontier: Array = []
	for t in tiles_of(loser):
		var wn := _winner_neighbors(t, winner)
		if wn > 0:
			frontier.append([t, wn, int(depth.get(key_of(t.x, t.y), 0))])
	if frontier.is_empty() and not field.is_empty():
		for t in _front_tiles(winner, loser, field):
			frontier.append([t, 0, int(depth.get(key_of(t.x, t.y), 0))])
	if frontier.is_empty():
		return Vector2i(-1, -1)
	var cap := capital_site(winner)
	frontier.sort_custom(func(a, b):
		var ta: Vector2i = a[0]
		var tb: Vector2i = b[0]
		if int(a[2]) != int(b[2]):
			return int(a[2]) < int(b[2])
		if int(a[1]) != int(b[1]):
			return int(a[1]) > int(b[1])
		var da: int = hex_distance(ta, cap)
		var db: int = hex_distance(tb, cap)
		if da != db:
			return da < db
		if ta.x != tb.x:
			return ta.x < tb.x
		return ta.y < tb.y)
	if tile_count(loser) <= 1:
		return frontier[0][0]
	for f in frontier:
		if not _splits_loser(f[0], loser):
			return f[0]
	# Last resort: every border tile would split the loser (tiny enclave
	# wedged between nations). Take one anyway so wars always make progress
	# and a full conquest stays possible; later takes rejoin the pieces.
	return frontier[0][0]

func _splits_loser(t: Vector2i, loser: String) -> bool:
	var k := key_of(t.x, t.y)
	owner.erase(k)
	var ok := is_territory_connected(loser)
	owner[k] = loser
	return not ok

# Current flag site: the capital until it falls, then wherever the flag was
# last moved (see relocate_flag). The flag always stands inside friendly
# borders. Dead nations keep their original site (drawn greyed out).
func capital_site(nation: String) -> Vector2i:
	var home := WorldMap.nation_start(nation)
	if not is_alive(nation):
		return home
	var site: Vector2i = flag_sites.get(nation, home)
	if owner_of(site.x, site.y) == nation:
		return site
	return relocate_flag(nation, {})

# Move a nation's flag to the owned hex nearest the centre of its territory,
# skipping hexes in `blocked` ("x,y" -> true, e.g. hexes holding cards) when
# possible. Returns the new site.
func relocate_flag(nation: String, blocked: Dictionary) -> Vector2i:
	var tiles := tiles_of(nation)
	if tiles.is_empty():
		return WorldMap.nation_start(nation)
	# centroid in hex-pixel space, unwrapped around the first tile (east-west wrap)
	const ROW_H := 0.8660254 # hex row spacing / hex width
	var ref: Vector2i = tiles[0]
	var sum := Vector2.ZERO
	var pts: Array = []
	for t in tiles:
		var tv := t as Vector2i
		var px: float = tv.x + 0.5 * float(tv.y & 1)
		var dx: float = px - (ref.x + 0.5 * float(ref.y & 1))
		if WorldMap.WRAPS and dx > WorldMap.GRID_W * 0.5:
			px -= WorldMap.GRID_W
		elif WorldMap.WRAPS and dx < -WorldMap.GRID_W * 0.5:
			px += WorldMap.GRID_W
		var p := Vector2(px, tv.y * ROW_H)
		pts.append(p)
		sum += p
	var centre := sum / float(tiles.size())
	var best := Vector2i(-1, -1)
	var best_d: float = INF
	var best_any := Vector2i(-1, -1)
	var best_any_d: float = INF
	for i in range(tiles.size()):
		var tv2: Vector2i = tiles[i]
		var d: float = (pts[i] as Vector2).distance_squared_to(centre)
		if d < best_any_d or (d == best_any_d and _key_less([0, tv2.x, tv2.y], [0, best_any.x, best_any.y])):
			best_any_d = d
			best_any = tv2
		if blocked.has(key_of(tv2.x, tv2.y)):
			continue
		if d < best_d or (d == best_d and _key_less([0, tv2.x, tv2.y], [0, best.x, best.y])):
			best_d = d
			best = tv2
	if best.x < 0:
		best = best_any
	flag_sites[nation] = best
	return best

static func _key_less(a: Array, b: Array) -> bool:
	for i in range(3):
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false

# Nation whose flag currently flies at (x, y), or "" if none.
func capital_holder_at(x: int, y: int) -> String:
	var at := Vector2i(x, y)
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		if is_alive(nm) and capital_site(nm) == at:
			return nm
	return ""

func has_won() -> bool:
	if player_nation == "" or not is_alive(player_nation):
		return false
	for k in owner.keys():
		if str(owner[k]) != player_nation:
			return false
	return true

func has_lost() -> bool:
	return player_nation != "" and not is_alive(player_nation)

func to_data() -> Dictionary:
	var flags: Dictionary = {}
	for n in flag_sites.keys():
		var t: Vector2i = flag_sites[n]
		flags[n] = [t.x, t.y]
	return {"player_nation": player_nation, "owner": owner.duplicate(), "map": WorldMap.MAP_ID, "grid": [WorldMap.GRID_W, WorldMap.GRID_H], "flags": flags}

# Saves from an older map layout (different grid) can't be mapped onto the
# current world, so they restart the campaign for the same nation.
static func from_data(d: Dictionary) -> MapCampaign:
	var nation := str(d.get("player_nation", ""))
	WorldMap.use_map(str(d.get("map", "world"))) # saves remember which map they were played on
	var grid = d.get("grid", [])
	if not (grid is Array and grid.size() == 2 and int(grid[0]) == WorldMap.GRID_W and int(grid[1]) == WorldMap.GRID_H):
		var fresh := MapCampaign.new(nation) if nation != "" else MapCampaign.new()
		fresh.set_meta("restarted", true)
		return fresh
	var c := MapCampaign.new()
	c.player_nation = nation
	var o = d.get("owner", {})
	if o is Dictionary:
		c.owner = (o as Dictionary).duplicate()
	var fl = d.get("flags", {})
	if fl is Dictionary:
		for n in (fl as Dictionary).keys():
			var xy = fl[n]
			if xy is Array and (xy as Array).size() == 2:
				c.flag_sites[str(n)] = Vector2i(int(xy[0]), int(xy[1]))
	return c
