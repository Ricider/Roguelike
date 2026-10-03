# WorldMap: the hex campaign map currently in play (Geopolitics map view).
# Scope is map-only: terrain grid + nation start positions, no gameplay rules.
# Maps are data files (Assets/Maps/<id>.json) generated from real coastlines by
# tools/make_world.py: the world plus regional maps. use_map(id) switches the
# active map; the world map is loaded by default. Only the world map wraps
# east-west (at the Bering Strait). Hexes are pointy-top in odd-r layout.
# Legend: '.' ocean, 'g' grassland, 'd' desert, 'm' mountain, 's' snow, 'j' forest/jungle.
extends RefCounted
class_name WorldMap

const MAPS: Array = ["world", "europe", "byzantium", "east_asia", "north_america", "british_isles", "bering_strait", "balkans"]
const MAP_DIR := "res://Assets/Maps/%s.json"

const OCEAN: String = "ocean"
const GRASSLAND: String = "grassland"
const DESERT: String = "desert"
const MOUNTAIN: String = "mountain"
const SNOW: String = "snow"
const JUNGLE: String = "jungle"

# Faction colours and flavour (the same 8 factions play on every map).
const NATION_STYLE := {
	"Insurgents": {"color": "b5651d", "blurb": "Sparse mountain village + Guerilla Warfare."},
	"State Troops": {"color": "c9a227", "blurb": "Old town with towers and domes + State of emergency."},
	"Fundamentalists": {"color": "7d3c98", "blurb": "Medieval village + Fanaticism."},
	"Mercenaries": {"color": "922b21", "blurb": "Warzone rubble + Corruption."},
	"Peace Keepers": {"color": "2e86c1", "blurb": "United Nations tents + Defensive Doctrine."},
	"Horde": {"color": "cb4335", "blurb": "Snowy fortified city + Conscription."},
	"Coalition Army": {"color": "1e8449", "blurb": "European-style towers + Aerial Supremacy."},
	"Corporate Troops": {"color": "17a589", "blurb": "Cyberpunk skyrises + Advanced Robotics."},
}

# Active map (set by use_map). Read these like constants.
static var MAP_ID: String = ""
static var MAP_NAME: String = ""
static var MAP_BLURB: String = ""
static var GRID_W: int = 0
static var GRID_H: int = 0
static var WRAPS: bool = true
static var LON0: float = 0.0 # west edge
static var LON_SPAN: float = 360.0 # degrees of longitude across the grid
static var LAT_TOP: float = 0.0
static var LAT_BOT: float = 0.0
static var AMERICAS_SPLIT: bool = false # world only: starting land never crosses the Americas/Old World line
static var ROWS: Array = []
static var NATIONS: Array = []
# Optional starting-territory claims, first match wins: [{"nation", "boxes": [[lat0, lat1, lon0, lon1], ...]}]
static var CLAIMS: Array = []
# Story chapter maps (tools/make_story.py) fix who owns what at the start and grey
# out everything outside the chapter's war. Empty on the normal maps.
static var START_OWNER: Array = [] # rows: "0".."9" = index into NATIONS, "." = nobody
static var VOID_ROWS: Array = []   # rows: "x" = out of play (greyed, never owned or entered)
static var STORY_CHAPTER: int = 0  # 1..5 on story maps, 0 otherwise

static func _static_init() -> void:
	use_map("world")

static func map_data(map_id: String) -> Dictionary:
	var path := MAP_DIR % map_id
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

# Switch the active map. Returns false (and keeps the current map) if unknown.
static func use_map(map_id: String) -> bool:
	if map_id == MAP_ID and not ROWS.is_empty():
		return true
	var d := map_data(map_id)
	if d.is_empty():
		push_warning("WorldMap: unknown map '%s'" % map_id)
		return false
	MAP_ID = map_id
	MAP_NAME = str(d.get("name", map_id))
	MAP_BLURB = str(d.get("blurb", ""))
	GRID_W = int(d["grid_w"])
	GRID_H = int(d["grid_h"])
	WRAPS = bool(d.get("wraps", false))
	LON0 = float(d["lon0"])
	LON_SPAN = float(d.get("lon_span", 360.0))
	LAT_TOP = float(d["lat_top"])
	LAT_BOT = float(d["lat_bot"])
	AMERICAS_SPLIT = bool(d.get("americas_split", false))
	ROWS = []
	for r in d["rows"]:
		ROWS.append(str(r))
	NATIONS = []
	for n in d["nations"]:
		var nd: Dictionary = n
		var nm := str(nd["name"])
		var style: Dictionary = NATION_STYLE.get(nm, {"color": "888888", "blurb": ""})
		var seeds: Array = []
		for sd in nd.get("seeds", []):
			seeds.append({"city": str(sd["city"]), "x": int(sd["x"]), "y": int(sd["y"])})
		NATIONS.append({"name": nm, "capital": str(nd["capital"]), "x": int(nd["x"]), "y": int(nd["y"]),
			"color": style["color"], "blurb": style["blurb"], "region": MAP_NAME, "seeds": seeds})
	CLAIMS = []
	for c in d.get("claims", []):
		CLAIMS.append({"nation": str(c["nation"]), "boxes": c["boxes"]})
	START_OWNER = []
	for r in d.get("start_owner", []):
		START_OWNER.append(str(r))
	VOID_ROWS = []
	for r in d.get("void", []):
		VOID_ROWS.append(str(r))
	STORY_CHAPTER = int(d.get("story_chapter", 0))
	return true

