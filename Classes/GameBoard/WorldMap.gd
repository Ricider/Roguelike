# WorldMap: Civ-style square-grid Earth for the Geopolitics map view.
# Scope is map-only: terrain grid + nation start positions, no gameplay rules.
# Legend: '.' ocean, 'g' grassland, 'd' desert, 'm' mountain, 's' snow, 'j' jungle.
extends RefCounted
class_name WorldMap

const GRID_W: int = 60
const GRID_H: int = 30

const OCEAN: String = "ocean"
const GRASSLAND: String = "grassland"
const DESERT: String = "desert"
const MOUNTAIN: String = "mountain"
const SNOW: String = "snow"
const JUNGLE: String = "jungle"

const ROWS: Array[String] = [
	"............................................................",
	"........sssss.......sssss...................................",
	"..sssss.sssssssss.ssssssss............ssssssssssssssssss....",
	"..sssssssssssssssss..ssss......ssss.sssssssssssssssssssssss.",
	"ggggggggggggg...gggg..ss......gggggggggggggggggggggggggggggg",
	"......gggggggggggggg.........ggggggggggggggggggggggggggggg..",
	".......ggggggggggggg.........gggggggggggggggggggggggggggg...",
	".........ggggggggggg........ggggggggggggggggggggggg.gg......",
	".........mmmgggggggg........gg.g.ggggggggmmgggggggg.gg......",
	"..........dddggggggg........ggggggggggdddggmmmggggg.gg......",
	"..........ggggg...gg........dddddddddddddggggggggg..........",
	"...........gggg.............ddddddddddddd.ggg.ggg...........",
	"..............ggg...........gggggggg......gg..ggg...........",
	"...............gggg.........gggggggg.......g..gg............",
	"................gggjjjjj....ggjjjjjg.........jjjjjj.........",
	"................mmjjjjjj....jjjjjgggg.........jjjj..........",
	".................mmgggg......gggggggg.g..........gg.........",
	".................mmgggg......gggggggggg.........gggggg......",
	".................mgggg.......dddggggg.g.........gdddddg.....",
	".................gggg.........gggggg............gdddddg.....",
	".................gggg.........ggggg..............ggggg....g.",
	".................ggg...............................gg....gg.",
	".................ggg.....................................g..",
	".................gg.........................................",
	".................g..........................................",
	"............................................................",
	"............................................................",
	"............................................................",
	"............................................................",
	".....ssssssssssssssssssssssssssssssssssssssssssssssssss.....",
]

# Sample nations mapped to real-world regions matching their spec descriptions
# (BackgroundImage / theme). x/y are tile coords into ROWS (x = column).
const NATIONS: Array = [
	{
		"name": "Insurgents", "capital": "Kabul", "region": "Central Asia (Hindu Kush)",
		"x": 41, "y": 9, "color": "b5651d",
		"blurb": "Sparse mountain village + Guerilla Warfare -> Afghan mountains.",
	},
	{
		"name": "State Troops", "capital": "Baghdad", "region": "Middle East",
		"x": 37, "y": 9, "color": "c9a227",
		"blurb": "Middle Eastern town with mosques -> Mesopotamia.",
	},
	{
		"name": "Fundamentalists", "capital": "London", "region": "British Isles",
		"x": 29, "y": 6, "color": "7d3c98",
		"blurb": "Medieval village + Fanaticism -> old-world Europe.",
	},
	{
		"name": "Mercenaries", "capital": "Kinshasa", "region": "Central Africa (Congo)",
		"x": 33, "y": 14, "color": "922b21",
		"blurb": "Warzone rubble + Corruption -> Congo basin.",
	},
	{
		"name": "Peace Keepers", "capital": "New York", "region": "North America (East Coast)",
		"x": 18, "y": 8, "color": "2e86c1",
		"blurb": "United Nation tents + Defensive Doctrine -> UN HQ (NYC).",
	},
	{
		"name": "Horde", "capital": "Moscow", "region": "Russia",
		"x": 36, "y": 6, "color": "cb4335",
		"blurb": "Snowy Russian-style city + Conscription -> Russia.",
	},
	{
		"name": "Coalition Army", "capital": "Paris", "region": "Western Europe",
		"x": 30, "y": 7, "color": "1e8449",
		"blurb": "European-style towers + Aerial Supremacy -> NATO heartland.",
	},
	{
		"name": "Corporate Troops", "capital": "Tokyo", "region": "East Asia (Japan)",
		"x": 53, "y": 9, "color": "17a589",
		"blurb": "Cyberpunk skyrises + Advanced Robotics -> tech-hub Japan.",
	},
]

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
