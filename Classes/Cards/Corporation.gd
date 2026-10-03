extends Building
class_name Corporation

func _init():
	super._init(25, 12, 70, 20, "Corporation", 25)
	SpecialEffect = "Every card you deploy costs [20% less Money] (each Corporation stacks: two make it 36% less). Also pays 12 Money each turn."

static func money_cost_reduction(player: Player) -> float:
	var n: int = 0
	for row in player.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null and sq.Inhabitant is Corporation:
				n += 1
	for c in player.MapCards: # Corporations standing on the world map count too
		if c is Corporation:
			n += 1
	if n == 0:
		return 1.0
	# 20% per Corporation, stacking multiplicatively? Spec says reduce by 20% — treat as 0.8^n
	# For single test, 1 corporation => 0.8
	var factor: float = 1.0
	for i in range(n):
		factor *= 0.8
	return factor

static func discounted_money_cost(player: Player, base_cost: int) -> int:
	var factor: float = money_cost_reduction(player)
	return int(round(base_cost * factor))
