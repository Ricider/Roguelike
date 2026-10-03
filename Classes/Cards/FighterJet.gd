extends Unit
class_name FighterJet

func _init():
	super._init(14, 4, true, 35, 5, "Fighter Jet", true, 25)
	SpecialEffect = "Strike jet with Range: hits a [random target] of the closest enemy nation and [splashes] the same damage onto that nation's cards next to it. Takes half damage from attackers without Range; flies 4 hexes a turn."
