extends Unit
class_name AntiAircraft

func _init():
	super._init(10, 3, false, 10, 5, "Anti Aircraft", false, 15)
	SpecialEffect = "Flak gun: deals [triple damage] to flying units, and they can't dodge it for half damage. Shoots the [closest enemy target] every turn."
