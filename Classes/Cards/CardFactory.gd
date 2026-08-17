extends RefCounted
class_name CardFactory

static func make_starting_deck() -> Array:
	# State Troops (was JohnDoe): [10 wall, 10 Infantry, 3 Tank, 3 Artilery, 2 Factory, 2 Housing, 1 Barrack] =31 - per spec Player: State Troops
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

static func make_state_troops_deck() -> Array:
	return make_starting_deck()

static func make_horde_deck() -> Array:
	# Horde: [10 wall, 15 Infantry, 8 Drones, 2 Tank, 2 Artillery, 4 Fighter Jet, 4 Factory, 1 Housing, 2 Barrack] =48? per spec sum
	var deck: Array = []
	for i in range(10):
		deck.append(Wall.new())
	for i in range(15):
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

# --- Shop pool helper ---
static func all_card_types() -> Array:
	return [Wall.new(), Infantry.new(), Tank.new(), Artilery.new(), RocketLauncher.new(), Drone.new(), FighterJet.new(), Factory.new(), Barracks.new(), Housing.new(), Corporation.new()]

static func random_shop_offer() -> Array:
	var pool := all_card_types()
	pool.shuffle()
	var offer: Array = []
	for i in range(min(5, pool.size())):
		offer.append(pool[i])
	return offer

static func make_insurgents_player() -> AIPlayer:
	var p := AIPlayer.new(120, 120, 10, 1, "Insurgents", "Sparse mountain village", 10)
	p.DrawPile = make_insurgents_deck()
	return p

static func make_state_troops_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(100, 100, 20, 2, "State Troops", "Middle Eastern town, add some mosques around, don't make the entire thing a desert", 20)
	# Back row is furthest from enemy: row 3 for human (bottom), row 0 for AI (top)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	p.Board[back_row].Squares[positions[0]].place(Housing.new())
	p.Board[back_row].Squares[positions[1]].place(Infantry.new())
	p.DrawPile = make_state_troops_deck()
	return p

static func make_horde_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(200, 160, 0, 4, "Horde", "Russian style city, snowy, add few trees", 25)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	# 2 Housing and 1 Artilery, 2 tank randomly placed at back row, all damaged down to 5 hp
	var to_place: Array = [Housing.new(), Housing.new(), Artilery.new(), Tank.new(), Tank.new()]
	for i in range(to_place.size()):
		var card: Card = to_place[i]
		if card is Unit:
			(card as Unit).HitPoints = 5
		elif card is Building:
			(card as Building).HitPoints = 5
		p.Board[back_row].Squares[positions[i]].place(card)
	p.DrawPile = make_horde_deck()
	return p

static func make_euro_army_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(60, 80, 50, 5, "Euro Army", "City with european style towers", 50)
	# Board: 2 Housing and 1 Factory randomly placed at back row furthest from enemy - row 3 for human, row 0 for AI
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	p.Board[back_row].Squares[positions[0]].place(Housing.new())
	p.Board[back_row].Squares[positions[1]].place(Housing.new())
	p.Board[back_row].Squares[positions[2]].place(Factory.new())
	p.DrawPile = make_euro_army_deck()
	return p

static func all_enemy_players_sorted() -> Array:
	var arr: Array = [make_insurgents_player(), make_state_troops_player(), make_horde_player(), make_euro_army_player()]
	# Sort by Difficulty ascending per spec: Insurgents 1, State Troops 2, Horde 4, Euro 5
	# But State Troops is playable, not enemy if player chose it — filter later
	arr.sort_custom(func(a, b): return a.Difficulty < b.Difficulty)
	return arr

static func enemy_sequence_for_player(chosen_name: String) -> Array:
	var all := all_enemy_players_sorted()
	var seq: Array = []
	for e in all:
		if e.display_name == chosen_name:
			continue
		# Insurgents is always first per spec "starting with insurgents" then higher difficulty
		seq.append(e)
	# Ensure Insurgents first, then sorted by difficulty
	seq.sort_custom(func(a, b):
		if a.display_name == "Insurgents": return true
		if b.display_name == "Insurgents": return false
		return a.Difficulty < b.Difficulty
	)
	return seq