# Out of play on a story map: drawn greyed out, never owned, walked or fought over.
static func is_void(x: int, y: int) -> bool:
	if VOID_ROWS.is_empty() or y < 0 or y >= VOID_ROWS.size():
		return false
	var row: String = VOID_ROWS[y]
	return x >= 0 and x < row.length() and row[x] == "x"

# Who owns hex (x, y) when a story chapter starts ("" = nobody).
static func start_owner_at(x: int, y: int) -> String:
	if START_OWNER.is_empty() or y < 0 or y >= START_OWNER.size():
		return ""
	var ch: String = (START_OWNER[y] as String).substr(x, 1)
	if ch == "." or ch == "":
		return ""
	var i := int(ch)
	return str(NATIONS[i]["name"]) if i < NATIONS.size() else ""

# A nation's starting cities: its capital plus any extra seeds (e.g. Peace Keepers' Sydney).
static func nation_seeds(nation_name: String) -> Array:
	var n := nation_by_name(nation_name)
	if n.is_empty():
		return []
	var out: Array = [Vector2i(int(n["x"]), int(n["y"]))]
	for sd in n.get("seeds", []):
		out.append(Vector2i(int(sd["x"]), int(sd["y"])))
	return out

# The nation whose territory claim covers hex (x, y), or "".
static func claim_at(x: int, y: int) -> String:
	if CLAIMS.is_empty():
		return ""
	var ll := hex_latlon(x, y)
	for c in CLAIMS:
		for b in c["boxes"]:
			if ll.x >= float(b[0]) and ll.x <= float(b[1]) and ll.y >= float(b[2]) and ll.y <= float(b[3]):
				return str(c["nation"])
	return ""

# Real-world latitude/longitude at the centre of hex (x, y), as Vector2(lat, lon).
static func hex_latlon(x: int, y: int) -> Vector2:
	var fx: float = (x + 0.5 * float(y & 1) + 0.5) / GRID_W
	var fy: float = (y + 0.5) / GRID_H
	var lon: float = fposmod(LON0 + fx * LON_SPAN + 180.0, 360.0) - 180.0
	return Vector2(LAT_TOP - fy * (LAT_TOP - LAT_BOT), lon)

# 1 for the Americas (and Greenland), 0 for the Old World. Starting territories
# never spread across this line, so no nation begins with land on another continent.
static func region_of(x: int, y: int) -> int:
	if not AMERICAS_SPLIT:
		return 0
	var lon: float = hex_latlon(x, y).y
	return 1 if (lon > -170.0 and lon <= -20.0) else 0

# Hex containing a real-world latitude/longitude (same projection as make_world.py).
static func hex_for_latlon(lat: float, lon: float) -> Vector2i:
	var fy: float = (LAT_TOP - lat) / (LAT_TOP - LAT_BOT)
	var y: int = clampi(int(fy * GRID_H), 0, GRID_H - 1)
	# offset east of the map's west edge; regional maps may run past 180 (Bering Strait)
	var fx: float = (fposmod(lon - LON0, 360.0) if WRAPS else fposmod(lon - LON0 + 180.0, 360.0) - 180.0) / LON_SPAN
	var x: int = int(floor(fx * GRID_W - 0.5 * float(y & 1)))
	x = posmod(x, GRID_W) if WRAPS else clampi(x, 0, GRID_W - 1)
	return Vector2i(x, y)

static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < GRID_W and y < GRID_H

static func tile_char(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return "."
	return ROWS[y].substr(x, 1)

static func terrain_at(x: int, y: int) -> String:
	match tile_char(x, y):
		"g":
			return GRASSLAND
		"d":
			return DESERT
		"m":
			return MOUNTAIN
		"s":
			return SNOW
		"j":
			return JUNGLE
		_:
			return OCEAN

static func is_land(x: int, y: int) -> bool:
	return terrain_at(x, y) != OCEAN

static func nations() -> Array:
	return NATIONS.duplicate(true)

static func nation_by_name(nation_name: String) -> Dictionary:
	for n in NATIONS:
		if (n as Dictionary).get("name") == nation_name:
			return (n as Dictionary).duplicate(true)
	return {}

static func nation_start(nation_name: String) -> Vector2i:
	var n := nation_by_name(nation_name)
	if n.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(n["x"]), int(n["y"]))

static func nation_at(x: int, y: int) -> Dictionary:
	for n in NATIONS:
		var d := n as Dictionary
		if int(d["x"]) == x and int(d["y"]) == y:
			return d.duplicate(true)
	return {}
