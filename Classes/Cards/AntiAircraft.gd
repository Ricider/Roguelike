extends Unit
class_name AntiAircraft

func _init():
	super._init(10, 3, false, 10, 5, "Anti Aircraft", false, 15)
	SpecialEffect = "Deals +200% damage to cards with Flying set to true"
