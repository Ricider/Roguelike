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
# from non-ranged, Barracks +2 to adjacent units, Interceptors halve ranged/flying
# hits on adjacent friends, Fighter Jets splash the target's neighbors.
# Terrain: non-flying units on a mountain hex take 1 less damage (minimum 1).
# A destroyed card costs its owner HP equal to its BioCost. A nation at 0 HP
# cedes border hexes (1 per 10 HP the victor has left; x2 when it fields fewer
# than 3 units, x4 with none) to whoever damaged it most, loses the cards on those
# hexes, then rebuilds to full HP. A fallen flag moves to the free hex nearest
# the centre of the remaining territory; flags always keep a hex to themselves.
# The winner earns INFLUENCE_PER_HEX Influence per hex taken (spent in the shop).
extends RefCounted
class_name MapWar

# Influence (the shop currency) a nation earns per hex it takes.
const INFLUENCE_PER_HEX: int = 5
# A nation fielding fewer than this many units loses territory twice as fast;
# with no units on the map at all it loses territory four times as fast.
const WEAK_UNIT_COUNT: int = 3
# Shop: 5 card slots + 3 modifiers per nation, restocked at the start of its turn.
const SHOP_CARD_SLOTS: int = 5
const REMOVE_COST: int = 25

var campaign: MapCampaign = null
var players: Dictionary = {} # nation -> Player
var units: Dictionary = {} # "x,y" -> {"card": Card, "owner": String}
var ledger: Dictionary = {} # victim nation -> {attacker nation: HP damage dealt}
var turn: int = 1
var rng := RandomNumberGenerator.new()
var deck_weights: Dictionary = {} # nation -> {card name: copies in its starting deck}
var shops: Dictionary = {} # nation -> {"cards": Array[Card], "mods": Array[Modifier], "remove_used": bool}
var _last_intercept_from := Vector2i(-1, -1) # hex of the Interceptor that halved the latest hit

