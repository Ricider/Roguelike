# MapCampaign: territory ownership + conquest rules for the world-map game.
# Same battles/shop as the sequential run, but wars are chosen on the map:
# attack neighboring nations only; winner takes 1 tile per 10 HP left,
# always from the shared border so no side gets border gore.
extends RefCounted
class_name MapCampaign

const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var player_nation: String = ""
var owner: Dictionary = {} # "x,y" -> nation name, land tiles only

func _init(nation: String = "") -> void:
	if nation != "":
		new_campaign(nation)

static func key_of(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func tiles_for_hp(hp_left: int) -> int:
	return maxi(1, hp_left / 10)

# Orthogonal neighbors with east-west wraparound (Civ-style cylinder map),
# so the Bering Strait land bridge links the Americas to Asia.
static func wrapped_neighbors(t: Vector2i) -> Array:
	var out: Array = []
	for dir in DIRS:
		var nx: int = (t.x + (dir as Vector2i).x + WorldMap.GRID_W) % WorldMap.GRID_W
		var ny: int = t.y + (dir as Vector2i).y
		if ny >= 0 and ny < WorldMap.GRID_H:
			out.append(Vector2i(nx, ny))
	return out

func new_campaign(nation: String) -> void:
	player_nation = nation
	owner.clear()
	# Starting territory: multi-source BFS from every capital over land,
	# so each nation starts with one connected region (ties -> NATIONS order).
	var queue: Array = []
	for n in WorldMap.nations():
		var d := n as Dictionary
		var c := Vector2i(int(d["x"]), int(d["y"]))
		owner[key_of(c.x, c.y)] = str(d["name"])
		queue.append(c)
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for nt in wrapped_neighbors(cur):
			var t := nt as Vector2i
			if not WorldMap.is_land(t.x, t.y):
				continue
			var nk := key_of(t.x, t.y)
			if owner.has(nk):
				continue
			owner[nk] = str(owner[key_of(cur.x, cur.y)])
			queue.append(t)
	# Land unreachable by land (Antarctica, New Zealand) stays unowned
	# wilderness: it has no borders, so it can never be fought over, and
	# the win check only covers owned tiles.

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

# Border edges of a nation for map highlighting: Array of [tile, dir]
# where dir is the orthogonal step toward a non-nation neighbor
# (rival land, wilderness, ocean, or map edge).
func border_edges(nation: String) -> Array:
	var out: Array = []
	for t in tiles_of(nation):
		var tile := t as Vector2i
		for dir in DIRS:
			var d := dir as Vector2i
			var nx: int = (tile.x + d.x + WorldMap.GRID_W) % WorldMap.GRID_W
			var ny: int = tile.y + d.y
			var o := ""
			if ny >= 0 and ny < WorldMap.GRID_H:
				o = owner_of(nx, ny)
			if o != nation:
				out.append([tile, d])
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
func conquer(winner: String, loser: String, hp_left: int) -> int:
	var want := tiles_for_hp(hp_left)
	var moved := 0
	while moved < want and tile_count(loser) > 0:
		var pick := _pick_border_tile(winner, loser)
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

func _pick_border_tile(winner: String, loser: String) -> Vector2i:
	var frontier: Array = []
	for t in tiles_of(loser):
		if _adjacent_to(t, winner):
			frontier.append(t)
	if frontier.is_empty():
		return Vector2i(-1, -1)
	var cap := WorldMap.nation_start(winner)
	frontier.sort_custom(func(a, b):
		var da: int = absi((a as Vector2i).x - cap.x) + absi((a as Vector2i).y - cap.y)
		var db: int = absi((b as Vector2i).x - cap.x) + absi((b as Vector2i).y - cap.y)
		if da != db:
			return da < db
		if (a as Vector2i).x != (b as Vector2i).x:
			return (a as Vector2i).x < (b as Vector2i).x
		return (a as Vector2i).y < (b as Vector2i).y)
	if tile_count(loser) <= 1:
		return frontier[0]
	for t in frontier:
		if not _splits_loser(t, loser):
			return t
	# Last resort: every border tile would split the loser (tiny enclave
	# wedged between nations). Take one anyway so wars always make progress
	# and a full conquest stays possible; later takes rejoin the pieces.
	return frontier[0]

func _splits_loser(t: Vector2i, loser: String) -> bool:
	var k := key_of(t.x, t.y)
	owner.erase(k)
	var ok := is_territory_connected(loser)
	owner[k] = loser
	return not ok

# Current flag site: the original capital while owned, else the owned tile
# nearest to it (deterministic), so the flag always sits inside friendly
# borders. Dead nations keep their original site (drawn grayed out).
func capital_site(nation: String) -> Vector2i:
	var home := WorldMap.nation_start(nation)
	if not is_alive(nation):
		return home
	if owner_of(home.x, home.y) == nation:
		return home
	var best := home
	var best_key: Array = [1 << 30, 0, 0]
	for t in tiles_of(nation):
		var tile := t as Vector2i
		var key: Array = [absi(tile.x - home.x) + absi(tile.y - home.y), tile.x, tile.y]
		if _key_less(key, best_key):
			best_key = key
			best = tile
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
	return {"player_nation": player_nation, "owner": owner.duplicate()}

static func from_data(d: Dictionary) -> MapCampaign:
	var c := MapCampaign.new()
	c.player_nation = str(d.get("player_nation", ""))
	var o = d.get("owner", {})
	if o is Dictionary:
		c.owner = (o as Dictionary).duplicate()
	return c
