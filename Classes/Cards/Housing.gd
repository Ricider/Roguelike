extends Building
class_name Housing

func _init():
	super._init(50, 2, 20, 30, "Housing", 15)
	SpecialEffect = "In your economy phase gain +8 more BioSupply"

static func count_housing(player: Player) -> int:
	var n: int = 0
	for row in player.Board:
		for sq in row.Squares:
			if sq.Inhabitant != null and sq.Inhabitant is Housing:
				n += 1
	return n

static func extra_bio(player: Player) -> int:
	return count_housing(player) * 8

# Kept for backward compat — old 4% value still 0.04 per housing (not used for economy now)
static func extra_bio_rate(player: Player) -> float:
	return count_housing(player) * 0.04

static func bio_rate(player: Player) -> float:
	return 1.10
