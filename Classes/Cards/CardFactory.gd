extends RefCounted
class_name CardFactory

static func make_starting_deck() -> Array:
	var deck: Array = []
	for i in range(6):
		deck.append(Infantry.new())
	for i in range(3):
		deck.append(Tank.new())
	for i in range(3):
		deck.append(Artilery.new())
	for i in range(4):
		deck.append(Factory.new())
	for i in range(3):
		deck.append(Barracks.new())
	for i in range(2):
		deck.append(Housing.new())
	deck.shuffle()
	return deck
