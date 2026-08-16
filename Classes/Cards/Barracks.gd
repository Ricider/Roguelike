extends Building
class_name Barracks

func _init():
	super._init(70, 2, 20, 25, "Barracks")
	SpecialEffect = "Friendly units in adjacent squares have +2 damage"