# make_player: Callable(nation: String) -> Player for the AI nations.
func setup(c: MapCampaign, make_player: Callable, human: Player) -> void:
	campaign = c
	players.clear()
	units.clear()
	ledger.clear()
	turn = 1
	rng.randomize()
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		var p: Player = human if (nm == c.player_nation and human != null) else make_player.call(nm)
		p.display_name = nm
		p.MapCards.clear()
		players[nm] = p
		deck_weights[nm] = starting_deck_weights(p)
		# Starting cards on the 4x10 board move onto the map around the capital.
		var start_cards: Array = p.get_all_board_cards()
		for row in p.Board:
			for sq in row.Squares:
				sq.clear()
		for card in start_cards:
			var t := best_hex_for(nm, card as Card)
			if t.x >= 0:
				_put(nm, card as Card, t)

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
func can_place(nation: String, card: Card, t: Vector2i) -> String:
	if not WorldMap.in_bounds(t.x, t.y) or campaign.owner_of(t.x, t.y) != nation:
		return "You can only build on your own territory"
	if units.has(MapCampaign.key_of(t.x, t.y)):
		return "That hex is taken"
	if campaign.capital_site(nation) == t:
		return "Your flag stands here; it needs its own hex"
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
func begin_turn(nation: String) -> void:
	(players[nation] as Player).economy_phase() # income from map buildings + draw to 10
	restock_shop(nation)

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
	return true

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
func ai_shop(nation: String) -> Array:
	var p: Player = players[nation]
	var shop := shop_of(nation)
	var bought: Array = []
	# a random affordable modifier, so nations don't all converge on the same one
	var affordable: Array = []
	for m in shop["mods"]:
		if p.Influence >= (m as Modifier).InfluenceCost and not p.has_modifier((m as Modifier).modifier_name):
			affordable.append(m)
	if not affordable.is_empty():
		var pick: Modifier = affordable[rng.randi_range(0, affordable.size() - 1)]
		if buy_modifier(nation, pick):
			bought.append(pick.modifier_name)
	while true:
		var best: Card = null
		for c in shop["cards"]:
			var card := c as Card
			if card.InfluenceCost <= p.Influence and (best == null or card.InfluenceCost > best.InfluenceCost):
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
	var dist: Dictionary = {}
	var queue: Array = []
	for k in campaign.owner.keys():
		var o := str(campaign.owner[k])
		if o != nation:
			dist[k] = 0
			queue.append(key_to_hex(str(k)))
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = int(dist[MapCampaign.key_of(cur.x, cur.y)])
		for nb in MapCampaign.wrapped_neighbors(cur):
			var v := nb as Vector2i
			var nk := MapCampaign.key_of(v.x, v.y)
			if not dist.has(nk):
				dist[nk] = d + 1
				queue.append(v)
	return dist

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
	var flag := campaign.capital_site(nation)
	for t in campaign.tiles_of(nation):
		var tv := t as Vector2i
		if units.has(MapCampaign.key_of(tv.x, tv.y)) or tv == flag:
			continue
		var d: float = float(fdist.get(MapCampaign.key_of(tv.x, tv.y), 50))
		var score: float
		if card is Unit or card is Wall:
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
	var p: Player = players[nation]
	var placed: Array = []
	var fdist := frontier_distance(nation)
	var hand: Array = p.Hand.duplicate()
	hand.shuffle()
	# economy first when there is little of it, then the army
	hand.sort_custom(func(a, b): return (a is Building and not (a is Wall)) and not (b is Building and not (b is Wall)))
	for c in hand:
		var card := c as Card
		if shortfall(nation, card) != "":
			continue
		var t := best_hex_for(nation, card, fdist)
		if t.x < 0:
			break
		if place(nation, card, t):
			placed.append([card, t])
	return placed

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
# and is it covered by an adjacent Interceptor that can still pay (6 Money)?
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
	for nb in MapCampaign.wrapped_neighbors(key_to_hex(k)):
		var info := unit_at(nb as Vector2i)
		if not info.is_empty() and str(info["owner"]) == owner and info["card"] is Interceptor and card_hp(info["card"]) > 0:
			return true
	return false

func effective_damage(nation: String, unit: Unit, t: Vector2i) -> int:
	var p: Player = players[nation]
	return p.effective_damage_for(unit, null) + _barracks_bonus(nation, t)

# Where each living nation's flag stands (its capital, or the owned hex nearest it).
func flag_sites() -> Dictionary:
	var out: Dictionary = {}
	for n in WorldMap.nations():
		var nm := str((n as Dictionary)["name"])
		if alive(nm):
			out[nm] = campaign.capital_site(nm)
	return out

# {} when nothing to shoot; {"key": String} for a card; {"flag": nation, "hex": Vector2i} for a flag.
# Targets are enemy cards plus enemy flags. Units without Range take the closest
# (random among ties); ranged units find the closest enemy nation and pick a random
# target of that nation (any of its cards or its flag).
func pick_target(nation: String, from: Vector2i, ranged: bool, flags: Dictionary = {}) -> Dictionary:
	if flags.is_empty():
		flags = flag_sites()
	var closest := _closest_targets(nation, from, flags)
	if closest.is_empty():
		return {}
	var pick: Dictionary = closest[rng.randi_range(0, closest.size() - 1)]
	if not ranged:
		return pick
	# Ranged: a random target (card or flag) of the closest enemy nation.
	var victim := str(pick["owner"])
	var pool: Array = []
	for k in cards_of(victim):
		if card_hp(units[k]["card"]) > 0:
			pool.append({"key": k, "owner": victim})
	if flags.has(victim):
		pool.append({"flag": victim, "hex": flags[victim], "owner": victim})
	return pool[rng.randi_range(0, pool.size() - 1)]

