extends Card
class_name Item

# One-use weapons for the world-map war. An Item is bought in the shop with
# Influence like any card and drawn into your hand, but instead of going onto the
# map it is fired: pay its MoneyCost, pick a target hex within range of one of your
# launch sites, and it lands there, hitting every enemy card (and enemy flag)
# within BlastRadius hexes for Damage. Used up afterwards (it goes to the graveyard).
# An enemy Interceptor within reach of the target halves it (see MapWar.fire_item).

var Damage: int = 0 # at the hex it hits
var BlastRadius: int = 0
var Falloff: int = 0 # damage lost per hex of distance from the hit
# card name of a launch site -> how far (hexes) it can fire this item from there
var LaunchRanges: Dictionary = {}

func _init(name: String = "Item", money_cost: int = 0, influence_cost: int = 0, damage: int = 0, blast_radius: int = 0, launch_ranges: Dictionary = {}):
	super._init()
	card_name = name
	MoneyCost = money_cost
	InfluenceCost = influence_cost
	Damage = damage
	BlastRadius = blast_radius
	LaunchRanges = launch_ranges

# Damage to a card or flag `dist` hexes from where it lands (never below 1);
# halved (never below 1) when an Interceptor shot it down.
func damage_at(dist: int, intercepted: bool = false) -> int:
	var d := maxi(1, Damage - Falloff * dist)
	return maxi(1, d / 2) if intercepted else d

# How far this item can be fired from `site` (0: it can't be fired from there).
func launch_range(site: Card) -> int:
	return int(LaunchRanges.get(site.card_name, 0))

# "Barracks (6 hexes), Interceptor (8) or Airport (12)" for rule texts.
func launcher_text() -> String:
	var parts: Array = []
	var names: Array = LaunchRanges.keys()
	names.sort_custom(func(a, b): return int(LaunchRanges[a]) < int(LaunchRanges[b]))
	for i in range(names.size()):
		parts.append("%s (%d%s)" % [names[i], int(LaunchRanges[names[i]]), " hexes" if i == 0 else ""])
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " or " + str(parts[parts.size() - 1])
