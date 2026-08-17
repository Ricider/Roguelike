extends RefCounted
class_name CardFactory

static func make_starting_deck() -> Array:
	# Per spec updated: DrawPile [10 Wall, 10 Infantry, 3 Tank, 3 Artilery, 2 Rocket Launcher, 2 Factory, 2 Housing, 1 Barrack, 2 Fighter Jet] =35
	var deck: Array = []
	for i in range(10):
		deck.append(Wall.new())
	for i in range(10):
		deck.append(Infantry.new())
	for i in range(3):
		deck.append(Tank.new())
	for i in range(3):
		deck.append(Artilery.new())
	for i in range(2):
		deck.append(RocketLauncher.new())
	for i in range(2):
		deck.append(Factory.new())
	for i in range(2):
		deck.append(Housing.new())
	for i in range(1):
		deck.append(Barracks.new())
	for i in range(2):
		deck.append(FighterJet.new())
	deck.shuffle()
	return deck

static func make_insurgents_deck() -> Array:
	# Per spec: Insurgents [8 Wall, 5 Infantry, 2 Tank, 2 Artilery, 2 Factory, 2 Housing, 1 Barrack, 8 Drone] =30
	var deck: Array = []
	for i in range(8):
		deck.append(Wall.new())
	for i in range(5):
		deck.append(Infantry.new())
	for i in range(2):
		deck.append(Tank.new())
	for i in range(2):
		deck.append(Artilery.new())
	for i in range(2):
		deck.append(Factory.new())
	for i in range(2):
		deck.append(Housing.new())
	for i in range(1):
		deck.append(Barracks.new())
	for i in range(8):
		deck.append(Drone.new())
	deck.shuffle()
	return deck
