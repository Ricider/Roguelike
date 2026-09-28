# MapWar: the world map as the battlefield. Every nation places cards from its
# hand onto its own empty hexes; on its turn each of its units fires.
#   - Units without Range hit the closest enemy card on the map (hex distance,
#     east-west wrap), random among ties.
#   - Units with Range (random-target units) pick the closest enemy *nation*
#     (owner of the closest enemy card) and hit a random card of that nation.
#   - With no enemy cards anywhere, units hit the closest enemy nation's HP directly.
# Card rules carry over from the 4x10 battles: Rocket Launcher/Howitzer fire 4
# times, Special Ops x2 vs ground, Anti Aircraft x3 vs flying, Flying takes half
# from non-ranged, Barracks +2 to adjacent units, Interceptors halve ranged/flying
# hits on adjacent friends, Fighter Jets splash the target's neighbors.
# A destroyed card costs its owner HP equal to its BioCost. A nation at 0 HP
# cedes border hexes (1 per 10 HP the victor has left) to whoever damaged it
# most, loses the cards on those hexes, then rebuilds to full HP.
extends RefCounted
class_name MapWar

var campaign: MapCampaign = null
var players: Dictionary = {} # nation -> Player
var units: Dictionary = {} # "x,y" -> {"card": Card, "owner": String}
var ledger: Dictionary = {} # victim nation -> {attacker nation: HP damage dealt}
var turn: int = 1
var rng := RandomNumberGenerator.new()

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
	var best: int = 1 << 30
	for shift in [-WorldMap.GRID_W, 0, WorldMap.GRID_W]:
		best = mini(best, _cube_distance(a, Vector2i(b.x + int(shift), b.y)))
	return best

static func _cube_distance(a: Vector2i, b: Vector2i) -> int:
	var aq: int = a.x - (a.y - (a.y & 1)) / 2
	var bq: int = b.x - (b.y - (b.y & 1)) / 2
	var dq: int = aq - bq
	var dr: int = a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2

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
	for t in campaign.tiles_of(nation):
		var tv := t as Vector2i
		if units.has(MapCampaign.key_of(tv.x, tv.y)):
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

func effective_damage(nation: String, unit: Unit, t: Vector2i) -> int:
	var p: Player = players[nation]
	return p.effective_damage_for(unit, null) + _barracks_bonus(nation, t)

# {} when nothing to shoot; {"key": String} for a card; {"direct": nation, "hex": Vector2i} for an HP hit.
func pick_target(nation: String, from: Vector2i, ranged: bool) -> Dictionary:
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
			closest = [k]
		elif d == best:
			closest.append(k)
	if closest.is_empty():
		# No enemy cards anywhere: strike the closest enemy nation's HP directly.
		var best_hex := Vector2i(-1, -1)
		var bd: int = 1 << 30
		for k in campaign.owner.keys():
			if str(campaign.owner[k]) == nation:
				continue
			var d2 := hex_distance(from, key_to_hex(str(k)))
			if d2 < bd:
				bd = d2
				best_hex = key_to_hex(str(k))
		if best_hex.x < 0:
			return {}
		return {"direct": campaign.owner_of(best_hex.x, best_hex.y), "hex": best_hex}
	var pick: String = closest[rng.randi_range(0, closest.size() - 1)]
	if not ranged:
		return {"key": pick}
	# Ranged: a random card of the closest enemy nation.
	var victim := str(units[pick]["owner"])
	var pool: Array = []
	for k in cards_of(victim):
		if card_hp(units[k]["card"]) > 0:
			pool.append(k)
	return {"key": pool[rng.randi_range(0, pool.size() - 1)]}

func _hurt_nation(victim: String, attacker: String, amount: int) -> void:
	var p: Player = players[victim]
	p.HitPoints = clampi(p.HitPoints - amount, 0, p.MaxHitPoints)
	if not ledger.has(victim):
		ledger[victim] = {}
	var row: Dictionary = ledger[victim]
	row[attacker] = int(row.get(attacker, 0)) + amount

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
	var vp: Player = players[victim]
	var ranged: bool = (players[attacker] as Player).has_range_for(unit)
	if vp.MoneySupply < 6 or not (ranged or unit.Flying):
		return dmg
	for nb in MapCampaign.wrapped_neighbors(t):
		var info := unit_at(nb as Vector2i)
		if not info.is_empty() and str(info["owner"]) == victim and info["card"] is Interceptor and card_hp(info["card"]) > 0:
			(info["card"] as Building).HitPoints -= 2
			vp.MoneySupply = maxi(0, vp.MoneySupply - 6)
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
	for s in range(shots):
		if not units.has(k) or unit.HitPoints <= 0:
			break
		var tgt := pick_target(nation, from, ranged)
		if tgt.is_empty():
			break
		var dmg := effective_damage(nation, unit, from)
		if tgt.has("direct"):
			var victim := str(tgt["direct"])
			_hurt_nation(victim, nation, dmg)
			log.append({"from": from, "to": tgt["hex"], "attacker": nation, "card": unit.card_name, "target_name": victim + " HQ",
				"victim": victim, "damage": dmg, "direct": true, "intercepted": false, "destroyed": [], "splash": []})
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
		_damage_card(tk, actual)
		var splash: Array = []
		if unit is FighterJet:
			for nb in MapCampaign.wrapped_neighbors(to):
				var ninfo := unit_at(nb as Vector2i)
				if not ninfo.is_empty() and str(ninfo["owner"]) == victim2:
					_damage_card(MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y), actual)
					splash.append(nb)
		var destroyed := _reap(nation)
		log.append({"from": from, "to": to, "attacker": nation, "card": unit.card_name, "target_name": target.card_name,
			"victim": victim2, "damage": actual, "direct": false, "intercepted": actual < before, "destroyed": destroyed, "splash": splash})
	return log

# Nations at 0 HP cede border hexes to their top damager and rebuild.
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
		var winner := ""
		var moved := 0
		for cand in ranked:
			var w := str(cand)
			if w == loser or not alive(w):
				continue
			moved = campaign.conquer(w, loser, (players[w] as Player).HitPoints)
			if moved > 0:
				winner = w
				break
		# Loser's cards on hexes it no longer owns are lost with the land.
		for k in cards_of(loser):
			var t := key_to_hex(k)
			if campaign.owner_of(t.x, t.y) != loser:
				_remove(k)
		var lp: Player = players[loser]
		lp.HitPoints = lp.MaxHitPoints
		ledger[loser] = {}
		events.append({"loser": loser, "winner": winner, "tiles": moved, "eliminated": not alive(loser)})
	return events

# --------------------------------------------------------------- save/load
func to_data() -> Dictionary:
	var nat: Dictionary = {}
	for nm in players.keys():
		var p: Player = players[nm]
		nat[nm] = {"hp": p.HitPoints, "bio": p.BioSupply, "money": p.MoneySupply}
	var us: Array = []
	for k in units.keys():
		var info: Dictionary = units[k]
		us.append({"key": k, "name": (info["card"] as Card).card_name, "owner": info["owner"], "hp": card_hp(info["card"])})
	return {"turn": turn, "nations": nat, "units": us}

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
	return w
