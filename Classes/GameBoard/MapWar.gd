# MapWar: the world map as the battlefield. Every nation places cards from its
# hand onto its own empty hexes; on its turn each of its units fires.
#   - Units without Range hit the closest enemy card on the map (hex distance,
#     east-west wrap), random among ties.
#   - Units with Range (random-target units) pick the closest enemy *nation*
#     (owner of the closest enemy card) and hit a random card of that nation.
#   - Every living nation's capital flag is a target too (on its capital hex):
#     damage to a flag goes straight to that nation's HP.
# Card rules carry over from the 4x10 battles: Rocket Launcher/Howitzer fire 4
# times, Special Ops x2 vs ground, Anti Aircraft x3 vs flying, Flying takes half
# from non-ranged, Barracks +2 to adjacent units, Interceptors block 75% of ranged/flying
# hits on friends within INTERCEPTOR_RANGE hexes, Fighter and Bomber Jets splash the
# target's neighbors.
# Terrain: non-flying units on a mountain hex take 1 less damage (minimum 1);
# units in a forest (jungle hex) take 1 less from flying attackers (minimum 1).
# Buildings (walls included) can't be placed on mountains.
# Scars: a destroyed building leaves ruins on its hex (non-flying units there take
# RUINS_COVER less per hit); a Nuke leaves nuclear wasteland (units starting their
# turn there take FALLOUT_DAMAGE). Items (Missile, Nuke) are one-use weapons fired
# from launch sites; see "items" below.
# A destroyed card costs its owner HP equal to its BioCost. A nation at 0 HP
# cedes border hexes (1 per 10 HP the victor has left; x2 when it fields fewer
# than 3 units, x4 with none) to whoever damaged it most, loses the cards on those
# hexes, then rebuilds to full HP. A fallen flag moves to the free hex nearest
# the centre of the remaining territory; flags always keep a hex to themselves.
# The winner earns INFLUENCE_PER_HEX Influence per hex taken (spent in the shop), and
# destroying an enemy building pays its attacker BUILDING_BOUNTY of its Influence cost.
extends RefCounted
class_name MapWar

# Influence (the shop currency) a nation earns per hex it takes.
const INFLUENCE_PER_HEX: float = 2.5 # rounded on each collapse's total
# Influence for destroying an enemy building: this share of its Influence cost, rounded.
const BUILDING_BOUNTY := 1.0 / 3.0
# Every nation earns at least this much Influence a turn: at the start of its turn,
# whatever it earned since its last turn (hexes, buildings) is topped up to this.
const MIN_INFLUENCE_PER_TURN := 5
# A nation fielding fewer than this many units loses territory twice as fast;
# with no units on the map at all it loses territory four times as fast.
const WEAK_UNIT_COUNT: int = 3
# Shop: 5 card slots + 3 modifiers per nation, restocked at the start of its turn.
const SHOP_CARD_SLOTS: int = 5
const REMOVE_COST: int = 25

var campaign: MapCampaign = null
var players: Dictionary = {} # nation -> Player
var scars: Dictionary = {} # "x,y" -> "ruins" | "wasteland" (see RUINS_COVER, FALLOUT_DAMAGE)
var last_fallout: Array = [] # [[hex, died], ...] units hurt by wasteland in the latest begin_turn
var units: Dictionary = {} # "x,y" -> {"card": Card, "owner": String}
var ledger: Dictionary = {} # victim nation -> {attacker nation: HP damage dealt}
var turn: int = 1
var rng := RandomNumberGenerator.new()
var deck_weights: Dictionary = {} # nation -> {card name: copies in its starting deck}
var shops: Dictionary = {} # nation -> {"cards": Array[Card], "mods": Array[Modifier], "remove_used": bool}
var _last_intercept_from := Vector2i(-1, -1) # hex of the Interceptor that blocked part of the latest hit
# Influence earned from destroyed enemy buildings, per nation, until the map screen
# collects it with take_bounty() (to show and log it).
var bounties: Dictionary = {}
# Story reinforcements: extras rules with "turn" > 1, waiting to land at the start of
# their nation's turn that round (see arrive_reinforcements). last_arrivals holds the
# [[nation, card name, hex], ...] that landed in the latest begin_turn, for the map screen.
var pending: Array = []
var last_arrivals: Array = []
var last_upkeep: Dictionary = {} # {"money", "bio"} paid in the latest begin_turn
var last_attrition: Array = [] # [[hex, crashed], ...] Fighter Jets out of Airport range in the latest begin_turn
# Each nation's latest turn of income, line by line, for the round report:
# {"money": [[label, amount], ...], "bio": [...], "money_from", "money_to", "bio_from", "bio_to"}
var last_economy: Dictionary = {}
# Influence earned since reset_round_stats: nation -> {"hexes": n, "buildings": n}
var influence_log: Dictionary = {}
# Influence each nation earned since the start of its last turn (for the minimum top-up)
var earned_since_turn: Dictionary = {}

# make_player: Callable(nation: String) -> Player for the AI nations.
func setup(c: MapCampaign, make_player: Callable, human: Player) -> void:
	campaign = c
	players.clear()
	units.clear()
	scars.clear()
	ledger.clear()
	turn = 1
	rng.randomize()
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		var p: Player = human if (nm == c.player_nation and human != null) else make_player.call(nm)
		p.display_name = nm
		p.MapCards.clear()
		players[nm] = p
		_add_starting_items(p, nm)
		deck_weights[nm] = starting_deck_weights(p)
		# Starting cards on the 4x10 board move onto the map around the capital.
		var start_cards: Array = p.get_all_board_cards()
		for row in p.Board:
			for sq in row.Squares:
				sq.clear()
		# buildings first, so units can be summoned near them (deploy zones)
		start_cards.sort_custom(func(a, b): return (a is Building) and not (b is Building))
		for card in start_cards:
			var t := best_hex_for(nm, card as Card)
			if t.x >= 0:
				_put(nm, card as Card, t)
			else:
				p.DiscardPile.append(card) # no room near its flag or buildings: back into the deck
	# story chapters start some nations stronger or weaker than usual...
	apply_setup(WorldMap.SETUP)
	# ...and add their own set pieces on top of the default starting cards; rules
	# with a later "turn" wait in `pending` and land as reinforcements.
	pending.clear()
	last_arrivals = []
	var now: Array = []
	for r in WorldMap.EXTRAS:
		if int((r as Dictionary).get("turn", 1)) > 1:
			pending.append((r as Dictionary).duplicate(true))
		else:
			now.append(r)
	place_extras(now)

# One-use weapons some nations start the war with, shuffled into their draw piles
# (map war only: the legacy card battles never see them). They also make the
# shop offer them to those nations (deck_weights).
const STARTING_ITEMS := {
	"Coalition Army": {"Nuke": 1, "Missile": 3},
	"Corporate Troops": {"Nuke": 2, "Missile": 5},
	"Horde": {"Nuke": 3, "Missile": 2},
	"State Troops": {"Missile": 2},
}

func _add_starting_items(p: Player, nation: String) -> void:
	var items: Dictionary = STARTING_ITEMS.get(nation, {})
	if items.is_empty():
		return
	for item_name in items.keys():
		for i in range(int(items[item_name])):
			p.DrawPile.append(p._base_card_by_name(str(item_name)))
	p.DrawPile.shuffle()

# Per-nation starting tweaks of a story chapter: {nation: {"max_hp", "influence",
# "money", "bio"}}. max_hp also sets current HP (collapses refill to it as usual).
func apply_setup(setup_rules: Dictionary) -> void:
	for nm in setup_rules.keys():
		if not players.has(nm):
			continue
		var p: Player = players[nm]
		var st: Dictionary = setup_rules[nm]
		if st.has("max_hp"):
			p.MaxHitPoints = maxi(1, int(st["max_hp"]))
			p.HitPoints = p.MaxHitPoints
		if st.has("influence"):
			p.Influence = int(st["influence"])
		if st.has("money"):
			p.MoneySupply = int(st["money"])
		if st.has("bio"):
			p.BioSupply = int(st["bio"])

# Land the reinforcements due for `nation` by now (rules whose "turn" has come).
# Cards with no free hex to land on wait for the next turn; a nation that is gone
# gets none. Rules land one by one, so a reinforcement can't use "next_to".
# Returns the placed [[nation, card name, hex], ...].
func arrive_reinforcements(nation: String) -> Array:
	if not alive(nation):
		pending = pending.filter(func(r): return str((r as Dictionary).get("nation", "")) != nation)
		return []
	var placed: Array = []
	var keep: Array = []
	for r in pending:
		var rule: Dictionary = r
		if str(rule.get("nation", "")) != nation or int(rule.get("turn", 1)) > turn:
			keep.append(rule)
			continue
		var got := place_extras([rule])
		placed.append_array(got)
		if got.size() < int(rule.get("count", 1)):
			var rest := rule.duplicate(true)
			rest["count"] = int(rule.get("count", 1)) - got.size()
			keep.append(rest) # no room yet: the rest try again next turn
	pending = keep
	return placed

# What is still on its way: [{"nation", "card", "count", "turn"}, ...] by turn.
func upcoming_reinforcements() -> Array:
	var out: Array = []
	for r in pending:
		var rule: Dictionary = r
		if alive(str(rule.get("nation", ""))):
			out.append({"nation": str(rule["nation"]), "card": str(rule["card"]), "count": int(rule.get("count", 1)), "turn": int(rule["turn"])})
	out.sort_custom(func(a, b): return int(a["turn"]) < int(b["turn"]))
	return out

# ------------------------------------------------------------------ story extras
# Free cards a story chapter starts with (tools/make_story.py, "extras"). Each rule:
# {nation, card, count, at, hp?, id?}; "at" is one of
#   {"random": true}                  anywhere in the nation's free land
#   {"random_in": [[lat0, lat1, lon0, lon1], ...]}   ...inside those boxes
#   {"near": [lat, lon]}              its free hexes nearest that point
#   {"border": nation}                random free hexes of its land touching that nation
#   {"border": nation, "middle": true}   the free hex in the middle of that border
#       (with "room": n, the nearest one to the middle with n free hexes beside it)
#   {"next_to": id}                   free hexes beside an earlier rule's cards
# Any of these may add "terrain": "mountain" (or another terrain) to keep to such hexes.
# A rule with "hp" starts its cards damaged (shown against their full HP).
# A rule with "turn": n (n > 1) is a reinforcement: it lands at the start of that
# nation's turn in round n instead (setup keeps it in `pending`).
# Returns the placed [[nation, card name, hex], ...].
func place_extras(rules: Array) -> Array:
	var placed: Array = []
	var by_id: Dictionary = {}
	for r in rules:
		var rule: Dictionary = r
		var nation := str(rule.get("nation", ""))
		if not players.has(nation) or not alive(nation):
			continue
		var p: Player = players[nation]
		var at: Dictionary = rule.get("at", {})
		var spots: Array = []
		for i in range(int(rule.get("count", 1))):
			var t := _extra_spot(nation, at, by_id)
			if t.x < 0:
				break
			var card: Card = p._base_card_by_name(str(rule.get("card", "")))
			if card == null:
				break
			p.apply_hitpoints_modifier(card)
			card.set_meta("map_max_hp", maxi(card_hp(card), 1))
			if rule.has("hp"):
				var hp := clampi(int(rule["hp"]), 1, card_hp(card))
				if card is Unit:
					(card as Unit).HitPoints = hp
				elif card is Building:
					(card as Building).HitPoints = hp
			_put(nation, card, t)
			spots.append(t)
			placed.append([nation, card.card_name, t])
		if rule.has("id"):
			by_id[str(rule["id"])] = spots
		if str(rule.get("card", "")) == "Fighter Jet" and not spots.is_empty():
			_ensure_airport(nation, spots) # set-piece jets come with somewhere to land
	return placed

func _extra_free(nation: String, t: Vector2i) -> bool:
	return campaign.owner_of(t.x, t.y) == nation and not units.has(MapCampaign.key_of(t.x, t.y)) and campaign.capital_site(nation) != t

func _extra_spot(nation: String, at: Dictionary, by_id: Dictionary) -> Vector2i:
	var free: Array = []
	for t in campaign.tiles_of(nation):
		if _extra_free(nation, t):
			free.append(t)
	if at.has("terrain"):
		var on_terrain: Array = free.filter(func(t: Vector2i) -> bool: return WorldMap.terrain_at(t.x, t.y) == str(at["terrain"]))
		if not on_terrain.is_empty():
			free = on_terrain # none of that terrain left: fall back to any free land
	if free.is_empty():
		return Vector2i(-1, -1)
	if at.has("near"):
		var ll: Array = at["near"]
		var goal := WorldMap.hex_for_latlon(float(ll[0]), float(ll[1]))
		return _nearest_of(free, [goal])
	if at.has("next_to"):
		var anchors: Array = by_id.get(str(at["next_to"]), [])
		if anchors.is_empty():
			return Vector2i(-1, -1)
		return _nearest_of(free, anchors) # right beside it, or as close as the land allows
	var pool: Array = free
	if at.has("random_in"):
		pool = free.filter(func(t: Vector2i) -> bool:
			var ll2 := WorldMap.hex_latlon(t.x, t.y)
			for b in at["random_in"]:
				if ll2.x >= float(b[0]) and ll2.x <= float(b[1]) and ll2.y >= float(b[2]) and ll2.y <= float(b[3]):
					return true
			return false)
	elif at.has("border"):
		var other := str(at["border"])
		pool = free.filter(func(t: Vector2i) -> bool:
			for nb in MapCampaign.wrapped_neighbors(t):
				if campaign.owner_of((nb as Vector2i).x, (nb as Vector2i).y) == other:
					return true
			return false)
		if bool(at.get("middle", false)) and not pool.is_empty():
			pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
			# from the middle outwards, the first hex with "room" free hexes of its own beside it
			var room := int(at.get("room", 0))
			var mid: int = pool.size() / 2
			var order: Array = range(pool.size())
			order.sort_custom(func(a: int, b: int) -> bool: return absi(a - mid) < absi(b - mid) if absi(a - mid) != absi(b - mid) else a < b)
			for i in order:
				var cand: Vector2i = pool[i]
				var roomy := 0
				for nb in MapCampaign.wrapped_neighbors(cand):
					if _extra_free(nation, nb as Vector2i):
						roomy += 1
				if roomy >= room:
					return cand
			return pool[mid]
	if pool.is_empty():
		pool = free # nothing matched: anywhere in its land rather than nowhere
	return pool[rng.randi_range(0, pool.size() - 1)]

