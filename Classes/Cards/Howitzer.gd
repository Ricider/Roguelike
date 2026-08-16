extends Unit
class_name Howitzer

func _init():
	super._init(8, 2, true, 25, 4, "Howitzer")
	SpecialEffect = "attacks 4 times every Combat Phase"
