extends Unit
class_name Drone

func _init():
	super._init(6, 3, false, 5, 0, "Drone", true, 15)
	SpecialEffect = "Cheap flying scout: takes [half damage] from attackers without Range and flies 4 hexes a turn over land or sea. Its small charge only stings."
