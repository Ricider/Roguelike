extends Player
class_name AIPlayer

var rng := RandomNumberGenerator.new()

func _init(hp: int = 100, bio: int = 100, money: int = 20, difficulty: int = 1, name: String = "", background: String = "", influence: int = 0):
	super._init(hp, bio, money, difficulty, name, background, influence)
	rng.randomize()

func take_build_turn() -> Array:
	var placed: Array = []
	var hand_copy: Array = Hand.duplicate()
	hand_copy.shuffle()
	for card in hand_copy:
		var eff_money: int = get_effective_money_cost(card)
		if MoneySupply < eff_money:
			continue
		if BioSupply < card.BioCost:
			continue
		var empty: Array = get_empty_squares()
		if empty.is_empty():
			break
		var sq: Square = empty[rng.randi_range(0, empty.size() - 1)]
		MoneySupply -= eff_money
		BioSupply -= card.BioCost
		sq.place(card)
		Hand.erase(card)
		placed.append({"card": card, "square": sq})
		if rng.randf() < 0.3:
			break
	return placed
