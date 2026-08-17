extends Unit
class_name FighterJet

func _init():
	super._init(14, 6, true, 35, 5, "Fighter Jet", true, 40)
	SpecialEffect = "Also damages tiles adjacent to where it hit"