# The hex of `pool` nearest any of `targets` (ties broken by position, so it is stable).
static func _nearest_of(pool: Array, targets: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for t in pool:
		var d := 1 << 30
		for g in targets:
			d = mini(d, MapCampaign.hex_distance(t, g))
		if d < best_d or (d == best_d and (t.y < best.y or (t.y == best.y and t.x < best.x))):
			best_d = d
			best = t
	return best

# ------------------------------------------------------------------ geometry
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return MapCampaign.hex_distance(a, b)

static func key_to_hex(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

# ------------------------------------------------------------------- queries
func alive(nation: String) -> bool:
	return campaign != null and campaign.is_alive(nation)

func unit_at(t: Vector2i) -> Dictionary:
	return units.get(MapCampaign.key_of(t.x, t.y), {})

func card_hp(card: Card) -> int:
	if card is Unit:
		return (card as Unit).HitPoints
	if card is Building:
		return (card as Building).HitPoints
	return 1

func cards_of(nation: String) -> Array:
	var out: Array = []
	for k in units.keys():
		if str(units[k]["owner"]) == nation:
			out.append(k)
	return out

func turn_order() -> Array:
	var out: Array = []
	if alive(campaign.player_nation):
		out.append(campaign.player_nation)
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		if nm != campaign.player_nation and alive(nm):
			out.append(nm)
	return out

func shortfall(nation: String, card: Card) -> String:
	var p: Player = players[nation]
	var parts: Array = []
	var need_m: int = p.get_effective_money_cost(card)
	if need_m > p.MoneySupply:
		parts.append("%d more Money" % (need_m - p.MoneySupply))
	if card.BioCost > p.BioSupply:
		parts.append("%d more Bio" % (card.BioCost - p.BioSupply))
	return " and ".join(parts)

# "" when the card can go on hex t, else a human-readable reason.
# ------------------------------------------------------------- airports
# Fighter Jets live off their Airports: they can only be deployed on, or fly to, hexes
# within AIRPORT_RANGE of one of their nation's standing Airports, and a jet left
# outside that range (its Airport destroyed) loses JET_ATTRITION HP at the start of
# each of its nation's turns until it gets back (or crashes). A stranded jet may fly
# anywhere it can reach, to get home. Bomber Jets don't need an Airport, but within
# range of one they take BOMBER_AIRPORT_COVER less from every hit.
const AIRPORT_RANGE := 12
const JET_ATTRITION := 2
const BOMBER_AIRPORT_COVER := 1

func _splashes(unit: Unit) -> bool:
	return unit is FighterJet or unit is BomberJet

func airports_of(nation: String) -> Array:
	var out: Array = []
	for k in cards_of(nation):
		var c: Card = units[k]["card"]
		if c is Airport and card_hp(c) > 0:
			out.append(key_to_hex(k))
	return out

func in_airport_range(nation: String, t: Vector2i, airports: Array = []) -> bool:
	if airports.is_empty():
		airports = airports_of(nation)
	for a in airports:
		if hex_distance(t, a as Vector2i) <= AIRPORT_RANGE:
			return true
	return false

# Jets out of their Airports' range lose JET_ATTRITION HP; returns [[hex, crashed], ...].
func jet_attrition(nation: String) -> Array:
	var out: Array = []
	var airports := airports_of(nation)
	for k in cards_of(nation):
		var c: Card = units[k]["card"]
		if not (c is FighterJet) or in_airport_range(nation, key_to_hex(k), airports):
			continue
		(c as Unit).HitPoints -= JET_ATTRITION
		var crashed := (c as Unit).HitPoints <= 0
		out.append([key_to_hex(k), crashed])
		if crashed:
			_remove(k) # out of fuel: lost, but costs its nation no HP
	return out

# Story set pieces: jets placed by a chapter get an Airport beside them if they have none in range.
func _ensure_airport(nation: String, jets: Array) -> void:
	var airports := airports_of(nation)
	var stranded: Array = jets.filter(func(t): return not in_airport_range(nation, t, airports))
	if stranded.is_empty():
		return
	var free: Array = []
	var flag := campaign.capital_site(nation)
	for t in campaign.tiles_of(nation):
		var tv := t as Vector2i
		if not units.has(MapCampaign.key_of(tv.x, tv.y)) and tv != flag and can_build_on(Airport.new(), tv):
			free.append(tv)
	if free.is_empty():
		return
	var spot := _nearest_of(free, stranded)
	var ap := Airport.new()
	ap.set_meta("map_max_hp", ap.HitPoints)
	_put(nation, ap, spot)
	var covered := stranded.filter(func(t): return hex_distance(t, spot) <= AIRPORT_RANGE)
	if not covered.is_empty() and covered.size() < stranded.size():
		_ensure_airport(nation, stranded) # the jets were spread far apart: another one

# ------------------------------------------------------------- deploy zones
# Cards go only on free hexes of your own land, and only near what raises them.
# Units: within DEPLOY_RADIUS hexes of your flag or one of your standing buildings:
#   BioCost >= MoneyCost (people: Infantry, Special Ops)       -> Housing or Barracks
#   Fighter Jets and Bomber Jets                                -> an Airport only (not the flag)
#   MoneyCost > BioCost, Flying (Drone)                         -> Corporation, Factory or Airport
#   MoneyCost > BioCost, on the ground (Tank, Artilery, AA...)  -> Factory
# Buildings (Walls included): within BUILD_RADIUS hexes of your flag or any of your
# standing buildings, or within BUILD_INFANTRY_RADIUS hexes of one of your Infantry
# (the builders): settlements grow out from what you hold, or follow your troops.
const DEPLOY_RADIUS := 2
const BUILD_RADIUS := 5
const BUILD_INFANTRY_RADIUS := 2

# Names of the buildings (besides the flag) a unit can be deployed near; [] for buildings.
static func deploy_anchors(card: Card) -> Array:
	if not (card is Unit):
		return []
	if _airport_built(card):
		return ["Airport"]
	if card.BioCost >= card.MoneyCost:
		return ["Housing", "Barracks"]
	if (card as Unit).Flying:
		return ["Corporation", "Factory", "Airport"]
	return ["Factory"]

# Jets are built only at Airports: not even near the flag.
static func _airport_built(card: Card) -> bool:
	return card is FighterJet or card is BomberJet

# "your flag or a Housing", "your flag, a Corporation or a Factory", ... (units)
static func deploy_anchor_text(card: Card) -> String:
	if _airport_built(card):
		return "one of your Airports"
	var names: Array = deploy_anchors(card).map(func(n): return "a " + str(n))
	if names.is_empty():
		return "your flag or one of your buildings"
	if names.size() == 1:
		return "your flag or %s" % names[0]
	return "your flag, %s or %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]

# Where a card may go, in words: "within 2 hexes of your flag or a Housing", ...
static func deploy_rule_text(card: Card) -> String:
	if card is Unit:
		return "within %d hexes of %s" % [DEPLOY_RADIUS, deploy_anchor_text(card)]
	return "within %d hexes of your flag or one of your buildings, or %d hexes of one of your Infantry" % [BUILD_RADIUS, BUILD_INFANTRY_RADIUS]

# What a card of `nation` may be placed near: [[hex, radius], ...] (its flag first).
func deploy_zone(nation: String, card: Card) -> Array:
	var flag := campaign.capital_site(nation)
	if card is Unit:
		var anchors := deploy_anchors(card)
		var out: Array = [] if _airport_built(card) else [[flag, DEPLOY_RADIUS]]
		for k in cards_of(nation):
			var c: Card = units[k]["card"]
			if anchors.has(c.card_name) and card_hp(c) > 0:
				out.append([key_to_hex(k), DEPLOY_RADIUS])
		return out
	var zone: Array = [[flag, BUILD_RADIUS]]
	for k in cards_of(nation):
		var c2: Card = units[k]["card"]
		if card_hp(c2) <= 0:
			continue
		if c2 is Building:
			zone.append([key_to_hex(k), BUILD_RADIUS])
		elif c2 is Infantry:
			zone.append([key_to_hex(k), BUILD_INFANTRY_RADIUS])
	return zone

# Just the hexes of deploy_zone (the flag and the cards a card can be placed near).
func deploy_sources(nation: String, card: Card) -> Array:
	return deploy_zone(nation, card).map(func(z): return z[0])

func in_deploy_zone(nation: String, card: Card, t: Vector2i, zone: Array = []) -> bool:
	if card is FighterJet and not in_airport_range(nation, t):
		return false # and within AIRPORT_RANGE of one of your Airports
	if zone.is_empty():
		zone = deploy_zone(nation, card)
	for z in zone:
		if hex_distance(t, z[0] as Vector2i) <= int(z[1]):
			return true
	return false

# Every hex `card` could be placed on now (own, free, not the flag, terrain allows,
# within its deploy zone), ignoring whether it is in hand or affordable.
func deploy_hexes(nation: String, card: Card) -> Array:
	var out: Array = []
	var flag := campaign.capital_site(nation)
	var zone := deploy_zone(nation, card)
	var airports := airports_of(nation) if card is FighterJet else []
	if card is FighterJet and airports.is_empty():
		return out # no Airport, no Fighter Jets
	for t in campaign.tiles_of(nation):
		var tv := t as Vector2i
		if units.has(MapCampaign.key_of(tv.x, tv.y)) or tv == flag or not can_build_on(card, tv):
			continue
		if card is FighterJet and not in_airport_range(nation, tv, airports):
			continue
		var in_zone := false
		for z in zone:
			if hex_distance(tv, z[0] as Vector2i) <= int(z[1]):
				in_zone = true
				break
		if not in_zone:
			continue
		out.append(tv)
	return out

func can_place(nation: String, card: Card, t: Vector2i) -> String:
	if card is Item:
		return "%s is fired, not placed: from your %s" % [card.card_name, (card as Item).launcher_text()]
	if not WorldMap.in_bounds(t.x, t.y) or campaign.owner_of(t.x, t.y) != nation:
		return "You can only build on your own territory"
	if units.has(MapCampaign.key_of(t.x, t.y)):
		return "That hex is taken"
	if campaign.capital_site(nation) == t:
		return "Your flag stands here; it needs its own hex"
	if not can_build_on(card, t):
		return "Buildings can't be placed on mountains"
	if not in_deploy_zone(nation, card, t):
		return "%s must be %s %s" % [card.card_name, "deployed" if card is Unit else "built", deploy_rule_text(card)]
	var p: Player = players[nation]
	if not p.Hand.has(card):
		return "That card is not in your hand"
	var short := shortfall(nation, card)
	if short != "":
		return "Can't afford %s: need %s" % [card.card_name, short]
	return ""

func place(nation: String, card: Card, t: Vector2i) -> bool:
	if can_place(nation, card, t) != "":
		return false
	var p: Player = players[nation]
	p.MoneySupply -= p.get_effective_money_cost(card)
	p.BioSupply -= card.BioCost
	p.Hand.erase(card)
	p.apply_hitpoints_modifier(card)
	_put(nation, card, t)
	if card is Building and str(scars.get(MapCampaign.key_of(t.x, t.y), "")) == "ruins":
		scars.erase(MapCampaign.key_of(t.x, t.y)) # built over: the ruins are cleared
	card.set_meta("moves_left", 0) # freshly deployed: it can move from next turn
	card.set_meta("deployed_turn", turn)
	return true

func _put(nation: String, card: Card, t: Vector2i) -> void:
	if not card.has_meta("map_max_hp"):
		card.set_meta("map_max_hp", maxi(card_hp(card), 1))
	units[MapCampaign.key_of(t.x, t.y)] = {"card": card, "owner": nation}
	(players[nation] as Player).MapCards.append(card)

func _remove(k: String) -> void:
	if not units.has(k):
		return
	var info: Dictionary = units[k]
	var p: Player = players.get(str(info["owner"]))
	if p != null:
		p.MapCards.erase(info["card"])
		p.Graveyard.append(info["card"])
	units.erase(k)

# ------------------------------------------------------------------ turns
# Upkeep: every turn a nation pays for its units on the map, MoneyCost out of its
# Money and BioCost out of its Bio (buildings are free to keep). It works like a
# progressive tax: the 1st unit pays UPKEEP_RATE of its cost, each further unit one
# UPKEEP_RAMP more (2nd 11%, 3rd 12% ...), never more than UPKEEP_MAX (50%, from the
# 41st unit on). A unit only pays its own bracket, so a new unit never makes the
# others dearer. In the nation's favour, its most expensive units fill the cheapest
# brackets, Money and Bio each sorted on their own (the lowest bill any order gives).
# Rounded on the totals; supplies never drop below 0.
const UPKEEP_RATE := 0.10
const UPKEEP_RAMP := 0.01
const UPKEEP_MAX := 0.50

# The rate of the n-th unit's bracket (n from 1).
static func upkeep_bracket(n: int) -> float:
	return minf(UPKEEP_RATE + UPKEEP_RAMP * maxi(n - 1, 0), UPKEEP_MAX)

# The bracket the next unit `nation` deploys would pay (the marginal rate).
func upkeep_rate(nation: String) -> float:
	return upkeep_bracket(unit_count(nation) + 1)

# Costs (the most expensive first) times the brackets (the cheapest first).
static func progressive_upkeep(costs: Array) -> float:
	var sorted_costs := costs.duplicate()
	sorted_costs.sort()
	sorted_costs.reverse()
	var total := 0.0
	for i in range(sorted_costs.size()):
		total += float(sorted_costs[i]) * upkeep_bracket(i + 1)
	return total

# {"money": int, "bio": int} that `nation` pays at the start of its next turn,
# plus "money_cost"/"bio_cost": the units' total cost (for the effective rate).
func upkeep(nation: String) -> Dictionary:
	var money: Array = []
	var bio: Array = []
	for k in cards_of(nation):
		var c: Card = units[k]["card"]
		if c is Unit:
			money.append(c.MoneyCost)
			bio.append(c.BioCost)
	return {"money": roundi(progressive_upkeep(money)), "bio": roundi(progressive_upkeep(bio))}

func pay_upkeep(nation: String) -> Dictionary:
	var up := upkeep(nation)
	var p: Player = players[nation]
	p.MoneySupply = maxi(p.MoneySupply - int(up["money"]), 0)
	p.BioSupply = maxi(p.BioSupply - int(up["bio"]), 0)
	return up

# What `nation`'s income this turn is made of, before the 200 cap and upkeep:
# {"money": [[label, amount], ...], "bio": [...]} (mirrors Player.economy_phase).
func income_breakdown(nation: String) -> Dictionary:
	var p: Player = players[nation]
	var money: Array = [["Base income", 10]]
	var counts: Dictionary = {} # building name -> [count, income]
	for c in p.MapCards:
		if c is Building and (c as Building).Income != 0:
			var e: Array = counts.get(c.card_name, [0, 0])
			counts[c.card_name] = [int(e[0]) + 1, int(e[1]) + (c as Building).Income]
	var names: Array = counts.keys()
	names.sort()
	for nm in names:
		var e2: Array = counts[nm]
		money.append(["%s x%d" % [nm, int(e2[0])], int(e2[1])])
	if p.has_modifier("Conscription"):
		var gross := 10 + p.total_money_income()
		money.append(["Conscription (halves Money)", int(gross * 0.5) - gross])
	if p.has_modifier("Corruption"):
		money.append(["Corruption", 10])
	var grown: int = int(p.BioSupply * Housing.bio_rate(p) + 5 + 0.0001)
	var bio: Array = [["Growth (10% + 5)", grown - p.BioSupply]]
	var houses := Housing.count_housing(p)
	if houses > 0:
		bio.append(["Housing x%d" % houses, Housing.extra_bio(p)])
	if p.has_modifier("Conscription"):
		bio.append(["Conscription", 15])
	return {"money": money, "bio": bio}

func begin_turn(nation: String) -> void:
	var p: Player = players[nation]
	var econ := income_breakdown(nation)
	var money0 := p.MoneySupply
	var bio0 := p.BioSupply
	p.economy_phase() # income from map buildings + draw to 10
	var money1 := p.MoneySupply
	var bio1 := p.BioSupply
	last_upkeep = pay_upkeep(nation) # then the army's upkeep comes out of it
	# what really happened, line by line (cap and upkeep included)
	for key in ["money", "bio"]:
		var lines: Array = econ[key]
		var gross := 0
		for l in lines:
			gross += int(l[1])
		var before: int = money0 if key == "money" else bio0
		var after_income: int = money1 if key == "money" else bio1
		var capped: int = before + gross - after_income
		if capped > 0:
			lines.append(["Over the 200 cap", -capped])
		var after: int = p.MoneySupply if key == "money" else p.BioSupply
		lines.append(["Upkeep (%d units, progressive: 10%% up to %d%% of their %s)" % [unit_count(nation), roundi(upkeep_bracket(maxi(unit_count(nation), 1)) * 100.0), "MoneyCost" if key == "money" else "BioCost"], after - after_income]) # shown even at 0
	econ["money_from"] = money0
	econ["money_to"] = p.MoneySupply
	econ["bio_from"] = bio0
	econ["bio_to"] = p.BioSupply
	econ["influence_topup"] = influence_topup(nation)
	last_economy[nation] = econ
	last_attrition = jet_attrition(nation) # stranded Fighter Jets run low
	last_fallout = fallout(nation) # units sitting in nuclear wasteland
	restock_shop(nation)
	last_arrivals = arrive_reinforcements(nation) # before the refill: they can move at once
	refill_moves(nation)

# ------------------------------------------------------------------- movement
# Units can move each turn; buildings (walls included) and flags never move.
# Hexes per turn, first rule that applies:
#   Flying 6  >  ranged (HasRange, modifiers included) 3  >  BioCost < MoneyCost 4  >  else 5
# Units cross borders: they can stop on any free hex in play, enemy land and sea
# included (ground units sail there by boat), but never on a flag. Ground units
# pass their own cards but not other nations'; flying units pass over anything.
# Standing on enemy land takes nothing: hexes still change hands only when a nation
# collapses. Ground units are slower by boat, and 1-move units can't sail
# (SEA_PENALTY). A card deployed this turn starts moving next turn. Moves left are
# kept on the card (meta "moves_left"); missing means a full turn's worth.
const MOVE_FLYING := 6
const MOVE_RANGED := 3
const MOVE_CHEAP := 4   # BioCost < MoneyCost (machines more than men: tanks, AA...)
const MOVE_DEFAULT := 5

func move_allowance(nation: String, card: Card) -> int:
	if not (card is Unit):
		return 0
	var u := card as Unit
	if u.Flying:
		return MOVE_FLYING
	if (players[nation] as Player).has_range_for(u):
		return MOVE_RANGED
	if card.BioCost < card.MoneyCost:
		return MOVE_CHEAP
	return MOVE_DEFAULT

# Boats: ground units are slower at sea. Boarding (a step from land onto the sea)
# costs 1 extra move, and a turn begun at sea refills SEA_PENALTY fewer moves; so an
# Infantry sails 4 hexes a turn instead of walking 5. A ground unit with only 1 move a
# turn couldn't board at all (none has so few now). A unit stuck at sea still gets 1 move.
const SEA_PENALTY := 1

func _at_sea(t: Vector2i) -> bool:
	return not WorldMap.is_land(t.x, t.y)

# Moves a card on hex key `k` gets at the start of a turn (fewer for ground units at sea).
func turn_allowance(k: String) -> int:
	var card: Card = units[k]["card"]
	var full := move_allowance(str(units[k]["owner"]), card)
	if full > 0 and card is Unit and not (card as Unit).Flying and _at_sea(key_to_hex(k)):
		return maxi(full - SEA_PENALTY, 1)
	return full

# Can this ground unit board a boat? Not with only 1 move a turn.
func can_sail(nation: String, card: Card) -> bool:
	return card is Unit and ((card as Unit).Flying or move_allowance(nation, card) > SEA_PENALTY)

func moves_left(k: String) -> int:
	if not units.has(k):
		return 0
	var card: Card = units[k]["card"]
	return int(card.get_meta("moves_left", turn_allowance(k)))

func refill_moves(nation: String) -> void:
	for k in cards_of(nation):
		var card: Card = units[k]["card"]
		card.set_meta("moves_left", turn_allowance(k))

# Moves one step from `a` onto `b` costs: 1, or 1 + SEA_PENALTY for a ground unit
# boarding (land onto sea); -1 = not allowed (a ground unit that can't sail, onto sea).
func _step_cost(a: Vector2i, b: Vector2i, flying: bool, sails: bool) -> int:
	if flying or not _at_sea(b):
		return 1
	if not sails:
		return -1
	return 1 if _at_sea(a) else 1 + SEA_PENALTY

# Moves a path costs the card on `k` (see _step_cost).
func path_cost(k: String, path: Array) -> int:
	var card: Card = units[k]["card"]
	var flying := card is Unit and (card as Unit).Flying
	var sails := can_sail(str(units[k]["owner"]), card)
	var total := 0
	for i in range(1, path.size()):
		total += maxi(_step_cost(path[i - 1], path[i], flying, sails), 1)
	return total

# Hexes the card at `k` can move to this turn: {hex: [path from k's hex to it]}.
# Cheapest paths first (boarding costs extra), fewest steps among equals.
func reachable(k: String) -> Dictionary:
	var out := {}
	if not units.has(k):
		return out
	var budget := moves_left(k)
	var card: Card = units[k]["card"]
	if budget <= 0 or not (card is Unit):
		return out
	var nation := str(units[k]["owner"])
	var flying := (card as Unit).Flying
	var sails := can_sail(nation, card)
	var start := key_to_hex(k)
	var flags: Dictionary = {}
	for site in flag_sites().values():
		flags[site] = true
	var parent := {start: start}
	var cost := {start: 0}
	var queue: Array = [start]
	var head := 0
	while head < queue.size(): # small budgets: relax until nothing improves
		var cur: Vector2i = queue[head]
		head += 1
		for nb in MapCampaign.wrapped_neighbors(cur):
			var t := nb as Vector2i
			if t == start or WorldMap.is_void(t.x, t.y):
				continue
			var tk := MapCampaign.key_of(t.x, t.y)
			if not flying and units.has(tk) and str(units[tk]["owner"]) != nation:
				continue # ground units can't push through another nation's cards
			var step := _step_cost(cur, t, flying, sails)
			if step < 0:
				continue # too slow to board a boat
			var c: int = int(cost[cur]) + step
			if c > budget or (cost.has(t) and c >= int(cost[t])):
				continue
			cost[t] = c
			parent[t] = cur
			queue.append(t)
	# Fighter Jets in range of an Airport only fly where they stay in range
	var airports := airports_of(nation) if card is FighterJet else []
	var tethered: bool = card is FighterJet and in_airport_range(nation, start, airports)
	for t in cost.keys():
		if t == start or flags.has(t) or units.has(MapCampaign.key_of(t.x, t.y)):
			continue
		if tethered and not in_airport_range(nation, t, airports):
			continue
		var path: Array = [t]
		while path[0] != start:
			path.push_front(parent[path[0]])
		out[t] = path
	return out

# Move the card at `k` to hex `to`. Returns the path walked ([] = not allowed).
func move(nation: String, k: String, to: Vector2i) -> Array:
	if not units.has(k) or str(units[k]["owner"]) != nation:
		return []
	var reach := reachable(k)
	if not reach.has(to):
		return []
	var path: Array = reach[to]
	var spent := path_cost(k, path)
	var info: Dictionary = units[k]
	var card: Card = info["card"]
	card.set_meta("moves_left", moves_left(k) - spent)
	units.erase(k)
	units[MapCampaign.key_of(to.x, to.y)] = info
	return path

# Bulk move: march the cards on `keys` towards hex `goal`, each as close as its
# moves allow. Those already nearest go first and take the hexes closest to the goal,
# so the group fans out around it instead of queueing. A unit that can't get any
# closer stays put. Returns [[from key, to hex, path], ...] in the order moved.
func move_group(nation: String, keys: Array, goal: Vector2i) -> Array:
	var order: Array = []
	for k in keys:
		if units.has(k) and str(units[k]["owner"]) == nation and units[k]["card"] is Unit and moves_left(k) > 0:
			order.append(k)
	order.sort_custom(func(a, b):
		var da := hex_distance(key_to_hex(a), goal)
		var db := hex_distance(key_to_hex(b), goal)
		return da < db if da != db else str(a) < str(b))
	var moves: Array = []
	for k in order:
		var here := key_to_hex(k)
		var best := here
		var best_d := hex_distance(here, goal)
		var best_len := 0
		var reach := reachable(k)
		for t in reach.keys():
			var d := hex_distance(t, goal)
			var steps: int = (reach[t] as Array).size() - 1
			if d < best_d or (d == best_d and steps < best_len):
				best = t
				best_d = d
				best_len = steps
		if best != here:
			var path := move(nation, k, best)
			if not path.is_empty():
				moves.append([k, best, path])
	return moves

# Where move_group would send each card, without moving anything (for the preview).
func plan_group(nation: String, keys: Array, goal: Vector2i) -> Array:
	var saved: Dictionary = {} # card -> moves_left meta before (null = none)
	for k in keys:
		if units.has(k):
			var card: Card = units[k]["card"]
			saved[card] = card.get_meta("moves_left") if card.has_meta("moves_left") else null
	var moves := move_group(nation, keys, goal)
	for i in range(moves.size() - 1, -1, -1): # undo, last move first
		var to: Vector2i = moves[i][1]
		var tk := MapCampaign.key_of(to.x, to.y)
		var info: Dictionary = units[tk]
		units.erase(tk)
		units[str(moves[i][0])] = info
	for card in saved.keys():
		if saved[card] == null:
			(card as Card).remove_meta("moves_left")
		else:
			(card as Card).set_meta("moves_left", saved[card])
	return moves

# Every hex in play within `r` hexes of `center`.
func hexes_within(center: Vector2i, r: int) -> Array:
	var seen: Dictionary = {}
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r - 1, center.x + r + 2):
			var t := Vector2i(posmod(x, WorldMap.GRID_W) if WorldMap.WRAPS else x, y)
			if not WorldMap.in_bounds(t.x, t.y) or WorldMap.is_void(t.x, t.y):
				continue
			if hex_distance(center, t) <= r:
				seen[t] = true
	return seen.keys()

# The enemy cards and flags a unit of `nation` standing on `from` could hit (within `r`).
func targets_in_range(nation: String, from: Vector2i, r: int) -> Array:
	var out: Array = []
	for k in units.keys():
		if str(units[k]["owner"]) != nation and card_hp(units[k]["card"]) > 0:
			var t := key_to_hex(k)
			if hex_distance(from, t) <= r:
				out.append(t)
	var fs := flag_sites()
	for fnation in fs.keys():
		if str(fnation) != nation and hex_distance(from, fs[fnation]) <= r:
			out.append(fs[fnation])
	return out

# The AI repositions its units before it fires. Each unit weighs every hex it can
# reach (staying put included) and takes the best one:
#   + something to shoot within its attack range (else: closer to the nearest target)
#   + tucked behind one of its own Walls (the wall sits between it and the nearest enemy)
#   + beside its own Barracks (+2 damage) or Interceptor (blocks part of ranged/flying hits)
#   - flanked, surrounded or encircled by enemy units there (takes more per hit)
#   - in a boat there (shorter reach, takes more per hit)
#   + closing in on weakened enemy cards (to finish them off)
# Returns [[from key, to hex, path], ...] in the order moved.
func ai_move(nation: String) -> Array:
	var moves: Array = []
	var ctx := _ai_move_setup(nation)
	if ctx.is_empty():
		return moves
	for k in cards_of(nation):
		var mv := _ai_move_one(nation, k, ctx)
		if not mv.is_empty():
			moves.append(mv)
	return moves

# ai_move for the game screen: the same moves in the same order, but it waits for the
# next frame whenever it has thought for `budget_usec`, so a crowded map keeps
# animating instead of freezing while a nation plans. `on_move` gets each move as
# it is made ([from key, to hex, path]), so its walk can start straight away.
func ai_move_sliced(nation: String, budget_usec: int, on_move: Callable = Callable()) -> Array:
	var moves: Array = []
	var t0 := Time.get_ticks_usec()
	var ctx := _ai_move_setup(nation)
	if ctx.is_empty():
		return moves
	for k in cards_of(nation):
		if Time.get_ticks_usec() - t0 > budget_usec:
			await (Engine.get_main_loop() as SceneTree).process_frame
			t0 = Time.get_ticks_usec()
		var mv := _ai_move_one(nation, k, ctx)
		if not mv.is_empty():
			moves.append(mv)
			if on_move.is_valid():
				on_move.call(mv)
	return moves

# What every unit's choice depends on, worked out once per nation's move phase.
# Empty when there is nothing to move towards.
func _ai_move_setup(nation: String) -> Dictionary:
	# every enemy card once: [hex, how badly hurt 0..1] (parsed here, not per candidate hex)
	var foes: Array = []
	for k in units.keys():
		if str(units[k]["owner"]) == nation:
			continue
		var card: Card = units[k]["card"]
		var mx: int = int(card.get_meta("map_max_hp", maxi(card_hp(card), 1)))
		var hurt: float = 1.0 - clampf(float(card_hp(card)) / float(maxi(mx, 1)), 0.0, 1.0)
		foes.append([key_to_hex(k), hurt])
	var enemy_flags: Array = []
	var fs := flag_sites()
	for fn in fs.keys():
		if str(fn) != nation:
			enemy_flags.append(fs[fn])
	if foes.is_empty() and enemy_flags.is_empty():
		return {}
	var wts := _move_weights(nation)
	# The nearest enemy card and the distance to the focus nation's cards, for every
	# hex at once: _position_score looks them up instead of scanning every enemy for
	# every hex every unit could reach (seconds per nation on a crowded map).
	var foe_hexes: Array = []
	var hurt_foes: Array = []
	for f in foes:
		foe_hexes.append(f[0])
		if float(f[1]) > 0.0:
			hurt_foes.append(f)
	var field := MapCampaign.distance_field(foe_hexes)
	wts["_near_d"] = field[0]
	wts["_near_i"] = field[1]
	wts["_hurt"] = hurt_foes
	if not (wts["focus_hexes"] as Array).is_empty():
		wts["_focus_d"] = MapCampaign.distance_field(wts["focus_hexes"])[0]
	return {"foes": foes, "flags": enemy_flags, "wts": wts}

# One unit's move in ai_move: [from key, to hex, path], or [] when it stays.
func _ai_move_one(nation: String, k: String, ctx: Dictionary) -> Array:
	if not units.has(k) or not (units[k]["card"] is Unit) or moves_left(k) <= 0:
		return []
	var foes: Array = ctx["foes"]
	var enemy_flags: Array = ctx["flags"]
	var wts: Dictionary = ctx["wts"]
	var here := key_to_hex(k)
	var reach := reachable(k)
	if reach.is_empty():
		return []
	var u := units[k]["card"] as Unit
	var best := here
	var best_score := _position_score(nation, k, here, foes, enemy_flags, attack_range(nation, u, here), wts) + float(ai_param(nation, "w_stay")) # a small bias to stay put
	for t in reach.keys():
		var sc := _position_score(nation, k, t, foes, enemy_flags, attack_range(nation, u, t), wts) # shorter reach from a boat
		if sc > best_score:
			best_score = sc
			best = t
	if best == here:
		return []
	var path := move(nation, k, best)
	return [] if path.is_empty() else [k, best, path]

# How good hex `t` is for the unit on key `k`. foes: [[hex, hurt 0..1], ...] for every
# enemy card; enemy_flags: their flag hexes; reach_hexes: the unit's attack range.
func _position_score(nation: String, k: String, t: Vector2i, foes: Array, enemy_flags: Array = [], reach_hexes: int = 1 << 20, wts: Dictionary = {}) -> float:
	if wts.is_empty():
		wts = _move_weights(nation)
	var score := 0.0
	# the nearest enemy card (for walls), the nearest target (cards or flags, for range),
	# and a pull towards badly hurt enemies nearby
	var nearest := Vector2i(-1, -1)
	var nearest_d := 1 << 30
	var weak_pull := 0.0
	var w_weak: float = wts["w_weak"]
	if wts.has("_near_d"): # precomputed by ai_move for these foes (same result, see there)
		var cell: int = t.y * WorldMap.GRID_W + t.x
		var ni: int = (wts["_near_i"] as PackedInt32Array)[cell]
		if ni >= 0:
			nearest_d = (wts["_near_d"] as PackedInt32Array)[cell]
			nearest = foes[ni][0]
		for f in wts["_hurt"]:
			weak_pull += float(f[1]) * w_weak / float(1 + MapCampaign.hex_distance(t, f[0])) # closer to a badly hurt enemy is better
	else:
		for f in foes:
			var et: Vector2i = f[0]
			var d := MapCampaign.hex_distance(t, et)
			if d < nearest_d:
				nearest_d = d
				nearest = et
			var hurt: float = f[1]
			if hurt > 0.0:
				weak_pull += hurt * w_weak / float(1 + d) # closer to a badly hurt enemy is better
	var target_d := nearest_d
	var flag_d := 1 << 30
	for fl in enemy_flags:
		var fd := MapCampaign.hex_distance(t, fl as Vector2i)
		target_d = mini(target_d, fd)
		flag_d = mini(flag_d, fd)
	if target_d <= reach_hexes:
		score += float(wts["w_inrange"]) # something to shoot from here
	elif target_d < (1 << 30):
		score -= float(wts["w_close"]) * float(target_d - reach_hexes) # else: as close as it can get
	if float(wts["w_flag"]) != 0.0 and flag_d < (1 << 30):
		score += float(wts["w_flag"]) * 4.0 / float(2 + flag_d) # toward enemy flags: hits there cost them HP
	score += weak_pull
	var focus_hexes: Array = wts.get("focus_hexes", [])
	if wts.has("_focus_d"):
		if (wts["_focus_d"] as PackedInt32Array)[t.y * WorldMap.GRID_W + t.x] <= reach_hexes:
			score += float(wts["w_focus"]) # can shoot at the nation we are ganging up on
	elif not focus_hexes.is_empty():
		for fh in focus_hexes:
			if MapCampaign.hex_distance(t, fh as Vector2i) <= reach_hexes:
				score += float(wts["w_focus"]) # can shoot at the nation we are ganging up on
				break
	score -= float(wts["w_flank"]) * float(flank_at(nation, t)) # don't walk into a pincer
	if units.has(k) and in_boat(units[k]["card"], t):
		score -= float(wts["w_boat"]) * float(SEA_DAMAGE_PENALTY) # boats are exposed: land when it can
	var scar := str(scars.get(MapCampaign.key_of(t.x, t.y), ""))
	if scar == "wasteland":
		score -= float(wts["w_waste"]) # fallout every turn it stays
	elif scar == "ruins" and units.has(k) and not (units[k]["card"] as Unit).Flying:
		score += float(wts["w_ruins"]) # cover in the rubble
	if float(wts["w_home"]) != 0.0 and campaign.owner_of(t.x, t.y) == nation:
		score += float(wts["w_home"]) # home ground: +1 damage
	var w_coh: float = wts["w_cohesion"]
	for nb in MapCampaign.wrapped_neighbors(t):
		var info := unit_at(nb as Vector2i)
		if info.is_empty() or str(info["owner"]) != nation or MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y) == k:
			continue
		var c: Card = info["card"]
		if c is Wall and nearest.x >= 0 and MapCampaign.hex_distance(nb as Vector2i, nearest) < nearest_d:
			score += float(wts["w_wall"]) # the wall stands between this hex and the nearest enemy
		elif c is Barracks:
			score += float(wts["w_barracks"])
		elif c is Interceptor:
			score += float(wts["w_interceptor"])
		elif c is Unit:
			score += w_coh # stick together: harder to flank
	return score

