extends Building
class_name Housing

func _init():
	super._init(50, 2, 20, 30, "Housing")
	SpecialEffect = "In your economy phase gain 4% more BioSupply"

static func extra_bio_rate(player: Player) -> float:
	var n: int = 0
	for row in player.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null and sq.Inhabitant is Housing:
				n += 1
	return n * 0.04

static func bio_rate(player: Player) -> float:
	return 1.10 + extra_bio_rate(player)
