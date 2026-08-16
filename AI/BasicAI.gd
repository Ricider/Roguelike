extends RefCounted
class_name BasicAI

# Simple AI: plays affordable cards randomly, then ends turn.
# Uses same economy/build/combat phases as player.

var rng := RandomNumberGenerator.new()

func _init():
	rng.randomize()

func take_build_turn(player: Player):
	# Try to play cards from hand in random order if affordable and space exists
	var hand_copy: Array = player.Hand.duplicate()
	hand_copy.shuffle()
	for card in hand_copy:
		if player.MoneySupply < card.MoneyCost: continue
		if player.BioSupply < card.BioCost: continue
		var empty: Array = []
		for row in player.Board:
			for sq in row.Squares:
				if sq.is_empty():
					empty.append(sq)
		if empty.is_empty():
			break
		var sq: Square = empty[rng.randi_range(0, empty.size()-1)]
		# pay costs
		player.MoneySupply -= card.MoneyCost
		player.BioSupply -= card.BioCost
		sq.place(card)
		player.Hand.erase(card)
		# 50% chance to stop early to leave some cards
		if rng.randf() < 0.3:
			break