func _move_weights(nation: String) -> Dictionary:
	var out := {}
	for key in ["w_inrange", "w_close", "w_wall", "w_barracks", "w_interceptor", "w_flank", "w_boat", "w_weak", "w_flag", "w_home", "w_cohesion", "w_focus", "w_waste", "w_ruins"]:
		out[key] = float(ai_param(nation, key))
	out["focus_hexes"] = []
	if str(ai_param(nation, "focus")) == "weakest" and float(out["w_focus"]) != 0.0:
		var victim := focus_target(nation)
		if victim != "":
			var hexes: Array = []
			for k in cards_of(victim):
				hexes.append(key_to_hex(k))
			if campaign.is_alive(victim):
				hexes.append(campaign.capital_site(victim))
			out["focus_hexes"] = hexes
	return out

# The neighbour `nation` should gang up on: the one with the least HP left (share of its max).
func focus_target(nation: String) -> String:
	var best := ""
	var best_hp := 2.0
	for nb in campaign.neighbors_of(nation):
		var n := str(nb)
		if n == nation or not alive(n):
			continue
		var p: Player = players[n]
		var frac := float(p.HitPoints) / float(maxi(p.MaxHitPoints, 1))
		if frac < best_hp:
			best_hp = frac
			best = n
	return best

# ------------------------------------------------------------------- shop
# Copies of each card in a player's whole deck (piles, hand and board), used as
# the odds for that nation's shop: 10 Infantry + 5 Tank -> each slot is
# Infantry 2/3 of the time and Tank 1/3.
static func starting_deck_weights(p: Player) -> Dictionary:
	var w: Dictionary = {}
	for pile in [p.DrawPile, p.DiscardPile, p.Hand, p.get_all_board_cards()]:
		for c in pile:
			var cn := (c as Card).card_name
			w[cn] = int(w.get(cn, 0)) + 1
	return w

