extends Card
class_name Building

var HitPoints: int = 50
var Income: int = 0 # MoneyIncome per turn

func _init(hp: int = 50, income: int = 0, money_cost: int = 0, bio_cost: int = 0, name: String = "Building", influence_cost: int = 0):
	super._init()
	HitPoints = hp
	Income = income
	MoneyCost = money_cost
	BioCost = bio_cost
	InfluenceCost = influence_cost
	card_name = name
