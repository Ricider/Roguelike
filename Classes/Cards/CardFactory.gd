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
	# Insurgents: [5 wall, 10 Infantry, 8 Drones, 2 Tank 1 Factory, 3 Housing, 2 Barrack, 2 Anti Aircraft] =33
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
	for i in range(2):
		deck.append(AntiAircraft.new())
	deck.shuffle()
	return deck

static func make_state_troops_deck() -> Array:
	# State Troops: [10 wall, 10 Infantry, 3 Tank, 3 Artilery, 2 Factory, 2 Housing, 1 Barrack, 3 Anti Aircraft] =34
	var deck: Array = make_starting_deck()
	for i in range(3):
		deck.append(AntiAircraft.new())
	deck.shuffle()
	return deck

static func make_fundamentalists_deck() -> Array:
	# Fundamentalists: [5 wall, 15 Infantry, 4 Artillery, 2 Tank, 4 Barrack, 5 Anti Aircraft, 2 Housing, 1 Factory] =38
	var deck: Array = []
	for i in range(5):
		deck.append(Wall.new())
	for i in range(15):
		deck.append(Infantry.new())
	for i in range(4):
		deck.append(Artilery.new())
	for i in range(2):
		deck.append(Tank.new())
	for i in range(4):
		deck.append(Barracks.new())
	for i in range(5):
		deck.append(AntiAircraft.new())
	for i in range(2):
		deck.append(Housing.new())
	for i in range(1):
		deck.append(Factory.new())
	deck.shuffle()
	return deck

static func make_mercenaries_deck() -> Array:
	# Mercenaries: [4 wall, 9 Infantry, 4 Artillery, 4 Tank, 2 Drones, 1 Barrack, 1 Interceptor, 5 Anti Aircraft] =30
	var deck: Array = []
	for i in range(4):
		deck.append(Wall.new())
	for i in range(9):
		deck.append(Infantry.new())
	for i in range(4):
		deck.append(Artilery.new())
	for i in range(4):
		deck.append(Tank.new())
	for i in range(2):
		deck.append(Drone.new())
	for i in range(1):
		deck.append(Barracks.new())
	for i in range(1):
		deck.append(Interceptor.new())
	for i in range(5):
		deck.append(AntiAircraft.new())
	deck.shuffle()
	return deck

static func make_peace_keepers_deck() -> Array:
	# Peace Keepers: [12 wall, 6 Infantry, 5 Drones, 1 Fighter Jet, 1 Corporation, 2 Housing, 2 Barrack, 3 Interceptor, 3 Anti Aircraft] =35
	var deck: Array = []
	for i in range(12):
		deck.append(Wall.new())
	for i in range(6):
		deck.append(Infantry.new())
	for i in range(5):
		deck.append(Drone.new())
	for i in range(1):
		deck.append(FighterJet.new())
	for i in range(1):
		deck.append(Corporation.new())
	for i in range(2):
		deck.append(Housing.new())
	for i in range(2):
		deck.append(Barracks.new())
	for i in range(3):
		deck.append(Interceptor.new())
	for i in range(3):
		deck.append(AntiAircraft.new())
	deck.shuffle()
	return deck

static func make_horde_deck() -> Array:
	# Horde: [10 wall, 15 Infantry, 8 Drones, 2 Tank, 2 Artillery, 3 Fighter Jet, 3 Factory, 1 Housing, 2 Barrack, 3 Anti Aircraft, 3 Special Ops] =52
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
	for i in range(3):
		deck.append(FighterJet.new())
	for i in range(3):
		deck.append(Factory.new())
	for i in range(1):
		deck.append(Housing.new())
	for i in range(2):
		deck.append(Barracks.new())
	for i in range(3):
		deck.append(AntiAircraft.new())
	for i in range(3):
		deck.append(SpecialOps.new())
	deck.shuffle()
	return deck

static func make_coalition_army_deck() -> Array:
	# Coalition Army: [10 wall, 8 Infantry, 8 Drones, 2 Tank, 2 Artillery, 2 Rocket Launcher, 4 Fighter Jet, 3 Factory, 1 Housing, 2 Barrack, 1 Corporation, 2 Special Ops, 1 Interceptor] =46
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
	for i in range(2):
		deck.append(RocketLauncher.new())
	for i in range(4):
		deck.append(FighterJet.new())
	for i in range(3):
		deck.append(Factory.new())
	for i in range(1):
		deck.append(Housing.new())
	for i in range(2):
		deck.append(Barracks.new())
	for i in range(1):
		deck.append(Corporation.new())
	for i in range(2):
		deck.append(SpecialOps.new())
	for i in range(1):
		deck.append(Interceptor.new())
	deck.shuffle()
	return deck

static func make_euro_army_deck() -> Array:
	# Euro Army kept for backward compat (old spec 41) — alias to coalition without RL/Corp for legacy tests
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

