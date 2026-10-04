extends Unit
class_name Howitzer

func _init():
	super._init(12, 2, true, 25, 5, "Howitzer", false, 30)
	SpecialEffect = "Heavy guns that fire [4 shots] every turn, each at a [random target] of the closest enemy nation within [8 hexes]. Light damage per shot. 3 hexes a turn."
