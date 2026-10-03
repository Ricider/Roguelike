extends Howitzer
class_name RocketLauncher

func _init():
	super._init()
	card_name = "Rocket Launcher"
	InfluenceCost = 20
	SpecialEffect = "A battery of rockets: [4 shots] every turn, each at a [random target] of the closest enemy nation. Light damage per rocket. 1 hex a turn."
	# Howitzer's stats (12HP 2DMG HasRange, 25/5, fires 4 times) with its own description
