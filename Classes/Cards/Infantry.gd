extends Unit
class_name Infantry

func _init():
	super._init(12, 2, false, 5, 15, "Infantry", false, 10)
	SpecialEffect = "The backbone of any army: paid for in people ([BioSupply]) more than money. Shoots the [closest enemy target] every turn and walks 3 hexes a turn."
