extends GameObject
class_name Player

var HitPoints: int = 100
var Board: Array = [] # Row[3]
var BioSupply: int = 100
var MoneySupply: int = 20
var DrawPile: Array = [] # Card[]
var DiscardPile: Array = [] # Card[]
var Hand: Array = [] # Card[]
var Graveyard: Array = [] # Card[]

func _init(hp: int = 100, bio: int = 100, money: int = 20):
	super._init()
	HitPoints = hp
	BioSupply = bio
	MoneySupply = money
	Board = []
	for i in range(3):
		Board.append(Row.new())
	DrawPile = []
	DiscardPile = []
	Hand = []
	Graveyard = []

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
	while Hand.size() < 5:
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
	BioSupply = int(BioSupply * rate)
	if BioSupply == 0:
		BioSupply = 1
	MoneySupply += 2 + total_money_income()
	draw_cards()

func discard_hand():
	for c in Hand:
		DiscardPile.append(c)
	Hand.clear()

func play_card(card: Card, row_idx: int, col_idx: int) -> bool:
	if not (0 <= row_idx and row_idx < 3 and 0 <= col_idx and col_idx < 7):
		return false
	if not Hand.has(card):
		return false
	if MoneySupply < card.MoneyCost:
		return false
	if BioSupply < card.BioCost:
		return false
	var sq: Square = (Board[row_idx] as Row).Squares[col_idx]
	if not sq.is_empty():
		return false
	MoneySupply -= card.MoneyCost
	BioSupply -= card.BioCost
	sq.place(card)
	Hand.erase(card)
	return true
