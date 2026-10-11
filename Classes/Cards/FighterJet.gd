extends Unit
class_name FighterJet

func _init():
	super._init(14, 3, false, 45, 10, "Fighter Jet", true, 50)
	SpecialEffect = "Fast strike jet: shoots the [closest enemy target] within [4 hexes] and [splashes] the same damage onto that nation's cards next to it. Takes half damage from attackers without Range; flies 6 hexes a turn. Must stay within [12 hexes] of one of your [Airports]: it can't be deployed or fly further, and loses 2 HP every turn it is out of range."
