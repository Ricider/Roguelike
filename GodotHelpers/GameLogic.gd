extends RefCounted
class_name GameLogic

# Implements turn phases per spec
static func draw_cards(player: Player):
	# Draw up to 5 cards. Shuffle discard into draw if needed.
	while player.Hand.size() < 5:
		if player.DrawPile.is_empty():
			if player.DiscardPile.is_empty():
				break # no cards left
			# shuffle discard into draw
			player.DrawPile = player.DiscardPile.duplicate()
			player.DiscardPile.clear()
			player.DrawPile.shuffle()
		if not player.DrawPile.is_empty():
			var c = player.DrawPile.pop_back()
			player.Hand.append(c)
		else:
			break

static func economy_phase(player: Player):
	# Bio +10% base +4% per Housing
	var housing_bonus: int = 0
	for row in player.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null and sq.Inhabitant is Housing:
				housing_bonus += 1
	var bio_rate: float = 1.1 + housing_bonus * 0.04
	player.BioSupply = int(player.BioSupply * bio_rate)
	if player.BioSupply == 0:
		player.BioSupply = 1
	player.MoneySupply += 2 + player.total_money_income()
	draw_cards(player)

static func discard_hand(player: Player):
	for c in player.Hand:
		player.DiscardPile.append(c)
	player.Hand.clear()

static func play_card(player: Player, card: Card, row_idx: int, col_idx: int) -> bool:
	if not (0 <= row_idx and row_idx < 3 and 0 <= col_idx and col_idx < 7):
		return false
	if not player.Hand.has(card):
		return false
	if player.MoneySupply < card.MoneyCost: return false
	if player.BioSupply < card.BioCost: return false
	var sq: Square = (player.Board[row_idx] as Row).Squares[col_idx]
	if not sq.is_empty():
		return false
	player.MoneySupply -= card.MoneyCost
	player.BioSupply -= card.BioCost
	sq.place(card)
	player.Hand.erase(card)
	return true

static func _is_adjacent_to_barracks(player: Player, square: Square) -> bool:
	for r_idx in range(player.Board.size()):
		var row: Row = player.Board[r_idx]
		for c_idx in range(row.Squares.size()):
			if row.Squares[c_idx] == square:
				# check 8 neighbors (including diagonals? spec says adjacent squares, assume orthogonal+diagonal)
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0: continue
						var nr: int = r_idx + dr
						var nc: int = c_idx + dc
						if nr < 0 or nr >= player.Board.size(): continue
						if nc < 0 or nc >= 7: continue
						var n_sq: Square = (player.Board[nr] as Row).Squares[nc]
						if n_sq.Inhabitant != null and n_sq.Inhabitant is Barracks:
							return true
				return false
	return false

static func _effective_damage(player: Player, unit: Unit, square: Square) -> int:
	var dmg: int = unit.Damage
	if _is_adjacent_to_barracks(player, square):
		dmg += 2
	return dmg

static func combat_phase(state: CombatState):
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(state.Players.size()):
		var attacker: Player = state.Players[i]
		var defender: Player = state.Players[1 - i]
		var attackers: Array = []
		for row in attacker.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null and sq.Inhabitant is Unit:
					attackers.append({"card": sq.Inhabitant, "square": sq})
		for info in attackers:
			var unit: Unit = info["card"]
			var sq: Square = info["square"]
			if unit.HitPoints <= 0: continue
			var dmg: int = _effective_damage(attacker, unit, sq)
			var target = _pick_target(defender, unit.HasRange, rng)
			if target == null:
				defender.HitPoints -= dmg
				continue
			var target_card: Card = target["card"]
			if target_card is Unit:
				(target_card as Unit).HitPoints -= dmg
			elif target_card is Building:
				(target_card as Building).HitPoints -= dmg
			_apply_special_effect(unit, target_card)
		_resolve_deaths(defender)
		# also check attacker deaths from previous opponent's attacks? handled next iteration

static func _pick_target(defender: Player, has_range: bool, rng: RandomNumberGenerator):
	# Find closest row with enemies (front row = index 2 for defender? Actually defender rows 0..2 where 2 is front facing attacker)
	# For spec: Boards face each other, so closest enemy is front row (closest to attacker)
	# Defender front is row 2 if attacker is 0's opponent? Both boards orientation same, but we define front as row nearest center.
	# For defender, front is row 0 when viewed from attacker's perspective? Simplify: front = Board[0] is closest
	# We define front order: Row 2 is front (closest to enemy), Row 0 is back
	# So check Row 2, then 1, then 0
	var ordered_rows: Array = []
	if has_range:
		# any row
		for row in defender.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null:
					ordered_rows.append({"card": sq.Inhabitant, "square": sq})
		if ordered_rows.is_empty():
			return null
		return ordered_rows[rng.randi_range(0, ordered_rows.size()-1)]
	else:
		# closest row only
		for row_idx in [2, 1, 0]:
			var candidates: Array = []
			var row: Row = defender.Board[row_idx]
			for sq in row.Squares:
				if sq.Inhabitant != null:
					candidates.append({"card": sq.Inhabitant, "square": sq})
			if not candidates.is_empty():
				return candidates[rng.randi_range(0, candidates.size()-1)]
		return null

static func _apply_special_effect(attacker: Card, target: Card):
	# placeholder - spec says "If a card has a special effect defined it is applied during the combat phase after the damage is calculated"
	pass

static func _resolve_deaths(player: Player):
	for row in player.Board:
		for sq in row.Squares:
			var c: Card = sq.Inhabitant
			if c == null: continue
			var hp: int = 0
			if c is Unit:
				hp = (c as Unit).HitPoints
			elif c is Building:
				hp = (c as Building).HitPoints
			if hp <= 0:
				# BioCost deduced from owning player's hp
				player.HitPoints -= c.BioCost
				player.Graveyard.append(c)
				sq.clear()

static func make_starting_deck() -> Array:
	# Deck with all spec cards - balanced for new economy
	var deck: Array = []
	for i in range(6):
		deck.append(Infantry.new())
	for i in range(3):
		deck.append(Tank.new())
	for i in range(3):
		deck.append(Artilery.new())
	for i in range(4):
		deck.append(Factory.new())
	for i in range(3):
		deck.append(Barracks.new())
	for i in range(2):
		deck.append(Housing.new())
	deck.shuffle()
	return deck
