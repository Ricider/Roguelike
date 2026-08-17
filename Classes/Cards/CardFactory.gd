extends RefCounted
class_name CardFactory

static func make_starting_deck() -> Array:
	# JohnDoe: [10 wall, 10 Infantry, 3 Tank, 3 Artilery, 2 Factory, 2 Housing, 1 Barrack] =31
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
		deck.append(Factory.new())
	for i in range(2):
		deck.append(Housing.new())
	for i in range(1):
		deck.append(Barracks.new())
	deck.shuffle()
	return deck

static func make_insurgents_deck() -> Array:
	# Insurgents: [5 wall, 10 Infantry, 8 Drones, 2 Tank 1 Factory, 3 Housing, 2 Barrack] =31
	var deck: Array = []
	for i in range(5):
		deck.append(Wall.new())
	for i in range(10):
		deck.append(Infantry.new())
	for i in range(8):
		deck.append(Drone.new())
	for i in range(2):
		deck.append(Tank.new())
	for i in range(1):
		deck.append(Factory.new())
	for i in range(3):
		deck.append(Housing.new())
	for i in range(2):
		deck.append(Barracks.new())
	deck.shuffle()
	return deck

static func make_euro_army_deck() -> Array:
	# Euro Army: [10 wall, 8 Infantry, 8 Drones, 2 Tank, 2 Artilery, 4 Fighter Jet, 4 Factory, 1 Housing, 2 Barrack] =41
	var deck: Array = []
	for i in range(10):
		deck.append(Wall.new())
	for i in range(8):
		deck.append(Infantry.new())
	for i in range(8):
		deck.append(Drone.new())
	for i in range(2):
		deck.append(Tank.new())
	for i in range(2):
		deck.append(Artilery.new())
	for i in range(4):
		deck.append(FighterJet.new())
	for i in range(4):
		deck.append(Factory.new())
	for i in range(1):
		deck.append(Housing.new())
	for i in range(2):
		deck.append(Barracks.new())
	deck.shuffle()
	return deck

static func make_euro_army_player() -> AIPlayer:
	var p := AIPlayer.new(60, 80, 50, 2, "Euro Army")
	# Board: 2 Housing and 1 Factory randomly placed at back row (row 3)
	var back_row: int = 3
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	p.Board[back_row].Squares[positions[0]].place(Housing.new())
	p.Board[back_row].Squares[positions[1]].place(Housing.new())
	p.Board[back_row].Squares[positions[2]].place(Factory.new())
	p.DrawPile = make_euro_army_deck()
	return p