# One shop slot: a card type drawn with odds proportional to deck_weights.
func roll_shop_card(nation: String) -> Card:
	var weights: Dictionary = deck_weights.get(nation, {})
	var total := 0
	for cn in weights.keys():
		total += int(weights[cn])
	if total <= 0:
		var pool: Array = CardFactory.all_card_types()
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll := rng.randi_range(1, total)
	var names: Array = weights.keys()
	names.sort() # deterministic order for a given seed
	for cn in names:
		roll -= int(weights[cn])
		if roll <= 0:
			return (players[nation] as Player)._base_card_by_name(str(cn))
	return null

func restock_shop(nation: String) -> void:
	var p: Player = players[nation]
	var cards: Array = []
	for i in range(SHOP_CARD_SLOTS):
		var c := roll_shop_card(nation)
		if c != null:
			cards.append(c)
	var owned: Array = []
	for m in p.Modifiers:
		if m is Modifier:
			owned.append((m as Modifier).modifier_name)
	shops[nation] = {"cards": cards, "mods": CardFactory.random_modifier_offer_excluding(owned), "remove_used": false}

func shop_of(nation: String) -> Dictionary:
	if not shops.has(nation):
		restock_shop(nation)
	return shops[nation]

func buy_card(nation: String, card: Card) -> bool:
	var p: Player = players[nation]
	var shop := shop_of(nation)
	if card == null or not (shop["cards"] as Array).has(card) or p.Influence < card.InfluenceCost:
		return false
	p.Influence -= card.InfluenceCost
	p.DrawPile.append(card) # drawn next (draws pop from the back)
	(shop["cards"] as Array).erase(card)
	return true

func buy_modifier(nation: String, mod: Modifier) -> bool:
	var p: Player = players[nation]
	var shop := shop_of(nation)
	if mod == null or not (shop["mods"] as Array).has(mod) or p.Influence < mod.InfluenceCost or p.has_modifier(mod.modifier_name):
		return false
	p.Influence -= mod.InfluenceCost
	p.Modifiers.append(mod)
	(shop["mods"] as Array).erase(mod)
	last_modifier_changes = apply_modifiers_to_map(nation)
	last_modifier_changes_nation = nation
	return true

# HP changes from the latest modifier purchase, for the log: [{key, name, delta}]
var last_modifier_changes: Array = []
var last_modifier_changes_nation: String = ""

# Modifiers take effect on cards already on the map, not just new deployments.
# Damage, cost and Range modifiers are read live on every shot; HP modifiers are
# re-applied here: each card's max HP is recomputed with all of the nation's
# modifiers and its current HP shifts by the same amount (damage taken is kept).
# A card whose HP would drop to 0 or below is pinned at 1.
func apply_modifiers_to_map(nation: String) -> Array:
	var p: Player = players[nation]
	var changes: Array = []
	for k in cards_of(nation):
		var card: Card = units[k]["card"]
		var fresh := p._base_card_by_name(card.card_name)
		if fresh == null:
			continue
		var new_max: int = maxi(1, p.effective_hitpoints_for(fresh))
		var old_max: int = int(card.get_meta("map_max_hp", card_hp(card)))
		var delta: int = new_max - old_max
		if delta == 0:
			continue
		var hp: int = maxi(1, card_hp(card) + delta)
		if card is Unit:
			(card as Unit).HitPoints = hp
		elif card is Building:
			(card as Building).HitPoints = hp
		card.set_meta("map_max_hp", new_max)
		changes.append({"key": k, "name": card.card_name, "delta": delta})
	return changes

# Remove one card (by instance, else by name) from the draw/discard piles or hand.
func remove_card(nation: String, card: Card) -> bool:
	var p: Player = players[nation]
	var shop := shop_of(nation)
	if card == null or bool(shop["remove_used"]) or p.Influence < REMOVE_COST:
		return false
	for pile in [p.DrawPile, p.DiscardPile, p.Hand]:
		if pile.has(card):
			pile.erase(card)
			p.Influence -= REMOVE_COST
			shop["remove_used"] = true
			return true
	return false

