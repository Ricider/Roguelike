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
			# Rocket Launcher (was Howitzer) special: attacks 4 times
			var attacks: int = 4 if unit is RocketLauncher or unit is Howitzer else 1
			for a_idx in range(attacks):
				if unit.HitPoints <= 0:
					break
				var effective_range: bool = unit.HasRange
				if attacker.has_method("has_range_for"):
					effective_range = attacker.has_range_for(unit)
				var target = _pick_target_manhattan(defender, attacker, sq, effective_range, rng)
				if target == null:
					defender.HitPoints -= dmg
					defender.HitPoints = clamp(defender.HitPoints, 0, defender.MaxHitPoints)
					log.append({"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": null, "target_sq": null, "damage": dmg, "is_direct": true})
					continue
				var target_card: Card = target["card"]
				var target_sq: Square = target["square"]
				var actual_dmg: int = dmg
				# Flying: half damage from non-ranged attackers (use effective range)
				var att_has_range: bool = unit.HasRange
				if attacker.has_method("has_range_for"):
					att_has_range = attacker.has_range_for(unit)
				if target_card is Unit and (target_card as Unit).Flying and not att_has_range:
					actual_dmg = int(actual_dmg / 2)
					if actual_dmg < 1:
						actual_dmg = 1
				# New unit special effects: Special Ops vs non-flying, Anti Aircraft vs flying
				if unit is SpecialOps and target_card is Unit and not (target_card as Unit).Flying:
					actual_dmg *= 2
				elif unit is AntiAircraft and target_card is Unit and (target_card as Unit).Flying:
					actual_dmg *= 3
				if target_card is Unit:
					(target_card as Unit).HitPoints -= actual_dmg
				elif target_card is Building:
					(target_card as Building).HitPoints -= actual_dmg
				# Fighter Jet splash: also damages tiles adjacent to where it hit
				if unit is FighterJet:
					_apply_fighter_splash(defender, target_sq, actual_dmg)
				_apply_special_effect(unit, target_card)
				log.append({"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": target_card, "target_sq": target_sq, "damage": actual_dmg, "is_direct": false})
				# if target died, allow next hit to pick new target (if remaining attacks)
				if target_card is Unit and (target_card as Unit).HitPoints <= 0:
					_resolve_deaths(defender)
				elif target_card is Building and (target_card as Building).HitPoints <= 0:
					_resolve_deaths(defender)
		_resolve_deaths(defender)
	return log

func _apply_fighter_splash(defender: Player, center_sq: Square, dmg: int):
	var pos = _find_square_pos(defender, center_sq)
	if pos == null:
		return
	var cr: int = pos["r"]
	var cc: int = pos["c"]
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var nr: int = cr + dr
			var nc: int = cc + dc
			if nr < 0 or nr >= defender.Board.size():
				continue
			if nc < 0 or nc >= 10:
				continue
			var sq: Square = (defender.Board[nr] as Row).Squares[nc]
			if sq.Inhabitant == null:
				continue
			var adj: Card = sq.Inhabitant
			var adj_dmg: int = dmg
			if adj is Unit and (adj as Unit).Flying and false: # splash is from ranged FighterJet, so flying halved only if needed? keep same
				pass
			if adj is Unit:
				# splash also respects Flying half-damage if splash source is considered ranged (FighterJet HasRange true, so no halving)
				(adj as Unit).HitPoints -= adj_dmg
			elif adj is Building:
				(adj as Building).HitPoints -= adj_dmg
			if adj is Unit and (adj as Unit).HitPoints <= 0:
				_resolve_deaths(defender)
			elif adj is Building and (adj as Building).HitPoints <= 0:
				_resolve_deaths(defender)

func _find_square_pos(player: Player, sq: Square):
	for r in range(player.Board.size()):
		for c in range(player.Board[r].Squares.size()):
			if player.Board[r].Squares[c] == sq:
				return {"r": r, "c": c}
	return null

func _effective_damage(player: Player, unit: Unit, square: Square) -> int:
	# Use Player helper so modifiers (Guerilla, Aerial Supremacy) apply
	if player.has_method("effective_damage_for"):
		return player.effective_damage_for(unit, square)
	return unit.Damage + Barracks.bonus_if_adjacent(player, square)

