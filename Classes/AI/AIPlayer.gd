extends Player
class_name AIPlayer

var rng := RandomNumberGenerator.new()

func _init(hp: int = 100, bio: int = 100, money: int = 20, difficulty: int = 1, name: String = "", background: String = ""):
	super._init(hp, bio, money, difficulty, name, background)
	rng.randomize()

func take_build_turn():
	var hand_copy: Array = Hand.duplicate()
	hand_copy.shuffle()
	for card in hand_copy:
		if MoneySupply < card.MoneyCost:
			continue
		if BioSupply < card.BioCost:
			continue
		var empty: Array = get_empty_squares()
		if empty.is_empty():
			break
		var sq: Square = empty[rng.randi_range(0, empty.size() - 1)]
		MoneySupply -= card.MoneyCost
		BioSupply -= card.BioCost
		sq.place(card)
		Hand.erase(card)
		if rng.randf() < 0.3:
			break