# AI shopping: a random affordable modifier (they last all game), then the
# priciest affordable cards until Influence runs out. Returns item names bought.
# ---------------------------------------------------------------- AI policy
# Every choice the AI makes is a named setting, so strategies can be compared in
# headless tournaments (tools/dev/ai_tournament.gd). AI_DEFAULT is what every AI
# nation plays; ai_policy[nation] can override any of it.
#   mod_pick     "random" any affordable modifier | "fit" the one that suits its deck | "none"
#   card_pick    "priciest" | "value" (most firepower and HP per Influence) | "army" (units first)
#   influence_reserve  Influence kept back after shopping
#   build_order  "economy" buildings first | "army" units first | "auto" economy only while income is low
#   money_reserve      Money kept unspent (Interceptors need 6 to block)
#   walls        "always" | "front" (only near enemy units) | "never"
#   unit_spot    "frontier" nearest the border | "threat" nearest enemy units and flags
#   move weights: w_inrange (something to shoot), w_close (per hex short of range), w_wall,
#     w_barracks, w_interceptor, w_flank (penalty), w_boat (penalty), w_weak (wounded
#     enemies), w_stay (bias to hold still), w_flag (pull to enemy flags), w_home (own
#     land: +1 damage), w_cohesion (per friendly unit next to it)
#   focus        "none" | "weakest": gang up on the neighbour with the least HP left,
#     w_focus being the bonus for a spot that can shoot at it
#   thin_walls   spend REMOVE_COST Influence a turn taking a Wall out of the deck
#
# AI_DEFAULT came out of self-play tournaments against AI_CLASSIC (the first AI): over
# 5 rounds of paired games on the Europe and world maps it gained about +1.4 points of
# Europe and +2.6 points of the world map per nation (t about 4). What made the difference:
#   - keep units together (w_cohesion 1) and only move when it is clearly better
#     (w_stay 3): loose units get flanked and picked off; most of the gain
#   - fear flanks less (w_flank 1): staying together already prevents them
#   - close in faster when out of range (w_close 2.5)
#   - place new units nearest the actual threat, not just the border (unit_spot "threat")
#   - buy the modifier that suits the deck and the cards with the most firepower and HP
#     per Influence (mod_pick "fit", card_pick "value")
# What did not help, or hurt: keeping Money back for Interceptors, valuing home ground
# more, chasing wounded enemies harder, ganging up on the weakest neighbour (focus),
# thinning Walls from the deck, skipping Walls, units-first building, flag pulls.
const AI_DEFAULT := {
	"mod_pick": "fit", "card_pick": "value", "influence_reserve": 0,
	"build_order": "economy", "money_reserve": 0, "walls": "always", "unit_spot": "threat",
	"w_inrange": 5.0, "w_close": 2.5, "w_wall": 4.0, "w_barracks": 2.5, "w_interceptor": 2.0,
	"w_flank": 1.0, "w_boat": 1.5, "w_weak": 6.0, "w_stay": 3.0, "w_flag": 0.0, "w_home": 0.0,
	"w_cohesion": 1.0, "focus": "none", "w_focus": 0.0, "thin_walls": false,
	"w_waste": 8.0, "w_ruins": 1.0,
}
# The first AI, kept for comparisons (and as an easier opponent): pass it as ai_policy.
const AI_CLASSIC := {
	"mod_pick": "random", "card_pick": "priciest", "unit_spot": "frontier",
	"w_close": 0.8, "w_flank": 2.5, "w_stay": 0.25, "w_cohesion": 0.0,
}
var ai_policy: Dictionary = {} # nation -> {setting: value} overriding AI_DEFAULT

func ai_param(nation: String, key: String) -> Variant:
	var own: Dictionary = ai_policy.get(nation, {})
	return own.get(key, AI_DEFAULT[key])

# How well a modifier suits `nation`'s starting deck (for mod_pick "fit").
func _modifier_fit(nation: String, m: Modifier) -> float:
	var w: Dictionary = deck_weights.get(nation, {})
	var total := 0.0
	var units_n := 0.0
	var flyers := 0.0
	var people := 0.0
	for nm in w.keys():
		var c: Card = (players[nation] as Player)._base_card_by_name(str(nm))
		if c == null:
			continue
		var n := float(w[nm])
		total += n
		if c is Unit:
			units_n += n
			if (c as Unit).Flying:
				flyers += n
			if c.BioCost > c.MoneyCost:
				people += n
	if total <= 0.0:
		return 0.0
	match m.modifier_name:
		"Guerilla Warfare": return 2.0 * people / total
		"Fanaticism": return 1.6 * units_n / total
		"Aerial Supremacy", "Advanced Robotics": return 2.2 * flyers / total
		"Corruption": return 0.9
		"Conscription": return 1.0 if (players[nation] as Player).BioSupply < 60 else 0.3
		"State of emergency": return 0.7
		"Defensive Doctrine": return 0.6
	return 0.0

# Firepower and toughness per Influence (card_pick "value").
static func _card_value(c: Card) -> float:
	if c is Unit:
		var u := c as Unit
		var shots := 4.0 if (c is RocketLauncher or c is Howitzer) else 1.0
		return (u.Damage * shots * 3.0 + u.HitPoints + (6.0 if u.HasRange else 0.0)) / maxf(c.InfluenceCost, 1.0)
	if c is Building:
		return ((c as Building).Income * 2.0 + (c as Building).HitPoints * 0.3) / maxf(c.InfluenceCost, 1.0)
	if c is Item:
		return (c as Item).Damage * (1.0 + (c as Item).BlastRadius) * 1.5 / maxf(c.InfluenceCost, 1.0)
	return 0.0

func ai_shop(nation: String) -> Array:
	var p: Player = players[nation]
	var shop := shop_of(nation)
	var bought: Array = []
	last_modifier_changes = []
	last_modifier_changes_nation = ""
	var reserve: int = int(ai_param(nation, "influence_reserve"))
	var mod_pick: String = ai_param(nation, "mod_pick")
	var affordable: Array = []
	for m in shop["mods"]:
		if p.Influence - reserve >= (m as Modifier).InfluenceCost and not p.has_modifier((m as Modifier).modifier_name):
			affordable.append(m)
	if not affordable.is_empty() and mod_pick != "none":
		var pick: Modifier = null
		if mod_pick == "fit":
			var best_fit := 0.5 # only buy one that clearly suits the deck
			for m in affordable:
				var f := _modifier_fit(nation, m)
				if f > best_fit:
					best_fit = f
					pick = m
		else:
			# a random affordable modifier, so nations don't all converge on the same one
			pick = affordable[rng.randi_range(0, affordable.size() - 1)]
		if pick != null and buy_modifier(nation, pick):
			bought.append(pick.modifier_name)
	if bool(ai_param(nation, "thin_walls")) and p.Influence - reserve >= REMOVE_COST:
		for pile in [p.DrawPile, p.DiscardPile, p.Hand]:
			var wall: Card = null
			for c in pile:
				if c is Wall:
					wall = c
					break
			if wall != null:
				if remove_card(nation, wall):
					bought.append("(removed a Wall)")
				break
	var card_pick: String = ai_param(nation, "card_pick")
	while true:
		var best: Card = null
		var best_score := -INF
		for c in shop["cards"]:
			var card := c as Card
			if card.InfluenceCost > p.Influence - reserve:
				continue
			var score: float = float(card.InfluenceCost)
			if card_pick == "value":
				score = _card_value(card)
			elif card_pick == "army":
				score = float(card.InfluenceCost) + (1000.0 if card is Unit else 0.0)
			if score > best_score:
				best_score = score
				best = card
		if best == null or not buy_card(nation, best):
			break
		bought.append(best.card_name)
	return bought

func end_turn(nation: String) -> void:
	(players[nation] as Player).discard_hand()

# ---------------------------------------------------------------- AI build
# Distance from each hex to the nearest hex held by another living nation.
func frontier_distance(nation: String) -> Dictionary:
	var sources: Array = []
	for k in campaign.owner.keys():
		if str(campaign.owner[k]) != nation:
			sources.append(key_to_hex(str(k)))
	var field: PackedInt32Array = MapCampaign.distance_field(sources)[0]
	var dist: Dictionary = {}
	var gw: int = WorldMap.GRID_W
	for c in range(field.size()):
		if field[c] < (1 << 30):
			dist[MapCampaign.key_of(c % gw, c / gw)] = field[c]
	return dist

# Hex distance from `t` to the nearest enemy unit (or flag too); 99 if none.
func _nearest_enemy_unit(nation: String, t: Vector2i, flags_too: bool = false) -> int:
	var best := 99
	for k in units.keys():
		if str(units[k]["owner"]) != nation and units[k]["card"] is Unit:
			best = mini(best, hex_distance(t, key_to_hex(k)))
	if flags_too:
		var fs := flag_sites()
		for fn in fs.keys():
			if str(fn) != nation:
				best = mini(best, hex_distance(t, fs[fn]))
	return best

# _nearest_enemy_unit (before its cap of 99) for every hex at once: cell y * GRID_W + x.
func _enemy_unit_field(nation: String, flags_too: bool = false) -> PackedInt32Array:
	var sources: Array = []
	for k in units.keys():
		if str(units[k]["owner"]) != nation and units[k]["card"] is Unit:
			sources.append(key_to_hex(k))
	if flags_too:
		var fs := flag_sites()
		for fn in fs.keys():
			if str(fn) != nation:
				sources.append(fs[fn])
	return MapCampaign.distance_field(sources)[0]

func _friendly_adjacent(nation: String, t: Vector2i, want_units: bool) -> int:
	var n := 0
	for nb in MapCampaign.wrapped_neighbors(t):
		var info := unit_at(nb as Vector2i)
		if not info.is_empty() and str(info["owner"]) == nation and (info["card"] is Unit) == want_units:
			n += 1
	return n

# Where a card would best go: fighters and walls to the front, economy to the
# rear, Barracks/Interceptors beside the most friendly units near the front.
func best_hex_for(nation: String, card: Card, fdist: Dictionary = {}) -> Vector2i:
	if fdist.is_empty():
		fdist = frontier_distance(nation)
	var best := Vector2i(-1, -1)
	var best_score: float = -1e9
	var threat: bool = card is Unit and ai_param(nation, "unit_spot") == "threat"
	var near := _enemy_unit_field(nation, true) if threat else PackedInt32Array()
	for t in deploy_hexes(nation, card):
		var tv := t as Vector2i
		var d: float = float(fdist.get(MapCampaign.key_of(tv.x, tv.y), 50))
		var score: float
		if threat:
			score = -float(mini(99, near[tv.y * WorldMap.GRID_W + tv.x])) * 10.0 - d * 2.0 # _nearest_enemy_unit
		elif card is Unit or card is Wall:
			score = -d * 10.0
		elif card is Barracks or card is Interceptor:
			score = _friendly_adjacent(nation, tv, true) * 25.0 - d * 4.0
		else:
			score = d * 10.0 - _friendly_adjacent(nation, tv, false) * 2.0
		score += rng.randf() * 3.0
		if score > best_score:
			best_score = score
			best = tv
	return best

# AI nation plays every affordable card; returns [[card, hex], ...] in order.
func ai_build(nation: String) -> Array:
	var placed: Array = []
	var ctx := _ai_build_setup(nation)
	for c in ctx["hand"]:
		var pl := _ai_build_one(nation, c as Card, ctx)
		if not pl.is_empty():
			placed.append(pl)
	return placed

# ai_build for the game screen: the same cards in the same order, waiting for the
# next frame whenever it has thought for `budget_usec` (see ai_move_sliced).
func ai_build_sliced(nation: String, budget_usec: int) -> Array:
	var placed: Array = []
	var t0 := Time.get_ticks_usec()
	var ctx := _ai_build_setup(nation)
	for c in ctx["hand"]:
		if Time.get_ticks_usec() - t0 > budget_usec:
			await (Engine.get_main_loop() as SceneTree).process_frame
			t0 = Time.get_ticks_usec()
		var pl := _ai_build_one(nation, c as Card, ctx)
		if not pl.is_empty():
			placed.append(pl)
	return placed

# The hand in the order ai_build plays it, and what each placement depends on.
func _ai_build_setup(nation: String) -> Dictionary:
	var p: Player = players[nation]
	var fdist := frontier_distance(nation)
	var hand: Array = p.Hand.duplicate()
	hand.shuffle()
	var order: String = ai_param(nation, "build_order")
	if order == "auto":
		order = "economy" if p.predicted_money_gain() < 30 else "army"
	if order == "army":
		hand.sort_custom(func(a, b): return (a is Unit) and not (b is Unit))
	else:
		# economy first, then the army
		hand.sort_custom(func(a, b): return (a is Building and not (a is Wall)) and not (b is Building and not (b is Wall)))
	# holding a Missile or Nuke it can't pay for yet, with a target worth it in
	# reach: keep that much Money back instead of spending it all on cards
	var reserve: int = int(ai_param(nation, "money_reserve"))
	var save := ai_pick_item(nation, true)
	if not save.is_empty():
		reserve = maxi(reserve, p.get_effective_money_cost(save["item"]))
	return {"hand": hand, "fdist": fdist, "reserve": reserve, "walls": str(ai_param(nation, "walls"))}

# One card of ai_build: [card, hex] if it was placed, else [].
func _ai_build_one(nation: String, card: Card, ctx: Dictionary) -> Array:
	if card is Item:
		return [] # fired (ai_use_items), never placed
	var p: Player = players[nation]
	var reserve: int = ctx["reserve"]
	var walls: String = ctx["walls"]
	if shortfall(nation, card) != "":
		return []
	if reserve > 0 and p.MoneySupply - p.get_effective_money_cost(card) < reserve:
		return [] # keep some Money back
	if card is Wall and walls == "never":
		return []
	var t := best_hex_for(nation, card, ctx["fdist"])
	if card is Wall and walls == "front" and t.x >= 0 and _nearest_enemy_unit(nation, t) > 6:
		return [] # no enemy nearby: a Wall here would only waste Money
	if t.x < 0:
		return [] # nowhere for this one (land full, or no flag/building near enough): try the rest
	if place(nation, card, t):
		return [card, t]
	return []

# ----------------------------------------------------------------- combat
func unit_count(nation: String) -> int:
	var n := 0
	for k in cards_of(nation):
		if units[k]["card"] is Unit:
			n += 1
	return n

func is_weak(nation: String) -> bool:
	return unit_count(nation) < WEAK_UNIT_COUNT

# How many times the normal number of hexes a nation cedes when it collapses:
# 4x with no units on the map, 2x with fewer than WEAK_UNIT_COUNT, else 1x.
func loss_multiplier(nation: String) -> int:
	var n := unit_count(nation)
	if n == 0:
		return 4
	if n < WEAK_UNIT_COUNT:
		return 2
	return 1

func attackers_of(nation: String) -> Array:
	var out: Array = []
	for k in cards_of(nation):
		if units[k]["card"] is Unit:
			out.append(k)
	return out

func _barracks_bonus(nation: String, t: Vector2i) -> int:
	for nb in MapCampaign.wrapped_neighbors(t):
		var info := unit_at(nb as Vector2i)
		if not info.is_empty() and str(info["owner"]) == nation and info["card"] is Barracks and card_hp(info["card"]) > 0:
			return 2
	return 0

# Hover/animation helpers: is the card on hex key `k` boosted by an adjacent Barracks,
# and is it covered by one of its nation's Interceptors (within INTERCEPTOR_RANGE)
# that can still pay (6 Money)?
func is_buffed(k: String) -> bool:
	if not units.has(k) or not (units[k]["card"] is Unit):
		return false
	return _barracks_bonus(str(units[k]["owner"]), key_to_hex(k)) > 0

