extends GameObject
class_name Player

var HitPoints: int = 100
var MaxHitPoints: int = 100
var Board: Array = [] # Row[4]
var Difficulty: int = 0
var BackgroundImage: String = ""
var BioSupply: int = 100
var MoneySupply: int = 20
var Influence: int = 0
var DrawPile: Array = [] # Card[]
var DiscardPile: Array = [] # Card[]
var Hand: Array = [] # Card[]
var Graveyard: Array = [] # Card[]
var Modifiers: Array = [] # Modifier[]
var display_name: String = ""

func _init(hp: int = 100, bio: int = 100, money: int = 20, difficulty: int = 0, name: String = "", background: String = "", influence: int = 0):
	super._init()
	HitPoints = hp
	MaxHitPoints = hp
	BioSupply = bio
	MoneySupply = money
	Influence = influence
	Difficulty = difficulty
	display_name = name
	BackgroundImage = background
	Board = []
	for i in range(4):
		Board.append(Row.new())
	DrawPile = []
	DiscardPile = []
	Hand = []
	Graveyard = []
	Modifiers = []

func total_money_income() -> int:
	var income: int = 0
	for row in Board:
		for sq in row.Squares:
			if sq.Inhabitant != null and sq.Inhabitant is Building:
				income += (sq.Inhabitant as Building).Income
	return income

func get_all_board_cards() -> Array:
	var out: Array = []
	for row in Board:
		for sq in row.Squares:
			if sq.Inhabitant != null:
				out.append(sq.Inhabitant)
	return out

func get_empty_squares() -> Array:
	var out: Array = []
	for row in Board:
		for sq in row.Squares:
			if sq.is_empty():
				out.append(sq)
	return out

func draw_cards():
	while Hand.size() < 10:
		if DrawPile.is_empty():
			if DiscardPile.is_empty():
				break
			DrawPile = DiscardPile.duplicate()
			DiscardPile.clear()
			DrawPile.shuffle()
		if not DrawPile.is_empty():
			var c = DrawPile.pop_back()
			Hand.append(c)
		else:
			break

func economy_phase():
	var rate: float = Housing.bio_rate(self)
	BioSupply = int(BioSupply * rate + 5 + 0.0001)
	if BioSupply == 0:
		BioSupply = 1
	# Modifier: Conscription +15 Bio
	if has_modifier("Conscription"):
		BioSupply += 15
	# Cap resources at their limits (Bio 200, Money 200, HP at player's max)
	BioSupply = clamp(BioSupply, 0, 200)
	var money_gain: int = 10 + total_money_income()
	# Modifier: Conscription 50% less MoneySupply
	if has_modifier("Conscription"):
		money_gain = int(money_gain * 0.5)
	# Modifier: Corruption +10 MoneySupply
	if has_modifier("Corruption"):
		money_gain += 10
	MoneySupply += money_gain
	MoneySupply = clamp(MoneySupply, 0, 200)
	# Modifier: State of emergency +3 HP
	if has_modifier("State of emergency"):
		HitPoints = min(HitPoints + 3, MaxHitPoints)
	HitPoints = clamp(HitPoints, 0, MaxHitPoints)
	draw_cards()

func discard_hand():
	for c in Hand:
		DiscardPile.append(c)
	Hand.clear()

func play_card(card: Card, row_idx: int, col_idx: int) -> bool:
	if not (0 <= row_idx and row_idx < Board.size() and 0 <= col_idx and col_idx < 10):
		return false
	if not Hand.has(card):
		return false
	var effective_money: int = get_effective_money_cost(card)
	if MoneySupply < effective_money:
		return false
	if BioSupply < card.BioCost:
		return false
	var sq: Square = (Board[row_idx] as Row).Squares[col_idx]
	if not sq.is_empty():
		return false
	MoneySupply -= effective_money
	BioSupply -= card.BioCost
	# Store base/effective for UI coloring (hand/board show eff vs base)
	var base_hp: int = 0
	if card is Unit:
		base_hp = (card as Unit).HitPoints
	elif card is Building:
		base_hp = (card as Building).HitPoints
	var eff_hp: int = effective_hitpoints_for(card)
	card.set_meta("base_hp", base_hp)
	card.set_meta("eff_hp", eff_hp)
	# Apply HP modifiers before placing (so building/unit starts with modified HP)
	apply_hitpoints_modifier(card)
	sq.place(card)
	Hand.erase(card)
	return true

