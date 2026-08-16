extends RefCounted
class_name CardFactory

static func make_starting_deck() -> Array:
	# Per spec: DrawPile [5 Infantry, 2 Tank, 2 Artillery, 2 Factory, 2 Housing, 1 Barrack]
	var deck: Array = []
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
	deck.shuffle()
	return deck
