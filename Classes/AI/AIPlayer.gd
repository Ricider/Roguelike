extends Player
class_name AIPlayer

var rng := RandomNumberGenerator.new()

func _init(hp: int = 100, bio: int = 100, money: int = 20, difficulty: int = 1, name: String = "", background: String = "", influence: int = 0):
	super._init(hp, bio, money, difficulty, name, background, influence)
	rng.randomize()

func _is_bonus_vs_opponent(card: Card, opponent: Player) -> bool:
	if opponent == null:
		return false
	# Check opponent board for vulnerable units
	var has_flying: bool = false
	var has_non_flying: bool = false
	for row in opponent.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null and sq.Inhabitant is Unit:
				var u: Unit = sq.Inhabitant as Unit
				if u.Flying:
					has_flying = true
				else:
					has_non_flying = true
				if has_flying and has_non_flying:
					break
		if has_flying and has_non_flying:
			break
	if card is SpecialOps and has_non_flying:
		return true
	if card is AntiAircraft and has_flying:
		return true
	return false

func _get_wall_behind_squares() -> Array:
	var res: Array = []
	var n: int = Board.size()
	var front_row: int = n - 1 # AI front closest to opponent
	for r in range(n):
		for c in range(10):
			var sq: Square = (Board[r] as Row).Squares[c]
			if not sq.is_empty():
				continue
			# Check if there is a Wall directly in front (r+1 same column)
			var nr: int = r + 1
			if nr < n:
				var front_sq: Square = (Board[nr] as Row).Squares[c]
				if front_sq.Inhabitant != null and front_sq.Inhabitant is Wall:
					res.append(sq)
			# Also allow any Wall behind vertically (further front rows same column)
			# If not directly adjacent, check any Wall in same column with row > r
			# But spec says "behind a wall vertically" — we already handle directly behind,
			# additionally check if any Wall in front column exists (broader)
			if res.has(sq):
				continue
			for fr in range(r + 1, n):
				var f_sq: Square = (Board[fr] as Row).Squares[c]
				if f_sq.Inhabitant != null and f_sq.Inhabitant is Wall:
					res.append(sq)
					break
	return res

func _get_best_barracks_square(empty_squares: Array) -> Square:
	var best: Square = null
	var best_score: int = -1
	for sq in empty_squares:
		var pos = _find_square_pos(sq)
		if pos == null:
			continue
		var r: int = pos["r"]
		var c: int = pos["c"]
		var score: int = 0
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr == 0 and dc == 0:
					continue
				var nr: int = r + dr
				var nc: int = c + dc
				if nr < 0 or nr >= Board.size():
					continue
				if nc < 0 or nc >= 10:
					continue
				var n_sq: Square = (Board[nr] as Row).Squares[nc]
				if n_sq.Inhabitant != null:
					score += 1
		if score > best_score:
			best_score = score
			best = sq
	return best

func _find_square_pos(sq: Square):
	for r in range(Board.size()):
		for c in range((Board[r] as Row).Squares.size()):
			if (Board[r] as Row).Squares[c] == sq:
				return {"r": r, "c": c}
	return null

func take_build_turn(opponent: Player = null) -> Array:
	# Try to find opponent via GameState if not provided (for bonus rule)
	if opponent == null and Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		var root := tree.root
		if root != null and root.has_node("/root/GameState"):
			var gs2 = root.get_node("/root/GameState")
			if gs2 != null and gs2.run_player != null:
				if gs2.run_player == self:
					opponent = gs2.get_current_enemy()
				else:
					opponent = gs2.run_player
	var placed: Array = []
	# Build priority ordering for hand
	var hand_copy: Array = Hand.duplicate()
	# Rule 1: If low resources (<10 Bio or Money), prioritize buildings
	var low_resources: bool = BioSupply < 10 or MoneySupply < 10
	# Rule 5: Prioritize bonus damage units
	# Sort hand_copy: primary key = bonus (first), secondary = building priority if low_resources, tertiary = random/shuffle for tie break
	# We implement stable sort: first partition by bonus, then by building
	hand_copy.shuffle() # initial random to avoid deterministic same order each turn
	var buildings: Array = []
	var units: Array = []
	var bonus_cards: Array = []
	var non_bonus: Array = []
	for card in hand_copy:
		if _is_bonus_vs_opponent(card as Card, opponent):
			bonus_cards.append(card)
		else:
			non_bonus.append(card)
	# If low resources, buildings first within each bonus group
	var sorted_hand: Array = []
	if low_resources:
		# Bonus buildings first, then bonus units, then non-bonus buildings, then non-bonus units
		var bonus_buildings: Array = []
		var bonus_units: Array = []
		for c in bonus_cards:
			if c is Building:
				bonus_buildings.append(c)
			else:
				bonus_units.append(c)
		var non_bonus_buildings: Array = []
		var non_bonus_units: Array = []
		for c in non_bonus:
			if c is Building:
				non_bonus_buildings.append(c)
			else:
				non_bonus_units.append(c)
		sorted_hand.append_array(bonus_buildings)
		sorted_hand.append_array(bonus_units)
		sorted_hand.append_array(non_bonus_buildings)
		sorted_hand.append_array(non_bonus_units)
	else:
		# Normal: bonus first (any), then rest (keep original shuffle order within groups)
		sorted_hand.append_array(bonus_cards)
		sorted_hand.append_array(non_bonus)
	hand_copy = sorted_hand

	for card in hand_copy:
		var eff_money: int = get_effective_money_cost(card as Card)
		if MoneySupply < eff_money:
			continue
		if BioSupply < (card as Card).BioCost:
			continue
		var empty: Array = get_empty_squares()
		if empty.is_empty():
			break
		var sq: Square = null
		# Rule 3: Walls only on front row
		if card is Wall:
			var front_row: int = Board.size() - 1
			var front_empty: Array = []
			for c in range(10):
				var f_sq: Square = (Board[front_row] as Row).Squares[c]
				if f_sq.is_empty():
					front_empty.append(f_sq)
			if front_empty.is_empty():
				continue # cannot place wall
			sq = front_empty[rng.randi_range(0, front_empty.size() - 1)]
		elif card is Barracks:
			# Rule 4: most neighbors
			sq = _get_best_barracks_square(empty)
			if sq == null:
				sq = empty[rng.randi_range(0, empty.size() - 1)]
		elif card is Unit:
			# Rule 2: behind wall
			var behind: Array = _get_wall_behind_squares()
			# Intersect behind with empty (behind already empty by definition)
			if not behind.is_empty():
				sq = behind[rng.randi_range(0, behind.size() - 1)]
			else:
				sq = empty[rng.randi_range(0, empty.size() - 1)]
		else:
			# Other buildings: random empty
			sq = empty[rng.randi_range(0, empty.size() - 1)]
		MoneySupply -= eff_money
		BioSupply -= (card as Card).BioCost
		sq.place(card as Card)
		Hand.erase(card)
		placed.append({"card": card, "square": sq})
		if rng.randf() < 0.3:
			break
	return placed
