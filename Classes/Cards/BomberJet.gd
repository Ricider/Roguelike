extends Unit
class_name BomberJet

func _init():
	super._init(8, 4, true, 50, 15, "Bomber Jet", true, 60)
	SpecialEffect = "Heavy bomber with Range: hits a [random target] of the closest enemy nation within [8 hexes] and [splashes] the same damage onto that nation's cards next to it. Takes half damage from attackers without Range; flies 6 hexes a turn. Built at an [Airport] (within 2 hexes); within [12 hexes] of one of your Airports it takes [1 less damage] from every hit."
