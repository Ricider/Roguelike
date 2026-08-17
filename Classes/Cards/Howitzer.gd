extends Unit
class_name Howitzer

func _init():
	super._init(12, 2, true, 25, 5, "Howitzer", false)
	SpecialEffect = "attacks 4 times every Combat Phase"
