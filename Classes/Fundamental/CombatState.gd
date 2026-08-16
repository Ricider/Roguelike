extends GameObject
class_name CombatState

var Players: Array = [] # Player[2]

func _init(p1: Player = null, p2: Player = null):
	super._init()
	Players = []
	if p1 != null:
		Players.append(p1)
	if p2 != null:
		Players.append(p2)

func combat_phase() -> Array:
	# Returns log of attacks for UI animation: [{attacker, attacker_sq, attacker_player, defender, target, target_sq, damage, is_direct}]
	var log: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(Players.size()):
		var attacker: Player = Players[i]
		var defender: Player = Players[1 - i]
		var attackers: Array = []
		for row in attacker.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null and sq.Inhabitant is Unit:
					attackers.append({"card": sq.Inhabitant, "square": sq})
		for info in attackers:
			var unit: Unit = info["card"]
			var sq: Square = info["square"]
			if unit.HitPoints <= 0:
				continue
			var dmg: int = _effective_damage(attacker, unit, sq)
			var target = _pick_target(defender, unit.HasRange, rng)
			if target == null:
				defender.HitPoints -= dmg
				log.append({"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": null, "target_sq": null, "damage": dmg, "is_direct": true})
				continue
			var target_card: Card = target["card"]
			var target_sq: Square = target["square"]
			if target_card is Unit:
				(target_card as Unit).HitPoints -= dmg
			elif target_card is Building:
				(target_card as Building).HitPoints -= dmg
			_apply_special_effect(unit, target_card)
			log.append({"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": target_card, "target_sq": target_sq, "damage": dmg, "is_direct": false})
		_resolve_deaths(defender)
	return log

func _effective_damage(player: Player, unit: Unit, square: Square) -> int:
	return unit.Damage + Barracks.bonus_if_adjacent(player, square)

func _pick_target(defender: Player, has_range: bool, rng: RandomNumberGenerator):
	if has_range:
		var all: Array = []
		for row in defender.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null:
					all.append({"card": sq.Inhabitant, "square": sq})
		if all.is_empty():
			return null
		return all[rng.randi_range(0, all.size() - 1)]
	else:
		# Boards face each other (8x10 combined): AI board on top (row size-1 closest to middle),
		# human board below (row 0 closest to middle). Closest enemy is the defender's
		# front row nearest the middle. Dynamic for 4×10 spec.
		var n: int = defender.Board.size()
		var order: Array = []
		var idx: int = Players.find(defender)
		if idx == 0:
			# defender is Players[0] (human, bottom) — front is row 0
			for i in range(n):
				order.append(i)
		elif idx == 1:
			# defender is Players[1] (AI, top) — front is row n-1
			for i in range(n):
				order.append(n - 1 - i)
		else:
			# Fallback if defender not in Players (tests): assume AI-style
			for i in range(n):
				order.append(n - 1 - i)
		for row_idx in order:
			var candidates: Array = []
			var row: Row = defender.Board[row_idx]
			for sq in row.Squares:
				if sq.Inhabitant != null:
					candidates.append({"card": sq.Inhabitant, "square": sq})
			if not candidates.is_empty():
				return candidates[rng.randi_range(0, candidates.size() - 1)]
		return null

func _apply_special_effect(_attacker: Card, _target: Card):
	pass

func _resolve_deaths(player: Player):
	for row in player.Board:
		for sq in row.Squares:
			var c: Card = sq.Inhabitant
			if c == null:
				continue
			var hp: int = 0
			if c is Unit:
				hp = (c as Unit).HitPoints
			elif c is Building:
				hp = (c as Building).HitPoints
			if hp <= 0:
				player.HitPoints -= c.BioCost
				player.Graveyard.append(c)
				sq.clear()