static func make_corporate_troops_deck() -> Array:
	# Corporate Troops: [8 wall, 4 Infantry, 12 Drones, 3 Fighter Jet, 1 Corporation, 1 Housing, 2 Barrack, 3 Rocket Launcher, 2 Interceptor] =36
	var deck: Array = []
	for i in range(8):
		deck.append(Wall.new())
	for i in range(4):
		deck.append(Infantry.new())
	for i in range(12):
		deck.append(Drone.new())
	for i in range(3):
		deck.append(FighterJet.new())
	for i in range(1):
		deck.append(Corporation.new())
	for i in range(1):
		deck.append(Housing.new())
	for i in range(2):
		deck.append(Barracks.new())
	for i in range(3):
		deck.append(RocketLauncher.new())
	for i in range(2):
		deck.append(Interceptor.new())
	deck.shuffle()
	return deck

# --- Shop pool helper ---
static func all_card_types() -> Array:
	return [Wall.new(), Infantry.new(), Tank.new(), Artilery.new(), RocketLauncher.new(), Drone.new(), FighterJet.new(), Factory.new(), Barracks.new(), Housing.new(), Corporation.new(), AntiAircraft.new(), SpecialOps.new(), Interceptor.new()]

static func random_shop_offer() -> Array:
	var pool := all_card_types()
	pool.shuffle()
	var offer: Array = []
	for i in range(min(5, pool.size())):
		offer.append(pool[i])
	return offer

static func random_modifier_offer() -> Array:
	var pool := Modifier.all_modifiers()
	pool.shuffle()
	var offer: Array = []
	for i in range(min(3, pool.size())):
		offer.append(pool[i])
	return offer

static func make_insurgents_player() -> AIPlayer:
	var p := AIPlayer.new(120, 120, 10, 1, "Insurgents", "Sparse mountain village", 10)
	p.DrawPile = make_insurgents_deck()
	p.Modifiers = [Modifier.new("Guerilla Warfare", "Your cards that have a BioCost higher than MoneyCost deal 100% more damage, but the ones that have BioCost lower than MoneyCost have 50% less HP", 25)]
	return p

static func make_state_troops_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(180, 100, 20, 2, "State Troops", "Middle Eastern town, add some mosques around, don't make the entire thing a desert", 20)
	# Back row is furthest from enemy: row 3 for human (bottom), row 0 for AI (top)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	var h1 := Housing.new()
	p.Board[back_row].Squares[positions[0]].place(h1)
	p.apply_hitpoints_modifier(h1)
	var inf1 := Infantry.new()
	p.Board[back_row].Squares[positions[1]].place(inf1)
	p.apply_hitpoints_modifier(inf1)
	p.DrawPile = make_state_troops_deck()
	p.Modifiers = [Modifier.new("State of emergency", "You gain 3 HitPoints every turn", 20)]
	return p

static func make_fundamentalists_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(150, 60, 60, 3, "Fundamentalists", "Cyberpunk Skyrises", 50)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	var h1 := Housing.new()
	p.Board[back_row].Squares[positions[0]].place(h1)
	p.apply_hitpoints_modifier(h1)
	var h2 := Housing.new()
	p.Board[back_row].Squares[positions[1]].place(h2)
	p.apply_hitpoints_modifier(h2)
	p.DrawPile = make_fundamentalists_deck()
	p.Modifiers = [Modifier.new("Fanaticism", "Your buildings have 50% less HP, but Units have 100% more", 30)]
	return p

static func make_mercenaries_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(130, 60, 60, 4, "Mercenaries", "Warzone, fires and rubble everywhere", 50)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	var b1 := Barracks.new()
	p.Board[back_row].Squares[positions[0]].place(b1)
	p.apply_hitpoints_modifier(b1)
	var b2 := Barracks.new()
	p.Board[back_row].Squares[positions[1]].place(b2)
	p.apply_hitpoints_modifier(b2)
	p.DrawPile = make_mercenaries_deck()
	p.Modifiers = [Modifier.new("Corruption", "Your buildings have 50% less HP, but you gain +10 MoneySupply every turn", 30)]
	return p

static func make_peace_keepers_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(90, 20, 80, 5, "Peace Keepers", "United nation tents", 50)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	var i1 := Interceptor.new()
	p.Board[back_row].Squares[positions[0]].place(i1)
	p.apply_hitpoints_modifier(i1)
	var i2 := Interceptor.new()
	p.Board[back_row].Squares[positions[1]].place(i2)
	p.apply_hitpoints_modifier(i2)
	var b1 := Barracks.new()
	p.Board[back_row].Squares[positions[2]].place(b1)
	p.apply_hitpoints_modifier(b1)
	p.DrawPile = make_peace_keepers_deck()
	p.Modifiers = [Modifier.new("Defensive Doctrine", "Your cards have +10 hp, but they deal -1 damage", 40)]
	return p

