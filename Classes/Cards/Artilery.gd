extends Unit
class_name Artilery

func _init():
	super._init(12, 8, true, 20, 8, "Artilery", false, 20)
	SpecialEffect = "Long-range gun: every turn it hits a [random target] of the closest enemy nation, however far away. Slow to haul: 1 hex a turn."