func is_shielded(k: String) -> bool:
	if not units.has(k):
		return false
	var owner := str(units[k]["owner"])
	if (players[owner] as Player).MoneySupply < 6:
		return false
	return covering_interceptor(owner, key_to_hex(k)).x >= 0

# An Interceptor covers its nation's cards within this many hexes.
const INTERCEPTOR_RANGE := 3

# The nearest living Interceptor of `owner` within INTERCEPTOR_RANGE of `t`
# (first in map order among equally near ones), or (-1, -1). Money isn't checked.
func covering_interceptor(owner: String, t: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INTERCEPTOR_RANGE + 1
	for h in hexes_within(t, INTERCEPTOR_RANGE):
		var info := unit_at(h as Vector2i)
		if info.is_empty() or str(info["owner"]) != owner or not (info["card"] is Interceptor) or card_hp(info["card"]) <= 0:
			continue
		var d := hex_distance(t, h as Vector2i)
		if d < best_d:
			best_d = d
			best = h
	return best

# Home ground: a unit firing from its own nation's land deals HOME_BONUS more per shot
# (not from enemy land, unclaimed land or the sea).
const HOME_BONUS := 1

func _home_bonus(nation: String, t: Vector2i) -> int:
	return HOME_BONUS if campaign.owner_of(t.x, t.y) == nation else 0

# Flanking: a unit hemmed in by enemy units takes more from every hit (highest tier only).
# Enemies = living units of any other nation on the 6 neighbouring hexes (not buildings).
#   flanked    enemy units on two opposite sides    +FLANK_FLANKED
#   surrounded 4 or more enemy neighbours           +FLANK_SURROUNDED
#   encircled  all 6 neighbours are enemy units     +FLANK_ENCIRCLED
const FLANK_FLANKED := 1
const FLANK_SURROUNDED := 2
const FLANK_ENCIRCLED := 4

# Extra damage a unit of `nation` standing on `t` would take per hit (0 = not flanked).
func flank_at(nation: String, t: Vector2i) -> int:
	var enemy: Array = []
	var n := 0
	for i in range(6):
		var nb := MapCampaign.hex_neighbor(t, i)
		var e := false
		if WorldMap.in_bounds(nb.x, nb.y):
			var info := unit_at(nb)
			e = not info.is_empty() and str(info["owner"]) != nation and info["card"] is Unit and card_hp(info["card"]) > 0
		enemy.append(e)
		if e:
			n += 1
	if n >= 6:
		return FLANK_ENCIRCLED
	if n >= 4:
		return FLANK_SURROUNDED
	for i in range(3): # directions i and i + 3 are opposite
		if enemy[i] and enemy[i + 3]:
			return FLANK_FLANKED
	return 0

# The flanking penalty of the unit on hex key `k` (0 for buildings and flags).
func flank_bonus(k: String) -> int:
	if not units.has(k) or not (units[k]["card"] is Unit):
		return 0
	return flank_at(str(units[k]["owner"]), key_to_hex(k))

func flank_name(bonus: int) -> String:
	match bonus:
		FLANK_ENCIRCLED: return "encircled"
		FLANK_SURROUNDED: return "surrounded"
		FLANK_FLANKED: return "flanked"
	return ""

func effective_damage(nation: String, unit: Unit, t: Vector2i) -> int:
	var p: Player = players[nation]
	return p.effective_damage_for(unit, null) + _barracks_bonus(nation, t) + _home_bonus(nation, t)

# Where each living nation's flag stands (its capital, or the owned hex nearest it).
func flag_sites() -> Dictionary:
	var out: Dictionary = {}
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		if alive(nm):
			out[nm] = campaign.capital_site(nm)
	return out

# How far a unit can shoot, in hexes: units with Range (modifiers included) reach
# RANGED_RANGE, the rest MELEE_RANGE. Nothing further away can be hit. A ground unit
# firing from a boat (standing on a sea hex) reaches SEA_RANGE_PENALTY less.
const MELEE_RANGE := 4
const RANGED_RANGE := 8
const SEA_RANGE_PENALTY := 2
# ...and takes SEA_DAMAGE_PENALTY more from every hit while it sits in that boat.
const SEA_DAMAGE_PENALTY := 1

# A ground unit on a sea hex (in a boat)?
func in_boat(unit: Card, t: Vector2i) -> bool:
	return unit is Unit and not (unit as Unit).Flying and WorldMap.in_bounds(t.x, t.y) and _at_sea(t)

# `at`: where the unit stands (or would stand); Vector2i(-1, -1) = ignore its position.
func attack_range(nation: String, unit: Unit, at: Vector2i = Vector2i(-1, -1)) -> int:
	var r := RANGED_RANGE if (players[nation] as Player).has_range_for(unit) else MELEE_RANGE
	if at.x >= 0 and in_boat(unit, at):
		r = maxi(r - SEA_RANGE_PENALTY, 1)
	return r

# {} when nothing to shoot; {"key": String} for a card; {"flag": nation, "hex": Vector2i} for a flag.
# Targets are enemy cards plus enemy flags within `reach` hexes. Units without Range
# take the closest (random among ties); ranged units find the closest enemy nation
# and pick a random target of that nation within reach (any of its cards or its flag).
func pick_target(nation: String, from: Vector2i, ranged: bool, flags: Dictionary = {}, reach: int = -1) -> Dictionary:
	if flags.is_empty():
		flags = flag_sites()
	if reach < 0:
		reach = RANGED_RANGE if ranged else MELEE_RANGE
	var closest := _closest_targets(nation, from, flags, reach)
	if closest.is_empty():
		return {}
	var pick: Dictionary = closest[rng.randi_range(0, closest.size() - 1)]
	if not ranged:
		return pick
	# Ranged: a random target (card or flag) of the closest enemy nation, within reach.
	var victim := str(pick["owner"])
	var pool: Array = []
	for k in cards_of(victim):
		if card_hp(units[k]["card"]) > 0 and hex_distance(from, key_to_hex(k)) <= reach:
			pool.append({"key": k, "owner": victim})
	if flags.has(victim) and hex_distance(from, flags[victim]) <= reach:
		pool.append({"flag": victim, "hex": flags[victim], "owner": victim})
	return pool[rng.randi_range(0, pool.size() - 1)]

# Where the unit on hex key `k` would shoot next, without rolling dice (for hover help):
# {"hex", "owner", "name", "distance", "ranged", "ties"}; ranged units report the nation they aim at.
# {} when nothing is within its attack range.
func predict_target(k: String) -> Dictionary:
	if not units.has(k) or not (units[k]["card"] is Unit):
		return {}
	var nation := str(units[k]["owner"])
	var unit := units[k]["card"] as Unit
	var from := key_to_hex(k)
	var closest := _closest_targets(nation, from, flag_sites(), attack_range(nation, unit, from))
	if closest.is_empty():
		return {}
	closest.sort_custom(func(a, b): return str(a.get("key", a.get("flag", ""))) < str(b.get("key", b.get("flag", ""))))
	var first: Dictionary = closest[0]
	var hex: Vector2i = first["hex"] if first.has("hex") else key_to_hex(str(first["key"]))
	var nm: String = (str(first["owner"]) + " flag") if first.has("flag") else (units[first["key"]]["card"] as Card).card_name
	return {"hex": hex, "owner": str(first["owner"]), "name": nm, "distance": hex_distance(from, hex),
		"ranged": (players[nation] as Player).has_range_for(unit), "ties": closest.size()}

# Every enemy target (cards and flags) at the smallest hex distance from `from`,
# no further than `reach` hexes.
func _closest_targets(nation: String, from: Vector2i, flags: Dictionary, reach: int = 1 << 29) -> Array:
	var best: int = 1 << 30
	var closest: Array = []
	# Look only at the hexes within reach when there are fewer of them than cards on
	# the map (every attack of a crowded map asks this): the same cards in the same order.
	var w_box: int = 2 * reach + 3
	if reach < 64 and w_box * (2 * reach + 1) < units.size() and (not WorldMap.WRAPS or w_box <= WorldMap.GRID_W):
		var keys: Array = []
		for y in range(from.y - reach, from.y + reach + 1):
			if y < 0 or y >= WorldMap.GRID_H:
				continue
			for x in range(from.x - reach - 1, from.x + reach + 2):
				var t := Vector2i(posmod(x, WorldMap.GRID_W) if WorldMap.WRAPS else x, y)
				if not WorldMap.in_bounds(t.x, t.y):
					continue
				var k := MapCampaign.key_of(t.x, t.y)
				var info: Dictionary = units.get(k, {})
				if info.is_empty() or str(info["owner"]) == nation or card_hp(info["card"]) <= 0:
					continue
				var d := hex_distance(from, t)
				if d > reach:
					continue
				if d < best:
					best = d
					keys = [k]
				elif d == best:
					keys.append(k)
		if keys.size() > 1: # ties in the order of the full scan (units' order)
			var order: Array = units.keys()
			var pos: Array = []
			for k in keys:
				pos.append([order.find(k), k])
			pos.sort()
			keys = []
			for pk in pos:
				keys.append(pk[1])
		for k in keys:
			closest.append({"key": k, "owner": str(units[k]["owner"])})
		return _closest_flags(nation, from, flags, reach, best, closest)
	for k in units.keys():
		var info: Dictionary = units[k]
		var o := str(info["owner"])
		if o == nation or card_hp(info["card"]) <= 0:
			continue
		var d := hex_distance(from, key_to_hex(str(k)))
		if d > reach:
			continue
		if d < best:
			best = d
			closest = [{"key": k, "owner": o}]
		elif d == best:
			closest.append({"key": k, "owner": o})
	return _closest_flags(nation, from, flags, reach, best, closest)

# _closest_targets' second half: enemy flags as near as (or nearer than) the cards found.
func _closest_flags(nation: String, from: Vector2i, flags: Dictionary, reach: int, best: int, closest: Array) -> Array:
	for fnation in flags.keys():
		if str(fnation) == nation:
			continue
		var site: Vector2i = flags[fnation]
		var d2 := hex_distance(from, site)
		if d2 > reach:
			continue
		var cand := {"flag": str(fnation), "hex": site, "owner": str(fnation)}
		if d2 < best:
			best = d2
			closest = [cand]
		elif d2 == best:
			closest.append(cand)
	return closest

func _hurt_nation(victim: String, attacker: String, amount: int) -> void:
	var p: Player = players[victim]
	p.HitPoints = clampi(p.HitPoints - amount, 0, p.MaxHitPoints)
	if not ledger.has(victim):
		ledger[victim] = {}
	var row: Dictionary = ledger[victim]
	row[attacker] = int(row.get(attacker, 0)) + amount

# Buildings (walls included) can't stand on mountain hexes; units can.
static func can_build_on(card: Card, t: Vector2i) -> bool:
	return not (card is Building and WorldMap.terrain_at(t.x, t.y) == WorldMap.MOUNTAIN)

# Terrain cover, min 1 damage: a non-flying unit on a mountain hex takes 1 less from
# every hit; any unit in a forest (jungle hex) takes 1 less from flying attackers.
static func terrain_adjusted(card: Card, t: Vector2i, dmg: int, attacker: Card = null) -> int:
	if not (card is Unit):
		return dmg
	var terrain := WorldMap.terrain_at(t.x, t.y)
	if terrain == WorldMap.MOUNTAIN and not (card as Unit).Flying:
		return maxi(1, dmg - 1)
	if terrain == WorldMap.JUNGLE and attacker is Unit and (attacker as Unit).Flying:
		return maxi(1, dmg - 1)
	return dmg

# Ruins: a non-flying unit standing in a destroyed building's rubble takes
# RUINS_COVER less from every hit (never below 1).
const RUINS_COVER := 2

func ruins_adjusted(card: Card, t: Vector2i, dmg: int) -> int:
	if card is Unit and not (card as Unit).Flying and str(scars.get(MapCampaign.key_of(t.x, t.y), "")) == "ruins":
		return maxi(1, dmg - RUINS_COVER)
	return dmg

func scar_at(t: Vector2i) -> String:
	return str(scars.get(MapCampaign.key_of(t.x, t.y), ""))

# Nuclear wasteland: every unit of `nation` that starts its turn on it loses
# FALLOUT_DAMAGE HP (and is lost at 0, costing its nation no HP, like a crashed jet).
const FALLOUT_DAMAGE := 3

func fallout(nation: String) -> Array:
	var out: Array = []
	for k in cards_of(nation):
		var c: Card = units[k]["card"]
		if not (c is Unit) or str(scars.get(k, "")) != "wasteland":
			continue
		(c as Unit).HitPoints -= FALLOUT_DAMAGE
		var died := (c as Unit).HitPoints <= 0
		out.append([key_to_hex(k), died])
		if died:
			_remove(k)
	return out

func _damage_card(k: String, amount: int) -> void:
	var card: Card = units[k]["card"]
	if card is Unit:
		(card as Unit).HitPoints -= amount
	elif card is Building:
		(card as Building).HitPoints -= amount

# Remove destroyed cards; each costs its owner BioCost HP credited to `attacker`.
# Returns [{key, hex, name, owner}] so the view can show the wreck until impact.
func _reap(attacker: String) -> Array:
	var dead: Array = []
	for k in units.keys():
		if card_hp(units[k]["card"]) <= 0:
			dead.append(k)
	var out: Array = []
	for k in dead:
		var info: Dictionary = units[k]
		out.append({"key": k, "hex": key_to_hex(k), "name": (info["card"] as Card).card_name, "owner": info["owner"],
			"bio": (info["card"] as Card).BioCost})
		_stat(attacker, str(info["owner"]), "kills", 1)
		_stat(attacker, str(info["owner"]), "kill_hp", (info["card"] as Card).BioCost)
		_hurt_nation(str(info["owner"]), attacker, (info["card"] as Card).BioCost)
		if info["card"] is Building and str(scars.get(k, "")) != "wasteland":
			scars[k] = "ruins" # what is left of it gives ground units cover
		var bounty := building_bounty(info["card"]) if str(info["owner"]) != attacker else 0
		if bounty > 0 and players.has(attacker):
			(players[attacker] as Player).Influence += bounty
			bounties[attacker] = int(bounties.get(attacker, 0)) + bounty
			_log_influence(attacker, "buildings", bounty)
			out[-1]["bounty"] = bounty
		_remove(k)
	return out

# Influence for destroying `card` if it is a building: BUILDING_BOUNTY of its Influence cost.
static func building_bounty(card: Card) -> int:
	if not (card is Building):
		return 0
	return roundi(card.InfluenceCost * BUILDING_BOUNTY)

# Influence `nation` has earned from destroyed buildings since the last call (then cleared).
func take_bounty(nation: String) -> int:
	var n := int(bounties.get(nation, 0))
	bounties.erase(nation)
	return n

# Interceptors block INTERCEPT_SHARE of a hit from an attacker with Range or Flying.
# Hits are whole numbers, so the fraction is rounded at random in proportion (a
# 5-damage hit has 3.75 to block: 4 points 75% of the time, else 3), which blocks
# 75% on average. A hit is never cut below 1. Only an actual block costs the
# Interceptor 2 HP and its owner 6 Money.
const INTERCEPT_SHARE := 0.75

func intercept_block(dmg: int) -> int:
	var exact: float = dmg * INTERCEPT_SHARE
	var blocked := int(floor(exact))
	if rng.randf() < exact - floor(exact):
		blocked += 1
	return clampi(blocked, 0, maxi(dmg - 1, 0))

func _intercept(victim: String, t: Vector2i, unit: Unit, attacker: String, dmg: int) -> int:
	_last_intercept_from = Vector2i(-1, -1)
	var vp: Player = players[victim]
	var ranged: bool = (players[attacker] as Player).has_range_for(unit)
	if vp.MoneySupply < 6 or not (ranged or unit.Flying):
		return dmg
	var ih := covering_interceptor(victim, t)
	if ih.x < 0:
		return dmg
	var blocked := intercept_block(dmg)
	if blocked <= 0:
		return dmg # nothing stopped this time: no cost
	(unit_at(ih)["card"] as Building).HitPoints -= 2
	vp.MoneySupply = maxi(0, vp.MoneySupply - 6)
	_last_intercept_from = ih
	return dmg - blocked

# One unit fires (1 or 4 shots). Returns log entries for animation:
# {from, to, attacker, card, target_name, victim, damage, direct, intercepted, destroyed: [keys], splash: [hexes]}
func fire(k: String) -> Array:
	var log: Array = []
	if not units.has(k):
		return log
	var info: Dictionary = units[k]
	var nation := str(info["owner"])
	var unit := info["card"] as Unit
	if unit == null or unit.HitPoints <= 0:
		return log
	var from := key_to_hex(k)
	var shots: int = 4 if (unit is RocketLauncher or unit is Howitzer) else 1
	var ranged: bool = (players[nation] as Player).has_range_for(unit)
	for s in range(shots):
		if not units.has(k) or unit.HitPoints <= 0:
			break
		var flags := flag_sites() # a flag moves the moment its nation collapses
		var tgt := pick_target(nation, from, ranged, flags, attack_range(nation, unit, from))
		if tgt.is_empty():
			break
		var dmg := effective_damage(nation, unit, from)
		var buff := _barracks_bonus(nation, from)
		var buffed := buff > 0
		var home := _home_bonus(nation, from)
		var mod_delta: int = (players[nation] as Player).effective_damage_for(unit, null) - unit.Damage
		if tgt.has("flag"):
			# Flag hit: the damage goes to the nation's HP (Fighter Jets still splash around it).
			var victim := str(tgt["flag"])
			var site: Vector2i = tgt["hex"]
			_hurt_nation(victim, nation, dmg)
			_stat(nation, victim, "dealt", dmg)
			_stat(nation, victim, "flag", dmg)
			_stat(nation, victim, "barracks", buff)
			_stat(nation, victim, "home", home)
			_stat(nation, victim, "modifiers", mod_delta)
			var fsplash: Array = []
			if _splashes(unit):
				for nb in MapCampaign.wrapped_neighbors(site):
					var ninfo := unit_at(nb as Vector2i)
					if not ninfo.is_empty() and str(ninfo["owner"]) == victim:
						var sd := ruins_adjusted(ninfo["card"], nb as Vector2i, terrain_adjusted(ninfo["card"], nb as Vector2i, dmg, unit))
						_damage_card(MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y), sd)
						_stat(nation, victim, "splash", sd)
						fsplash.append(nb)
			log.append({"from": from, "to": site, "attacker": nation, "card": unit.card_name, "target_name": victim + " flag",
				"victim": victim, "damage": dmg, "direct": true, "intercepted": false, "destroyed": _reap(nation), "splash": fsplash,
				"buffed": buffed, "intercept_from": Vector2i(-1, -1)})
			_collapse_now(log)
			continue
		var tk := str(tgt["key"])
		var tinfo: Dictionary = units[tk]
		var target: Card = tinfo["card"]
		var victim2 := str(tinfo["owner"])
		var to := key_to_hex(tk)
		var actual := dmg
		if unit is SpecialOps and target is Unit and not (target as Unit).Flying:
			actual *= 2
		elif unit is AntiAircraft and target is Unit and (target as Unit).Flying:
			actual *= 3
		var unit_bonus := actual - dmg
		var pre_fly := actual
		if target is Unit and (target as Unit).Flying and not ranged and not (unit is AntiAircraft):
			actual = maxi(1, actual / 2)
		var flank := flank_bonus(tk) # hemmed in: it takes more from every hit
		actual += flank
		var boat := SEA_DAMAGE_PENALTY if in_boat(target, to) else 0 # caught at sea
		actual += boat
		var before := actual
		actual = _intercept(victim2, to, unit, nation, actual)
		var intercept_from := _last_intercept_from
		var pre_terrain := actual
		actual = terrain_adjusted(target, to, actual, unit)
		var pre_ruins := actual
		actual = ruins_adjusted(target, to, actual)
		var pre_airport := actual
		if target is BomberJet and in_airport_range(victim2, to):
			actual = maxi(1, actual - BOMBER_AIRPORT_COVER) # its Airport keeps it patched up
		_damage_card(tk, actual)
		# round report (see round_stats)
		_stat(nation, victim2, "dealt", actual)
		_stat(nation, victim2, "barracks", buff)
		_stat(nation, victim2, "home", home)
		_stat(nation, victim2, "modifiers", mod_delta)
		_stat(nation, victim2, "unit_bonus", unit_bonus)
		_stat(nation, victim2, "flank", flank)
		_stat(nation, victim2, "boat", boat)
		_stat(nation, victim2, "blocked_flying", pre_fly - before)
		_stat(nation, victim2, "blocked_interceptor", before - pre_terrain)
		_stat(nation, victim2, "blocked_airport", pre_airport - actual)
		var cover := "blocked_mountain" if WorldMap.terrain_at(to.x, to.y) == WorldMap.MOUNTAIN else "blocked_forest"
		_stat(nation, victim2, cover, pre_terrain - pre_ruins)
		_stat(nation, victim2, "blocked_ruins", pre_ruins - pre_airport)
		var splash: Array = []
		if _splashes(unit):
			for nb in MapCampaign.wrapped_neighbors(to):
				var ninfo := unit_at(nb as Vector2i)
				if not ninfo.is_empty() and str(ninfo["owner"]) == victim2:
					var sd2 := ruins_adjusted(ninfo["card"], nb as Vector2i, terrain_adjusted(ninfo["card"], nb as Vector2i, pre_terrain, unit))
					_damage_card(MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y), sd2)
					_stat(nation, victim2, "splash", sd2)
					splash.append(nb)
		var destroyed := _reap(nation)
		log.append({"from": from, "to": to, "attacker": nation, "card": unit.card_name, "target_name": target.card_name,
			"victim": victim2, "damage": actual, "direct": false, "intercepted": pre_terrain < before, "mountain": actual < pre_terrain,
			"destroyed": destroyed, "splash": splash, "buffed": buffed, "intercept_from": intercept_from, "flank": flank})
		_collapse_now(log)
	return log