static func make_horde_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(200, 160, 0, 6, "Horde", "Russian style city, snowy, add few trees", 25)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	# 2 Factory, 2 Housing and 1 Artilery, 2 tank randomly placed at back row, all damaged down to 5 hp (7 cards)
	var to_place: Array = [Factory.new(), Factory.new(), Housing.new(), Housing.new(), Artilery.new(), Tank.new(), Tank.new()]
	for i in range(to_place.size()):
		var card: Card = to_place[i]
		if card is Unit:
			(card as Unit).HitPoints = 5
		elif card is Building:
			(card as Building).HitPoints = 5
		p.Board[back_row].Squares[positions[i]].place(card)
	p.DrawPile = make_horde_deck()
	p.Modifiers = [Modifier.new("Conscription", "Gain 15 additional BioSupply every turn, but earn 50% less MoneySupply", 35)]
	return p

static func make_coalition_army_player(for_human: bool = false) -> AIPlayer:
	var p := AIPlayer.new(120, 80, 50, 7, "Coalition Army", "City with european style towers", 50)
	# Board: 2 Housing and 1 Factory randomly placed at back row furthest from enemy - row 3 for human, row 0 for AI
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	var h1 := Housing.new()
	p.Board[back_row].Squares[positions[0]].place(h1)
	p.apply_hitpoints_modifier(h1)
	var h2 := Housing.new()
	p.Board[back_row].Squares[positions[1]].place(h2)
	p.apply_hitpoints_modifier(h2)
	var f1 := Factory.new()
	p.Board[back_row].Squares[positions[2]].place(f1)
	p.apply_hitpoints_modifier(f1)
	p.DrawPile = make_coalition_army_deck()
	p.Modifiers = [Modifier.new("Aerial Supremacy", "If a unit has Flying set to true then they deal +2 damage, but they cost +5 extra MoneySupply", 50)]
	return p

static func make_euro_army_player(for_human: bool = false) -> AIPlayer:
	# Backward compat alias — Euro Army same stats as Coalition Army per rename
	var p := AIPlayer.new(120, 80, 50, 5, "Euro Army", "City with european style towers", 50)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	var h1 := Housing.new()
	p.Board[back_row].Squares[positions[0]].place(h1)
	p.apply_hitpoints_modifier(h1)
	var h2 := Housing.new()
	p.Board[back_row].Squares[positions[1]].place(h2)
	p.apply_hitpoints_modifier(h2)
	var f1 := Factory.new()
	p.Board[back_row].Squares[positions[2]].place(f1)
	p.apply_hitpoints_modifier(f1)
	p.DrawPile = make_euro_army_deck()
	return p

static func make_corporate_troops_player(for_human: bool = false) -> AIPlayer:
	# Corporate Troops: HitPoints 70, Background Cyberpunk Skyrises, Board 2 Corporation at back row, Diff 8, Bio 10 Money 100 Influence 50
	var p := AIPlayer.new(70, 10, 100, 8, "Corporate Troops", "Cyberpunk Skyrises", 50)
	var back_row: int = p.Board.size() - 1 if for_human else 0
	var positions: Array = []
	for c in range(10):
		positions.append(c)
	positions.shuffle()
	var c1 := Corporation.new()
	p.Board[back_row].Squares[positions[0]].place(c1)
	p.apply_hitpoints_modifier(c1)
	var c2 := Corporation.new()
	p.Board[back_row].Squares[positions[1]].place(c2)
	p.apply_hitpoints_modifier(c2)
	p.DrawPile = make_corporate_troops_deck()
	p.Modifiers = [Modifier.new("Advanced Robotics", "All units have HasRange set to true, but they cost +5 extra MoneySupply", 60)]
	return p

static func all_enemy_players_sorted() -> Array:
	var arr: Array = [make_insurgents_player(), make_state_troops_player(), make_fundamentalists_player(), make_mercenaries_player(), make_peace_keepers_player(), make_horde_player(), make_coalition_army_player(), make_corporate_troops_player()]
	arr.sort_custom(func(a, b): return a.Difficulty < b.Difficulty)
	return arr

static func enemy_sequence_for_player(chosen_name: String) -> Array:
	var all := all_enemy_players_sorted()
	var seq: Array = []
	for e in all:
		if e.display_name == chosen_name:
			continue
		# Also exclude Euro alias duplicate — only Coalition represents difficulty 5
		if e.display_name == "Euro Army":
			continue
		seq.append(e)
	# Ensure Insurgents first, then sorted by difficulty
	seq.sort_custom(func(a, b):
		if a.display_name == "Insurgents": return true
		if b.display_name == "Insurgents": return false
		return a.Difficulty < b.Difficulty
	)
	return seq
