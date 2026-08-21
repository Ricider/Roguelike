extends Unit
class_name FighterJet

func _init():
	super._init(14, 4, true, 35, 5, "Fighter Jet", true, 25)
	SpecialEffect = "Also damages tiles adjacent to where it hit"