func _manhattan_distance(attacker: Player, attacker_sq: Square, defender: Player, target_sq: Square) -> int:
	var a_pos = _find_square_pos(attacker, attacker_sq)
	var d_pos = _find_square_pos(defender, target_sq)
	if a_pos == null or d_pos == null:
		return 9999
	var a_r: int = a_pos.get("r")
	var a_c: int = a_pos.get("c")
	var d_r: int = d_pos.get("r")
	var d_c: int = d_pos.get("c")
	var n: int = 4
	var a_idx: int = Players.find(attacker)
	var d_idx: int = Players.find(defender)
	var a_dist: int
	var d_dist: int
	if a_idx == 0:
		a_dist = a_r
	elif a_idx == 1:
		a_dist = (n - 1) - a_r
	else:
		a_dist = a_r
	if d_idx == 0:
		d_dist = d_r
	elif d_idx == 1:
		d_dist = (n - 1) - d_r
	else:
		d_dist = (n - 1) - d_r
	var row_dist: int = a_dist + d_dist + 1
	var col_dist: int = absi(a_c - d_c)
	return row_dist + col_dist

func _pick_target_manhattan(defender: Player, attacker: Player, attacker_sq: Square, has_range: bool, rng: RandomNumberGenerator):
	if has_range:
		var all: Array = []
		for row in defender.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null:
					var c: Card = sq.Inhabitant
					var hp: int = (c as Unit).HitPoints if c is Unit else (c as Building).HitPoints if c is Building else 1
					if hp > 0:
						all.append({"card": c, "square": sq})
		if all.is_empty():
			return null
		return all[rng.randi_range(0, all.size() - 1)]
	# Deterministic Manhattan closest to match arrow (arrow shows first minimal)
	var best: int = 9999
	var candidates: Array = []
	for row in defender.Board:
		for sq in row.Squares:
			if sq.Inhabitant == null:
				continue
			var c2: Card = sq.Inhabitant
			var hp2: int = (c2 as Unit).HitPoints if c2 is Unit else (c2 as Building).HitPoints if c2 is Building else 1
			if hp2 <= 0:
				continue
			var d: int = _manhattan_distance(attacker, attacker_sq, defender, sq)
			if d < best:
				best = d
				candidates = [{"card": c2, "square": sq}]
			elif d == best:
				candidates.append({"card": c2, "square": sq})
	if candidates.is_empty():
		return null
	# Deterministic first to match arrow (was random among ties, now first for consistency)
	return candidates[0]

func predict_target(attacker: Player, attacker_sq: Square, defender: Player) -> Dictionary:
	if attacker_sq == null:
		return {}
	var best: int = 9999
	var best_sq: Square = null
	var best_card: Card = null
	for row in defender.Board:
		for sq in row.Squares:
			if sq.Inhabitant == null:
				continue
			var c: Card = sq.Inhabitant
			var hp: int = (c as Unit).HitPoints if c is Unit else (c as Building).HitPoints if c is Building else 1
			if hp <= 0:
				continue
			var d: int = _manhattan_distance(attacker, attacker_sq, defender, sq)
			if d < best:
				best = d
				best_sq = sq
				best_card = c
	return {"card": best_card, "square": best_sq, "distance": best} if best_sq != null else {}

func _pick_target(defender: Player, has_range: bool, rng: RandomNumberGenerator):
	# Only living cards (HP >0) are targetable — prevents overkill on already-lethal targets
	if has_range:
		var all: Array = []
		for row in defender.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null:
					var c: Card = sq.Inhabitant
					var hp: int = (c as Unit).HitPoints if c is Unit else (c as Building).HitPoints if c is Building else 1
					if hp > 0:
						all.append({"card": c, "square": sq})
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
					var c2: Card = sq.Inhabitant
					var hp2: int = (c2 as Unit).HitPoints if c2 is Unit else (c2 as Building).HitPoints if c2 is Building else 1
					if hp2 > 0:
						candidates.append({"card": c2, "square": sq})
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
				# Keep HitPoints within limits (never above max, never below 0 for gauge)
				player.HitPoints = clamp(player.HitPoints, 0, player.MaxHitPoints)
				player.Graveyard.append(c)
				sq.clear()
