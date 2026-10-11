extends Building
class_name Airport

func _init():
	super._init(25, 0, 25, 15, "Airport", 50)
	SpecialEffect = "Home base for your air force: [Fighter Jets] and [Bomber Jets] are built here (within 2 hexes), and [Drones] can be too, Fighter Jets can only fly within [12 hexes] of one of your Airports, and lose 2 HP every turn they are out of range. [Bomber Jets] within 12 hexes take [1 less damage] from every hit."