# ------------------------------------------------------------------- items
# Items (Missile, Nuke) are one-use cards: instead of being placed they are fired
# from one of the nation's launch sites (Item.LaunchRanges: card name -> range) at
# any hex in play within that range, for their MoneyCost. Every enemy card and
# enemy flag within BlastRadius of the impact takes Damage (the firing nation's own
# cards are spared; mountain, forest and ruins cover count as for any hit). If an
# enemy Interceptor that can pay covers the impact hex (within INTERCEPTOR_RANGE)
# it shoots the item down to half damage, for its usual 2 HP and 6 Money. A Nuke
# leaves nuclear wasteland on the 7 hexes at its heart. The card then goes to the
# graveyard.

# Living cards of `nation` that can fire `item`: [[hex, range], ...].
func item_launchers(nation: String, item: Item) -> Array:
	var out: Array = []
	for k in cards_of(nation):
		var c: Card = units[k]["card"]
		var r := item.launch_range(c)
		if r > 0 and card_hp(c) > 0:
			out.append([key_to_hex(k), r])
	return out

# Every hex `nation` could fire `item` at right now: {hex: true}.
func item_targets(nation: String, item: Item) -> Dictionary:
	var out: Dictionary = {}
	for l in item_launchers(nation, item):
		for h in hexes_within(l[0] as Vector2i, int(l[1])):
			out[h] = true
	return out

