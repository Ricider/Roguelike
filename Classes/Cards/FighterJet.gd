extends Unit
class_name FighterJet

func _init():
	super._init(14, 3, false, 45, 10, "Fighter Jet", true, 50)
	SpecialEffect = "Fast strike jet: shoots the [closest enemy target] within [4 hexes] and [splashes] the same damage onto that nation's cards next to it. Takes half damage from attackers without Range; flies 6 hexes a turn. Built at an [Airport] (within 2 hexes) and must stay within [12 hexes] of one: it can't fly further, and loses 2 HP every turn it is out of range."
