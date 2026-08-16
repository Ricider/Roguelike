extends Card
class_name Unit

var HitPoints: int = 10
var Damage: int = 2
var HasRange: bool = false

func _init(hp: int = 10, dmg: int = 2, has_range: bool = false, money_cost: int = 0, bio_cost: int = 0, name: String = "Unit"):
	super._init()
	HitPoints = hp
	Damage = dmg
	HasRange = has_range
	MoneyCost = money_cost
	BioCost = bio_cost
	card_name = name
