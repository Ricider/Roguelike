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
	# Bio +10%, Money +2 + building income
	player.BioSupply = int(player.BioSupply * 1.1)
	# ensure at least +1 if rounding down and >0?
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

static func combat_phase(state: CombatState):
	# Each player's cards deal damage to random enemy prioritizing closest row
	# We collect all attackers first, then resolve
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(state.Players.size()):
		var attacker: Player = state.Players[i]
		var defender: Player = state.Players[1 - i]
		# gather attackers
		var attackers: Array = []
		for row in attacker.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null and sq.Inhabitant is Unit:
					attackers.append({"card": sq.Inhabitant, "square": sq})
		for info in attackers:
			var unit: Unit = info["card"]
			if unit.HitPoints <= 0: continue
			var target = _pick_target(defender, unit.HasRange, rng)
			if target == null:
				# no enemy units, hit player directly? spec says random enemy - if no board enemies, we skip
				# alternative: damage to player HP directly
				defender.HitPoints -= unit.Damage
				continue
			var target_card: Card = target["card"]
			# deal damage
			if target_card is Unit:
				(target_card as Unit).HitPoints -= unit.Damage
			elif target_card is Building:
				(target_card as Building).HitPoints -= unit.Damage
			# special effect after damage (none defined yet, placeholder)
			_apply_special_effect(unit, target_card)
		# after all damage, check deaths for defender
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
	# Per player spec: create a deck - spec doesn't define exact deck, we make 10 infantry + 5 factories shuffled
	var deck: Array = []
	for i in range(10):
		deck.append(Infantry.new())
	for i in range(5):
		deck.append(Factory.new())
	deck.shuffle()
	return deck
