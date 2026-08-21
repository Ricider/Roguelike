extends GameObject
class_name Modifier

var modifier_name: String = ""
var Effect: String = ""
var InfluenceCost: int = 0
var card_name: String = "" # alias for shop UI generic handling (Card compatibility)

func _init(name: String = "", effect: String = "", cost: int = 0):
	super._init()
	modifier_name = name
	Effect = effect
	InfluenceCost = cost
	card_name = name

static func all_modifiers() -> Array:
	return [
		Modifier.new("Conscription", "Gain 15 additional BioSupply every turn, but earn 50% less MoneySupply", 50),
		Modifier.new("Guerilla Warfare", "Your cards that have a BioCost higher than MoneyCost deal 100% more damage, but the ones that have BioCost lower than MoneyCost have 50% less HP", 70),
		Modifier.new("State of emergency", "You gain 3 HitPoints every turn", 90),
		Modifier.new("Fanaticism", "Your buildings have 50% less HP, but Units have 100% more", 40),
		Modifier.new("Corruption", "Your buildings have 50% less HP, but you gain +10 MoneySupply every turn", 40),
		Modifier.new("Advanced Robotics", "All units have HasRange set to true, but they cost +5 extra MoneySupply", 100),
		Modifier.new("Aerial Supremacy", "If a unit has Flying set to true then they deal +2 damage, but they cost +5 extra MoneySupply", 80),
	]

static func by_name(name: String) -> Modifier:
	for m in all_modifiers():
		if (m as Modifier).modifier_name == name:
			return m as Modifier
	return null
