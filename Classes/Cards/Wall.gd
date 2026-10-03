extends Building
class_name Wall

func _init():
	super._init(20, 0, 10, 0, "Wall", 5)
	SpecialEffect = "Sandbags and concrete: no attack and never moves, but lots of HP for only 10 Money. Enemies without Range shoot the closest target, so a Wall in front of your units soaks up their fire."
