extends Unit
class_name Tank

func _init():
	super._init(25, 8, false, 25, 10, "Tank", false, 15)
	SpecialEffect = "Heavy armour with a big gun: shoots the [closest enemy target] every turn. Costs more Money than Bio, so it rolls only 2 hexes a turn."