# Where the unit on hex key `k` would shoot next, without rolling dice (for hover help):
# {"hex", "owner", "name", "distance", "ranged", "ties"}; ranged units report the nation they aim at.
func predict_target(k: String) -> Dictionary:
	if not units.has(k) or not (units[k]["card"] is Unit):
		return {}
	var nation := str(units[k]["owner"])
	var unit := units[k]["card"] as Unit
	var from := key_to_hex(k)
	var closest := _closest_targets(nation, from, flag_sites())
	if closest.is_empty():
		return {}
	closest.sort_custom(func(a, b): return str(a.get("key", a.get("flag", ""))) < str(b.get("key", b.get("flag", ""))))
	var first: Dictionary = closest[0]
	var hex: Vector2i = first["hex"] if first.has("hex") else key_to_hex(str(first["key"]))
	var nm: String = (str(first["owner"]) + " flag") if first.has("flag") else (units[first["key"]]["card"] as Card).card_name
	return {"hex": hex, "owner": str(first["owner"]), "name": nm, "distance": hex_distance(from, hex),
		"ranged": (players[nation] as Player).has_range_for(unit), "ties": closest.size()}

# Every enemy target (cards and flags) at the smallest hex distance from `from`.
func _closest_targets(nation: String, from: Vector2i, flags: Dictionary) -> Array:
	var best: int = 1 << 30
	var closest: Array = []
	for k in units.keys():
		var info: Dictionary = units[k]
		var o := str(info["owner"])
		if o == nation or card_hp(info["card"]) <= 0:
			continue
		var d := hex_distance(from, key_to_hex(str(k)))
		if d < best:
			best = d
			closest = [{"key": k, "owner": o}]
		elif d == best:
			closest.append({"key": k, "owner": o})
	for fnation in flags.keys():
		if str(fnation) == nation:
			continue
		var site: Vector2i = flags[fnation]
		var d2 := hex_distance(from, site)
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

# Mountain cover: a non-flying unit standing on a mountain hex takes 1 less damage (min 1).
static func terrain_adjusted(card: Card, t: Vector2i, dmg: int) -> int:
	if card is Unit and not (card as Unit).Flying and WorldMap.terrain_at(t.x, t.y) == WorldMap.MOUNTAIN:
		return maxi(1, dmg - 1)
	return dmg

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
		out.append({"key": k, "hex": key_to_hex(k), "name": (info["card"] as Card).card_name, "owner": info["owner"]})
		_hurt_nation(str(info["owner"]), attacker, (info["card"] as Card).BioCost)
		_remove(k)
	return out

