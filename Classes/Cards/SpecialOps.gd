extends Unit
class_name SpecialOps

func _init():
	super._init(10, 7, false, 15, 20, "Special Ops", false, 25)
	SpecialEffect = "Elite saboteurs: deal [double damage] to ground units (not to flying units or buildings). Shoots the [closest enemy target] within [4 hexes] every turn."