# The launch site that fires `item` at `t`: the nearest one in range, or (-1, -1).
func item_launcher_for(nation: String, item: Item, t: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for l in item_launchers(nation, item):
		var d := hex_distance(l[0] as Vector2i, t)
		if d <= int(l[1]) and d < best_d:
			best_d = d
			best = l[0]
	return best

# "" when `nation` can fire `item` at `t` now, else why not.
func can_fire_item(nation: String, item: Item, t: Vector2i) -> String:
	var p: Player = players[nation]
	if not p.Hand.has(item):
		return "That card is not in your hand"
	var short := shortfall(nation, item)
	if short != "":
		return "Can't afford %s: need %s" % [item.card_name, short]
	if item_launchers(nation, item).is_empty():
		return "%s needs one of your %s to fire from" % [item.card_name, item.launcher_text()]
	if not WorldMap.in_bounds(t.x, t.y) or WorldMap.is_void(t.x, t.y):
		return "That hex is out of this war"
	if item_launcher_for(nation, item, t).x < 0:
		return "Out of range: %s fires from your %s" % [item.card_name, item.launcher_text()]
	return ""

# The enemy Interceptor that would shoot down an item `nation` fires at `t` (the
# nearest one covering it whose nation can pay), or (-1, -1). Nothing is paid here.
func item_interceptor(nation: String, t: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INTERCEPTOR_RANGE + 1
	for h in hexes_within(t, INTERCEPTOR_RANGE):
		var info := unit_at(h as Vector2i)
		if info.is_empty() or str(info["owner"]) == nation or not (info["card"] is Interceptor) or card_hp(info["card"]) <= 0:
			continue
		if (players[str(info["owner"])] as Player).MoneySupply < 6:
			continue
		var d := hex_distance(t, h as Vector2i)
		if d < best_d:
			best_d = d
			best = h
	return best

# Fire `item` at `t`. Returns {} if it can't (see can_fire_item), else
# {"item", "from", "to", "radius", "damage" (per hit, after interception),
#  "intercept_from" (hex or (-1, -1)), "wasteland": [hexes], "entries": [...]}
# where entries are shaped like fire()'s log (one per card or flag hit, with
# "destroyed" and, on the last, "collapses"), so the screen replays them the same way.
func fire_item(nation: String, item: Item, t: Vector2i) -> Dictionary:
	if can_fire_item(nation, item, t) != "":
		return {}
	var p: Player = players[nation]
	var from := item_launcher_for(nation, item, t)
	p.MoneySupply -= p.get_effective_money_cost(item)
	p.BioSupply -= item.BioCost
	p.Hand.erase(item)
	p.Graveyard.append(item) # one use
	var icpt := item_interceptor(nation, t)
	var hit_down := icpt.x >= 0
	var dmg := item.damage_at(0, hit_down) # where it lands (Nukes weaken further out)
	if hit_down:
		var iinfo := unit_at(icpt)
		(iinfo["card"] as Building).HitPoints -= 2
		var ip: Player = players[str(iinfo["owner"])]
		ip.MoneySupply = maxi(0, ip.MoneySupply - 6)
	var blast := hexes_within(t, item.BlastRadius)
	var entries: Array = []
	var by_key: Dictionary = {}
	for h in blast:
		var k := MapCampaign.key_of((h as Vector2i).x, (h as Vector2i).y)
		if not units.has(k):
			continue
		var victim := str(units[k]["owner"])
		var card: Card = units[k]["card"]
		if victim == nation or card_hp(card) <= 0:
			continue # its own side is spared
		var dist := hex_distance(h, t)
		var here := item.damage_at(dist, hit_down)
		var terrain := terrain_adjusted(card, h, here)
		var d := ruins_adjusted(card, h, terrain)
		_damage_card(k, d)
		_stat(nation, victim, "dealt", d)
		_stat(nation, victim, "missiles", d)
		_stat(nation, victim, "blocked_interceptor", item.damage_at(dist) - here)
		var cover := "blocked_mountain" if WorldMap.terrain_at((h as Vector2i).x, (h as Vector2i).y) == WorldMap.MOUNTAIN else "blocked_forest"
		_stat(nation, victim, cover, here - terrain)
		_stat(nation, victim, "blocked_ruins", terrain - d)
		var e := {"from": from, "to": h, "attacker": nation, "card": item.card_name, "target_name": card.card_name,
			"victim": victim, "damage": d, "direct": false, "intercepted": icpt.x >= 0, "destroyed": [], "splash": [],
			"buffed": false, "intercept_from": icpt, "item": true}
		entries.append(e)
		by_key[k] = e
	var fs := flag_sites()
	for fn in fs.keys():
		var fdist := hex_distance(fs[fn], t)
		if str(fn) == nation or fdist > item.BlastRadius:
			continue
		var fd := item.damage_at(fdist, hit_down)
		_hurt_nation(str(fn), nation, fd)
		_stat(nation, str(fn), "dealt", fd)
		_stat(nation, str(fn), "flag", fd)
		_stat(nation, str(fn), "missiles", fd)
		_stat(nation, str(fn), "blocked_interceptor", item.damage_at(fdist) - fd)
		entries.append({"from": from, "to": fs[fn], "attacker": nation, "card": item.card_name, "target_name": str(fn) + " flag",
			"victim": str(fn), "damage": fd, "direct": true, "intercepted": icpt.x >= 0, "destroyed": [], "splash": [],
			"buffed": false, "intercept_from": icpt, "item": true})
	var wasteland: Array = []
	if item is Nuke:
		for h in hexes_within(t, 1):
			scars[MapCampaign.key_of((h as Vector2i).x, (h as Vector2i).y)] = "wasteland"
			wasteland.append(h)
	for dd in _reap(nation):
		var de: Dictionary = by_key.get(str(dd["key"]), {})
		if not de.is_empty():
			(de["destroyed"] as Array).append(dd)
	if not entries.is_empty():
		_collapse_now(entries)
	return {"item": item.card_name, "from": from, "to": t, "radius": item.BlastRadius, "damage": dmg,
		"intercept_from": icpt, "wasteland": wasteland, "entries": entries, "nuke": item is Nuke}

# AI: how much firing `item` at `t` is worth to `nation` (damage it would do,
# kills, flag hits; for a Nuke, its own units caught in the wasteland count against).
const ITEM_FIRE_SCORE := {"Missile": 14.0, "Nuke": 60.0} # fire only when worth at least this

func item_score(nation: String, item: Item, t: Vector2i) -> float:
	var hit_down := item_interceptor(nation, t).x >= 0
	var score := 0.0
	for h in hexes_within(t, item.BlastRadius):
		var info := unit_at(h as Vector2i)
		if info.is_empty():
			continue
		var card: Card = info["card"]
		var hp := card_hp(card)
		if str(info["owner"]) == nation:
			if item is Nuke and card is Unit and hex_distance(h as Vector2i, t) <= 1:
				score -= 8.0 # left standing in its own fallout
			continue
		if hp <= 0:
			continue
		var dmg: float = item.damage_at(hex_distance(h as Vector2i, t), hit_down)
		score += minf(dmg, hp)
		if dmg >= hp:
			score += card.BioCost + 4.0 # a kill: its owner loses BioCost HP too
	var fs := flag_sites()
	for fn in fs.keys():
		if str(fn) != nation and hex_distance(fs[fn], t) <= item.BlastRadius:
			score += item.damage_at(hex_distance(fs[fn], t), hit_down) * 1.5
	return score

# The best item shot for `nation` right now: {"item", "target", "score"}, or {}
# when nothing in its hand is worth firing (see ITEM_FIRE_SCORE).
# With `unaffordable`: only items it can't pay for yet (what it should save up for).
func ai_pick_item(nation: String, unaffordable: bool = false) -> Dictionary:
	var p: Player = players[nation]
	var best: Dictionary = {}
	var tried: Dictionary = {} # one evaluation per item type
	for c in p.Hand:
		if not (c is Item) or tried.has((c as Card).card_name) or (shortfall(nation, c) != "") != unaffordable:
			continue
		tried[(c as Card).card_name] = true
		var item := c as Item
		var launchers := item_launchers(nation, item)
		if launchers.is_empty():
			continue
		# aim at enemy cards and flags in reach (a blast centred elsewhere rarely does better)
		var cands: Array = []
		for k in units.keys():
			if str(units[k]["owner"]) != nation:
				cands.append(key_to_hex(k))
		var fs := flag_sites()
		for fn in fs.keys():
			if str(fn) != nation:
				cands.append(fs[fn])
		for t in cands:
			var in_reach := false
			for l in launchers:
				if hex_distance(l[0] as Vector2i, t) <= int(l[1]):
					in_reach = true
					break
			if not in_reach:
				continue
			var sc := item_score(nation, item, t)
			if sc >= float(ITEM_FIRE_SCORE.get(item.card_name, 20.0)) and (best.is_empty() or sc > float(best["score"])):
				best = {"item": item, "target": t, "score": sc}
	return best

# Fire every item worth firing (headless games; the game screen fires them one at
# a time with ai_pick_item so each can be shown). Returns fire_item's results.
func ai_use_items(nation: String) -> Array:
	var out: Array = []
	for i in range(12):
		var pick := ai_pick_item(nation)
		if pick.is_empty():
			break
		var ev := fire_item(nation, pick["item"], pick["target"])
		if ev.is_empty():
			break
		out.append(ev)
	return out

# A nation that just hit 0 HP collapses right away (cedes land, its flag moves,
# it rebuilds to full HP), so later shots never pound a flag that is already
# down. The event rides on the shot that caused it (log entry "collapses") and
# is also queued for resolve_collapses().
var pending_collapses: Array = []

# Round report: what each nation did to each other nation since the player's last
# turn began. "attacker|victim" -> {category: amount}. Categories:
#   dealt (all damage that landed, flags included), flag, kills, kill_hp (HP the
#   victim lost for destroyed cards), barracks, home (firing from own land), modifiers (can be negative),
#   unit_bonus (Special Ops x2 / Anti Aircraft x3), flank (target hemmed in), boat (target
#   a ground unit at sea), splash (Fighter and Bomber Jets), blocked_airport,
#   blocked_interceptor, blocked_mountain, blocked_forest, blocked_flying.
# The world map shows it at the start of the player's turn, then resets it.
var round_stats: Dictionary = {}
const STAT_CATEGORIES := ["dealt", "flag", "kills", "kill_hp", "missiles", "barracks", "home", "modifiers", "unit_bonus", "flank", "boat", "splash",
	"blocked_interceptor", "blocked_mountain", "blocked_forest", "blocked_ruins", "blocked_flying", "blocked_airport"]

func _stat(attacker: String, victim: String, cat: String, amount: int) -> void:
	if amount == 0 or attacker == victim:
		return
	var k := attacker + "|" + victim
	if not round_stats.has(k):
		round_stats[k] = {}
	var row: Dictionary = round_stats[k]
	row[cat] = int(row.get(cat, 0)) + amount

func reset_round_stats() -> void:
	round_stats.clear()
	influence_log.clear()

func _log_influence(nation: String, source: String, amount: int) -> void:
	if amount <= 0:
		return
	if not influence_log.has(nation):
		influence_log[nation] = {"hexes": 0, "buildings": 0}
	influence_log[nation][source] = int(influence_log[nation].get(source, 0)) + amount
	earned_since_turn[nation] = int(earned_since_turn.get(nation, 0)) + amount

# Top `nation` up to MIN_INFLUENCE_PER_TURN for the turn just gone; returns what it got.
func influence_topup(nation: String) -> int:
	var topup := maxi(0, MIN_INFLUENCE_PER_TURN - int(earned_since_turn.get(nation, 0)))
	earned_since_turn[nation] = 0
	(players[nation] as Player).Influence += topup
	return topup

func _collapse_now(log: Array) -> void:
	var ev := _collapse_all()
	if ev.is_empty():
		return
	pending_collapses.append_array(ev)
	(log[log.size() - 1] as Dictionary)["collapses"] = ev

# Nations at 0 HP cede border hexes to their top damager (x2 when weak, x4 with no units) and rebuild.
# Returns [{loser, winner, tiles}] (winner "" when nobody could take land), including
# the collapses that already happened mid-attack (see _collapse_now).
func resolve_collapses() -> Array:
	var events: Array = pending_collapses.duplicate()
	pending_collapses.clear()
	events.append_array(_collapse_all())
	return events

func _collapse_all() -> Array:
	var events: Array = []
	for n in WorldMap.nations():
		var loser := str((n as Dictionary)["name"])
		if not alive(loser) or (players[loser] as Player).HitPoints > 0:
			continue
		var row: Dictionary = ledger.get(loser, {})
		var ranked: Array = row.keys()
		ranked.sort_custom(func(a, b): return int(row[a]) > int(row[b]))
		var mult := loss_multiplier(loser)
		var old_flag := campaign.capital_site(loser)
		# the loser's cards standing on its own land: those whose hex changes hands go with it
		var at_home: Array = []
		for k in cards_of(loser):
			var th := key_to_hex(k)
			if campaign.owner_of(th.x, th.y) == loser:
				at_home.append(k)
		var winner := ""
		var moved := 0
		for cand in ranked:
			var w := str(cand)
			if w == loser or not alive(w):
				continue
			moved = campaign.conquer(w, loser, (players[w] as Player).HitPoints, mult)
			if moved > 0:
				winner = w
				break
		# Loser's cards on the hexes it just ceded are lost with the land; units away
		# from home (on enemy land or at sea) carry on, unless the nation is gone.
		var lost: Array = []
		var gone := not alive(loser)
		for k in (cards_of(loser) if gone else at_home):
			var t := key_to_hex(k)
			if gone or campaign.owner_of(t.x, t.y) != loser:
				lost.append(k)
				_remove(k)
		# Flag fell: move it to the free hex nearest the centre of what's left.
		var flag_moved := false
		if alive(loser) and campaign.owner_of(old_flag.x, old_flag.y) != loser:
			var blocked: Dictionary = {}
			for k in units.keys():
				blocked[k] = true # its own cards, and enemy units standing on its land
			var site := campaign.relocate_flag(loser, blocked)
			var fk := MapCampaign.key_of(site.x, site.y)
			if units.has(fk):
				# every hex was full: the card there makes way for the flag
				var evicted: Player = players[str(units[fk]["owner"])]
				evicted.DiscardPile.append(units[fk]["card"])
				evicted.MapCards.erase(units[fk]["card"])
				units.erase(fk)
				lost.append(fk)
			flag_moved = true
		var gained: int = 0
		if winner != "":
			gained = roundi(moved * INFLUENCE_PER_HEX)
			(players[winner] as Player).Influence += gained
			_log_influence(winner, "hexes", gained)
		var lp: Player = players[loser]
		lp.HitPoints = lp.MaxHitPoints
		ledger[loser] = {}
		events.append({"loser": loser, "winner": winner, "tiles": moved, "eliminated": not alive(loser), "influence": gained,
			"multiplier": mult, "doubled": mult > 1, "flag_moved": flag_moved, "flag": campaign.capital_site(loser) if alive(loser) else Vector2i(-1, -1),
			"lost": lost, "max_hp": lp.MaxHitPoints})
	return events

# --------------------------------------------------------------- save/load
func to_data() -> Dictionary:
	var nat: Dictionary = {}
	for nm in players.keys():
		var p: Player = players[nm]
		var mod_names: Array = []
		for m in p.Modifiers:
			mod_names.append((m as Modifier).modifier_name if m is Modifier else str(m))
		nat[nm] = {"hp": p.HitPoints, "bio": p.BioSupply, "money": p.MoneySupply, "influence": p.Influence, "mods": mod_names}
	var us: Array = []
	for k in units.keys():
		var info: Dictionary = units[k]
		us.append({"key": k, "name": (info["card"] as Card).card_name, "owner": info["owner"], "hp": card_hp(info["card"])})
	var sh: Dictionary = {}
	for nm in shops.keys():
		var shop: Dictionary = shops[nm]
		var card_names: Array = []
		for c in shop["cards"]:
			card_names.append((c as Card).card_name)
		var shop_mods: Array = []
		for m2 in shop["mods"]:
			shop_mods.append((m2 as Modifier).modifier_name)
		sh[nm] = {"cards": card_names, "mods": shop_mods, "remove_used": shop["remove_used"]}
	return {"turn": turn, "nations": nat, "units": us, "weights": deck_weights.duplicate(true), "shops": sh,
		"pending": pending.duplicate(true), "scars": scars.duplicate()}

# Rebuild from saved data; decks come fresh from the factory (make_player).
static func from_data(d: Dictionary, c: MapCampaign, make_player: Callable, human: Player) -> MapWar:
	var w := MapWar.new()
	w.setup(c, make_player, human)
	for k in w.units.keys().duplicate():
		w._remove(k)
	for nm in w.players.keys():
		(w.players[nm] as Player).Graveyard.clear()
	w.turn = int(d.get("turn", 1))
	w.scars = (d.get("scars", {}) as Dictionary).duplicate()
	if d.has("pending"):
		w.pending = (d["pending"] as Array).duplicate(true)
	else:
		# older saves: whatever was due by the saved round has already landed
		w.pending = w.pending.filter(func(r): return int((r as Dictionary).get("turn", 1)) > w.turn)
	var nat: Dictionary = d.get("nations", {})
	for nm in nat.keys():
		if w.players.has(nm):
			var p: Player = w.players[nm]
			var nd: Dictionary = nat[nm]
			p.HitPoints = int(nd.get("hp", p.HitPoints))
			p.BioSupply = int(nd.get("bio", p.BioSupply))
			p.MoneySupply = int(nd.get("money", p.MoneySupply))
			p.Influence = int(nd.get("influence", p.Influence))
			if nd.has("mods"):
				p.Modifiers.clear()
				for mn in nd["mods"]:
					for mm in Modifier.all_modifiers():
						if (mm as Modifier).modifier_name == str(mn):
							p.Modifiers.append(mm)
	for u in d.get("units", []):
		var ud: Dictionary = u
		var owner := str(ud.get("owner", ""))
		if not w.players.has(owner):
			continue
		var card: Card = (w.players[owner] as Player)._base_card_by_name(str(ud.get("name", "")))
		if card == null:
			continue
		if card is Unit:
			(card as Unit).HitPoints = int(ud.get("hp", 1))
		elif card is Building:
			(card as Building).HitPoints = int(ud.get("hp", 1))
		w._put(owner, card, key_to_hex(str(ud["key"])))
	# shop odds come from the deck each nation started the campaign with
	var wd = d.get("weights", {})
	if wd is Dictionary and not (wd as Dictionary).is_empty():
		w.deck_weights = (wd as Dictionary).duplicate(true)
	else:
		# older saves: rebuild from fresh starting decks, never the (bought/trimmed) current ones
		for nm in w.players.keys():
			var fresh: Player = make_player.call(nm)
			w._add_starting_items(fresh, nm)
			w.deck_weights[nm] = starting_deck_weights(fresh)
	var sd = d.get("shops", {})
	if sd is Dictionary:
		for nm in (sd as Dictionary).keys():
			if not w.players.has(nm):
				continue
			var entry: Dictionary = sd[nm]
			var p2: Player = w.players[nm]
			var cards: Array = []
			for cn in entry.get("cards", []):
				var shop_card := p2._base_card_by_name(str(cn))
				if shop_card != null:
					cards.append(shop_card)
			var mods: Array = []
			for mn in entry.get("mods", []):
				for mm in Modifier.all_modifiers():
					if (mm as Modifier).modifier_name == str(mn):
						mods.append(mm)
			w.shops[nm] = {"cards": cards, "mods": mods, "remove_used": bool(entry.get("remove_used", false))}
	return w
