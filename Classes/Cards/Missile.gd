extends Item
class_name Missile

func _init():
	super._init("Missile", 30, 60, 6, 1, {"Barracks": 6, "Interceptor": 8, "Airport": 12})
	SpecialEffect = "One use: fire it from one of your [Barracks] (6 hexes), [Interceptors] (8) or [Airports] (12) at any hex in range. Every enemy card and flag within [1 hex] of where it lands (7 hexes) takes [6 damage]. An enemy Interceptor within 3 hexes of the target halves it."
