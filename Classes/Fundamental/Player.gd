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
