# WorldMap: Civ-style hex Earth for the Geopolitics map view.
# Scope is map-only: terrain grid + nation start positions, no gameplay rules.
# ROWS and capitals are generated from real coastlines by tools/make_world.py
# (equirectangular, pointy-top hexes in odd-r layout, wrapping at the Bering Strait).
# Legend: '.' ocean, 'g' grassland, 'd' desert, 'm' mountain, 's' snow, 'j' jungle.
extends RefCounted
class_name WorldMap

const GRID_W: int = 90
const GRID_H: int = 40

const LON0: float = -169.0 # west edge (Bering Strait); the map wraps east-west here
const LAT_TOP: float = 80.0
const LAT_BOT: float = -62.0

const OCEAN: String = "ocean"
const GRASSLAND: String = "grassland"
const DESERT: String = "desert"
const MOUNTAIN: String = "mountain"
const SNOW: String = "snow"
const JUNGLE: String = "jungle"

const ROWS: Array[String] = [
	"....................sss.ssssssssssssss.......ss....................s......................",
	"............ss..s.ssss.s...ssssssssss........s.........ss......sssssss......ss............",
	"...s.......s.sss.ss.sssss....ssssssss........s...s.....s...ssssssssssssssssssssss.........",
	"sssssssssssssssssssss..sss..ssssss..s........sssssss..ssssssssssssssssssssssssssssssssssss",
	".sssssssssssssssssss.s..ss...sss.....s......sssssssssssssssssssssssssssssssssssssssssss...",
	"gggggggmmmgggggggg....gg......s............ggg.gggggggggmgggggggggggggggggggggggg.ggg.....",
	".........ggggggggggg...gggg..............g..gg..ggggggggmmggggggggggggggggggg....gg.......",
	".........ggmmmmgggggg.gggggg...........g.g.gggggggggggggmgggggggggggggggggggg....g........",
	"..........ggmmmmggggggggggggg............ggggggggggggggggggggggggggggggggggggg............",
	"...........mmmmgggggggggggg..............ggmmgggggggggggggggggggdddddddggggg..............",
	"...........gmmmmggggggggg...............ggg..gggg...mmgddddgggggdddddddgggg..g............",
	"...........mmmmgggggggg................ggg.....ggggggggdddggdddddddddddggg................",
	"............gddddgggggg.................g.ggg......gggmmdddgmmmmmmmggggg..ggg.............",
	"............ddddgggggg.................gmmgggg.g..gggmmddddgmmmmmmmggggg..g...............",
	".............ddddg...g.................ddddddddddddddd.ddddgmmmmmmmgggggg.................",
	"...............gg....g................dddddddddddddddddd..gggggggggggggg..................",
	"................gg..g.g...............ddddddddddddddddddd...gggg.ggggg....................",
	"................gggj..j...............ddddddddddddd.dddd....ggg..jjj......................",
	"...................jjj.g..............ggggggggggggggggg......j.....jjj....................",
	"....................j..gg.............gggggggggggggmggg......j......j.....................",
	".......................ggggg...........ggggggggggggmmgg.......g....jj....j................",
	"......................mmjjjjj...............jjjjjggmgg............jj..j...................",
	"......................mmjjjjjj..............jjjjjjgmm..............jjjjj..................",
	".....................gmmjjjjjjjg............jjjjjggm...............j..jj...jjj............",
	"......................mmjjjjjjjggg...........jjjjjgg.................jj....j.jj...........",
	"......................mmjjjjjjjgg............ggggggg......................g...............",
	".......................mggggggggg............ggggggggjj...................gg..............",
	"........................mggggggg.............dddggg..j..................gggggg............",
	".........................mgggggg..............ddggg..j.................gddddddgg..........",
	"........................mggggg...............dddgg...g................gddddddggg..........",
	"........................mmgggg................gggg.....................gddddddggg.........",
	"........................mgggg.................ggg......................ddddddggg..........",
	"........................mmgg.................................................ggg..........",
	".......................gmgg..........................................................g....",
	"........................gg..........................................................gg....",
	".......................gg..........................................................g......",
	".......................gg.................................................................",
	".......................gg.................................................................",
	"..........................................................................................",
	"........sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss.........",
]

# Sample nations mapped to real-world regions matching their spec descriptions
# (BackgroundImage / theme). x/y are tile coords into ROWS (x = column).
const NATIONS: Array = [
	{
		"name": "Insurgents", "capital": "Kabul", "region": "Central Asia (Hindu Kush)",
		"x": 59, "y": 12, "color": "b5651d",
		"blurb": "Sparse mountain village + Guerilla Warfare -> Afghan mountains.",
	},
	{
		"name": "State Troops", "capital": "Baghdad", "region": "Middle East",
		"x": 52, "y": 13, "color": "c9a227",
		"blurb": "Middle Eastern town with mosques -> Mesopotamia.",
	},
	{
		"name": "Fundamentalists", "capital": "London", "region": "British Isles",
		"x": 42, "y": 8, "color": "7d3c98",
		"blurb": "Medieval village + Fanaticism -> old-world Europe.",
	},
	{
		"name": "Mercenaries", "capital": "Kinshasa", "region": "Central Africa (Congo)",
		"x": 45, "y": 23, "color": "922b21",
		"blurb": "Warzone rubble + Corruption -> Congo basin.",
	},
	{
		"name": "Peace Keepers", "capital": "New York", "region": "North America (East Coast)",
		"x": 23, "y": 10, "color": "2e86c1",
		"blurb": "United Nation tents + Defensive Doctrine -> UN HQ (NYC).",
	},
	{
		"name": "Horde", "capital": "Moscow", "region": "Russia",
		"x": 51, "y": 6, "color": "cb4335",
		"blurb": "Snowy Russian-style city + Conscription -> Russia.",
	},
	{
		"name": "Coalition Army", "capital": "Paris", "region": "Western Europe",
		"x": 43, "y": 8, "color": "1e8449",
		"blurb": "European-style towers + Aerial Supremacy -> NATO heartland.",
	},
	{
		"name": "Corporate Troops", "capital": "Tokyo", "region": "East Asia (Japan)",
		"x": 76, "y": 12, "color": "17a589",
		"blurb": "Cyberpunk skyrises + Advanced Robotics -> tech-hub Japan.",
	},
]

# Hex containing a real-world latitude/longitude (same projection as make_world.py).
static func hex_for_latlon(lat: float, lon: float) -> Vector2i:
	var fy: float = (LAT_TOP - lat) / (LAT_TOP - LAT_BOT)
	var y: int = clampi(int(fy * GRID_H), 0, GRID_H - 1)
	var fx: float = fposmod(lon - LON0, 360.0) / 360.0
	var x: int = posmod(int(fx * GRID_W - 0.5 * float(y & 1)), GRID_W)
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