func get_effective_money_cost(card: Card) -> int:
	var cost: int = card.MoneyCost
	if Corporation != null:
		cost = Corporation.discounted_money_cost(self, cost)
	# Modifiers: Advanced Robotics +5 for all units, Aerial Supremacy +5 for Flying
	if has_modifier("Advanced Robotics") and card is Unit:
		cost += 5
	if has_modifier("Aerial Supremacy") and card is Unit and (card as Unit).Flying:
		cost += 5
	return cost

func has_modifier(name: String) -> bool:
	for m in Modifiers:
		if m is Modifier and (m as Modifier).modifier_name == name:
			return true
		if m is String and m == name:
			return true
	return false

func has_range_for(card: Card) -> bool:
	if card is Unit and has_modifier("Advanced Robotics"):
		return true
	if card is Unit:
		return (card as Unit).HasRange
	return false

func effective_damage_for(card: Card, square: Square) -> int:
	var base: int = 0
	if card is Unit:
		base = (card as Unit).Damage + Barracks.bonus_if_adjacent(self, square)
	else:
		base = 0
	# Modifier: Guerilla Warfare - BioCost > MoneyCost => +100% damage
	if card is Unit or card is Building:
		if has_modifier("Guerilla Warfare"):
			if card.BioCost > card.MoneyCost:
				base *= 2
	# Modifier: Aerial Supremacy - Flying +2 damage
	if card is Unit and has_modifier("Aerial Supremacy") and (card as Unit).Flying:
		base += 2
	return base

func effective_hitpoints_for(card: Card) -> int:
	var hp: int = 0
	if card is Unit:
		hp = (card as Unit).HitPoints
	elif card is Building:
		hp = (card as Building).HitPoints
	else:
		return hp
	# Guerilla Warfare: BioCost < MoneyCost => 50% less HP
	if has_modifier("Guerilla Warfare"):
		if card.BioCost < card.MoneyCost:
			hp = int(hp * 0.5)
			if hp < 1:
				hp = 1
	# Fanaticism: buildings 50% less, units 100% more (double)
	if has_modifier("Fanaticism"):
		if card is Building:
			hp = int(hp * 0.5)
			if hp < 1:
				hp = 1
		elif card is Unit:
			hp = hp * 2
	# Corruption: buildings 50% less HP
	if has_modifier("Corruption"):
		if card is Building:
			hp = int(hp * 0.5)
			if hp < 1:
				hp = 1
	return hp

func apply_hitpoints_modifier(card: Card):
	var new_hp: int = effective_hitpoints_for(card)
	if card is Unit:
		(card as Unit).HitPoints = new_hp
	elif card is Building:
		(card as Building).HitPoints = new_hp

func _base_card_by_name(name: String) -> Card:
	match name:
		"Wall": return Wall.new()
		"Infantry": return Infantry.new()
		"Tank": return Tank.new()
		"Artilery": return Artilery.new()
		"Rocket Launcher": return RocketLauncher.new()
		"Drone": return Drone.new()
		"Fighter Jet": return FighterJet.new()
		"Factory": return Factory.new()
		"Barracks": return Barracks.new()
		"Housing": return Housing.new()
		"Corporation": return Corporation.new()
		"Howitzer": return Howitzer.new()
		_: return null

func base_hitpoints_for(card: Card) -> int:
	var b: Card = _base_card_by_name(card.card_name)
	if b == null:
		return 0
	if b is Unit:
		return (b as Unit).HitPoints
	elif b is Building:
		return (b as Building).HitPoints
	return 0

func base_damage_for(card: Card) -> int:
	var b: Card = _base_card_by_name(card.card_name)
	if b is Unit and b is Unit:
		return (b as Unit).Damage
	return 0

func get_hp_color(card: Card) -> Color:
	var base: int = 0
	var eff: int = 0
	if card.has_meta("base_hp") and card.has_meta("eff_hp"):
		base = card.get_meta("base_hp") as int
		eff = card.get_meta("eff_hp") as int
	else:
		base = base_hitpoints_for(card)
		eff = effective_hitpoints_for(card)
	if eff == 0 or base == 0 or eff == base:
		return Color(1,1,1)
	return Color(0.35, 0.9, 0.35) if eff > base else Color(1, 0.35, 0.35)

func get_dmg_color(card: Card, square: Square) -> Color:
	var base: int = base_damage_for(card)
	var eff: int = effective_damage_for(card, square)
	if eff == base:
		return Color(1,1,1)
	return Color(0.35, 0.9, 0.35) if eff > base else Color(1, 0.35, 0.35)
