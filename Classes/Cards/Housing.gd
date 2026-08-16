extends Building
class_name Housing

func _init():
	super._init(120, 4, 80, 40, "Housing")
	SpecialEffect = "In your economy phase gain 4% more BioSupply"

static func extra_bio_rate(player: Player) -> float:
	var n: int = 0
	for row in player.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null and sq.Inhabitant is Housing:
				n += 1
	return n * 0.04

static func bio_rate(player: Player) -> float:
	return 1.1 + extra_bio_rate(player)