func _intercept(victim: String, t: Vector2i, unit: Unit, attacker: String, dmg: int) -> int:
	_last_intercept_from = Vector2i(-1, -1)
	var vp: Player = players[victim]
	var ranged: bool = (players[attacker] as Player).has_range_for(unit)
	if vp.MoneySupply < 6 or not (ranged or unit.Flying):
		return dmg
	for nb in MapCampaign.wrapped_neighbors(t):
		var info := unit_at(nb as Vector2i)
		if not info.is_empty() and str(info["owner"]) == victim and info["card"] is Interceptor and card_hp(info["card"]) > 0:
			(info["card"] as Building).HitPoints -= 2
			vp.MoneySupply = maxi(0, vp.MoneySupply - 6)
			_last_intercept_from = nb as Vector2i
			return maxi(1, dmg / 2)
	return dmg

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
	var flags := flag_sites()
	for s in range(shots):
		if not units.has(k) or unit.HitPoints <= 0:
			break
		var tgt := pick_target(nation, from, ranged, flags)
		if tgt.is_empty():
			break
		var dmg := effective_damage(nation, unit, from)
		var buffed := _barracks_bonus(nation, from) > 0
		if tgt.has("flag"):
			# Flag hit: the damage goes to the nation's HP (Fighter Jets still splash around it).
			var victim := str(tgt["flag"])
			var site: Vector2i = tgt["hex"]
			_hurt_nation(victim, nation, dmg)
			var fsplash: Array = []
			if unit is FighterJet:
				for nb in MapCampaign.wrapped_neighbors(site):
					var ninfo := unit_at(nb as Vector2i)
					if not ninfo.is_empty() and str(ninfo["owner"]) == victim:
						_damage_card(MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y), terrain_adjusted(ninfo["card"], nb as Vector2i, dmg))
						fsplash.append(nb)
			log.append({"from": from, "to": site, "attacker": nation, "card": unit.card_name, "target_name": victim + " flag",
				"victim": victim, "damage": dmg, "direct": true, "intercepted": false, "destroyed": _reap(nation), "splash": fsplash,
				"buffed": buffed, "intercept_from": Vector2i(-1, -1)})
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
		if target is Unit and (target as Unit).Flying and not ranged and not (unit is AntiAircraft):
			actual = maxi(1, actual / 2)
		var before := actual
		actual = _intercept(victim2, to, unit, nation, actual)
		var intercept_from := _last_intercept_from
		var pre_terrain := actual
		actual = terrain_adjusted(target, to, actual)
		_damage_card(tk, actual)
		var splash: Array = []
		if unit is FighterJet:
			for nb in MapCampaign.wrapped_neighbors(to):
				var ninfo := unit_at(nb as Vector2i)
				if not ninfo.is_empty() and str(ninfo["owner"]) == victim2:
					_damage_card(MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y), terrain_adjusted(ninfo["card"], nb as Vector2i, pre_terrain))
					splash.append(nb)
		var destroyed := _reap(nation)
		log.append({"from": from, "to": to, "attacker": nation, "card": unit.card_name, "target_name": target.card_name,
			"victim": victim2, "damage": actual, "direct": false, "intercepted": pre_terrain < before, "mountain": actual < pre_terrain,
			"destroyed": destroyed, "splash": splash, "buffed": buffed, "intercept_from": intercept_from})
	return log

# Nations at 0 HP cede border hexes to their top damager (x2 when weak, x4 with no units) and rebuild.
# Returns [{loser, winner, tiles}] (winner "" when nobody could take land).
func resolve_collapses() -> Array:
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
		# Loser's cards on hexes it no longer owns are lost with the land.
		for k in cards_of(loser):
			var t := key_to_hex(k)
			if campaign.owner_of(t.x, t.y) != loser:
				_remove(k)
		# Flag fell: move it to the free hex nearest the centre of what's left.
		var flag_moved := false
		if alive(loser) and campaign.owner_of(old_flag.x, old_flag.y) != loser:
			var blocked: Dictionary = {}
			for k in cards_of(loser):
				blocked[k] = true
			var site := campaign.relocate_flag(loser, blocked)
			var fk := MapCampaign.key_of(site.x, site.y)
			if units.has(fk):
				# every hex was full: the card there makes way for the flag
				(players[loser] as Player).DiscardPile.append(units[fk]["card"])
				(players[loser] as Player).MapCards.erase(units[fk]["card"])
				units.erase(fk)
			flag_moved = true
		var gained: int = 0
		if winner != "":
			gained = moved * INFLUENCE_PER_HEX
			(players[winner] as Player).Influence += gained
		var lp: Player = players[loser]
		lp.HitPoints = lp.MaxHitPoints
		ledger[loser] = {}
		events.append({"loser": loser, "winner": winner, "tiles": moved, "eliminated": not alive(loser), "influence": gained,
			"multiplier": mult, "doubled": mult > 1, "flag_moved": flag_moved, "flag": campaign.capital_site(loser) if alive(loser) else Vector2i(-1, -1)})
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
	return {"turn": turn, "nations": nat, "units": us, "weights": deck_weights.duplicate(true), "shops": sh}

# Rebuild from saved data; decks come fresh from the factory (make_player).
static func from_data(d: Dictionary, c: MapCampaign, make_player: Callable, human: Player) -> MapWar:
	var w := MapWar.new()
	w.setup(c, make_player, human)
	for k in w.units.keys().duplicate():
		w._remove(k)
	for nm in w.players.keys():
		(w.players[nm] as Player).Graveyard.clear()
	w.turn = int(d.get("turn", 1))
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
